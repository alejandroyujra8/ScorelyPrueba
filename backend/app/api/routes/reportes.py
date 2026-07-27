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

from app.api.dependencies.auth import requerir_roles
from app.core.database import obtener_conexion
from app.schemas.auth import UsuarioAutenticadoRespuesta
from app.schemas.reporte import (
    DashboardRespuesta,
    ReporteListaRespuesta,
    ReporteObjetoRespuesta,
)


router = APIRouter(
    prefix="/api/reportes",
    tags=["Reportes"],
)


ConexionPostgresql = Annotated[
    AsyncConnection,
    Depends(obtener_conexion),
]


UsuarioAdministrador = Annotated[
    UsuarioAutenticadoRespuesta,
    Depends(
        requerir_roles(
            "ADMINISTRADOR",
        )
    ),
]


UsuarioGestor = Annotated[
    UsuarioAutenticadoRespuesta,
    Depends(
        requerir_roles(
            "ADMINISTRADOR",
            "ORGANIZADOR",
        )
    ),
]


@router.get(
    "/dashboard",
    response_model=DashboardRespuesta,
    status_code=status.HTTP_200_OK,
    summary="Obtener indicadores generales",
)
async def obtener_dashboard(
    conexion: ConexionPostgresql,
) -> DashboardRespuesta:
    cursor = await conexion.execute(
        """
        SELECT
            (
                SELECT COUNT(*)
                FROM seguridad.usuario
            ) AS total_usuarios,

            (
                SELECT COUNT(*)
                FROM participantes.equipo
            ) AS total_equipos,

            (
                SELECT COUNT(*)
                FROM participantes.jugador
            ) AS total_jugadores,

            (
                SELECT COUNT(*)
                FROM competencia.torneo
            ) AS total_torneos,

            (
                SELECT COUNT(*)
                FROM competencia.torneo torneo

                INNER JOIN catalogo.estado_torneo estado
                    ON estado.id_estado_torneo =
                       torneo.id_estado_torneo

                WHERE estado.codigo = 'EN_CURSO'
            ) AS torneos_en_curso,

            (
                SELECT COUNT(*)
                FROM competencia.partido
            ) AS total_partidos,

            (
                SELECT COUNT(*)
                FROM competencia.partido partido

                INNER JOIN catalogo.estado_partido estado
                    ON estado.id_estado_partido =
                       partido.id_estado_partido

                WHERE estado.codigo = 'FINALIZADO'
            ) AS partidos_finalizados,

            COALESCE(
                (
                    SELECT SUM(pago.monto)

                    FROM finanzas.pago pago

                    INNER JOIN catalogo.estado_pago estado
                        ON estado.id_estado_pago =
                           pago.id_estado_pago

                    WHERE estado.codigo = 'CONFIRMADO'
                ),
                0
            ) AS total_recaudado,

            (
                SELECT COUNT(*)

                FROM finanzas.entrega_premio entrega

                INNER JOIN catalogo.estado_entrega_premio estado
                    ON estado.id_estado_entrega_premio =
                       entrega.id_estado_entrega_premio

                WHERE estado.codigo = 'ENTREGADO'
            ) AS premios_entregados
        """
    )

    fila = await cursor.fetchone()

    if fila is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="No se pudieron obtener los indicadores",
        )

    return DashboardRespuesta.model_validate(fila)


@router.get(
    "/torneos/{id_torneo}/resumen",
    response_model=ReporteObjetoRespuesta,
    status_code=status.HTTP_200_OK,
    summary="Obtener resumen de un torneo",
)
async def obtener_resumen_torneo(
    conexion: ConexionPostgresql,
    id_torneo: Annotated[
        int,
        Path(ge=1),
    ],
) -> ReporteObjetoRespuesta:
    cursor = await conexion.execute(
        """
        SELECT *
        FROM reportes.fn_resumen_torneo(
            %s::bigint
        )
        """,
        (id_torneo,),
    )

    fila: dict[str, Any] | None = await cursor.fetchone()

    if fila is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="El torneo no existe",
        )

    return ReporteObjetoRespuesta(
        datos=dict(fila),
    )


