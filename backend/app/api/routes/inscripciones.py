from typing import Annotated, Any

from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
    Path,
    Query,
    status,
)
from psycopg import AsyncConnection
from psycopg.errors import (
    CheckViolation,
    ForeignKeyViolation,
    RaiseException,
    UniqueViolation,
)

from app.core.database import (
    establecer_usuario_aplicacion,
    obtener_conexion,
)
from app.schemas.inscripcion import (
    InscripcionCrear,
    InscripcionRespuesta,
    JugadorNominaCrear,
    JugadorNominaRespuesta,
    ListaInscripcionesRespuesta,
    PagoCrear,
    PagoRespuesta,
)
from app.api.dependencies.auth import (
    requerir_roles_id,
)

router = APIRouter(
    prefix="/api/inscripciones",
    tags=["Inscripciones y pagos"],
)


ConexionPostgresql = Annotated[
    AsyncConnection,
    Depends(obtener_conexion),
]


UsuarioResponsable = Annotated[
    int,
    Depends(
        requerir_roles_id(
            "ADMINISTRADOR",
            "ORGANIZADOR",
        )
    ),
]


def obtener_mensaje_postgresql(
    error: Exception,
    mensaje_defecto: str,
) -> str:
    diagnostico = getattr(
        error,
        "diag",
        None,
    )

    mensaje = getattr(
        diagnostico,
        "message_primary",
        None,
    )

    if isinstance(mensaje, str) and mensaje.strip():
        return mensaje

    return mensaje_defecto


async def buscar_inscripcion(
    conexion: AsyncConnection,
    id_inscripcion: int,
) -> InscripcionRespuesta:
    cursor = await conexion.execute(
        """
        SELECT
            id_inscripcion,
            id_torneo,
            codigo_torneo,
            torneo,
            id_equipo,
            equipo,
            sigla,
            estado_inscripcion,
            monto_requerido,
            moneda,
            total_pagado,
            saldo_pendiente,
            jugadores_nomina,
            jugadores_habilitados,
            fecha_inscripcion,
            fecha_actualizacion
        FROM reportes.vw_inscripciones_resumen
        WHERE id_inscripcion = %s
        """,
        (id_inscripcion,),
    )

    fila: dict[str, Any] | None = await cursor.fetchone()

    if fila is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="La inscripcion no existe",
        )

    return InscripcionRespuesta.model_validate(fila)


@router.get(
    "",
    response_model=ListaInscripcionesRespuesta,
    status_code=status.HTTP_200_OK,
    summary="Listar inscripciones",
)
async def listar_inscripciones(
    conexion: ConexionPostgresql,
    id_torneo: Annotated[
        int | None,
        Query(ge=1),
    ] = None,
    estado: Annotated[
        str | None,
        Query(
            min_length=2,
            max_length=40,
        ),
    ] = None,
    busqueda: Annotated[
        str | None,
        Query(
            min_length=1,
            max_length=100,
        ),
    ] = None,
) -> ListaInscripcionesRespuesta:
    estado_normalizado = (
        estado.strip().upper()
        if estado is not None
        else None
    )

    patron_busqueda = (
        f"%{busqueda.strip()}%"
        if busqueda is not None
        else None
    )

    cursor = await conexion.execute(
        """
        SELECT
            id_inscripcion,
            id_torneo,
            codigo_torneo,
            torneo,
            id_equipo,
            equipo,
            sigla,
            estado_inscripcion,
            monto_requerido,
            moneda,
            total_pagado,
            saldo_pendiente,
            jugadores_nomina,
            jugadores_habilitados,
            fecha_inscripcion,
            fecha_actualizacion
        FROM reportes.vw_inscripciones_resumen
        WHERE (
            %s::bigint IS NULL
            OR id_torneo = %s
        )
        AND (
            %s::text IS NULL
            OR estado_inscripcion = %s
        )
        AND (
            %s::text IS NULL
            OR torneo ILIKE %s
            OR equipo ILIKE %s
        )
        ORDER BY
            fecha_inscripcion DESC,
            id_inscripcion DESC
        """,
        (
            id_torneo,
            id_torneo,
            estado_normalizado,
            estado_normalizado,
            patron_busqueda,
            patron_busqueda,
            patron_busqueda,
        ),
    )

    filas = await cursor.fetchall()

    resultados = [
        InscripcionRespuesta.model_validate(fila)
        for fila in filas
    ]

    return ListaInscripcionesRespuesta(
        total=len(resultados),
        resultados=resultados,
    )


@router.get(
    "/{id_inscripcion}",
    response_model=InscripcionRespuesta,
    status_code=status.HTTP_200_OK,
    summary="Obtener inscripcion",
)
async def obtener_inscripcion(
    conexion: ConexionPostgresql,
    id_inscripcion: Annotated[
        int,
        Path(ge=1),
    ],
) -> InscripcionRespuesta:
    return await buscar_inscripcion(
        conexion=conexion,
        id_inscripcion=id_inscripcion,
    )


