\set ON_ERROR_STOP on

BEGIN;

SELECT SET_CONFIG(
    'app.request_id',
    'PARTIDOS-DEMO-UMSA-2026',
    TRUE
);

SELECT SET_CONFIG(
    'app.ip_cliente',
    '127.0.0.1',
    TRUE
);

SELECT SET_CONFIG(
    'app.usuario_id',
    '487',
    TRUE
);

-- ============================================================
-- CERRAR INSCRIPCIONES DEL TORNEO
-- ============================================================

UPDATE competencia.torneo
SET
    id_estado_torneo = (
        SELECT id_estado_torneo
        FROM catalogo.estado_torneo
        WHERE codigo = 'INSCRIPCIONES_CERRADAS'
    ),
    fecha_actualizacion = CURRENT_TIMESTAMP
WHERE codigo = 'UMSA-FUT-2026'
  AND id_estado_torneo = (
      SELECT id_estado_torneo
      FROM catalogo.estado_torneo
      WHERE codigo = 'INSCRIPCIONES_ABIERTAS'
  );

-- ============================================================
-- PARTIDO 1: INGENIERÍA VS MEDICINA
-- ============================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM competencia.partido
        WHERE codigo = 'UMSA-GA-F1-P01'
    ) THEN
        CALL competencia.sp_programar_partido(
            p_id_jornada := 48,
            p_id_lugar := 61,
            p_codigo := 'UMSA-GA-F1-P01',
            p_numero_partido := 1::SMALLINT,
            p_fecha_hora_inicio :=
                TIMESTAMPTZ '2026-07-12 09:00:00-04',
            p_fecha_hora_fin :=
                TIMESTAMPTZ '2026-07-12 10:30:00-04',
            p_id_inscripcion_local := 63,
            p_id_inscripcion_visitante := 65,
            p_creado_por := 487,
            p_id_grupo_torneo := 18,
            p_nombre_ronda := 'Primera fecha - Grupo A',
            p_observaciones :=
                'Partido demo entre Ingeniería y Medicina'
        );
    END IF;
END;
$$;

-- ============================================================
-- PARTIDO 2: CIENCIAS PURAS VS DERECHO
-- ============================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM competencia.partido
        WHERE codigo = 'UMSA-GA-F1-P02'
    ) THEN
        CALL competencia.sp_programar_partido(
            p_id_jornada := 48,
            p_id_lugar := 61,
            p_codigo := 'UMSA-GA-F1-P02',
            p_numero_partido := 2::SMALLINT,
            p_fecha_hora_inicio :=
                TIMESTAMPTZ '2026-07-12 11:00:00-04',
            p_fecha_hora_fin :=
                TIMESTAMPTZ '2026-07-12 12:30:00-04',
            p_id_inscripcion_local := 64,
            p_id_inscripcion_visitante := 66,
            p_creado_por := 487,
            p_id_grupo_torneo := 18,
            p_nombre_ronda := 'Primera fecha - Grupo A',
            p_observaciones :=
                'Partido demo entre Ciencias Puras y Derecho'
        );
    END IF;
END;
$$;

-- ============================================================
-- PARTIDO 3: ARQUITECTURA VS ECONOMÍA
-- ============================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM competencia.partido
        WHERE codigo = 'UMSA-GB-F1-P01'
    ) THEN
        CALL competencia.sp_programar_partido(
            p_id_jornada := 48,
            p_id_lugar := 59,
            p_codigo := 'UMSA-GB-F1-P01',
            p_numero_partido := 3::SMALLINT,
            p_fecha_hora_inicio :=
                TIMESTAMPTZ '2026-07-12 14:00:00-04',
            p_fecha_hora_fin :=
                TIMESTAMPTZ '2026-07-12 15:30:00-04',
            p_id_inscripcion_local := 69,
            p_id_inscripcion_visitante := 67,
            p_creado_por := 487,
            p_id_grupo_torneo := 17,
            p_nombre_ronda := 'Primera fecha - Grupo B',
            p_observaciones :=
                'Partido demo entre Arquitectura y Economía'
        );
    END IF;
END;
$$;

-- ============================================================
-- ASIGNACIÓN DE ÁRBITROS
-- Carlos: 489
-- Lucía: 490
-- ============================================================

DO $$
DECLARE
    v_id_partido BIGINT;
BEGIN
    SELECT id_partido
    INTO v_id_partido
    FROM competencia.partido
    WHERE codigo = 'UMSA-GA-F1-P01';

    IF NOT EXISTS (
        SELECT 1
        FROM competencia.arbitro_partido
        WHERE id_partido = v_id_partido
          AND id_arbitro = 489
    ) THEN
        CALL competencia.sp_asignar_arbitro_partido(
            p_id_partido := v_id_partido,
            p_id_arbitro := 489,
            p_tipo_arbitro := 'PRINCIPAL',
            p_asignado_por := 487,
            p_observaciones :=
                'Árbitro principal del partido demo'
        );
    END IF;
END;
$$;

DO $$
DECLARE
    v_id_partido BIGINT;
BEGIN
    SELECT id_partido
    INTO v_id_partido
    FROM competencia.partido
    WHERE codigo = 'UMSA-GA-F1-P02';

    IF NOT EXISTS (
        SELECT 1
        FROM competencia.arbitro_partido
        WHERE id_partido = v_id_partido
          AND id_arbitro = 490
    ) THEN
        CALL competencia.sp_asignar_arbitro_partido(
            p_id_partido := v_id_partido,
            p_id_arbitro := 490,
            p_tipo_arbitro := 'PRINCIPAL',
            p_asignado_por := 487,
            p_observaciones :=
                'Árbitra principal del partido demo'
        );
    END IF;
END;
$$;

DO $$
DECLARE
    v_id_partido BIGINT;
BEGIN
    SELECT id_partido
    INTO v_id_partido
    FROM competencia.partido
    WHERE codigo = 'UMSA-GB-F1-P01';

    IF NOT EXISTS (
        SELECT 1
        FROM competencia.arbitro_partido
        WHERE id_partido = v_id_partido
          AND id_arbitro = 489
    ) THEN
        CALL competencia.sp_asignar_arbitro_partido(
            p_id_partido := v_id_partido,
            p_id_arbitro := 489,
            p_tipo_arbitro := 'PRINCIPAL',
            p_asignado_por := 487,
            p_observaciones :=
                'Árbitro principal del partido demo'
        );
    END IF;
END;
$$;

COMMIT;

-- ============================================================
-- RESULTADO DE LA CARGA
-- ============================================================

SELECT
    partido.codigo,
    partido.nombre_ronda,
    jornada.nombre AS jornada,
    grupo.codigo AS grupo,
    lugar.nombre AS lugar,
    partido.fecha_hora_inicio,
    estado.codigo AS estado
FROM competencia.partido partido
INNER JOIN competencia.jornada jornada
    ON jornada.id_jornada = partido.id_jornada
LEFT JOIN competencia.grupo_torneo grupo
    ON grupo.id_grupo_torneo =
       partido.id_grupo_torneo
INNER JOIN competencia.lugar lugar
    ON lugar.id_lugar = partido.id_lugar
INNER JOIN catalogo.estado_partido estado
    ON estado.id_estado_partido =
       partido.id_estado_partido
WHERE partido.codigo IN (
    'UMSA-GA-F1-P01',
    'UMSA-GA-F1-P02',
    'UMSA-GB-F1-P01'
)
ORDER BY partido.fecha_hora_inicio;
