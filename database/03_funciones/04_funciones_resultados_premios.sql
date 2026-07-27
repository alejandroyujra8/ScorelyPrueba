BEGIN;

CREATE OR REPLACE FUNCTION reportes.fn_estadistica_inscripcion_torneo(
    p_id_torneo BIGINT,
    p_id_inscripcion BIGINT
)
RETURNS TABLE (
    partidos_jugados BIGINT,
    partidos_ganados BIGINT,
    partidos_empatados BIGINT,
    partidos_perdidos BIGINT,
    marcador_favor BIGINT,
    marcador_contra BIGINT,
    diferencia_marcador BIGINT,
    puntos BIGINT
)
LANGUAGE sql
STABLE
AS $$
    SELECT
        COUNT(partido_equipo.id_partido_equipo)::BIGINT
            AS partidos_jugados,

        COUNT(*) FILTER (
            WHERE resultado.codigo = 'GANADOR'
        )::BIGINT AS partidos_ganados,

        COUNT(*) FILTER (
            WHERE resultado.codigo = 'EMPATE'
        )::BIGINT AS partidos_empatados,

        COUNT(*) FILTER (
            WHERE resultado.codigo = 'PERDEDOR'
        )::BIGINT AS partidos_perdidos,

        COALESCE(
            SUM(partido_equipo.marcador),
            0
        )::BIGINT AS marcador_favor,

        COALESCE(
            SUM(rival.marcador),
            0
        )::BIGINT AS marcador_contra,

        (
            COALESCE(
                SUM(partido_equipo.marcador),
                0
            )
            -
            COALESCE(
                SUM(rival.marcador),
                0
            )
        )::BIGINT AS diferencia_marcador,

        COALESCE(
            SUM(partido_equipo.puntos_tabla),
            0
        )::BIGINT AS puntos

    FROM competencia.partido_equipo partido_equipo

    INNER JOIN competencia.partido partido
        ON partido.id_partido =
           partido_equipo.id_partido

    INNER JOIN catalogo.estado_partido estado_partido
        ON estado_partido.id_estado_partido =
           partido.id_estado_partido
       AND estado_partido.codigo = 'FINALIZADO'

    INNER JOIN catalogo.resultado_equipo_partido resultado
        ON resultado.id_resultado_equipo_partido =
           partido_equipo.id_resultado_equipo_partido

    LEFT JOIN competencia.partido_equipo rival
        ON rival.id_partido =
           partido_equipo.id_partido
       AND rival.id_inscripcion <>
           partido_equipo.id_inscripcion

    WHERE partido_equipo.id_inscripcion =
          p_id_inscripcion

      AND EXISTS (
          SELECT 1
          FROM competencia.inscripcion inscripcion
          WHERE inscripcion.id_inscripcion =
                partido_equipo.id_inscripcion
            AND inscripcion.id_torneo =
                p_id_torneo
      );
$$;


