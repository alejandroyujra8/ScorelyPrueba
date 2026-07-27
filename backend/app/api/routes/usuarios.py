from typing import Annotated, Any

from fastapi import APIRouter, Depends, HTTPException, Path, Query, status
from psycopg import AsyncConnection, sql
from psycopg.errors import CheckViolation, ForeignKeyViolation, UniqueViolation

from app.api.dependencies.auth import requerir_roles_id
from app.core.database import establecer_usuario_aplicacion, obtener_conexion
from app.core.security import generar_hash_contrasenia
from app.schemas.usuario import (
    ListaUsuariosRespuesta,
    UsuarioActualizar,
    UsuarioContraseniaActualizar,
    UsuarioCrear,
    UsuarioRespuesta,
)


router = APIRouter(prefix="/api/usuarios", tags=["Usuarios"])

ConexionPostgresql = Annotated[AsyncConnection, Depends(obtener_conexion)]
UsuarioAdministrador = Annotated[
    int,
    Depends(requerir_roles_id("ADMINISTRADOR")),
]


CONSULTA_USUARIO = """
    SELECT
        usuario.id_usuario,
        tipo_documento.codigo AS tipo_documento_codigo,
        usuario.numero_documento,
        usuario.nombres,
        usuario.apellido_paterno,
        usuario.apellido_materno,
        usuario.fecha_nacimiento,
        usuario.sexo,
        usuario.correo,
        usuario.telefono,
        usuario.direccion,
        usuario.zona,
        estado.codigo AS estado_codigo,
        usuario.intentos_fallidos,
        usuario.ultimo_acceso,
        usuario.fecha_registro,
        usuario.fecha_actualizacion,
        COALESCE(
            ARRAY_AGG(DISTINCT rol.codigo ORDER BY rol.codigo)
            FILTER (
                WHERE usuario_rol.activo = TRUE
                  AND rol.activo = TRUE
                  AND usuario_rol.fecha_inicio <= CURRENT_DATE
                  AND (
                      usuario_rol.fecha_fin IS NULL
                      OR usuario_rol.fecha_fin >= CURRENT_DATE
                  )
            ),
            ARRAY[]::VARCHAR[]
        ) AS roles
    FROM seguridad.usuario usuario
    INNER JOIN catalogo.tipo_documento tipo_documento
        ON tipo_documento.id_tipo_documento = usuario.id_tipo_documento
    INNER JOIN catalogo.estado_usuario estado
        ON estado.id_estado_usuario = usuario.id_estado_usuario
    LEFT JOIN seguridad.usuario_rol usuario_rol
        ON usuario_rol.id_usuario = usuario.id_usuario
    LEFT JOIN seguridad.rol rol
        ON rol.id_rol = usuario_rol.id_rol
"""


def mensaje_integridad(error: Exception, defecto: str) -> str:
    restriccion = getattr(getattr(error, "diag", None), "constraint_name", None)
    mensajes = {
        "uq_usuario_correo_minuscula": "Ya existe un usuario con ese correo",
        "uq_usuario_documento": "Ya existe un usuario con ese documento",
    }
    return mensajes.get(restriccion, defecto)


async def buscar_usuario(
    conexion: AsyncConnection,
    id_usuario: int,
) -> UsuarioRespuesta:
    cursor = await conexion.execute(
        CONSULTA_USUARIO
        + """
        WHERE usuario.id_usuario = %s
        GROUP BY
            usuario.id_usuario,
            tipo_documento.codigo,
            estado.codigo
        """,
        (id_usuario,),
    )
    fila = await cursor.fetchone()
    if fila is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="El usuario no existe",
        )
    return UsuarioRespuesta.model_validate(fila)


async def obtener_id_catalogo(
    conexion: AsyncConnection,
    esquema_tabla: str,
    columna_id: str,
    codigo: str,
    mensaje: str,
) -> int:
    esquema, tabla = esquema_tabla.split(".", maxsplit=1)
    consulta = sql.SQL(
        """
        SELECT {columna_id} AS id
        FROM {esquema}.{tabla}
        WHERE codigo = %s
          AND activo = TRUE
        """
    ).format(
        columna_id=sql.Identifier(columna_id),
        esquema=sql.Identifier(esquema),
        tabla=sql.Identifier(tabla),
    )
    cursor = await conexion.execute(consulta, (codigo,))
    fila = await cursor.fetchone()
    if fila is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=mensaje,
        )
    return int(fila["id"])


