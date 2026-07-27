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
from app.schemas.torneo import (
    EstructuraTorneoRespuesta,
    FaseCrear,
    FaseRespuesta,
    JornadaCrear,
    JornadaRespuesta,
    ListaTorneosRespuesta,
    TorneoActualizar,
    TorneoCrear,
    TorneoEstadoActualizar,
    TorneoRespuesta,
)
from app.api.dependencies.auth import (
    requerir_roles_id,
)

router = APIRouter(
    prefix="/api/torneos",
    tags=["Torneos"],
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


async def buscar_torneo(
    conexion: AsyncConnection,
    id_torneo: int,
) -> TorneoRespuesta:
    cursor = await conexion.execute(
        """
        SELECT
            resumen.id_torneo,
            torneo.id_deporte,
            formato.codigo AS formato_codigo,
            resumen.codigo,
            resumen.nombre,
            resumen.edicion,
            resumen.categoria,
            resumen.rama,
            resumen.deporte,
            formato.nombre AS formato,
            resumen.estado_torneo,
            resumen.fecha_inicio_inscripcion,
            resumen.fecha_fin_inscripcion,
            resumen.fecha_inicio_torneo,
            resumen.fecha_fin_torneo,
            resumen.cantidad_maxima_equipos,
            resumen.cantidad_minima_jugadores,
            resumen.cantidad_maxima_jugadores,
            resumen.costo_inscripcion,
            resumen.moneda,
            torneo.permite_empate,
            torneo.descripcion,
            resumen.total_inscripciones,
            resumen.inscripciones_habilitadas,
            resumen.total_fases,
            resumen.total_partidos,
            resumen.partidos_finalizados,
            resumen.total_recaudado
        FROM reportes.vw_torneos_resumen resumen
        INNER JOIN competencia.torneo torneo
            ON torneo.id_torneo = resumen.id_torneo
        INNER JOIN catalogo.formato_torneo formato
            ON formato.id_formato_torneo = torneo.id_formato_torneo
        WHERE resumen.id_torneo = %s
        """,
        (id_torneo,),
    )

    fila: dict[str, Any] | None = await cursor.fetchone()

    if fila is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="El torneo no existe",
        )

    return TorneoRespuesta.model_validate(fila)


