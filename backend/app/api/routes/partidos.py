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
    ExclusionViolation,
    ForeignKeyViolation,
    RaiseException,
    UniqueViolation,
)

from app.core.database import (
    establecer_usuario_aplicacion,
    obtener_conexion,
)
from app.schemas.partido import (
    ArbitroAsignar,
    ArbitroOpcionRespuesta,
    ListaPartidosRespuesta,
    LugarOpcionRespuesta,
    OperacionPartidoRespuesta,
    ParticipacionJugadorCrear,
    ParticipacionJugadorRespuesta,
    PartidoCrear,
    PartidoFinalizar,
    PartidoRespuesta,
)
from app.api.dependencies.auth import (
    requerir_roles_id,
)


router = APIRouter(
    prefix="/api/partidos",
    tags=["Partidos"],
)


ConexionPostgresql = Annotated[
    AsyncConnection,
    Depends(obtener_conexion),
]


UsuarioGestionPartido = Annotated[
    int,
    Depends(
        requerir_roles_id(
            "ADMINISTRADOR",
            "ORGANIZADOR",
        )
    ),
]


UsuarioOperacionPartido = Annotated[
    int,
    Depends(
        requerir_roles_id(
            "ADMINISTRADOR",
            "ORGANIZADOR",
            "ARBITRO",
        )
    ),
]


UsuarioConsultaPartido = Annotated[
    int,
    Depends(
        requerir_roles_id(
            "ADMINISTRADOR",
            "ORGANIZADOR",
            "ARBITRO",
            "JUGADOR",
            "CONSULTA",
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


async def verificar_permiso_operacion_partido(
    conexion: AsyncConnection,
    id_partido: int,
    id_usuario: int,
) -> None:
    cursor = await conexion.execute(
        """
        SELECT
            EXISTS (
                SELECT 1
                FROM seguridad.usuario_rol usuario_rol
                INNER JOIN seguridad.rol rol
                    ON rol.id_rol = usuario_rol.id_rol
                WHERE usuario_rol.id_usuario = %s
                  AND usuario_rol.activo = TRUE
                  AND usuario_rol.fecha_inicio <= CURRENT_DATE
                  AND (
                      usuario_rol.fecha_fin IS NULL
                      OR usuario_rol.fecha_fin >= CURRENT_DATE
                  )
                  AND rol.activo = TRUE
                  AND rol.codigo IN ('ADMINISTRADOR', 'ORGANIZADOR')
            ) AS es_gestor,
            EXISTS (
                SELECT 1
                FROM competencia.arbitro_partido arbitro_partido
                WHERE arbitro_partido.id_partido = %s
                  AND arbitro_partido.id_arbitro = %s
                  AND arbitro_partido.activo = TRUE
                  AND arbitro_partido.fecha_fin IS NULL
            ) AS es_arbitro_asignado
        """,
        (id_usuario, id_partido, id_usuario),
    )
    fila = await cursor.fetchone()

    if not fila or not (
        fila["es_gestor"] or fila["es_arbitro_asignado"]
    ):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail=(
                "El arbitro solo puede operar partidos "
                "en los que se encuentra asignado"
            ),
        )


def validar_estado_partido(
    partido: PartidoRespuesta,
    estados_permitidos: set[str],
    operacion: str,
) -> None:
    if partido.estado_partido not in estados_permitidos:
        estados = ", ".join(sorted(estados_permitidos))
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=(
                f"No se puede {operacion} un partido en estado "
                f"{partido.estado_partido}. Estados permitidos: {estados}"
            ),
        )


async def buscar_partido(
    conexion: AsyncConnection,
    id_partido: int,
    id_usuario: int,
) -> PartidoRespuesta:
    cursor = await conexion.execute(
        """
        SELECT
            id_partido,
            codigo,
            numero_partido,
            nombre_ronda,

            id_torneo,
            torneo,

            fase,
            numero_jornada,
            jornada,

            grupo,

            lugar,
            direccion_lugar,

            fecha_hora_inicio,
            fecha_hora_fin,

            estado_partido,

            EXISTS (
                SELECT 1
                FROM competencia.arbitro_partido arbitro_partido
                WHERE arbitro_partido.id_partido =
                      partido_vista.id_partido
                  AND arbitro_partido.id_arbitro = %s
                  AND arbitro_partido.activo = TRUE
                  AND arbitro_partido.fecha_fin IS NULL
            ) AS arbitro_actual_asignado,

            (
                SELECT partido_equipo.id_inscripcion
                FROM competencia.partido_equipo partido_equipo
                INNER JOIN catalogo.condicion_equipo_partido condicion
                    ON condicion.id_condicion_equipo =
                       partido_equipo.id_condicion_equipo
                WHERE partido_equipo.id_partido =
                      partido_vista.id_partido
                  AND condicion.codigo = 'LOCAL'
                LIMIT 1
            ) AS id_inscripcion_local,

            equipo_local,
            marcador_local,
            desempate_local,
            resultado_local,

            (
                SELECT partido_equipo.id_inscripcion
                FROM competencia.partido_equipo partido_equipo
                INNER JOIN catalogo.condicion_equipo_partido condicion
                    ON condicion.id_condicion_equipo =
                       partido_equipo.id_condicion_equipo
                WHERE partido_equipo.id_partido =
                      partido_vista.id_partido
                  AND condicion.codigo = 'VISITANTE'
                LIMIT 1
            ) AS id_inscripcion_visitante,

            equipo_visitante,
            marcador_visitante,
            desempate_visitante,
            resultado_visitante,

            observaciones

        FROM reportes.vw_partidos_detalle partido_vista

        WHERE id_partido = %s
        """,
        (id_usuario, id_partido),
    )

    fila: dict[str, Any] | None = await cursor.fetchone()

    if fila is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="El partido no existe",
        )

    return PartidoRespuesta.model_validate(fila)