@router.get(
    "/torneos/{id_torneo}/finanzas",
    response_model=ReporteObjetoRespuesta,
    status_code=status.HTTP_200_OK,
    summary="Obtener reporte financiero del torneo",
)
async def obtener_finanzas_torneo(
    conexion: ConexionPostgresql,
    _: UsuarioGestor,
    id_torneo: Annotated[
        int,
        Path(ge=1),
    ],
) -> ReporteObjetoRespuesta:
    cursor = await conexion.execute(
        """
        SELECT *
        FROM reportes.fn_finanzas_torneo(
            %s::bigint
        )
        """,
        (id_torneo,),
    )

    fila: dict[str, Any] | None = await cursor.fetchone()

    if fila is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="El torneo no existe",
        )

    return ReporteObjetoRespuesta(
        datos=dict(fila),
    )


@router.get(
    "/torneos/{id_torneo}/resultados",
    response_model=ReporteListaRespuesta,
    status_code=status.HTTP_200_OK,
    summary="Obtener resultados finales del torneo",
)
async def obtener_resultados_torneo(
    conexion: ConexionPostgresql,
    id_torneo: Annotated[
        int,
        Path(ge=1),
    ],
) -> ReporteListaRespuesta:
    cursor = await conexion.execute(
        """
        SELECT
            id_resultado_torneo,
            id_torneo,
            codigo_torneo,
            torneo,
            deporte,
            posicion_final,
            id_equipo,
            equipo,
            sigla,
            partidos_jugados,
            partidos_ganados,
            partidos_empatados,
            partidos_perdidos,
            marcador_favor,
            marcador_contra,
            diferencia_marcador,
            puntos,
            fecha_generacion,
            observaciones

        FROM reportes.vw_resultados_torneo

        WHERE id_torneo = %s

        ORDER BY posicion_final
        """,
        (id_torneo,),
    )

    filas = await cursor.fetchall()

    return ReporteListaRespuesta(
        total=len(filas),
        datos=[
            dict(fila)
            for fila in filas
        ],
    )


@router.get(
    "/torneos/{id_torneo}/jugadores",
    response_model=ReporteListaRespuesta,
    status_code=status.HTTP_200_OK,
    summary="Obtener estadísticas de jugadores",
)
async def obtener_estadisticas_jugadores_torneo(
    conexion: ConexionPostgresql,
    id_torneo: Annotated[
        int,
        Path(ge=1),
    ],
) -> ReporteListaRespuesta:
    cursor = await conexion.execute(
        """
        SELECT
            id_torneo,
            torneo,
            id_jugador,
            numero_documento,
            nombres,
            apellido_paterno,
            apellido_materno,
            id_equipo,
            equipo,
            partidos_registrados,
            veces_convocado,
            asistencias,
            titularidades,
            porcentaje_asistencia,
            minutos_jugados,
            puntos_anotados,
            faltas,
            amonestaciones,
            expulsiones,
            lesiones,
            calificacion_promedio

        FROM reportes.vw_estadisticas_jugadores_torneo

        WHERE id_torneo = %s

        ORDER BY
            puntos_anotados DESC,
            calificacion_promedio DESC NULLS LAST,
            apellido_paterno,
            nombres
        """,
        (id_torneo,),
    )

    filas = await cursor.fetchall()

    return ReporteListaRespuesta(
        total=len(filas),
        datos=[
            dict(fila)
            for fila in filas
        ],
    )


@router.get(
    "/jugadores/{id_jugador}/rendimiento",
    response_model=ReporteListaRespuesta,
    status_code=status.HTTP_200_OK,
    summary="Obtener rendimiento histórico de un jugador",
)
async def obtener_rendimiento_jugador(
    conexion: ConexionPostgresql,
    id_jugador: Annotated[
        int,
        Path(ge=1),
    ],
) -> ReporteListaRespuesta:
    cursor = await conexion.execute(
        """
        SELECT *
        FROM reportes.fn_rendimiento_jugador(
            %s::bigint
        )
        """,
        (id_jugador,),
    )

    filas = await cursor.fetchall()

    return ReporteListaRespuesta(
        total=len(filas),
        datos=[
            dict(fila)
            for fila in filas
        ],
    )