@router.get(
    "",
    response_model=ListaTorneosRespuesta,
    status_code=status.HTTP_200_OK,
    summary="Listar torneos",
)
async def listar_torneos(
    conexion: ConexionPostgresql,
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
) -> ListaTorneosRespuesta:
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
            resumen.id_torneo,
            torneo.id_deporte,
            formato.codigo AS formato_codigo,
            resumen.codigo,
            resumen.nombre,
            resumen.edicion,
            resumen.categoria,
            resumen.rama,
            resumen.deporte,
            formato.nombre AS formato,
            resumen.estado_torneo,
            resumen.fecha_inicio_inscripcion,
            resumen.fecha_fin_inscripcion,
            resumen.fecha_inicio_torneo,
            resumen.fecha_fin_torneo,
            resumen.cantidad_maxima_equipos,
            resumen.cantidad_minima_jugadores,
            resumen.cantidad_maxima_jugadores,
            resumen.costo_inscripcion,
            resumen.moneda,
            torneo.permite_empate,
            torneo.descripcion,
            resumen.total_inscripciones,
            resumen.inscripciones_habilitadas,
            resumen.total_fases,
            resumen.total_partidos,
            resumen.partidos_finalizados,
            resumen.total_recaudado
        FROM reportes.vw_torneos_resumen resumen
        INNER JOIN competencia.torneo torneo
            ON torneo.id_torneo = resumen.id_torneo
        INNER JOIN catalogo.formato_torneo formato
            ON formato.id_formato_torneo = torneo.id_formato_torneo
        WHERE (
            %s::text IS NULL
            OR resumen.estado_torneo = %s
        )
        AND (
            %s::text IS NULL
            OR resumen.nombre ILIKE %s
            OR resumen.codigo ILIKE %s
        )
        ORDER BY resumen.fecha_inicio_torneo DESC, resumen.id_torneo DESC
        """,
        (
            estado_normalizado,
            estado_normalizado,
            patron_busqueda,
            patron_busqueda,
            patron_busqueda,
        ),
    )

    filas = await cursor.fetchall()

    resultados = [
        TorneoRespuesta.model_validate(fila)
        for fila in filas
    ]

    return ListaTorneosRespuesta(
        total=len(resultados),
        resultados=resultados,
    )


@router.post(
    "",
    response_model=TorneoRespuesta,
    status_code=status.HTTP_201_CREATED,
    summary="Crear torneo",
)
async def crear_torneo(
    datos: TorneoCrear,
    conexion: ConexionPostgresql,
    id_usuario: UsuarioResponsable,
) -> TorneoRespuesta:
    await establecer_usuario_aplicacion(
        conexion=conexion,
        id_usuario=id_usuario,
    )

    try:
        cursor = await conexion.execute(
            """
            WITH formato_seleccionado AS (
                SELECT id_formato_torneo
                FROM catalogo.formato_torneo
                WHERE codigo = %s
                  AND activo = TRUE
            ),
            estado_inicial AS (
                SELECT id_estado_torneo
                FROM catalogo.estado_torneo
                WHERE codigo = 'BORRADOR'
                  AND activo = TRUE
            ),
            torneo_insertado AS (
                INSERT INTO competencia.torneo (
                    id_deporte,
                    id_formato_torneo,
                    id_estado_torneo,
                    codigo,
                    nombre,
                    edicion,
                    categoria,
                    rama,
                    fecha_inicio_inscripcion,
                    fecha_fin_inscripcion,
                    fecha_inicio_torneo,
                    fecha_fin_torneo,
                    cantidad_maxima_equipos,
                    cantidad_minima_jugadores,
                    cantidad_maxima_jugadores,
                    costo_inscripcion,
                    moneda,
                    permite_empate,
                    descripcion,
                    creado_por
                )
                SELECT
                    deporte.id_deporte,
                    formato.id_formato_torneo,
                    estado.id_estado_torneo,
                    %s,
                    %s,
                    %s,
                    %s,
                    %s,
                    %s,
                    %s,
                    %s,
                    %s,
                    %s,
                    %s,
                    %s,
                    %s,
                    %s,
                    %s,
                    %s,
                    %s
                FROM competencia.deporte deporte
                INNER JOIN catalogo.estado_deporte estado_deporte
                    ON estado_deporte.id_estado_deporte =
                       deporte.id_estado_deporte
                CROSS JOIN formato_seleccionado formato
                CROSS JOIN estado_inicial estado
                WHERE deporte.id_deporte = %s
                  AND estado_deporte.codigo = 'ACTIVO'
                  AND estado_deporte.activo = TRUE
                RETURNING id_torneo
            )
            SELECT id_torneo
            FROM torneo_insertado
            """,
            (
                datos.formato_codigo,
                datos.codigo,
                datos.nombre,
                datos.edicion,
                datos.categoria,
                datos.rama,
                datos.fecha_inicio_inscripcion,
                datos.fecha_fin_inscripcion,
                datos.fecha_inicio_torneo,
                datos.fecha_fin_torneo,
                datos.cantidad_maxima_equipos,
                datos.cantidad_minima_jugadores,
                datos.cantidad_maxima_jugadores,
                datos.costo_inscripcion,
                datos.moneda,
                datos.permite_empate,
                datos.descripcion,
                id_usuario,
                datos.id_deporte,
            ),
        )

        fila = await cursor.fetchone()

    except UniqueViolation as error:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=(
                "Ya existe un torneo con ese codigo "
                "o nombre"
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
                "PostgreSQL rechazo los datos del torneo",
            ),
        ) from error

    if fila is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=(
                "El deporte o el formato seleccionado no existe"
            ),
        )

    return await buscar_torneo(
        conexion=conexion,
        id_torneo=int(fila["id_torneo"]),
    )


@router.patch(
    "/{id_torneo}",
    response_model=TorneoRespuesta,
    status_code=status.HTTP_200_OK,
    summary="Actualizar datos generales del torneo",
)
async def actualizar_torneo(
    datos: TorneoActualizar,
    conexion: ConexionPostgresql,
    id_usuario: UsuarioResponsable,
    id_torneo: Annotated[int, Path(ge=1)],
) -> TorneoRespuesta:
    actual = await buscar_torneo(
        conexion=conexion,
        id_torneo=id_torneo,
    )

    if actual.estado_torneo != "BORRADOR":
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=(
                "Solo se pueden editar los datos generales "
                "de un torneo en estado BORRADOR"
            ),
        )

    datos_completos = {
        "id_deporte": actual.id_deporte,
        "formato_codigo": actual.formato_codigo,
        "codigo": actual.codigo,
        "nombre": actual.nombre,
        "edicion": actual.edicion,
        "categoria": actual.categoria,
        "rama": actual.rama,
        "fecha_inicio_inscripcion": actual.fecha_inicio_inscripcion,
        "fecha_fin_inscripcion": actual.fecha_fin_inscripcion,
        "fecha_inicio_torneo": actual.fecha_inicio_torneo,
        "fecha_fin_torneo": actual.fecha_fin_torneo,
        "cantidad_maxima_equipos": actual.cantidad_maxima_equipos,
        "cantidad_minima_jugadores": actual.cantidad_minima_jugadores,
        "cantidad_maxima_jugadores": actual.cantidad_maxima_jugadores,
        "costo_inscripcion": actual.costo_inscripcion,
        "moneda": actual.moneda,
        "permite_empate": actual.permite_empate,
        "descripcion": actual.descripcion,
    }
    datos_completos.update(datos.model_dump(exclude_unset=True))
    datos_validados = TorneoCrear.model_validate(datos_completos)

    await establecer_usuario_aplicacion(
        conexion=conexion,
        id_usuario=id_usuario,
    )

    try:
        cursor = await conexion.execute(
            """
            WITH formato_seleccionado AS (
                SELECT id_formato_torneo
                FROM catalogo.formato_torneo
                WHERE codigo = %s
                  AND activo = TRUE
            ),
            deporte_seleccionado AS (
                SELECT deporte.id_deporte
                FROM competencia.deporte deporte
                INNER JOIN catalogo.estado_deporte estado
                    ON estado.id_estado_deporte =
                       deporte.id_estado_deporte
                WHERE deporte.id_deporte = %s
                  AND estado.codigo = 'ACTIVO'
                  AND estado.activo = TRUE
            )
            UPDATE competencia.torneo torneo
            SET
                id_deporte = deporte.id_deporte,
                id_formato_torneo = formato.id_formato_torneo,
                codigo = %s,
                nombre = %s,
                edicion = %s,
                categoria = %s,
                rama = %s,
                fecha_inicio_inscripcion = %s,
                fecha_fin_inscripcion = %s,
                fecha_inicio_torneo = %s,
                fecha_fin_torneo = %s,
                cantidad_maxima_equipos = %s,
                cantidad_minima_jugadores = %s,
                cantidad_maxima_jugadores = %s,
                costo_inscripcion = %s,
                moneda = %s,
                permite_empate = %s,
                descripcion = %s,
                fecha_actualizacion = CURRENT_TIMESTAMP
            FROM formato_seleccionado formato
            CROSS JOIN deporte_seleccionado deporte
            WHERE torneo.id_torneo = %s
            RETURNING torneo.id_torneo
            """,
            (
                datos_validados.formato_codigo,
                datos_validados.id_deporte,
                datos_validados.codigo,
                datos_validados.nombre,
                datos_validados.edicion,
                datos_validados.categoria,
                datos_validados.rama,
                datos_validados.fecha_inicio_inscripcion,
                datos_validados.fecha_fin_inscripcion,
                datos_validados.fecha_inicio_torneo,
                datos_validados.fecha_fin_torneo,
                datos_validados.cantidad_maxima_equipos,
                datos_validados.cantidad_minima_jugadores,
                datos_validados.cantidad_maxima_jugadores,
                datos_validados.costo_inscripcion,
                datos_validados.moneda,
                datos_validados.permite_empate,
                datos_validados.descripcion,
                id_torneo,
            ),
        )
        fila = await cursor.fetchone()
    except UniqueViolation as error:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Ya existe otro torneo con ese código o nombre",
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
                "PostgreSQL rechazó la actualización del torneo",
            ),
        ) from error

    if fila is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="El deporte o formato seleccionado no está disponible",
        )

    return await buscar_torneo(
        conexion=conexion,
        id_torneo=id_torneo,
    )


@router.patch(
    "/{id_torneo}/estado",
    response_model=TorneoRespuesta,
    status_code=status.HTTP_200_OK,
    summary="Cambiar estado del torneo",
)
async def actualizar_estado_torneo(
    datos: TorneoEstadoActualizar,
    conexion: ConexionPostgresql,
    id_usuario: UsuarioResponsable,
    id_torneo: Annotated[
        int,
        Path(ge=1),
    ],
) -> TorneoRespuesta:
    await buscar_torneo(
        conexion=conexion,
        id_torneo=id_torneo,
    )

    await establecer_usuario_aplicacion(
        conexion=conexion,
        id_usuario=id_usuario,
    )

    try:
        cursor = await conexion.execute(
            """
            WITH estado_seleccionado AS (
                SELECT id_estado_torneo
                FROM catalogo.estado_torneo
                WHERE codigo = %s
                  AND activo = TRUE
            )
            UPDATE competencia.torneo torneo
            SET
                id_estado_torneo =
                    estado.id_estado_torneo,
                fecha_actualizacion =
                    CURRENT_TIMESTAMP
            FROM estado_seleccionado estado
            WHERE torneo.id_torneo = %s
            RETURNING torneo.id_torneo
            """,
            (
                datos.estado_codigo,
                id_torneo,
            ),
        )

        fila = await cursor.fetchone()

    except (
        CheckViolation,
        RaiseException,
    ) as error:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=obtener_mensaje_postgresql(
                error,
                "La transicion de estado fue rechazada",
            ),
        ) from error

    if fila is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="El estado solicitado no existe",
        )

    return await buscar_torneo(
        conexion=conexion,
        id_torneo=id_torneo,
    )


@router.post(
    "/{id_torneo}/fases",
    response_model=FaseRespuesta,
    status_code=status.HTTP_201_CREATED,
    summary="Crear fase del torneo",
)
async def crear_fase(
    datos: FaseCrear,
    conexion: ConexionPostgresql,
    id_usuario: UsuarioResponsable,
    id_torneo: Annotated[
        int,
        Path(ge=1),
    ],
) -> FaseRespuesta:
    await buscar_torneo(
        conexion=conexion,
        id_torneo=id_torneo,
    )

    await establecer_usuario_aplicacion(
        conexion=conexion,
        id_usuario=id_usuario,
    )

    try:
        cursor = await conexion.execute(
            """
            WITH tipo_seleccionado AS (
                SELECT id_tipo_fase
                FROM catalogo.tipo_fase
                WHERE codigo = %s
                  AND activo = TRUE
            ),
            estado_inicial AS (
                SELECT id_estado_fase
                FROM catalogo.estado_fase
                WHERE codigo = 'PENDIENTE'
                  AND activo = TRUE
            ),
            fase_insertada AS (
                INSERT INTO competencia.fase_torneo (
                    id_torneo,
                    id_tipo_fase,
                    id_estado_fase,
                    nombre,
                    numero_orden,
                    cantidad_clasificados,
                    fecha_inicio,
                    fecha_fin,
                    descripcion
                )
                SELECT
                    %s,
                    tipo.id_tipo_fase,
                    estado.id_estado_fase,
                    %s,
                    %s,
                    %s,
                    %s,
                    %s,
                    %s
                FROM tipo_seleccionado tipo
                CROSS JOIN estado_inicial estado
                RETURNING *
            )
            SELECT
                fase.id_fase_torneo,
                fase.id_torneo,
                tipo.codigo AS tipo_fase,
                estado.codigo AS estado_fase,
                fase.nombre,
                fase.numero_orden,
                fase.cantidad_clasificados,
                fase.fecha_inicio,
                fase.fecha_fin,
                fase.descripcion
            FROM fase_insertada fase
            INNER JOIN catalogo.tipo_fase tipo
                ON tipo.id_tipo_fase =
                   fase.id_tipo_fase
            INNER JOIN catalogo.estado_fase estado
                ON estado.id_estado_fase =
                   fase.id_estado_fase
            """,
            (
                datos.tipo_fase_codigo,
                id_torneo,
                datos.nombre,
                datos.numero_orden,
                datos.cantidad_clasificados,
                datos.fecha_inicio,
                datos.fecha_fin,
                datos.descripcion,
            ),
        )

        fila = await cursor.fetchone()

    except (
        UniqueViolation,
        CheckViolation,
        ForeignKeyViolation,
        RaiseException,
    ) as error:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=obtener_mensaje_postgresql(
                error,
                "No se pudo registrar la fase",
            ),
        ) from error

    if fila is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="El tipo de fase no existe",
        )

    return FaseRespuesta.model_validate(fila)


@router.post(
    "/fases/{id_fase}/jornadas",
    response_model=JornadaRespuesta,
    status_code=status.HTTP_201_CREATED,
    summary="Crear jornada de una fase",
)
async def crear_jornada(
    datos: JornadaCrear,
    conexion: ConexionPostgresql,
    id_usuario: UsuarioResponsable,
    id_fase: Annotated[
        int,
        Path(ge=1),
    ],
) -> JornadaRespuesta:
    await establecer_usuario_aplicacion(
        conexion=conexion,
        id_usuario=id_usuario,
    )

    try:
        cursor = await conexion.execute(
            """
            WITH estado_inicial AS (
                SELECT id_estado_jornada
                FROM catalogo.estado_jornada
                WHERE codigo = 'PROGRAMADA'
                  AND activo = TRUE
            ),
            jornada_insertada AS (
                INSERT INTO competencia.jornada (
                    id_fase_torneo,
                    id_estado_jornada,
                    numero_jornada,
                    nombre,
                    fecha_inicio,
                    fecha_fin,
                    observaciones
                )
                SELECT
                    fase.id_fase_torneo,
                    estado.id_estado_jornada,
                    %s,
                    %s,
                    %s,
                    %s,
                    %s
                FROM competencia.fase_torneo fase
                CROSS JOIN estado_inicial estado
                WHERE fase.id_fase_torneo = %s
                RETURNING *
            )
            SELECT
                jornada.id_jornada,
                jornada.id_fase_torneo,
                estado.codigo AS estado_jornada,
                jornada.numero_jornada,
                jornada.nombre,
                jornada.fecha_inicio,
                jornada.fecha_fin,
                jornada.observaciones
            FROM jornada_insertada jornada
            INNER JOIN catalogo.estado_jornada estado
                ON estado.id_estado_jornada =
                   jornada.id_estado_jornada
            """,
            (
                datos.numero_jornada,
                datos.nombre,
                datos.fecha_inicio,
                datos.fecha_fin,
                datos.observaciones,
                id_fase,
            ),
        )

        fila = await cursor.fetchone()

    except (
        UniqueViolation,
        CheckViolation,
        ForeignKeyViolation,
        RaiseException,
    ) as error:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=obtener_mensaje_postgresql(
                error,
                "No se pudo registrar la jornada",
            ),
        ) from error

    if fila is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="La fase no existe",
        )

    return JornadaRespuesta.model_validate(fila)


@router.get(
    "/{id_torneo}/estructura",
    response_model=EstructuraTorneoRespuesta,
    status_code=status.HTTP_200_OK,
    summary="Consultar fases y jornadas",
)
async def obtener_estructura_torneo(
    conexion: ConexionPostgresql,
    id_torneo: Annotated[
        int,
        Path(ge=1),
    ],
) -> EstructuraTorneoRespuesta:
    await buscar_torneo(
        conexion=conexion,
        id_torneo=id_torneo,
    )

    cursor_fases = await conexion.execute(
        """
        SELECT
            fase.id_fase_torneo,
            fase.id_torneo,
            tipo.codigo AS tipo_fase,
            estado.codigo AS estado_fase,
            fase.nombre,
            fase.numero_orden,
            fase.cantidad_clasificados,
            fase.fecha_inicio,
            fase.fecha_fin,
            fase.descripcion
        FROM competencia.fase_torneo fase
        INNER JOIN catalogo.tipo_fase tipo
            ON tipo.id_tipo_fase =
               fase.id_tipo_fase
        INNER JOIN catalogo.estado_fase estado
            ON estado.id_estado_fase =
               fase.id_estado_fase
        WHERE fase.id_torneo = %s
        ORDER BY fase.numero_orden
        """,
        (id_torneo,),
    )

    fases = await cursor_fases.fetchall()

    cursor_jornadas = await conexion.execute(
        """
        SELECT
            jornada.id_jornada,
            jornada.id_fase_torneo,
            estado.codigo AS estado_jornada,
            jornada.numero_jornada,
            jornada.nombre,
            jornada.fecha_inicio,
            jornada.fecha_fin,
            jornada.observaciones
        FROM competencia.jornada jornada
        INNER JOIN competencia.fase_torneo fase
            ON fase.id_fase_torneo =
               jornada.id_fase_torneo
        INNER JOIN catalogo.estado_jornada estado
            ON estado.id_estado_jornada =
               jornada.id_estado_jornada
        WHERE fase.id_torneo = %s
        ORDER BY
            fase.numero_orden,
            jornada.numero_jornada
        """,
        (id_torneo,),
    )

    jornadas = await cursor_jornadas.fetchall()

    return EstructuraTorneoRespuesta(
        fases=[
            FaseRespuesta.model_validate(fila)
            for fila in fases
        ],
        jornadas=[
            JornadaRespuesta.model_validate(fila)
            for fila in jornadas
        ],
    )


@router.get(
    "/{id_torneo}",
    response_model=TorneoRespuesta,
    status_code=status.HTTP_200_OK,
    summary="Obtener torneo",
)
async def obtener_torneo(
    conexion: ConexionPostgresql,
    id_torneo: Annotated[
        int,
        Path(ge=1),
    ],
) -> TorneoRespuesta:
    return await buscar_torneo(
        conexion=conexion,
        id_torneo=id_torneo,
    )