@router.post(
    "",
    response_model=InscripcionRespuesta,
    status_code=status.HTTP_201_CREATED,
    summary="Inscribir equipo en un torneo",
)
async def crear_inscripcion(
    datos: InscripcionCrear,
    conexion: ConexionPostgresql,
    id_usuario: UsuarioResponsable,
) -> InscripcionRespuesta:
    await establecer_usuario_aplicacion(
        conexion=conexion,
        id_usuario=id_usuario,
    )

    try:
        await conexion.execute(
            """
            CALL competencia.sp_registrar_inscripcion(
                %s::bigint,
                %s::bigint,
                %s::bigint,
                %s::varchar
            )
            """,
            (
                datos.id_torneo,
                datos.id_equipo,
                id_usuario,
                datos.observaciones,
            ),
        )

        cursor = await conexion.execute(
            """
            SELECT id_inscripcion
            FROM competencia.inscripcion
            WHERE id_torneo = %s
              AND id_equipo = %s
            """,
            (
                datos.id_torneo,
                datos.id_equipo,
            ),
        )

        fila = await cursor.fetchone()

    except UniqueViolation as error:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=(
                "El equipo ya se encuentra inscrito "
                "en el torneo"
            ),
        ) from error

    except (
        CheckViolation,
        ForeignKeyViolation,
        RaiseException,
    ) as error:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=obtener_mensaje_postgresql(
                error,
                "PostgreSQL rechazo la inscripcion",
            ),
        ) from error

    if fila is None:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="No se pudo recuperar la inscripcion",
        )

    return await buscar_inscripcion(
        conexion=conexion,
        id_inscripcion=int(fila["id_inscripcion"]),
    )


@router.get(
    "/{id_inscripcion}/nomina",
    response_model=list[JugadorNominaRespuesta],
    status_code=status.HTTP_200_OK,
    summary="Consultar nomina de una inscripcion",
)
async def listar_nomina(
    conexion: ConexionPostgresql,
    id_inscripcion: Annotated[
        int,
        Path(ge=1),
    ],
) -> list[JugadorNominaRespuesta]:
    await buscar_inscripcion(
        conexion=conexion,
        id_inscripcion=id_inscripcion,
    )

    cursor = await conexion.execute(
        """
        SELECT
            jugador.id_jugador_inscripcion,
            jugador.id_inscripcion,
            jugador.id_jugador,

            usuario.numero_documento,
            usuario.nombres,
            usuario.apellido_paterno,
            usuario.apellido_materno,

            jugador.numero_camiseta,
            jugador.es_delegado,
            jugador.es_capitan,

            estado.codigo AS estado_codigo,

            jugador.fecha_baja,
            jugador.observaciones

        FROM competencia.jugador_inscripcion jugador

        INNER JOIN seguridad.usuario usuario
            ON usuario.id_usuario =
               jugador.id_jugador

        INNER JOIN catalogo.estado_jugador_inscripcion estado
            ON estado.id_estado_jugador_inscripcion =
               jugador.id_estado_jugador_inscripcion

        WHERE jugador.id_inscripcion = %s

        ORDER BY
            jugador.fecha_baja NULLS FIRST,
            usuario.apellido_paterno,
            usuario.nombres
        """,
        (id_inscripcion,),
    )

    filas = await cursor.fetchall()

    return [
        JugadorNominaRespuesta.model_validate(fila)
        for fila in filas
    ]


@router.post(
    "/{id_inscripcion}/nomina",
    response_model=JugadorNominaRespuesta,
    status_code=status.HTTP_201_CREATED,
    summary="Agregar jugador a la nomina",
)
async def agregar_jugador_nomina(
    datos: JugadorNominaCrear,
    conexion: ConexionPostgresql,
    id_usuario: UsuarioResponsable,
    id_inscripcion: Annotated[
        int,
        Path(ge=1),
    ],
) -> JugadorNominaRespuesta:
    await buscar_inscripcion(
        conexion=conexion,
        id_inscripcion=id_inscripcion,
    )

    await establecer_usuario_aplicacion(
        conexion=conexion,
        id_usuario=id_usuario,
    )

    try:
        await conexion.execute(
            """
            CALL competencia.sp_agregar_jugador_inscripcion(
                %s::bigint,
                %s::bigint,
                %s::smallint,
                %s::boolean,
                %s::boolean,
                %s::bigint,
                %s::varchar
            )
            """,
            (
                id_inscripcion,
                datos.id_jugador,
                datos.numero_camiseta,
                datos.es_delegado,
                datos.es_capitan,
                id_usuario,
                datos.observaciones,
            ),
        )

        cursor = await conexion.execute(
            """
            SELECT
                jugador.id_jugador_inscripcion,
                jugador.id_inscripcion,
                jugador.id_jugador,

                usuario.numero_documento,
                usuario.nombres,
                usuario.apellido_paterno,
                usuario.apellido_materno,

                jugador.numero_camiseta,
                jugador.es_delegado,
                jugador.es_capitan,

                estado.codigo AS estado_codigo,

                jugador.fecha_baja,
                jugador.observaciones

            FROM competencia.jugador_inscripcion jugador

            INNER JOIN seguridad.usuario usuario
                ON usuario.id_usuario =
                   jugador.id_jugador

            INNER JOIN catalogo.estado_jugador_inscripcion estado
                ON estado.id_estado_jugador_inscripcion =
                   jugador.id_estado_jugador_inscripcion

            WHERE jugador.id_inscripcion = %s
              AND jugador.id_jugador = %s

            ORDER BY jugador.id_jugador_inscripcion DESC
            LIMIT 1
            """,
            (
                id_inscripcion,
                datos.id_jugador,
            ),
        )

        fila = await cursor.fetchone()

    except UniqueViolation as error:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=(
                "El jugador ya pertenece a la nomina "
                "de esta inscripcion"
            ),
        ) from error

    except (
        CheckViolation,
        ForeignKeyViolation,
        RaiseException,
    ) as error:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=obtener_mensaje_postgresql(
                error,
                "PostgreSQL rechazo al jugador de la nomina",
            ),
        ) from error

    if fila is None:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="No se pudo recuperar al jugador",
        )

    return JugadorNominaRespuesta.model_validate(fila)