async def sincronizar_roles(
    conexion: AsyncConnection,
    id_usuario: int,
    roles: list[str],
    id_administrador: int,
    usuario_activo: bool,
) -> None:
    cursor = await conexion.execute(
        """
        SELECT codigo, id_rol
        FROM seguridad.rol
        WHERE activo = TRUE
          AND codigo = ANY(%s::varchar[])
        """,
        (roles,),
    )
    filas = await cursor.fetchall()
    ids_por_codigo = {fila["codigo"]: int(fila["id_rol"]) for fila in filas}

    faltantes = set(roles) - set(ids_por_codigo)
    if faltantes:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="No existen los roles: " + ", ".join(sorted(faltantes)),
        )

    cursor = await conexion.execute(
        """
        SELECT rol.codigo, usuario_rol.id_usuario_rol
        FROM seguridad.usuario_rol usuario_rol
        INNER JOIN seguridad.rol rol
            ON rol.id_rol = usuario_rol.id_rol
        WHERE usuario_rol.id_usuario = %s
          AND usuario_rol.activo = TRUE
          AND usuario_rol.fecha_fin IS NULL
        """,
        (id_usuario,),
    )
    activos = {
        fila["codigo"]: int(fila["id_usuario_rol"])
        for fila in await cursor.fetchall()
    }

    for codigo, id_usuario_rol in activos.items():
        if codigo not in roles:
            await conexion.execute(
                """
                UPDATE seguridad.usuario_rol
                SET activo = FALSE,
                    fecha_fin = CURRENT_DATE
                WHERE id_usuario_rol = %s
                """,
                (id_usuario_rol,),
            )

    for codigo in roles:
        if codigo in activos:
            continue
        await conexion.execute(
            """
            INSERT INTO seguridad.usuario_rol (
                id_usuario,
                id_rol,
                fecha_inicio,
                activo,
                asignado_por
            )
            VALUES (%s, %s, CURRENT_DATE, TRUE, %s)
            """,
            (id_usuario, ids_por_codigo[codigo], id_administrador),
        )

    id_estado_activo = await obtener_id_catalogo(
        conexion,
        "catalogo.estado_perfil_deportivo",
        "id_estado_perfil",
        "ACTIVO",
        "No existe el estado ACTIVO para perfiles deportivos",
    )
    id_estado_inactivo = await obtener_id_catalogo(
        conexion,
        "catalogo.estado_perfil_deportivo",
        "id_estado_perfil",
        "INACTIVO",
        "No existe el estado INACTIVO para perfiles deportivos",
    )

    perfiles = {
        "JUGADOR": "jugador",
        "ARBITRO": "arbitro",
        "ORGANIZADOR": "organizador",
    }
    for codigo_rol, tabla in perfiles.items():
        perfil_habilitado = usuario_activo and codigo_rol in roles
        id_estado_perfil = (
            id_estado_activo if perfil_habilitado else id_estado_inactivo
        )
        consulta_actualizar = sql.SQL(
            """
            UPDATE participantes.{tabla}
            SET id_estado_perfil = %s
            WHERE id_usuario = %s
            """
        ).format(tabla=sql.Identifier(tabla))
        cursor = await conexion.execute(
            consulta_actualizar,
            (id_estado_perfil, id_usuario),
        )

        if cursor.rowcount == 0 and codigo_rol in roles:
            consulta_insertar = sql.SQL(
                """
                INSERT INTO participantes.{tabla} (
                    id_usuario,
                    id_estado_perfil
                )
                VALUES (%s, %s)
                """
            ).format(tabla=sql.Identifier(tabla))
            await conexion.execute(
                consulta_insertar,
                (id_usuario, id_estado_perfil),
            )


@router.get("", response_model=ListaUsuariosRespuesta)
async def listar_usuarios(
    conexion: ConexionPostgresql,
    _: UsuarioAdministrador,
    estado: Annotated[str | None, Query(min_length=2, max_length=30)] = None,
    busqueda: Annotated[str | None, Query(min_length=1, max_length=150)] = None,
    limite: Annotated[int, Query(ge=1, le=100)] = 50,
    desplazamiento: Annotated[int, Query(ge=0)] = 0,
) -> ListaUsuariosRespuesta:
    estado_normalizado = estado.strip().upper() if estado else None
    patron = f"%{busqueda.strip()}%" if busqueda else None

    filtros = """
        WHERE (%s::text IS NULL OR estado.codigo = %s)
          AND (
              %s::text IS NULL
              OR usuario.numero_documento ILIKE %s
              OR usuario.nombres ILIKE %s
              OR COALESCE(usuario.apellido_paterno, '') ILIKE %s
              OR usuario.correo ILIKE %s
          )
    """
    parametros_filtro: tuple[Any, ...] = (
        estado_normalizado,
        estado_normalizado,
        patron,
        patron,
        patron,
        patron,
        patron,
    )

    cursor = await conexion.execute(
        """
        SELECT COUNT(*) AS total
        FROM seguridad.usuario usuario
        INNER JOIN catalogo.estado_usuario estado
            ON estado.id_estado_usuario = usuario.id_estado_usuario
        """
        + filtros,
        parametros_filtro,
    )
    total = int((await cursor.fetchone())["total"])

    cursor = await conexion.execute(
        CONSULTA_USUARIO
        + filtros
        + """
        GROUP BY
            usuario.id_usuario,
            tipo_documento.codigo,
            estado.codigo
        ORDER BY usuario.fecha_registro DESC, usuario.id_usuario DESC
        LIMIT %s OFFSET %s
        """,
        parametros_filtro + (limite, desplazamiento),
    )
    filas = await cursor.fetchall()

    return ListaUsuariosRespuesta(
        total=total,
        limite=limite,
        desplazamiento=desplazamiento,
        resultados=[UsuarioRespuesta.model_validate(fila) for fila in filas],
    )