CREATE OR REPLACE FUNCTION reportes.fn_tabla_posiciones_grupo(
    p_id_grupo_torneo BIGINT
)
RETURNS TABLE (
    posicion BIGINT,
    id_inscripcion BIGINT,
    id_equipo BIGINT,
    equipo VARCHAR,
    partidos_jugados BIGINT,
    partidos_ganados BIGINT,
    partidos_empatados BIGINT,
    partidos_perdidos BIGINT,
    marcador_favor BIGINT,
    marcador_contra BIGINT,
    diferencia_marcador BIGINT,
    puntos BIGINT
)
LANGUAGE sql
STABLE
AS $$
    WITH partidos_finalizados AS (
        SELECT partido.id_partido
        FROM competencia.partido partido
        INNER JOIN catalogo.estado_partido estado
            ON estado.id_estado_partido =
               partido.id_estado_partido
        WHERE partido.id_grupo_torneo =
              p_id_grupo_torneo
          AND estado.codigo = 'FINALIZADO'
    ),
    estadisticas AS (
        SELECT
            equipo_grupo.id_inscripcion,
            equipo.id_equipo,
            equipo.nombre::VARCHAR AS equipo,

            COUNT(
                partido_equipo.id_partido_equipo
            )::BIGINT AS partidos_jugados,

            COUNT(*) FILTER (
                WHERE resultado.codigo = 'GANADOR'
            )::BIGINT AS partidos_ganados,

            COUNT(*) FILTER (
                WHERE resultado.codigo = 'EMPATE'
            )::BIGINT AS partidos_empatados,

            COUNT(*) FILTER (
                WHERE resultado.codigo = 'PERDEDOR'
            )::BIGINT AS partidos_perdidos,

            COALESCE(
                SUM(partido_equipo.marcador),
                0
            )::BIGINT AS marcador_favor,

            COALESCE(
                SUM(rival.marcador),
                0
            )::BIGINT AS marcador_contra,

            (
                COALESCE(
                    SUM(partido_equipo.marcador),
                    0
                )
                -
                COALESCE(
                    SUM(rival.marcador),
                    0
                )
            )::BIGINT AS diferencia_marcador,

            COALESCE(
                SUM(partido_equipo.puntos_tabla),
                0
            )::BIGINT AS puntos

        FROM competencia.equipo_grupo equipo_grupo

        INNER JOIN competencia.inscripcion inscripcion
            ON inscripcion.id_inscripcion =
               equipo_grupo.id_inscripcion

        INNER JOIN participantes.equipo equipo
            ON equipo.id_equipo =
               inscripcion.id_equipo

        LEFT JOIN partidos_finalizados partido
            ON TRUE

        LEFT JOIN competencia.partido_equipo partido_equipo
            ON partido_equipo.id_partido =
               partido.id_partido
           AND partido_equipo.id_inscripcion =
               equipo_grupo.id_inscripcion

        LEFT JOIN catalogo.resultado_equipo_partido resultado
            ON resultado.id_resultado_equipo_partido =
               partido_equipo.id_resultado_equipo_partido

        LEFT JOIN competencia.partido_equipo rival
            ON rival.id_partido =
               partido_equipo.id_partido
           AND rival.id_inscripcion <>
               partido_equipo.id_inscripcion

        WHERE equipo_grupo.id_grupo_torneo =
              p_id_grupo_torneo

        GROUP BY
            equipo_grupo.id_inscripcion,
            equipo.id_equipo,
            equipo.nombre
    )
    SELECT
        ROW_NUMBER() OVER (
            ORDER BY
                estadisticas.puntos DESC,
                estadisticas.diferencia_marcador DESC,
                estadisticas.marcador_favor DESC,
                estadisticas.equipo ASC
        )::BIGINT AS posicion,

        estadisticas.id_inscripcion,
        estadisticas.id_equipo,
        estadisticas.equipo,

        estadisticas.partidos_jugados,
        estadisticas.partidos_ganados,
        estadisticas.partidos_empatados,
        estadisticas.partidos_perdidos,

        estadisticas.marcador_favor,
        estadisticas.marcador_contra,
        estadisticas.diferencia_marcador,
        estadisticas.puntos

    FROM estadisticas

    ORDER BY posicion;
$$;


CREATE OR REPLACE FUNCTION competencia.fn_validar_resultado_torneo()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_torneo_inscripcion BIGINT;
    v_estado_torneo VARCHAR(40);
BEGIN
    SELECT
        inscripcion.id_torneo
    INTO
        v_torneo_inscripcion
    FROM competencia.inscripcion inscripcion
    WHERE inscripcion.id_inscripcion =
          NEW.id_inscripcion;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'La inscripcion seleccionada no existe';
    END IF;

    IF v_torneo_inscripcion <> NEW.id_torneo THEN
        RAISE EXCEPTION
            'La inscripcion no pertenece al torneo';
    END IF;

    SELECT estado.codigo
    INTO v_estado_torneo
    FROM competencia.torneo torneo
    INNER JOIN catalogo.estado_torneo estado
        ON estado.id_estado_torneo =
           torneo.id_estado_torneo
    WHERE torneo.id_torneo =
          NEW.id_torneo;

    IF v_estado_torneo <> 'EN_CURSO' THEN
        RAISE EXCEPTION
            'Los resultados finales solo pueden generarse cuando el torneo esta EN_CURSO';
    END IF;

    IF TG_OP = 'UPDATE'
       AND (
            NEW.id_torneo <> OLD.id_torneo
            OR NEW.id_inscripcion <>
               OLD.id_inscripcion
       ) THEN

        RAISE EXCEPTION
            'No se puede cambiar el torneo o la inscripcion del resultado';
    END IF;

    NEW.diferencia_marcador :=
        NEW.marcador_favor
        - NEW.marcador_contra;

    RETURN NEW;
