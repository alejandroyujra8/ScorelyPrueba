BEGIN;

CREATE OR REPLACE FUNCTION reportes.fn_resumen_torneo(
    p_id_torneo BIGINT
)
RETURNS TABLE (
    id_torneo BIGINT,
    codigo VARCHAR,
    torneo VARCHAR,
    deporte VARCHAR,
    formato VARCHAR,
    estado VARCHAR,
    total_inscripciones BIGINT,
    inscripciones_habilitadas BIGINT,
    total_fases BIGINT,
    total_partidos BIGINT,
    partidos_finalizados BIGINT,
    total_recaudado NUMERIC
)
LANGUAGE sql
STABLE
AS $$
    SELECT
        resumen.id_torneo,
        resumen.codigo::VARCHAR,
        resumen.nombre::VARCHAR,
        resumen.deporte::VARCHAR,
        resumen.formato::VARCHAR,
        resumen.estado_torneo::VARCHAR,
        resumen.total_inscripciones,
        resumen.inscripciones_habilitadas,
        resumen.total_fases,
        resumen.total_partidos,
        resumen.partidos_finalizados,
        resumen.total_recaudado
    FROM reportes.vw_torneos_resumen resumen
    WHERE resumen.id_torneo =
          p_id_torneo;
$$;


CREATE OR REPLACE FUNCTION reportes.fn_finanzas_torneo(
    p_id_torneo BIGINT
)
RETURNS TABLE (
    id_torneo BIGINT,
    torneo VARCHAR,
    inscripciones BIGINT,
    monto_total_requerido NUMERIC,
    total_pagado NUMERIC,
    saldo_pendiente NUMERIC,
    pagos_confirmados BIGINT,
    pagos_pendientes BIGINT,
    pagos_rechazados BIGINT
)
LANGUAGE sql
STABLE
AS $$
    WITH resumen_inscripciones AS (
        SELECT
            inscripcion.id_torneo,

            COUNT(*) AS inscripciones,

            COALESCE(
                SUM(inscripcion.monto_requerido),
                0
            ) AS monto_total_requerido

        FROM competencia.inscripcion inscripcion

        WHERE inscripcion.id_torneo =
              p_id_torneo

        GROUP BY inscripcion.id_torneo
    ),

    resumen_pagos AS (
        SELECT
            inscripcion.id_torneo,

            COALESCE(
                SUM(pago.monto) FILTER (
                    WHERE estado_pago.codigo =
                          'CONFIRMADO'
                ),
                0
            ) AS total_pagado,

            COUNT(pago.id_pago) FILTER (
                WHERE estado_pago.codigo =
                      'CONFIRMADO'
            ) AS pagos_confirmados,

            COUNT(pago.id_pago) FILTER (
                WHERE estado_pago.codigo =
                      'PENDIENTE'
            ) AS pagos_pendientes,

            COUNT(pago.id_pago) FILTER (
                WHERE estado_pago.codigo =
                      'RECHAZADO'
            ) AS pagos_rechazados

        FROM competencia.inscripcion inscripcion

        LEFT JOIN finanzas.pago pago
            ON pago.id_inscripcion =
               inscripcion.id_inscripcion

        LEFT JOIN catalogo.estado_pago estado_pago
            ON estado_pago.id_estado_pago =
               pago.id_estado_pago

        WHERE inscripcion.id_torneo =
              p_id_torneo

        GROUP BY inscripcion.id_torneo
    )

    SELECT
        torneo.id_torneo,
        torneo.nombre::VARCHAR,

        COALESCE(
            inscripciones.inscripciones,
            0
        ),

        COALESCE(
            inscripciones.monto_total_requerido,
            0
        ),

        COALESCE(
            pagos.total_pagado,
            0
        ),

        GREATEST(
            COALESCE(
                inscripciones.monto_total_requerido,
                0
            )
            -
            COALESCE(
                pagos.total_pagado,
                0
            ),
            0
        ),

        COALESCE(
            pagos.pagos_confirmados,
            0
        ),

        COALESCE(
            pagos.pagos_pendientes,
            0
        ),

        COALESCE(
            pagos.pagos_rechazados,
            0
        )

    FROM competencia.torneo torneo

    LEFT JOIN resumen_inscripciones inscripciones
        ON inscripciones.id_torneo =
           torneo.id_torneo

    LEFT JOIN resumen_pagos pagos
        ON pagos.id_torneo =
           torneo.id_torneo

    WHERE torneo.id_torneo =
          p_id_torneo;