@router.get(
    "/opciones/lugares",
    response_model=list[LugarOpcionRespuesta],
    status_code=status.HTTP_200_OK,
    summary="Listar lugares disponibles",
)
async def listar_lugares(
    conexion: ConexionPostgresql,
    _: UsuarioGestionPartido,
) -> list[LugarOpcionRespuesta]:
    cursor = await conexion.execute(
        """
        SELECT
            id_lugar,
            nombre,
            direccion,
            zona,
            ciudad,
            capacidad,
            tipo_superficie
        FROM competencia.lugar
        WHERE activo = TRUE
        ORDER BY nombre
        """
    )

    filas = await cursor.fetchall()

    return [
        LugarOpcionRespuesta.model_validate(fila)
        for fila in filas
    ]


@router.get(
    "/opciones/arbitros",
    response_model=list[ArbitroOpcionRespuesta],
    status_code=status.HTTP_200_OK,
    summary="Listar arbitros activos",
)
async def listar_arbitros(
    conexion: ConexionPostgresql,
    _: UsuarioGestionPartido,
) -> list[ArbitroOpcionRespuesta]:
    cursor = await conexion.execute(
        """
        SELECT
            arbitro.id_usuario AS id_arbitro,
            arbitro.numero_licencia,

            CONCAT_WS(
                ' ',
                usuario.nombres,
                usuario.apellido_paterno,
                usuario.apellido_materno
            ) AS nombre_completo,

            arbitro.nivel

        FROM participantes.arbitro arbitro

        INNER JOIN seguridad.usuario usuario
            ON usuario.id_usuario =
               arbitro.id_usuario

        INNER JOIN catalogo.estado_perfil_deportivo estado_perfil
            ON estado_perfil.id_estado_perfil =
               arbitro.id_estado_perfil

        INNER JOIN catalogo.estado_usuario estado_usuario
            ON estado_usuario.id_estado_usuario =
               usuario.id_estado_usuario

        WHERE estado_perfil.codigo = 'ACTIVO'
          AND estado_usuario.codigo = 'ACTIVO'
          AND EXISTS (
              SELECT 1
              FROM seguridad.usuario_rol usuario_rol
              INNER JOIN seguridad.rol rol
                  ON rol.id_rol = usuario_rol.id_rol
              WHERE usuario_rol.id_usuario = usuario.id_usuario
                AND usuario_rol.activo = TRUE
                AND usuario_rol.fecha_inicio <= CURRENT_DATE
                AND (
                    usuario_rol.fecha_fin IS NULL
                    OR usuario_rol.fecha_fin >= CURRENT_DATE
                )
                AND rol.codigo = 'ARBITRO'
                AND rol.activo = TRUE
          )

        ORDER BY
            usuario.apellido_paterno,
            usuario.nombres
        """
    )

    filas = await cursor.fetchall()

    return [
        ArbitroOpcionRespuesta.model_validate(fila)
        for fila in filas
    ]