END;
$$;


CREATE OR REPLACE FUNCTION finanzas.fn_validar_torneo_premio()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado_torneo VARCHAR(40);
    v_tipo_premio VARCHAR(40);
BEGIN
    SELECT estado.codigo
    INTO v_estado_torneo
    FROM competencia.torneo torneo
    INNER JOIN catalogo.estado_torneo estado
        ON estado.id_estado_torneo =
           torneo.id_estado_torneo
    WHERE torneo.id_torneo =
          NEW.id_torneo;

    IF v_estado_torneo IN (
        'FINALIZADO',
        'CANCELADO'
    ) THEN
        RAISE EXCEPTION
            'No se pueden configurar premios en un torneo %',
            v_estado_torneo;
    END IF;

    SELECT tipo.codigo
    INTO v_tipo_premio
    FROM finanzas.premio premio
    INNER JOIN catalogo.tipo_premio tipo
        ON tipo.id_tipo_premio =
           premio.id_tipo_premio
    WHERE premio.id_premio =
          NEW.id_premio;

    IF v_tipo_premio = 'ECONOMICO'
       AND NEW.valor_economico <= 0 THEN

        RAISE EXCEPTION
            'Un premio economico debe tener un valor mayor que cero';
    END IF;

    IF TG_OP = 'UPDATE'
       AND NEW.id_torneo <> OLD.id_torneo THEN

        RAISE EXCEPTION
            'No se puede cambiar el torneo del premio';
    END IF;

    NEW.moneda := UPPER(NEW.moneda);

    RETURN NEW;
END;
$$;


CREATE OR REPLACE FUNCTION finanzas.fn_validar_entrega_premio()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_torneo_premio BIGINT;
    v_posicion_objetivo SMALLINT;

    v_id_torneo_resultado BIGINT;
    v_posicion_resultado SMALLINT;

    v_estado_torneo VARCHAR(40);
    v_estado_anterior VARCHAR(40);
    v_estado_nuevo VARCHAR(40);

    v_transicion_valida BOOLEAN := FALSE;
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION
            'Las entregas de premios no pueden eliminarse';
    END IF;

    SELECT
        torneo_premio.id_torneo,
        torneo_premio.posicion_objetivo
    INTO
        v_id_torneo_premio,
        v_posicion_objetivo
    FROM finanzas.torneo_premio torneo_premio
    WHERE torneo_premio.id_torneo_premio =
          NEW.id_torneo_premio;

    SELECT
        resultado.id_torneo,
        resultado.posicion_final
    INTO
        v_id_torneo_resultado,
        v_posicion_resultado
    FROM competencia.resultado_torneo resultado
    WHERE resultado.id_resultado_torneo =
          NEW.id_resultado_torneo;

    IF v_id_torneo_premio <>
       v_id_torneo_resultado THEN

        RAISE EXCEPTION
            'El premio y el resultado pertenecen a torneos diferentes';
    END IF;

    IF v_posicion_objetivo <>
       v_posicion_resultado THEN

        RAISE EXCEPTION
            'La posicion del ganador no coincide con la posicion premiada';
    END IF;

    SELECT estado.codigo
    INTO v_estado_torneo
    FROM competencia.torneo torneo
    INNER JOIN catalogo.estado_torneo estado
        ON estado.id_estado_torneo =
           torneo.id_estado_torneo
    WHERE torneo.id_torneo =
          v_id_torneo_premio;

    SELECT codigo
    INTO v_estado_nuevo
    FROM catalogo.estado_entrega_premio
    WHERE id_estado_entrega_premio =
          NEW.id_estado_entrega_premio;

    IF TG_OP = 'UPDATE' THEN
        IF NEW.id_torneo_premio <>
           OLD.id_torneo_premio
           OR NEW.id_resultado_torneo <>
              OLD.id_resultado_torneo THEN

            RAISE EXCEPTION
                'No se puede cambiar el premio o el resultado de una entrega';
        END IF;

        SELECT codigo
        INTO v_estado_anterior
        FROM catalogo.estado_entrega_premio
        WHERE id_estado_entrega_premio =
              OLD.id_estado_entrega_premio;

        IF v_estado_anterior =
           v_estado_nuevo THEN

            NEW.fecha_actualizacion :=
                CURRENT_TIMESTAMP;

            RETURN NEW;
        END IF;

        v_transicion_valida :=
            CASE
                WHEN v_estado_anterior = 'PENDIENTE'
                     AND v_estado_nuevo IN (
                         'AUTORIZADO',
                         'ANULADO'
                     )
                    THEN TRUE

                WHEN v_estado_anterior = 'AUTORIZADO'
                     AND v_estado_nuevo IN (
                         'ENTREGADO',
                         'ANULADO'
                     )
                    THEN TRUE

                ELSE FALSE
            END;

        IF v_transicion_valida = FALSE THEN
            RAISE EXCEPTION
                'Transicion de entrega no permitida: % -> %',
                v_estado_anterior,
                v_estado_nuevo;
        END IF;
    END IF;

    IF v_estado_nuevo IN (
        'AUTORIZADO',
        'ENTREGADO'
    )
       AND v_estado_torneo <>
           'FINALIZADO' THEN

        RAISE EXCEPTION
            'El torneo debe estar FINALIZADO para autorizar o entregar premios';
    END IF;

    IF v_estado_nuevo = 'PENDIENTE' THEN
        NEW.autorizado_por := NULL;
        NEW.entregado_por := NULL;
        NEW.fecha_autorizacion := NULL;
        NEW.fecha_entrega := NULL;

    ELSIF v_estado_nuevo = 'AUTORIZADO' THEN
        IF NEW.autorizado_por IS NULL THEN
            RAISE EXCEPTION
                'La autorizacion requiere un usuario responsable';
        END IF;

        NEW.fecha_autorizacion :=
            COALESCE(
                NEW.fecha_autorizacion,
                CURRENT_TIMESTAMP
            );

        NEW.entregado_por := NULL;
        NEW.fecha_entrega := NULL;

    ELSIF v_estado_nuevo = 'ENTREGADO' THEN
        IF NEW.autorizado_por IS NULL
           OR NEW.fecha_autorizacion IS NULL THEN

            RAISE EXCEPTION
                'El premio debe estar autorizado antes de ser entregado';
        END IF;

        IF NEW.entregado_por IS NULL THEN
            RAISE EXCEPTION
                'La entrega requiere un usuario responsable';
        END IF;

        NEW.fecha_entrega :=
            COALESCE(
                NEW.fecha_entrega,
                CURRENT_TIMESTAMP
            );
    END IF;

    NEW.fecha_actualizacion :=
        CURRENT_TIMESTAMP;

    RETURN NEW;