@router.get(
    "/{id_inscripcion}/pagos",
    response_model=list[PagoRespuesta],
    status_code=status.HTTP_200_OK,
    summary="Consultar pagos de una inscripcion",
)
async def listar_pagos(
    conexion: ConexionPostgresql,
    id_inscripcion: Annotated[
        int,
        Path(ge=1),
    ],
) -> list[PagoRespuesta]:
    await buscar_inscripcion(
        conexion=conexion,
        id_inscripcion=id_inscripcion,
    )

    cursor = await conexion.execute(
        """
        SELECT
            id_pago,
            id_inscripcion,
            id_torneo,
            torneo,
            id_equipo,
            equipo,
            metodo_pago,
            estado_pago,
            monto,
            moneda,
            referencia,
            fecha_pago,
            fecha_verificacion,
            id_usuario_registro,
            registrado_por,
            id_usuario_verificacion,
            verificado_por,
            observaciones

        FROM reportes.vw_pagos_resumen

        WHERE id_inscripcion = %s

        ORDER BY
            fecha_pago DESC,
            id_pago DESC
        """,
        (id_inscripcion,),
    )

    filas = await cursor.fetchall()

    return [
        PagoRespuesta.model_validate(fila)
        for fila in filas
    ]


@router.post(
    "/{id_inscripcion}/pagos",
    response_model=PagoRespuesta,
    status_code=status.HTTP_201_CREATED,
    summary="Registrar pago de inscripcion",
)
async def registrar_pago(
    datos: PagoCrear,
    conexion: ConexionPostgresql,
    id_usuario: UsuarioResponsable,
    id_inscripcion: Annotated[
        int,
        Path(ge=1),
    ],
) -> PagoRespuesta:
    await buscar_inscripcion(
        conexion=conexion,
        id_inscripcion=id_inscripcion,
    )

    estados_permitidos = {
        "PENDIENTE",
        "CONFIRMADO",
    }

    if datos.estado_codigo not in estados_permitidos:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=(
                "Para el MVP el estado debe ser "
                "PENDIENTE o CONFIRMADO"
            ),
        )

    verificado_por = (
        id_usuario
        if datos.estado_codigo == "CONFIRMADO"
        else None
    )

    await establecer_usuario_aplicacion(
        conexion=conexion,
        id_usuario=id_usuario,
    )

    try:
        await conexion.execute(
            """
            CALL finanzas.sp_registrar_pago(
                %s::bigint,
                %s::varchar,
                %s::varchar,
                %s::numeric,
                %s::varchar,
                %s::bigint,
                %s::bigint,
                %s::varchar
            )
            """,
            (
                id_inscripcion,
                datos.metodo_codigo,
                datos.estado_codigo,
                datos.monto,
                datos.referencia,
                id_usuario,
                verificado_por,
                datos.observaciones,
            ),
        )

        cursor = await conexion.execute(
            """
            SELECT
                id_pago,
                id_inscripcion,
                id_torneo,
                torneo,
                id_equipo,
                equipo,
                metodo_pago,
                estado_pago,
                monto,
                moneda,
                referencia,
                fecha_pago,
                fecha_verificacion,
                id_usuario_registro,
                registrado_por,
                id_usuario_verificacion,
                verificado_por,
                observaciones

            FROM reportes.vw_pagos_resumen

            WHERE id_inscripcion = %s

            ORDER BY id_pago DESC
            LIMIT 1
            """,
            (id_inscripcion,),
        )

        fila = await cursor.fetchone()

    except UniqueViolation as error:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=(
                "La referencia del pago ya se encuentra registrada"
            ),
        ) from error

    except (
        CheckViolation,
        ForeignKeyViolation,
        RaiseException,
    ) as error:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=obtener_mensaje_postgresql(
                error,
                "PostgreSQL rechazo el pago",
            ),
        ) from error

    if fila is None:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="No se pudo recuperar el pago",
        )

    return PagoRespuesta.model_validate(fila)