@router.get(
    "",
    response_model=ListaPartidosRespuesta,
    status_code=status.HTTP_200_OK,
    summary="Listar partidos",
)
async def listar_partidos(
    conexion: ConexionPostgresql,
    id_usuario: UsuarioConsultaPartido,
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
) -> ListaPartidosRespuesta:
    estado_normalizado = (
        estado.strip().upper()
        if estado is not None
        else None
    )

    cursor = await conexion.execute(
        """
        SELECT
            id_partido,
            codigo,
            numero_partido,
            nombre_ronda,

            id_torneo,
            torneo,

            fase,
            numero_jornada,
            jornada,

            grupo,

            lugar,
            direccion_lugar,

            fecha_hora_inicio,
            fecha_hora_fin,

            estado_partido,

            EXISTS (
                SELECT 1
                FROM competencia.arbitro_partido arbitro_partido
                WHERE arbitro_partido.id_partido =
                      partido_vista.id_partido
                  AND arbitro_partido.id_arbitro = %s
                  AND arbitro_partido.activo = TRUE
                  AND arbitro_partido.fecha_fin IS NULL
            ) AS arbitro_actual_asignado,

            (
                SELECT partido_equipo.id_inscripcion
                FROM competencia.partido_equipo partido_equipo
                INNER JOIN catalogo.condicion_equipo_partido condicion
                    ON condicion.id_condicion_equipo =
                       partido_equipo.id_condicion_equipo
                WHERE partido_equipo.id_partido =
                      partido_vista.id_partido
                  AND condicion.codigo = 'LOCAL'
                LIMIT 1
            ) AS id_inscripcion_local,

            equipo_local,
            marcador_local,
            desempate_local,
            resultado_local,

            (
                SELECT partido_equipo.id_inscripcion
                FROM competencia.partido_equipo partido_equipo
                INNER JOIN catalogo.condicion_equipo_partido condicion
                    ON condicion.id_condicion_equipo =
                       partido_equipo.id_condicion_equipo
                WHERE partido_equipo.id_partido =
                      partido_vista.id_partido
                  AND condicion.codigo = 'VISITANTE'
                LIMIT 1
            ) AS id_inscripcion_visitante,

            equipo_visitante,
            marcador_visitante,
            desempate_visitante,
            resultado_visitante,

            observaciones

        FROM reportes.vw_partidos_detalle partido_vista

        WHERE (
            %s::bigint IS NULL
            OR id_torneo = %s
        )

        AND (
            %s::text IS NULL
            OR estado_partido = %s
        )

        ORDER BY
            fecha_hora_inicio DESC,
            id_partido DESC
        """,
        (
            id_usuario,
            id_torneo,
            id_torneo,
            estado_normalizado,
            estado_normalizado,
        ),
    )

    filas = await cursor.fetchall()

    resultados = [
        PartidoRespuesta.model_validate(fila)
        for fila in filas
    ]

    return ListaPartidosRespuesta(
        total=len(resultados),
        resultados=resultados,
    )


