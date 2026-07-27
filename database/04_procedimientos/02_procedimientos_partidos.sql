BEGIN;

CREATE OR REPLACE PROCEDURE competencia.sp_asignar_equipo_grupo(
    IN p_id_fase_torneo BIGINT,
    IN p_id_grupo_torneo BIGINT,
    IN p_id_inscripcion BIGINT,
    IN p_posicion_sorteo SMALLINT,
    IN p_asignado_por BIGINT,
    IN p_observaciones VARCHAR DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO competencia.equipo_grupo (
        id_fase_torneo,
        id_grupo_torneo,
        id_inscripcion,
        posicion_sorteo,
        asignado_por,
        observaciones
    )
    VALUES (
        p_id_fase_torneo,
        p_id_grupo_torneo,
        p_id_inscripcion,
        p_posicion_sorteo,
        p_asignado_por,
        p_observaciones
    );
END;
$$;


CREATE OR REPLACE PROCEDURE competencia.sp_programar_partido(
    IN p_id_jornada BIGINT,
    IN p_id_lugar BIGINT,
    IN p_codigo VARCHAR,
    IN p_numero_partido SMALLINT,
    IN p_fecha_hora_inicio TIMESTAMPTZ,
    IN p_fecha_hora_fin TIMESTAMPTZ,
    IN p_id_inscripcion_local BIGINT,
    IN p_id_inscripcion_visitante BIGINT,
    IN p_creado_por BIGINT,
    IN p_id_grupo_torneo BIGINT DEFAULT NULL,
    IN p_nombre_ronda VARCHAR DEFAULT NULL,
    IN p_observaciones VARCHAR DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_partido BIGINT;
    v_id_estado_borrador SMALLINT;
    v_id_estado_programado SMALLINT;
    v_id_condicion_local SMALLINT;
    v_id_condicion_visitante SMALLINT;
    v_id_resultado_pendiente SMALLINT;
BEGIN
    IF p_id_inscripcion_local =
       p_id_inscripcion_visitante THEN

        RAISE EXCEPTION
            'Un equipo no puede enfrentarse contra si mismo';
    END IF;

    SELECT id_estado_partido
    INTO v_id_estado_borrador
    FROM catalogo.estado_partido
    WHERE codigo = 'BORRADOR';

    SELECT id_estado_partido
    INTO v_id_estado_programado
    FROM catalogo.estado_partido
    WHERE codigo = 'PROGRAMADO';

    SELECT id_condicion_equipo
    INTO v_id_condicion_local
    FROM catalogo.condicion_equipo_partido
    WHERE codigo = 'LOCAL';

    SELECT id_condicion_equipo
    INTO v_id_condicion_visitante
    FROM catalogo.condicion_equipo_partido
    WHERE codigo = 'VISITANTE';

    SELECT id_resultado_equipo_partido
    INTO v_id_resultado_pendiente
    FROM catalogo.resultado_equipo_partido
    WHERE codigo = 'PENDIENTE';

    INSERT INTO competencia.partido (
        id_jornada,
        id_grupo_torneo,
        id_lugar,
        id_estado_partido,
        codigo,
        numero_partido,
        nombre_ronda,
        fecha_hora_inicio,
        fecha_hora_fin,
        creado_por,
        observaciones
    )
    VALUES (
        p_id_jornada,
        p_id_grupo_torneo,
        p_id_lugar,
        v_id_estado_borrador,
        UPPER(p_codigo),
        p_numero_partido,
        p_nombre_ronda,
        p_fecha_hora_inicio,
        p_fecha_hora_fin,
        p_creado_por,
        p_observaciones
    )
    RETURNING id_partido
    INTO v_id_partido;

    INSERT INTO competencia.partido_equipo (
        id_partido,
        id_inscripcion,
        id_condicion_equipo,
        id_resultado_equipo_partido
    )
    VALUES
        (
            v_id_partido,
            p_id_inscripcion_local,
            v_id_condicion_local,
            v_id_resultado_pendiente
        ),
        (
            v_id_partido,
            p_id_inscripcion_visitante,
            v_id_condicion_visitante,
            v_id_resultado_pendiente
        );

    UPDATE competencia.partido
    SET
        id_estado_partido =
            v_id_estado_programado,
        actualizado_por =
            p_creado_por
    WHERE id_partido =
          v_id_partido;
END;
$$;


CREATE OR REPLACE PROCEDURE competencia.sp_asignar_arbitro_partido(
    IN p_id_partido BIGINT,
    IN p_id_arbitro BIGINT,
    IN p_tipo_arbitro VARCHAR,
    IN p_asignado_por BIGINT,
    IN p_observaciones VARCHAR DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_tipo_arbitro SMALLINT;
BEGIN
    SELECT id_tipo_arbitro_partido
    INTO v_id_tipo_arbitro
    FROM catalogo.tipo_arbitro_partido
    WHERE codigo =
          UPPER(p_tipo_arbitro)
      AND activo = TRUE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'El tipo de arbitro % no existe',
            p_tipo_arbitro;
    END IF;

    INSERT INTO competencia.arbitro_partido (
        id_partido,
        id_arbitro,
        id_tipo_arbitro_partido,
        asignado_por,
        observaciones
    )
    VALUES (
        p_id_partido,
        p_id_arbitro,
        v_id_tipo_arbitro,
        p_asignado_por,
        p_observaciones
    );
END;
$$;


CREATE OR REPLACE PROCEDURE competencia.sp_registrar_participacion_jugador(
    IN p_id_partido BIGINT,
    IN p_id_jugador_inscripcion BIGINT,
    IN p_convocado BOOLEAN,
    IN p_asistio BOOLEAN,
    IN p_titular BOOLEAN,
    IN p_minutos_jugados SMALLINT,
    IN p_puntos_anotados INTEGER,
    IN p_faltas SMALLINT,
    IN p_amonestaciones SMALLINT,
    IN p_expulsado BOOLEAN,
    IN p_lesionado BOOLEAN,
    IN p_calificacion NUMERIC,
    IN p_estadisticas JSONB,
    IN p_registrado_por BIGINT,
    IN p_observaciones VARCHAR DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_inscripcion BIGINT;
    v_id_partido_equipo BIGINT;
BEGIN
    SELECT id_inscripcion
    INTO v_id_inscripcion
    FROM competencia.jugador_inscripcion
    WHERE id_jugador_inscripcion =
          p_id_jugador_inscripcion;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'El jugador de la nomina no existe';
    END IF;

    SELECT id_partido_equipo
    INTO v_id_partido_equipo
    FROM competencia.partido_equipo
    WHERE id_partido =
          p_id_partido
      AND id_inscripcion =
          v_id_inscripcion;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'El equipo del jugador no participa en el partido';
    END IF;

    INSERT INTO competencia.jugador_partido (
        id_partido,
        id_partido_equipo,
        id_jugador_inscripcion,
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
        registrado_por,
        observaciones
    )
    VALUES (
        p_id_partido,
        v_id_partido_equipo,
        p_id_jugador_inscripcion,
        p_convocado,
        p_asistio,
        p_titular,
        p_minutos_jugados,
        p_puntos_anotados,
        p_faltas,
        p_amonestaciones,
        p_expulsado,
        p_lesionado,
        p_calificacion,
        COALESCE(
            p_estadisticas,
            '{}'::JSONB
        ),
        p_registrado_por,
        p_observaciones
    )
    ON CONFLICT (
        id_partido,
        id_jugador_inscripcion
    )
    DO UPDATE SET
        convocado =
            EXCLUDED.convocado,
        asistio =
            EXCLUDED.asistio,
        titular =
            EXCLUDED.titular,
        minutos_jugados =
            EXCLUDED.minutos_jugados,
        puntos_anotados =
            EXCLUDED.puntos_anotados,
        faltas =
            EXCLUDED.faltas,
        amonestaciones =
            EXCLUDED.amonestaciones,
        expulsado =
            EXCLUDED.expulsado,
        lesionado =
            EXCLUDED.lesionado,
        calificacion =
            EXCLUDED.calificacion,
        estadisticas =
            EXCLUDED.estadisticas,
        registrado_por =
            EXCLUDED.registrado_por,
        observaciones =
            EXCLUDED.observaciones,
        fecha_actualizacion =
            CURRENT_TIMESTAMP;
END;
$$;


CREATE OR REPLACE PROCEDURE competencia.sp_iniciar_partido(
    IN p_id_partido BIGINT,
    IN p_actualizado_por BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_estado_en_curso SMALLINT;
BEGIN
    SELECT id_estado_partido
    INTO v_id_estado_en_curso
    FROM catalogo.estado_partido
    WHERE codigo = 'EN_CURSO';

    UPDATE competencia.partido
    SET
        id_estado_partido =
            v_id_estado_en_curso,
        actualizado_por =
            p_actualizado_por
    WHERE id_partido =
          p_id_partido;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'El partido % no existe',
            p_id_partido;
    END IF;
END;
$$;


CREATE OR REPLACE PROCEDURE competencia.sp_finalizar_partido(
    IN p_id_partido BIGINT,
    IN p_marcador_local INTEGER,
    IN p_marcador_visitante INTEGER,
    IN p_marcador_desempate_local INTEGER,
    IN p_marcador_desempate_visitante INTEGER,
    IN p_actualizado_por BIGINT,
    IN p_observaciones VARCHAR DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado_actual VARCHAR(40);
    v_id_estado_finalizado SMALLINT;
    v_id_condicion_local SMALLINT;
    v_id_condicion_visitante SMALLINT;
BEGIN
    SELECT estado.codigo
    INTO v_estado_actual
    FROM competencia.partido partido
    INNER JOIN catalogo.estado_partido estado
        ON estado.id_estado_partido =
           partido.id_estado_partido
    WHERE partido.id_partido =
          p_id_partido;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'El partido % no existe',
            p_id_partido;
    END IF;

    IF v_estado_actual <> 'EN_CURSO' THEN
        RAISE EXCEPTION
            'Solo se puede finalizar un partido EN_CURSO';
    END IF;

    SELECT id_condicion_equipo
    INTO v_id_condicion_local
    FROM catalogo.condicion_equipo_partido
    WHERE codigo = 'LOCAL';

    SELECT id_condicion_equipo
    INTO v_id_condicion_visitante
    FROM catalogo.condicion_equipo_partido
    WHERE codigo = 'VISITANTE';

    UPDATE competencia.partido_equipo
    SET
        marcador =
            p_marcador_local,
        marcador_desempate =
            p_marcador_desempate_local
    WHERE id_partido =
          p_id_partido
      AND id_condicion_equipo =
          v_id_condicion_local;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'El partido no tiene equipo local';
    END IF;

    UPDATE competencia.partido_equipo
    SET
        marcador =
            p_marcador_visitante,
        marcador_desempate =
            p_marcador_desempate_visitante
    WHERE id_partido =
          p_id_partido
      AND id_condicion_equipo =
          v_id_condicion_visitante;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'El partido no tiene equipo visitante';
    END IF;

    SELECT id_estado_partido
    INTO v_id_estado_finalizado
    FROM catalogo.estado_partido
    WHERE codigo = 'FINALIZADO';

    UPDATE competencia.partido
    SET
        id_estado_partido =
            v_id_estado_finalizado,
        actualizado_por =
            p_actualizado_por,
        observaciones =
            COALESCE(
                p_observaciones,
                observaciones
            )
    WHERE id_partido =
          p_id_partido;
END;
$$;

COMMIT;