@router.get(
    "/equipos/{id_equipo}/historial",
    response_model=ReporteListaRespuesta,
    status_code=status.HTTP_200_OK,
    summary="Obtener historial deportivo de un equipo",
)
async def obtener_historial_equipo(
    conexion: ConexionPostgresql,
    id_equipo: Annotated[
        int,
        Path(ge=1),
    ],
) -> ReporteListaRespuesta:
    cursor = await conexion.execute(
        """
        SELECT *
        FROM reportes.fn_historial_equipo(
            %s::bigint
        )
        """,
        (id_equipo,),
    )

    filas = await cursor.fetchall()

    return ReporteListaRespuesta(
        total=len(filas),
        datos=[
            dict(fila)
            for fila in filas
        ],
    )


@router.get(
    "/torneos/{id_torneo}/premios",
    response_model=ReporteListaRespuesta,
    status_code=status.HTTP_200_OK,
    summary="Obtener premios de un torneo",
)
async def obtener_premios_torneo(
    conexion: ConexionPostgresql,
    id_torneo: Annotated[
        int,
        Path(ge=1),
    ],
) -> ReporteListaRespuesta:
    cursor = await conexion.execute(
        """
        SELECT
            id_torneo_premio,
            id_torneo,
            torneo,
            posicion_objetivo,
            id_premio,
            premio,
            tipo_premio,
            valor_economico,
            moneda,
            id_resultado_torneo,
            posicion_final,
            id_equipo,
            equipo_ganador,
            id_entrega_premio,
            estado_entrega,
            fecha_autorizacion,
            fecha_entrega,
            autorizado_por,
            entregado_por,
            observaciones

        FROM reportes.vw_premios_entregas

        WHERE id_torneo = %s

        ORDER BY posicion_objetivo
        """,
        (id_torneo,),
    )

    filas = await cursor.fetchall()

    return ReporteListaRespuesta(
        total=len(filas),
        datos=[
            dict(fila)
            for fila in filas
        ],
    )


@router.get(
    "/auditoria",
    response_model=ReporteListaRespuesta,
    status_code=status.HTTP_200_OK,
    summary="Consultar auditoría DML",
)
async def consultar_auditoria(
    conexion: ConexionPostgresql,
    usuario: UsuarioAdministrador,
    esquema: Annotated[
        str | None,
        Query(
            min_length=1,
            max_length=63,
        ),
    ] = None,
    tabla: Annotated[
        str | None,
        Query(
            min_length=1,
            max_length=63,
        ),
    ] = None,
    operacion: Annotated[
        str | None,
        Query(
            min_length=3,
            max_length=10,
        ),
    ] = None,
    limite: Annotated[
        int,
        Query(
            ge=1,
            le=500,
        ),
    ] = 100,
) -> ReporteListaRespuesta:
    del usuario

    operacion_normalizada = (
        operacion.strip().upper()
        if operacion is not None
        else None
    )

    if operacion_normalizada not in {
        None,
        "INSERT",
        "UPDATE",
        "DELETE",
    }:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=(
                "La operacion debe ser INSERT, "
                "UPDATE o DELETE"
            ),
        )

    cursor = await conexion.execute(
        """
        SELECT id_auditoria,
               fecha_evento,
               esquema,
               tabla,
               operacion,

               identificador_registro::text AS identificador_registro,
               columnas_modificadas,
               datos_anteriores,
               datos_nuevos,
               cambios,

               usuario_aplicacion,

               usuario_aplicacion_nombre,
               usuario_postgresql,
               ip_cliente,
               id_solicitud,
               id_transaccion,
               aplicacion

        FROM reportes.vw_auditoria_dml_detalle

        WHERE (
            %s::text IS NULL
            OR esquema = %s
            )

          AND (
            %s::text IS NULL
            OR tabla = %s
            )

          AND (
            %s::text IS NULL
            OR operacion = %s
            )

        ORDER BY fecha_evento DESC
            LIMIT %s
        """,
        (
            esquema,
            esquema,
            tabla,
            tabla,
            operacion_normalizada,
            operacion_normalizada,
            limite,
        ),
    )

    filas = await cursor.fetchall()

    return ReporteListaRespuesta(
        total=len(filas),
        datos=[
            dict(fila)
            for fila in filas
        ],
    )