@router.post(
    "",
    response_model=PartidoRespuesta,
    status_code=status.HTTP_201_CREATED,
    summary="Programar partido",
)
async def programar_partido(
    datos: PartidoCrear,
    conexion: ConexionPostgresql,
    id_usuario: UsuarioGestionPartido,
) -> PartidoRespuesta:
    await establecer_usuario_aplicacion(
        conexion=conexion,
        id_usuario=id_usuario,
    )

    try:
        await conexion.execute(
            """
            CALL competencia.sp_programar_partido(
                %s::bigint,
                %s::bigint,
                %s::varchar,
                %s::smallint,
                %s::timestamptz,
                %s::timestamptz,
                %s::bigint,
                %s::bigint,
                %s::bigint,
                %s::bigint,
                %s::varchar,
                %s::varchar
            )
            """,
            (
                datos.id_jornada,
                datos.id_lugar,
                datos.codigo,
                datos.numero_partido,
                datos.fecha_hora_inicio,
                datos.fecha_hora_fin,
                datos.id_inscripcion_local,
                datos.id_inscripcion_visitante,
                id_usuario,
                datos.id_grupo_torneo,
                datos.nombre_ronda,
                datos.observaciones,
            ),
        )

        cursor = await conexion.execute(
            """
            SELECT id_partido
            FROM competencia.partido
            WHERE codigo = %s
            """,
            (datos.codigo,),
        )

        fila = await cursor.fetchone()

    except UniqueViolation as error:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=(
                "Ya existe un partido con ese codigo"
            ),
        ) from error

    except (
        CheckViolation,
        ExclusionViolation,
        ForeignKeyViolation,
        RaiseException,
    ) as error:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=obtener_mensaje_postgresql(
                error,
                "PostgreSQL rechazo la programacion del partido",
            ),
        ) from error

    if fila is None:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="No se pudo recuperar el partido",
        )

    return await buscar_partido(
        conexion=conexion,
        id_partido=int(fila["id_partido"]),
        id_usuario=id_usuario,
    )


@router.post(
    "/{id_partido}/arbitros",
    response_model=OperacionPartidoRespuesta,
    status_code=status.HTTP_201_CREATED,
    summary="Asignar arbitro al partido",
)
async def asignar_arbitro(
    datos: ArbitroAsignar,
    conexion: ConexionPostgresql,
    id_usuario: UsuarioGestionPartido,
    id_partido: Annotated[
        int,
        Path(ge=1),
    ],
) -> OperacionPartidoRespuesta:
    partido = await buscar_partido(
        conexion=conexion,
        id_partido=id_partido,
        id_usuario=id_usuario,
    )
    validar_estado_partido(
        partido,
        {"BORRADOR", "PROGRAMADO"},
        "asignar árbitros a",
    )

    await establecer_usuario_aplicacion(
        conexion=conexion,
        id_usuario=id_usuario,
    )

    try:
        await conexion.execute(
            """
            CALL competencia.sp_asignar_arbitro_partido(
                %s::bigint,
                %s::bigint,
                %s::varchar,
                %s::bigint,
                %s::varchar
            )
            """,
            (
                id_partido,
                datos.id_arbitro,
                datos.tipo_arbitro,
                id_usuario,
                datos.observaciones,
            ),
        )

    except UniqueViolation as error:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=obtener_mensaje_postgresql(
                error,
                "El árbitro o el tipo de árbitro ya está asignado",
            ),
        ) from error

    except (
        CheckViolation,
        ExclusionViolation,
        ForeignKeyViolation,
        RaiseException,
    ) as error:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=obtener_mensaje_postgresql(
                error,
                "PostgreSQL rechazo la asignacion del arbitro",
            ),
        ) from error

    return OperacionPartidoRespuesta(
        mensaje="Arbitro asignado correctamente",
        id_partido=id_partido,
    )