@router.get("/{id_usuario}", response_model=UsuarioRespuesta)
async def obtener_usuario(
    conexion: ConexionPostgresql,
    _: UsuarioAdministrador,
    id_usuario: Annotated[int, Path(ge=1)],
) -> UsuarioRespuesta:
    return await buscar_usuario(conexion, id_usuario)


@router.post(
    "",
    response_model=UsuarioRespuesta,
    status_code=status.HTTP_201_CREATED,
)
async def crear_usuario(
    datos: UsuarioCrear,
    conexion: ConexionPostgresql,
    id_administrador: UsuarioAdministrador,
) -> UsuarioRespuesta:
    await establecer_usuario_aplicacion(conexion, id_administrador)

    id_tipo_documento = await obtener_id_catalogo(
        conexion,
        "catalogo.tipo_documento",
        "id_tipo_documento",
        datos.tipo_documento_codigo,
        "El tipo de documento no existe",
    )
    id_estado_usuario = await obtener_id_catalogo(
        conexion,
        "catalogo.estado_usuario",
        "id_estado_usuario",
        datos.estado_codigo,
        "El estado del usuario no existe",
    )

    try:
        cursor = await conexion.execute(
            """
            INSERT INTO seguridad.usuario (
                id_tipo_documento,
                numero_documento,
                nombres,
                apellido_paterno,
                apellido_materno,
                fecha_nacimiento,
                sexo,
                correo,
                telefono,
                direccion,
                zona,
                contrasenia_hash,
                id_estado_usuario
            )
            VALUES (
                %s, %s, %s, %s, %s, %s, %s,
                %s, %s, %s, %s, %s, %s
            )
            RETURNING id_usuario
            """,
            (
                id_tipo_documento,
                datos.numero_documento,
                datos.nombres,
                datos.apellido_paterno,
                datos.apellido_materno,
                datos.fecha_nacimiento,
                datos.sexo,
                datos.correo.lower(),
                datos.telefono,
                datos.direccion,
                datos.zona,
                generar_hash_contrasenia(datos.contrasenia),
                id_estado_usuario,
            ),
        )
        id_usuario = int((await cursor.fetchone())["id_usuario"])
        await sincronizar_roles(
            conexion,
            id_usuario,
            datos.roles,
            id_administrador,
            datos.estado_codigo == "ACTIVO",
        )
    except (UniqueViolation, CheckViolation, ForeignKeyViolation) as error:
        raise HTTPException(
            status_code=(
                status.HTTP_409_CONFLICT
                if isinstance(error, UniqueViolation)
                else status.HTTP_422_UNPROCESSABLE_ENTITY
            ),
            detail=mensaje_integridad(error, "No se pudo crear el usuario"),
        ) from error

    return await buscar_usuario(conexion, id_usuario)


