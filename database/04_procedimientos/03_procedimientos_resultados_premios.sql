BEGIN;

CREATE OR REPLACE PROCEDURE competencia.sp_finalizar_fase(
    IN p_id_fase_torneo BIGINT,
    IN p_actualizado_por BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_torneo BIGINT;
    v_estado_torneo VARCHAR(40);

    v_cantidad_partidos INTEGER;
    v_partidos_pendientes INTEGER;
    v_partidos_finalizados INTEGER;

    v_id_estado_finalizada SMALLINT;
BEGIN
    PERFORM SET_CONFIG(
        'app.usuario_id',
        p_actualizado_por::TEXT,
        TRUE
    );

    SELECT
        fase.id_torneo,
        estado.codigo
    INTO
        v_id_torneo,
        v_estado_torneo
    FROM competencia.fase_torneo fase
    INNER JOIN competencia.torneo torneo
        ON torneo.id_torneo =
           fase.id_torneo
    INNER JOIN catalogo.estado_torneo estado
        ON estado.id_estado_torneo =
           torneo.id_estado_torneo
    WHERE fase.id_fase_torneo =
          p_id_fase_torneo;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'La fase % no existe',
            p_id_fase_torneo;
    END IF;

    IF v_estado_torneo <> 'EN_CURSO' THEN
        RAISE EXCEPTION
            'El torneo debe estar EN_CURSO para finalizar una fase';
    END IF;

    SELECT
        COUNT(*),
        COUNT(*) FILTER (
            WHERE estado.codigo NOT IN (
                'FINALIZADO',
                'CANCELADO'
            )
        ),
        COUNT(*) FILTER (
            WHERE estado.codigo = 'FINALIZADO'
        )
    INTO
        v_cantidad_partidos,
        v_partidos_pendientes,
        v_partidos_finalizados
    FROM competencia.partido partido
    INNER JOIN competencia.jornada jornada
        ON jornada.id_jornada =
           partido.id_jornada
    INNER JOIN catalogo.estado_partido estado
        ON estado.id_estado_partido =
           partido.id_estado_partido
    WHERE jornada.id_fase_torneo =
          p_id_fase_torneo;

    IF v_cantidad_partidos = 0 THEN
        RAISE EXCEPTION
            'La fase no tiene partidos registrados';
    END IF;

    IF v_partidos_pendientes > 0 THEN
        RAISE EXCEPTION
            'La fase tiene % partidos pendientes',
            v_partidos_pendientes;
    END IF;

    IF v_partidos_finalizados = 0 THEN
        RAISE EXCEPTION
            'La fase debe tener al menos un partido finalizado';
    END IF;

    SELECT id_estado_fase
    INTO v_id_estado_finalizada
    FROM catalogo.estado_fase
    WHERE codigo = 'FINALIZADA';

    UPDATE competencia.fase_torneo
    SET id_estado_fase =
        v_id_estado_finalizada
    WHERE id_fase_torneo =
          p_id_fase_torneo;
END;
$$;


CREATE OR REPLACE PROCEDURE competencia.sp_generar_resultados_torneo(
    IN p_id_torneo BIGINT,
    IN p_generado_por BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_formato VARCHAR(40);
    v_estado_torneo VARCHAR(40);

    v_cantidad_grupos INTEGER;
    v_id_grupo BIGINT;

    v_id_fase_final BIGINT;
    v_cantidad_partidos_finales INTEGER;
    v_id_partido_final BIGINT;

    v_posicion SMALLINT := 0;

    v_partidos_jugados BIGINT;
    v_partidos_ganados BIGINT;
    v_partidos_empatados BIGINT;
    v_partidos_perdidos BIGINT;
    v_marcador_favor BIGINT;
    v_marcador_contra BIGINT;
    v_diferencia BIGINT;
    v_puntos BIGINT;

    v_fila RECORD;

    cursor_posiciones CURSOR FOR
        SELECT *
        FROM reportes.fn_tabla_posiciones_grupo(
            v_id_grupo
        )
        ORDER BY posicion;

    cursor_final CURSOR FOR
        SELECT
            partido_equipo.id_inscripcion,
            resultado.codigo AS resultado
        FROM competencia.partido_equipo partido_equipo
        INNER JOIN catalogo.resultado_equipo_partido resultado
            ON resultado.id_resultado_equipo_partido =
               partido_equipo.id_resultado_equipo_partido
        WHERE partido_equipo.id_partido =
              v_id_partido_final
        ORDER BY
            CASE resultado.codigo
                WHEN 'GANADOR' THEN 1
                WHEN 'PERDEDOR' THEN 2
                ELSE 3
            END;
BEGIN
    PERFORM SET_CONFIG(
        'app.usuario_id',
        p_generado_por::TEXT,
        TRUE
    );

    IF EXISTS (
        SELECT 1
        FROM competencia.resultado_torneo
        WHERE id_torneo =
              p_id_torneo
    ) THEN
        RAISE EXCEPTION
            'El torneo ya tiene resultados finales registrados';
    END IF;

    SELECT
        formato.codigo,
        estado.codigo
    INTO
        v_formato,
        v_estado_torneo
    FROM competencia.torneo torneo
    INNER JOIN catalogo.formato_torneo formato
        ON formato.id_formato_torneo =
           torneo.id_formato_torneo
    INNER JOIN catalogo.estado_torneo estado
        ON estado.id_estado_torneo =
           torneo.id_estado_torneo
    WHERE torneo.id_torneo =
          p_id_torneo;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'El torneo % no existe',
            p_id_torneo;
    END IF;

    IF v_estado_torneo <> 'EN_CURSO' THEN
        RAISE EXCEPTION
            'El torneo debe estar EN_CURSO para generar resultados';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM competencia.fase_torneo fase
        INNER JOIN catalogo.estado_fase estado
            ON estado.id_estado_fase =
               fase.id_estado_fase
        WHERE fase.id_torneo =
              p_id_torneo
          AND estado.codigo <>
              'FINALIZADA'
    ) THEN
        RAISE EXCEPTION
            'Todas las fases deben estar finalizadas';
    END IF;

    IF v_formato = 'FASE_GRUPOS' THEN
        SELECT
            COUNT(*),
            MIN(grupo.id_grupo_torneo)
        INTO
            v_cantidad_grupos,
            v_id_grupo
        FROM competencia.grupo_torneo grupo
        INNER JOIN competencia.fase_torneo fase
            ON fase.id_fase_torneo =
               grupo.id_fase_torneo
        WHERE fase.id_torneo =
              p_id_torneo;

        IF v_cantidad_grupos <> 1 THEN
            RAISE EXCEPTION
                'Un torneo solamente de grupos requiere un unico grupo para generar posiciones generales automaticamente';
        END IF;

        OPEN cursor_posiciones;

        LOOP
            FETCH cursor_posiciones
            INTO v_fila;

            EXIT WHEN NOT FOUND;

            INSERT INTO competencia.resultado_torneo (
                id_torneo,
                id_inscripcion,
                posicion_final,
                partidos_jugados,
                partidos_ganados,
                partidos_empatados,
                partidos_perdidos,
                marcador_favor,
                marcador_contra,
                diferencia_marcador,
                puntos,
                generado_por
            )
            VALUES (
                p_id_torneo,
                v_fila.id_inscripcion,
                v_fila.posicion,
                v_fila.partidos_jugados,
                v_fila.partidos_ganados,
                v_fila.partidos_empatados,
                v_fila.partidos_perdidos,
                v_fila.marcador_favor,
                v_fila.marcador_contra,
                v_fila.diferencia_marcador,
                v_fila.puntos,
                p_generado_por
            );
        END LOOP;

        CLOSE cursor_posiciones;

    ELSE
        SELECT fase.id_fase_torneo
        INTO v_id_fase_final
        FROM competencia.fase_torneo fase
        WHERE fase.id_torneo =
              p_id_torneo
        ORDER BY fase.numero_orden DESC
        LIMIT 1;

        SELECT
            COUNT(*),
            MIN(partido.id_partido)
        INTO
            v_cantidad_partidos_finales,
            v_id_partido_final
        FROM competencia.partido partido
        INNER JOIN competencia.jornada jornada
            ON jornada.id_jornada =
               partido.id_jornada
        INNER JOIN catalogo.estado_partido estado
            ON estado.id_estado_partido =
               partido.id_estado_partido
        WHERE jornada.id_fase_torneo =
              v_id_fase_final
          AND estado.codigo =
              'FINALIZADO';

        IF v_cantidad_partidos_finales <> 1 THEN
            RAISE EXCEPTION
                'La ultima fase debe contener exactamente un partido finalizado';
        END IF;

        OPEN cursor_final;

        LOOP
            FETCH cursor_final
            INTO v_fila;

            EXIT WHEN NOT FOUND;

            v_posicion :=
                v_posicion + 1;

            SELECT *
            INTO
                v_partidos_jugados,
                v_partidos_ganados,
                v_partidos_empatados,
                v_partidos_perdidos,
                v_marcador_favor,
                v_marcador_contra,
                v_diferencia,
                v_puntos
            FROM reportes.fn_estadistica_inscripcion_torneo(
                p_id_torneo,
                v_fila.id_inscripcion
            );

            INSERT INTO competencia.resultado_torneo (
                id_torneo,
                id_inscripcion,
                posicion_final,
                partidos_jugados,
                partidos_ganados,
                partidos_empatados,
                partidos_perdidos,
                marcador_favor,
                marcador_contra,
                diferencia_marcador,
                puntos,
                generado_por
            )
            VALUES (
                p_id_torneo,
                v_fila.id_inscripcion,
                v_posicion,
                v_partidos_jugados,
                v_partidos_ganados,
                v_partidos_empatados,
                v_partidos_perdidos,
                v_marcador_favor,
                v_marcador_contra,
                v_diferencia,
                v_puntos,
                p_generado_por
            );
        END LOOP;

        CLOSE cursor_final;
    END IF;
END;
$$;


CREATE OR REPLACE PROCEDURE competencia.sp_registrar_resultado_manual(
    IN p_id_torneo BIGINT,
    IN p_id_inscripcion BIGINT,
    IN p_posicion_final SMALLINT,
    IN p_generado_por BIGINT,
    IN p_observaciones VARCHAR DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_partidos_jugados BIGINT;
    v_partidos_ganados BIGINT;
    v_partidos_empatados BIGINT;
    v_partidos_perdidos BIGINT;
    v_marcador_favor BIGINT;
    v_marcador_contra BIGINT;
    v_diferencia BIGINT;
    v_puntos BIGINT;
BEGIN
    SELECT *
    INTO
        v_partidos_jugados,
        v_partidos_ganados,
        v_partidos_empatados,
        v_partidos_perdidos,
        v_marcador_favor,
        v_marcador_contra,
        v_diferencia,
        v_puntos
    FROM reportes.fn_estadistica_inscripcion_torneo(
        p_id_torneo,
        p_id_inscripcion
    );

    INSERT INTO competencia.resultado_torneo (
        id_torneo,
        id_inscripcion,
        posicion_final,
        partidos_jugados,
        partidos_ganados,
        partidos_empatados,
        partidos_perdidos,
        marcador_favor,
        marcador_contra,
        diferencia_marcador,
        puntos,
        generado_por,
        observaciones
    )
    VALUES (
        p_id_torneo,
        p_id_inscripcion,
        p_posicion_final,
        v_partidos_jugados,
        v_partidos_ganados,
        v_partidos_empatados,
        v_partidos_perdidos,
        v_marcador_favor,
        v_marcador_contra,
        v_diferencia,
        v_puntos,
        p_generado_por,
        p_observaciones
    );
END;
$$;


CREATE OR REPLACE PROCEDURE competencia.sp_finalizar_torneo(
    IN p_id_torneo BIGINT,
    IN p_actualizado_por BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado_actual VARCHAR(40);
    v_fases_pendientes INTEGER;
    v_partidos_pendientes INTEGER;
    v_partidos_finalizados INTEGER;
    v_id_estado_finalizado SMALLINT;
BEGIN
    PERFORM SET_CONFIG(
        'app.usuario_id',
        p_actualizado_por::TEXT,
        TRUE
    );

    SELECT estado.codigo
    INTO v_estado_actual
    FROM competencia.torneo torneo
    INNER JOIN catalogo.estado_torneo estado
        ON estado.id_estado_torneo =
           torneo.id_estado_torneo
    WHERE torneo.id_torneo =
          p_id_torneo;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'El torneo % no existe',
            p_id_torneo;
    END IF;

    IF v_estado_actual <> 'EN_CURSO' THEN
        RAISE EXCEPTION
            'Solo puede finalizarse un torneo EN_CURSO';
    END IF;

    SELECT COUNT(*)
    INTO v_fases_pendientes
    FROM competencia.fase_torneo fase
    INNER JOIN catalogo.estado_fase estado
        ON estado.id_estado_fase =
           fase.id_estado_fase
    WHERE fase.id_torneo =
          p_id_torneo
      AND estado.codigo <>
          'FINALIZADA';

    IF v_fases_pendientes > 0 THEN
        RAISE EXCEPTION
            'El torneo tiene % fases pendientes',
            v_fases_pendientes;
    END IF;

    SELECT
        COUNT(*) FILTER (
            WHERE estado.codigo NOT IN (
                'FINALIZADO',
                'CANCELADO'
            )
        ),
        COUNT(*) FILTER (
            WHERE estado.codigo = 'FINALIZADO'
        )
    INTO
        v_partidos_pendientes,
        v_partidos_finalizados
    FROM competencia.partido partido
    INNER JOIN competencia.jornada jornada
        ON jornada.id_jornada =
           partido.id_jornada
    INNER JOIN competencia.fase_torneo fase
        ON fase.id_fase_torneo =
           jornada.id_fase_torneo
    INNER JOIN catalogo.estado_partido estado
        ON estado.id_estado_partido =
           partido.id_estado_partido
    WHERE fase.id_torneo =
          p_id_torneo;

    IF v_partidos_pendientes > 0 THEN
        RAISE EXCEPTION
            'El torneo tiene % partidos pendientes',
            v_partidos_pendientes;
    END IF;

    IF v_partidos_finalizados = 0 THEN
        RAISE EXCEPTION
            'El torneo no tiene partidos finalizados';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM competencia.resultado_torneo
        WHERE id_torneo =
              p_id_torneo
    ) THEN
        CALL competencia.sp_generar_resultados_torneo(
            p_id_torneo,
            p_actualizado_por
        );
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM competencia.resultado_torneo
        WHERE id_torneo =
              p_id_torneo
          AND posicion_final = 1
    ) THEN
        RAISE EXCEPTION
            'El torneo no tiene un campeon registrado';
    END IF;

    SELECT id_estado_torneo
    INTO v_id_estado_finalizado
    FROM catalogo.estado_torneo
    WHERE codigo = 'FINALIZADO';

    UPDATE competencia.torneo
    SET
        id_estado_torneo =
            v_id_estado_finalizado,
        fecha_actualizacion =
            CURRENT_TIMESTAMP
    WHERE id_torneo =
          p_id_torneo;
END;
$$;


CREATE OR REPLACE PROCEDURE finanzas.sp_configurar_premio_torneo(
    IN p_id_torneo BIGINT,
    IN p_id_premio BIGINT,
    IN p_posicion_objetivo SMALLINT,
    IN p_valor_economico NUMERIC,
    IN p_moneda CHAR(3),
    IN p_registrado_por BIGINT,
    IN p_descripcion VARCHAR DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO finanzas.torneo_premio (
        id_torneo,
        id_premio,
        posicion_objetivo,
        valor_economico,
        moneda,
        descripcion_entrega,
        registrado_por
    )
    VALUES (
        p_id_torneo,
        p_id_premio,
        p_posicion_objetivo,
        p_valor_economico,
        UPPER(p_moneda),
        p_descripcion,
        p_registrado_por
    );
END;
$$;


CREATE OR REPLACE PROCEDURE finanzas.sp_generar_entregas_premios(
    IN p_id_torneo BIGINT,
    IN p_usuario BIGINT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado_torneo VARCHAR(40);
    v_id_estado_pendiente SMALLINT;
    v_fila RECORD;

    cursor_premios CURSOR FOR
        SELECT
            torneo_premio.id_torneo_premio,
            resultado.id_resultado_torneo
        FROM finanzas.torneo_premio torneo_premio
        INNER JOIN competencia.resultado_torneo resultado
            ON resultado.id_torneo =
               torneo_premio.id_torneo
           AND resultado.posicion_final =
               torneo_premio.posicion_objetivo
        WHERE torneo_premio.id_torneo =
              p_id_torneo
          AND NOT EXISTS (
              SELECT 1
              FROM finanzas.entrega_premio entrega
              WHERE entrega.id_torneo_premio =
                    torneo_premio.id_torneo_premio
          )
        ORDER BY torneo_premio.posicion_objetivo;
BEGIN
    PERFORM SET_CONFIG(
        'app.usuario_id',
        p_usuario::TEXT,
        TRUE
    );

    SELECT estado.codigo
    INTO v_estado_torneo
    FROM competencia.torneo torneo
    INNER JOIN catalogo.estado_torneo estado
        ON estado.id_estado_torneo =
           torneo.id_estado_torneo
    WHERE torneo.id_torneo =
          p_id_torneo;

    IF v_estado_torneo <> 'FINALIZADO' THEN
        RAISE EXCEPTION
            'El torneo debe estar FINALIZADO';
    END IF;

    SELECT id_estado_entrega_premio
    INTO v_id_estado_pendiente
    FROM catalogo.estado_entrega_premio
    WHERE codigo = 'PENDIENTE';

    OPEN cursor_premios;

    LOOP
        FETCH cursor_premios
        INTO v_fila;

        EXIT WHEN NOT FOUND;

        INSERT INTO finanzas.entrega_premio (
            id_torneo_premio,
            id_resultado_torneo,
            id_estado_entrega_premio,
            observaciones
        )
        VALUES (
            v_fila.id_torneo_premio,
            v_fila.id_resultado_torneo,
            v_id_estado_pendiente,
            'Entrega generada automaticamente'
        );
    END LOOP;

    CLOSE cursor_premios;
END;
$$;


CREATE OR REPLACE PROCEDURE finanzas.sp_autorizar_entrega_premio(
    IN p_id_entrega_premio BIGINT,
    IN p_autorizado_por BIGINT,
    IN p_observaciones VARCHAR DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_estado_autorizado SMALLINT;
BEGIN
    PERFORM SET_CONFIG(
        'app.usuario_id',
        p_autorizado_por::TEXT,
        TRUE
    );

    SELECT id_estado_entrega_premio
    INTO v_id_estado_autorizado
    FROM catalogo.estado_entrega_premio
    WHERE codigo = 'AUTORIZADO';

    UPDATE finanzas.entrega_premio
    SET
        id_estado_entrega_premio =
            v_id_estado_autorizado,
        autorizado_por =
            p_autorizado_por,
        fecha_autorizacion =
            CURRENT_TIMESTAMP,
        observaciones =
            COALESCE(
                p_observaciones,
                observaciones
            )
    WHERE id_entrega_premio =
          p_id_entrega_premio;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'La entrega % no existe',
            p_id_entrega_premio;
    END IF;
END;
$$;


CREATE OR REPLACE PROCEDURE finanzas.sp_entregar_premio(
    IN p_id_entrega_premio BIGINT,
    IN p_entregado_por BIGINT,
    IN p_observaciones VARCHAR DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_estado_entregado SMALLINT;
BEGIN
    PERFORM SET_CONFIG(
        'app.usuario_id',
        p_entregado_por::TEXT,
        TRUE
    );

    SELECT id_estado_entrega_premio
    INTO v_id_estado_entregado
    FROM catalogo.estado_entrega_premio
    WHERE codigo = 'ENTREGADO';

    UPDATE finanzas.entrega_premio
    SET
        id_estado_entrega_premio =
            v_id_estado_entregado,
        entregado_por =
            p_entregado_por,
        fecha_entrega =
            CURRENT_TIMESTAMP,
        observaciones =
            COALESCE(
                p_observaciones,
                observaciones
            )
    WHERE id_entrega_premio =
          p_id_entrega_premio;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'La entrega % no existe',
            p_id_entrega_premio;
    END IF;
END;
$$;

COMMIT;