@router.patch(
    "/{id_partido}/iniciar",
    response_model=PartidoRespuesta,
    status_code=status.HTTP_200_OK,
    summary="Iniciar partido",
)
async def iniciar_partido(
    conexion: ConexionPostgresql,
    id_usuario: UsuarioOperacionPartido,
    id_partido: Annotated[
        int,
        Path(ge=1),
    ],
) -> PartidoRespuesta:
    partido = await buscar_partido(
        conexion=conexion,
        id_partido=id_partido,
        id_usuario=id_usuario,
    )
    validar_estado_partido(
        partido,
        {"PROGRAMADO"},
        "iniciar",
    )

    await verificar_permiso_operacion_partido(
        conexion=conexion,
        id_partido=id_partido,
        id_usuario=id_usuario,
    )

    cursor = await conexion.execute(
        """
        SELECT EXISTS (
            SELECT 1
            FROM competencia.arbitro_partido arbitro_partido
            WHERE arbitro_partido.id_partido = %s
              AND arbitro_partido.activo = TRUE
              AND arbitro_partido.fecha_fin IS NULL
        ) AS tiene_arbitro
        """,
        (id_partido,),
    )
    fila_arbitro = await cursor.fetchone()
    if not fila_arbitro or not fila_arbitro["tiene_arbitro"]:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail="Debe asignar al menos un árbitro antes de iniciar el partido",
        )

    await establecer_usuario_aplicacion(
        conexion=conexion,
        id_usuario=id_usuario,
    )

    try:
        await conexion.execute(
            """
            CALL competencia.sp_iniciar_partido(
                %s::bigint,
                %s::bigint
            )
            """,
            (
                id_partido,
                id_usuario,
            ),
        )

    except (
        CheckViolation,
        ForeignKeyViolation,
        RaiseException,
    ) as error:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=obtener_mensaje_postgresql(
                error,
                "El partido no pudo ser iniciado",
            ),
        ) from error

    return await buscar_partido(
        conexion=conexion,
        id_partido=id_partido,
        id_usuario=id_usuario,
    )


@router.get(
    "/{id_partido}/participaciones",
    response_model=list[ParticipacionJugadorRespuesta],
    status_code=status.HTTP_200_OK,
    summary="Consultar asistencia y estadisticas",
)
async def listar_participaciones(
    conexion: ConexionPostgresql,
    id_usuario: UsuarioConsultaPartido,
    id_partido: Annotated[
        int,
        Path(ge=1),
    ],
) -> list[ParticipacionJugadorRespuesta]:
    await buscar_partido(
        conexion=conexion,
        id_partido=id_partido,
        id_usuario=id_usuario,
    )

    cursor = await conexion.execute(
        """
        SELECT
            id_jugador_partido,

            id_torneo,
            torneo,

            id_partido,
            partido,

            id_equipo,
            equipo,

            id_jugador,
            numero_documento,
            nombres,
            apellido_paterno,
            apellido_materno,

            convocado,
            asistio,
            titular,

            minutos_jugados,
            puntos_anotados,
            faltas,
            amonestaciones,

            expulsado,
            lesionado,

            calificacion,
            estadisticas,

            fecha_actualizacion

        FROM reportes.vw_asistencia_jugadores

        WHERE id_partido = %s

        ORDER BY
            equipo,
            apellido_paterno,
            nombres
        """,
        (id_partido,),
    )

    filas = await cursor.fetchall()

    return [
        ParticipacionJugadorRespuesta.model_validate(fila)
        for fila in filas
    ]