@router.patch("/{id_usuario}", response_model=UsuarioRespuesta)
async def actualizar_usuario(
    datos: UsuarioActualizar,
    conexion: ConexionPostgresql,
    id_administrador: UsuarioAdministrador,
    id_usuario: Annotated[int, Path(ge=1)],
) -> UsuarioRespuesta:
    actual = await buscar_usuario(conexion, id_usuario)
    cambios = datos.model_dump(exclude_unset=True)

    roles = cambios.pop("roles", None)
    estado_codigo = cambios.get("estado_codigo", actual.estado_codigo)

    if id_usuario == id_administrador:
        if estado_codigo != "ACTIVO":
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="No puede desactivar su propia cuenta",
            )
        if roles is not None and "ADMINISTRADOR" not in roles:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="No puede retirar su propio rol ADMINISTRADOR",
            )

    roles_finales = roles if roles is not None else actual.roles
    if estado_codigo == "ACTIVO" and not roles_finales:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Un usuario activo debe tener al menos un rol",
        )

    valores = {
        "tipo_documento_codigo": actual.tipo_documento_codigo,
        "numero_documento": actual.numero_documento,
        "nombres": actual.nombres,
        "apellido_paterno": actual.apellido_paterno,
        "apellido_materno": actual.apellido_materno,
        "fecha_nacimiento": actual.fecha_nacimiento,
        "sexo": actual.sexo,
        "correo": actual.correo,
        "telefono": actual.telefono,
        "direccion": actual.direccion,
        "zona": actual.zona,
        "estado_codigo": actual.estado_codigo,
    }
    valores.update(cambios)

    id_tipo_documento = await obtener_id_catalogo(
        conexion,
        "catalogo.tipo_documento",
        "id_tipo_documento",
        valores["tipo_documento_codigo"],
        "El tipo de documento no existe",
    )
    id_estado_usuario = await obtener_id_catalogo(
        conexion,
        "catalogo.estado_usuario",
        "id_estado_usuario",
        valores["estado_codigo"],
        "El estado del usuario no existe",
    )

    await establecer_usuario_aplicacion(conexion, id_administrador)

    try:
        await conexion.execute(
            """
            UPDATE seguridad.usuario
            SET
                id_tipo_documento = %s,
                numero_documento = %s,
                nombres = %s,
                apellido_paterno = %s,
                apellido_materno = %s,
                fecha_nacimiento = %s,
                sexo = %s,
                correo = %s,
                telefono = %s,
                direccion = %s,
                zona = %s,
                id_estado_usuario = %s,
                intentos_fallidos = CASE WHEN %s = 'ACTIVO' THEN 0 ELSE intentos_fallidos END,
                fecha_actualizacion = CURRENT_TIMESTAMP
            WHERE id_usuario = %s
            """,
            (
                id_tipo_documento,
                valores["numero_documento"],
                valores["nombres"],
                valores["apellido_paterno"],
                valores["apellido_materno"],
                valores["fecha_nacimiento"],
                valores["sexo"],
                valores["correo"].lower(),
                valores["telefono"],
                valores["direccion"],
                valores["zona"],
                id_estado_usuario,
                valores["estado_codigo"],
                id_usuario,
            ),
        )
        await sincronizar_roles(
            conexion,
            id_usuario,
            roles_finales,
            id_administrador,
            valores["estado_codigo"] == "ACTIVO",
        )
    except (UniqueViolation, CheckViolation, ForeignKeyViolation) as error:
        raise HTTPException(
            status_code=(
                status.HTTP_409_CONFLICT
                if isinstance(error, UniqueViolation)
                else status.HTTP_422_UNPROCESSABLE_ENTITY
            ),
            detail=mensaje_integridad(error, "No se pudo actualizar el usuario"),
        ) from error

    return await buscar_usuario(conexion, id_usuario)


@router.patch("/{id_usuario}/contrasenia", response_model=UsuarioRespuesta)
async def restablecer_contrasenia(
    datos: UsuarioContraseniaActualizar,
    conexion: ConexionPostgresql,
    id_administrador: UsuarioAdministrador,
    id_usuario: Annotated[int, Path(ge=1)],
) -> UsuarioRespuesta:
    await buscar_usuario(conexion, id_usuario)
    await establecer_usuario_aplicacion(conexion, id_administrador)
    await conexion.execute(
        """
        UPDATE seguridad.usuario
        SET
            contrasenia_hash = %s,
            intentos_fallidos = 0,
            fecha_actualizacion = CURRENT_TIMESTAMP
        WHERE id_usuario = %s
        """,
        (generar_hash_contrasenia(datos.contrasenia), id_usuario),
    )
    return await buscar_usuario(conexion, id_usuario)


@router.delete("/{id_usuario}", response_model=UsuarioRespuesta)
async def desactivar_usuario(
    conexion: ConexionPostgresql,
    id_administrador: UsuarioAdministrador,
    id_usuario: Annotated[int, Path(ge=1)],
) -> UsuarioRespuesta:
    if id_usuario == id_administrador:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="No puede desactivar su propia cuenta",
        )

    actual = await buscar_usuario(conexion, id_usuario)
    id_estado = await obtener_id_catalogo(
        conexion,
        "catalogo.estado_usuario",
        "id_estado_usuario",
        "INACTIVO",
        "No existe el estado INACTIVO",
    )
    await establecer_usuario_aplicacion(conexion, id_administrador)
    await conexion.execute(
        """
        UPDATE seguridad.usuario
        SET id_estado_usuario = %s, fecha_actualizacion = CURRENT_TIMESTAMP
        WHERE id_usuario = %s
        """,
        (id_estado, id_usuario),
    )
    await sincronizar_roles(
        conexion,
        id_usuario,
        actual.roles,
        id_administrador,
        False,
    )
    return await buscar_usuario(conexion, id_usuario)
