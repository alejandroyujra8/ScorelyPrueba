from typing import Annotated

from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
    status,
)
from psycopg import AsyncConnection

from app.api.dependencies.auth import (
    obtener_usuario_actual,
)
from app.core.config import obtener_configuracion
from app.core.database import (
    establecer_usuario_aplicacion,
    obtener_conexion,
)
from app.core.security import (
    crear_token_acceso,
    verificar_contrasenia,
)
from app.schemas.auth import (
    LoginEntrada,
    TokenRespuesta,
    UsuarioAutenticadoRespuesta,
)


router = APIRouter(
    prefix="/api/auth",
    tags=["Autenticacion"],
)


configuracion = obtener_configuracion()


ConexionPostgresql = Annotated[
    AsyncConnection,
    Depends(obtener_conexion),
]


@router.post(
    "/login",
    response_model=TokenRespuesta,
    status_code=status.HTTP_200_OK,
    summary="Iniciar sesion",
)
async def iniciar_sesion(
    datos: LoginEntrada,
    conexion: ConexionPostgresql,
) -> TokenRespuesta:
    cursor = await conexion.execute(
        """
        SELECT
            usuario.id_usuario,
            usuario.numero_documento,

            usuario.nombres,
            usuario.apellido_paterno,
            usuario.apellido_materno,

            usuario.correo,
            usuario.contrasenia_hash,

            estado.codigo AS estado_codigo,

            COALESCE(
                ARRAY_AGG(
                    DISTINCT rol.codigo
                    ORDER BY rol.codigo
                ) FILTER (
                    WHERE usuario_rol.activo = TRUE
                      AND rol.activo = TRUE
                      AND usuario_rol.fecha_inicio <= CURRENT_DATE
                      AND (
                          usuario_rol.fecha_fin IS NULL
                          OR usuario_rol.fecha_fin
                             >= CURRENT_DATE
                      )
                ),
                ARRAY[]::VARCHAR[]
            ) AS roles

        FROM seguridad.usuario usuario

        INNER JOIN catalogo.estado_usuario estado
            ON estado.id_estado_usuario =
               usuario.id_estado_usuario

        LEFT JOIN seguridad.usuario_rol usuario_rol
            ON usuario_rol.id_usuario =
               usuario.id_usuario

        LEFT JOIN seguridad.rol rol
            ON rol.id_rol =
               usuario_rol.id_rol

        WHERE (
            LOWER(usuario.correo)
                = LOWER(%s)
            OR usuario.numero_documento = %s
        )

        GROUP BY
            usuario.id_usuario,
            usuario.numero_documento,
            usuario.nombres,
            usuario.apellido_paterno,
            usuario.apellido_materno,
            usuario.correo,
            usuario.contrasenia_hash,
            estado.codigo
        """,
        (
            datos.identificador,
            datos.identificador,
        ),
    )

    fila = await cursor.fetchone()

    credenciales_invalidas = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail=(
            "El identificador o la contrasenia "
            "son incorrectos"
        ),
        headers={
            "WWW-Authenticate": "Bearer"
        },
    )

    if fila is None:
        raise credenciales_invalidas

    if fila["estado_codigo"] != "ACTIVO":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="La cuenta se encuentra inactiva",
        )

    es_valida = verificar_contrasenia(
        contrasenia_plana=datos.contrasenia,
        contrasenia_hash=fila[
            "contrasenia_hash"
        ],
    )

    if not es_valida:
        raise credenciales_invalidas

    roles = list(fila["roles"])

    if not roles:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=(
                "El usuario no tiene un rol activo"
            ),
        )

    id_usuario = int(fila["id_usuario"])

    await establecer_usuario_aplicacion(
        conexion=conexion,
        id_usuario=id_usuario,
    )

    await conexion.execute(
        """
        UPDATE seguridad.usuario
        SET ultimo_acceso = CURRENT_TIMESTAMP
        WHERE id_usuario = %s
        """,
        (id_usuario,),
    )

    usuario = UsuarioAutenticadoRespuesta(
        id_usuario=id_usuario,
        numero_documento=fila[
            "numero_documento"
        ],
        nombres=fila["nombres"],
        apellido_paterno=fila[
            "apellido_paterno"
        ],
        apellido_materno=fila[
            "apellido_materno"
        ],
        correo=fila["correo"],
        estado_codigo=fila[
            "estado_codigo"
        ],
        roles=roles,
    )

    token = crear_token_acceso(
        id_usuario=id_usuario
    )

    return TokenRespuesta(
        access_token=token,
        expires_in=(
            configuracion.jwt_expire_minutes
            * 60
        ),
        usuario=usuario,
    )


@router.get(
    "/me",
    response_model=UsuarioAutenticadoRespuesta,
    status_code=status.HTTP_200_OK,
    summary="Obtener usuario autenticado",
)
async def obtener_mi_usuario(
    usuario: Annotated[
        UsuarioAutenticadoRespuesta,
        Depends(obtener_usuario_actual),
    ],
) -> UsuarioAutenticadoRespuesta:
    return usuario