@router.post(
    "/{id_partido}/participaciones",
    response_model=OperacionPartidoRespuesta,
    status_code=status.HTTP_201_CREATED,
    summary="Registrar asistencia y estadisticas",
)
async def registrar_participacion(
    datos: ParticipacionJugadorCrear,
    conexion: ConexionPostgresql,
    id_usuario: UsuarioOperacionPartido,
    id_partido: Annotated[
        int,
        Path(ge=1),
    ],
) -> OperacionPartidoRespuesta:
    partido = await buscar_partido(
        conexion=conexion,
        id_partido=id_partido,
        id_usuario=id_usuario,
    )
    validar_estado_partido(
        partido,
        {"EN_CURSO"},
        "registrar participaciones en",
    )

    await verificar_permiso_operacion_partido(
        conexion=conexion,
        id_partido=id_partido,
        id_usuario=id_usuario,
    )

    await establecer_usuario_aplicacion(
        conexion=conexion,
        id_usuario=id_usuario,
    )

    try:
        await conexion.execute(
            """
            CALL competencia.sp_registrar_participacion_jugador(
                %s::bigint,
                %s::bigint,
                %s::boolean,
                %s::boolean,
                %s::boolean,
                %s::smallint,
                %s::integer,
                %s::smallint,
                %s::smallint,
                %s::boolean,
                %s::boolean,
                %s::numeric,
                %s::jsonb,
                %s::bigint,
                %s::varchar
            )
            """,
            (
                id_partido,
                datos.id_jugador_inscripcion,
                datos.convocado,
                datos.asistio,
                datos.titular,
                datos.minutos_jugados,
                datos.puntos_anotados,
                datos.faltas,
                datos.amonestaciones,
                datos.expulsado,
                datos.lesionado,
                datos.calificacion,
                datos.estadisticas,
                id_usuario,
                datos.observaciones,
            ),
        )

    except UniqueViolation as error:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=(
                "La participacion del jugador "
                "ya se encuentra registrada"
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
                "PostgreSQL rechazo la participacion",
            ),
        ) from error

    return OperacionPartidoRespuesta(
        mensaje="Participacion registrada correctamente",
        id_partido=id_partido,
    )


@router.patch(
    "/{id_partido}/finalizar",
    response_model=PartidoRespuesta,
    status_code=status.HTTP_200_OK,
    summary="Finalizar partido y registrar marcador",
)
async def finalizar_partido(
    datos: PartidoFinalizar,
    conexion: ConexionPostgresql,
    id_usuario: UsuarioOperacionPartido,
    id_partido: Annotated[
        int,
        Path(ge=1),
    ],
) -> PartidoRespuesta:
    partido = await buscar_partido(
        conexion=conexion,
        id_partido=id_partido,
        id_usuario=id_usuario,
    )
    validar_estado_partido(
        partido,
        {"EN_CURSO"},
        "finalizar",
    )

    await verificar_permiso_operacion_partido(
        conexion=conexion,
        id_partido=id_partido,
        id_usuario=id_usuario,
    )

    await establecer_usuario_aplicacion(
        conexion=conexion,
        id_usuario=id_usuario,
    )

    try:
        await conexion.execute(
            """
            CALL competencia.sp_finalizar_partido(
                %s::bigint,
                %s::integer,
                %s::integer,
                %s::integer,
                %s::integer,
                %s::bigint,
                %s::varchar
            )
            """,
            (
                id_partido,
                datos.marcador_local,
                datos.marcador_visitante,
                datos.desempate_local,
                datos.desempate_visitante,
                id_usuario,
                datos.observaciones,
            ),
        )

    except (
        CheckViolation,
        ForeignKeyViolation,
        RaiseException,
    ) as error:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=obtener_mensaje_postgresql(
                error,
                "PostgreSQL rechazo el resultado del partido",
            ),
        ) from error

    return await buscar_partido(
        conexion=conexion,
        id_partido=id_partido,
        id_usuario=id_usuario,
    )


@router.get(
    "/{id_partido}",
    response_model=PartidoRespuesta,
    status_code=status.HTTP_200_OK,
    summary="Obtener detalle de un partido",
)
async def obtener_partido(
    conexion: ConexionPostgresql,
    id_usuario: UsuarioConsultaPartido,
    id_partido: Annotated[
        int,
        Path(ge=1),
    ],
) -> PartidoRespuesta:
    return await buscar_partido(
        conexion=conexion,
        id_partido=id_partido,
        id_usuario=id_usuario,
    )