END;
$$;


CREATE OR REPLACE FUNCTION auditoria.fn_historial_entrega_premio()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_usuario_aplicacion BIGINT;
BEGIN
    v_usuario_aplicacion :=
        COALESCE(
            NULLIF(
                CURRENT_SETTING(
                    'app.usuario_id',
                    TRUE
                ),
                ''
            )::BIGINT,
            NEW.entregado_por,
            NEW.autorizado_por
        );

    IF TG_OP = 'INSERT' THEN
        INSERT INTO auditoria.historial_entrega_premio (
            id_entrega_premio,
            id_estado_anterior,
            id_estado_nuevo,
            operacion,
            usuario_aplicacion,
            detalle
        )
        VALUES (
            NEW.id_entrega_premio,
            NULL,
            NEW.id_estado_entrega_premio,
            'INSERT',
            v_usuario_aplicacion,
            JSONB_BUILD_OBJECT(
                'id_torneo_premio',
                NEW.id_torneo_premio,
                'id_resultado_torneo',
                NEW.id_resultado_torneo
            )
        );

    ELSIF NEW.id_estado_entrega_premio <>
          OLD.id_estado_entrega_premio THEN

        INSERT INTO auditoria.historial_entrega_premio (
            id_entrega_premio,
            id_estado_anterior,
            id_estado_nuevo,
            operacion,
            usuario_aplicacion,
            detalle
        )
        VALUES (
            NEW.id_entrega_premio,
            OLD.id_estado_entrega_premio,
            NEW.id_estado_entrega_premio,
            'UPDATE',
            v_usuario_aplicacion,
            JSONB_BUILD_OBJECT(
                'fecha_autorizacion',
                NEW.fecha_autorizacion,
                'fecha_entrega',
                NEW.fecha_entrega
            )
        );
    END IF;

    RETURN NEW;
END;
$$;

COMMIT;