$$;

CREATE OR REPLACE FUNCTION reportes.fn_rendimiento_jugador(
    p_id_jugador BIGINT
)
RETURNS TABLE (
    id_torneo BIGINT,
    torneo VARCHAR,
    equipo VARCHAR,
    partidos_registrados BIGINT,
    veces_convocado BIGINT,
    asistencias BIGINT,
    titularidades BIGINT,
    porcentaje_asistencia NUMERIC,
    minutos_jugados BIGINT,
    puntos_anotados BIGINT,
    faltas BIGINT,
    amonestaciones BIGINT,
    expulsiones BIGINT,
    lesiones BIGINT,
    calificacion_promedio NUMERIC
)
LANGUAGE sql
STABLE
AS $$
    SELECT
        estadistica.id_torneo,
        estadistica.torneo::VARCHAR,
        estadistica.equipo::VARCHAR,
        estadistica.partidos_registrados,
        estadistica.veces_convocado,
        estadistica.asistencias,
        estadistica.titularidades,
        estadistica.porcentaje_asistencia,
        estadistica.minutos_jugados,
        estadistica.puntos_anotados,
        estadistica.faltas,
        estadistica.amonestaciones,
        estadistica.expulsiones,
        estadistica.lesiones,
        estadistica.calificacion_promedio

    FROM reportes.vw_estadisticas_jugadores_torneo estadistica

    WHERE estadistica.id_jugador =
          p_id_jugador

    ORDER BY estadistica.id_torneo;
$$;


CREATE OR REPLACE FUNCTION reportes.fn_historial_equipo(
    p_id_equipo BIGINT
)
RETURNS TABLE (
    id_torneo BIGINT,
    torneo VARCHAR,
    estado_torneo VARCHAR,
    estado_inscripcion VARCHAR,
    posicion_final SMALLINT,
    partidos_jugados SMALLINT,
    partidos_ganados SMALLINT,
    partidos_empatados SMALLINT,
    partidos_perdidos SMALLINT,
    puntos INTEGER
)
LANGUAGE sql
STABLE
AS $$
    SELECT
        torneo.id_torneo,
        torneo.nombre::VARCHAR,
        estado_torneo.codigo::VARCHAR,
        estado_inscripcion.codigo::VARCHAR,

        resultado.posicion_final,
        resultado.partidos_jugados,
        resultado.partidos_ganados,
        resultado.partidos_empatados,
        resultado.partidos_perdidos,
        resultado.puntos

    FROM competencia.inscripcion inscripcion

    INNER JOIN competencia.torneo torneo
        ON torneo.id_torneo =
           inscripcion.id_torneo

    INNER JOIN catalogo.estado_torneo estado_torneo
        ON estado_torneo.id_estado_torneo =
           torneo.id_estado_torneo

    INNER JOIN catalogo.estado_inscripcion estado_inscripcion
        ON estado_inscripcion.id_estado_inscripcion =
           inscripcion.id_estado_inscripcion

    LEFT JOIN competencia.resultado_torneo resultado
        ON resultado.id_inscripcion =
           inscripcion.id_inscripcion

    WHERE inscripcion.id_equipo =
          p_id_equipo

    ORDER BY
        torneo.fecha_inicio_torneo DESC;
$$;

COMMIT;