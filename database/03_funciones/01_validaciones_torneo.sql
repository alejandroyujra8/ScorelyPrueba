BEGIN;

CREATE OR REPLACE FUNCTION competencia.fn_validar_torneo()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_formato VARCHAR(40);
    v_minimo_deporte SMALLINT;
    v_maximo_deporte SMALLINT;
BEGIN
    SELECT
        formato.codigo
    INTO
        v_formato
    FROM catalogo.formato_torneo formato
    WHERE formato.id_formato_torneo = NEW.id_formato_torneo;

    IF v_formato IS NULL THEN
        RAISE EXCEPTION
            'El formato de torneo seleccionado no existe';
    END IF;

    SELECT
        deporte.cantidad_minima_jugadores,
        deporte.cantidad_maxima_jugadores
    INTO
        v_minimo_deporte,
        v_maximo_deporte
    FROM competencia.deporte deporte
    WHERE deporte.id_deporte = NEW.id_deporte;

    IF NEW.cantidad_minima_jugadores < v_minimo_deporte THEN
        RAISE EXCEPTION
            'La cantidad minima de jugadores del torneo no puede ser menor que %',
            v_minimo_deporte;
    END IF;

    IF NEW.cantidad_maxima_jugadores > v_maximo_deporte THEN
        RAISE EXCEPTION
            'La cantidad maxima de jugadores del torneo no puede superar %',
            v_maximo_deporte;
    END IF;

    IF v_formato = 'PARTIDO_UNICO'
       AND NEW.cantidad_maxima_equipos <> 2 THEN

        RAISE EXCEPTION
            'Un torneo de partido unico debe permitir exactamente 2 equipos';
    END IF;

    NEW.fecha_actualizacion := CURRENT_TIMESTAMP;

    RETURN NEW;
END;
$$;


CREATE OR REPLACE FUNCTION competencia.fn_validar_transicion_torneo()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado_anterior VARCHAR(40);
    v_estado_nuevo VARCHAR(40);
    v_transicion_valida BOOLEAN := FALSE;
BEGIN
    IF NEW.id_estado_torneo = OLD.id_estado_torneo THEN
        RETURN NEW;
    END IF;

    SELECT codigo
    INTO v_estado_anterior
    FROM catalogo.estado_torneo
    WHERE id_estado_torneo = OLD.id_estado_torneo;

    SELECT codigo
    INTO v_estado_nuevo
    FROM catalogo.estado_torneo
    WHERE id_estado_torneo = NEW.id_estado_torneo;

    v_transicion_valida :=
        CASE
            WHEN v_estado_anterior = 'BORRADOR'
                AND v_estado_nuevo IN (
                    'INSCRIPCIONES_ABIERTAS',
                    'CANCELADO'
                )
                THEN TRUE

            WHEN v_estado_anterior = 'INSCRIPCIONES_ABIERTAS'
                AND v_estado_nuevo IN (
                    'INSCRIPCIONES_CERRADAS',
                    'CANCELADO'
                )
                THEN TRUE

            WHEN v_estado_anterior = 'INSCRIPCIONES_CERRADAS'
                AND v_estado_nuevo IN (
                    'PROGRAMADO',
                    'CANCELADO'
                )
                THEN TRUE

            WHEN v_estado_anterior = 'PROGRAMADO'
                AND v_estado_nuevo IN (
                    'EN_CURSO',
                    'CANCELADO'
                )
                THEN TRUE

            WHEN v_estado_anterior = 'EN_CURSO'
                AND v_estado_nuevo IN (
                    'FINALIZADO',
                    'CANCELADO'
                )
                THEN TRUE

            ELSE FALSE
        END;

    IF v_transicion_valida = FALSE THEN
        RAISE EXCEPTION
            'Transicion de estado no permitida: % -> %',
            v_estado_anterior,
            v_estado_nuevo;
    END IF;

    RETURN NEW;
END;
$$;


CREATE OR REPLACE FUNCTION competencia.fn_validar_rol_torneo()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_codigo_rol VARCHAR(40);
    v_estado_torneo VARCHAR(40);
BEGIN
    IF NEW.activo = FALSE THEN
        RETURN NEW;
    END IF;

    SELECT codigo
    INTO v_codigo_rol
    FROM catalogo.rol_torneo
    WHERE id_rol_torneo = NEW.id_rol_torneo;

    SELECT estado.codigo
    INTO v_estado_torneo
    FROM competencia.torneo torneo
    INNER JOIN catalogo.estado_torneo estado
        ON estado.id_estado_torneo = torneo.id_estado_torneo
    WHERE torneo.id_torneo = NEW.id_torneo;

    IF v_estado_torneo IN ('FINALIZADO', 'CANCELADO') THEN
        RAISE EXCEPTION
            'No se pueden asignar roles a un torneo %',
            v_estado_torneo;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM seguridad.usuario_rol usuario_rol
        INNER JOIN seguridad.rol rol
            ON rol.id_rol = usuario_rol.id_rol
        WHERE usuario_rol.id_usuario = NEW.id_usuario
          AND rol.codigo = v_codigo_rol
          AND usuario_rol.activo = TRUE
          AND usuario_rol.fecha_fin IS NULL
    ) THEN
        RAISE EXCEPTION
            'El usuario no tiene asignado el rol general %',
            v_codigo_rol;
    END IF;

    IF v_codigo_rol = 'JUGADOR'
       AND NOT EXISTS (
            SELECT 1
            FROM participantes.jugador
            WHERE id_usuario = NEW.id_usuario
       ) THEN

        RAISE EXCEPTION
            'El usuario no tiene un perfil de jugador';
    END IF;

    IF v_codigo_rol = 'ARBITRO'
       AND NOT EXISTS (
            SELECT 1
            FROM participantes.arbitro
            WHERE id_usuario = NEW.id_usuario
       ) THEN

        RAISE EXCEPTION
            'El usuario no tiene un perfil de arbitro';
    END IF;

    IF v_codigo_rol = 'ORGANIZADOR'
       AND NOT EXISTS (
            SELECT 1
            FROM participantes.organizador
            WHERE id_usuario = NEW.id_usuario
       ) THEN

        RAISE EXCEPTION
            'El usuario no tiene un perfil de organizador';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM competencia.usuario_torneo_rol asignacion
        INNER JOIN catalogo.conflicto_rol_torneo conflicto
            ON (
                conflicto.id_rol_torneo_a
                    = LEAST(
                        NEW.id_rol_torneo,
                        asignacion.id_rol_torneo
                    )
                AND conflicto.id_rol_torneo_b
                    = GREATEST(
                        NEW.id_rol_torneo,
                        asignacion.id_rol_torneo
                    )
            )
        WHERE asignacion.id_torneo = NEW.id_torneo
          AND asignacion.id_usuario = NEW.id_usuario
          AND asignacion.activo = TRUE
          AND asignacion.fecha_fin IS NULL
          AND asignacion.id_usuario_torneo_rol
                <> COALESCE(
                    NEW.id_usuario_torneo_rol,
                    0
                )
    ) THEN
        RAISE EXCEPTION
            'El usuario ya tiene un rol incompatible dentro del torneo';
    END IF;

    RETURN NEW;
END;
$$;


CREATE OR REPLACE FUNCTION competencia.fn_validar_fase_torneo()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_formato VARCHAR(40);
    v_tipo_fase VARCHAR(40);
    v_fecha_inicio_torneo DATE;
    v_fecha_fin_torneo DATE;
    v_cantidad_fases INTEGER;
BEGIN
    SELECT
        formato.codigo,
        torneo.fecha_inicio_torneo,
        torneo.fecha_fin_torneo
    INTO
        v_formato,
        v_fecha_inicio_torneo,
        v_fecha_fin_torneo
    FROM competencia.torneo torneo
    INNER JOIN catalogo.formato_torneo formato
        ON formato.id_formato_torneo =
           torneo.id_formato_torneo
    WHERE torneo.id_torneo = NEW.id_torneo;

    SELECT codigo
    INTO v_tipo_fase
    FROM catalogo.tipo_fase
    WHERE id_tipo_fase = NEW.id_tipo_fase;

    IF v_formato = 'PARTIDO_UNICO'
       AND v_tipo_fase <> 'PARTIDO_UNICO' THEN

        RAISE EXCEPTION
            'El formato PARTIDO_UNICO solo admite una fase PARTIDO_UNICO';
    END IF;

    IF v_formato = 'FASE_GRUPOS'
       AND v_tipo_fase <> 'GRUPOS' THEN

        RAISE EXCEPTION
            'El formato FASE_GRUPOS solo admite fases de grupos';
    END IF;

    IF v_formato = 'ELIMINACION_DIRECTA'
       AND v_tipo_fase NOT IN ('ELIMINACION', 'FINAL') THEN

        RAISE EXCEPTION
            'El formato ELIMINACION_DIRECTA no admite la fase %',
            v_tipo_fase;
    END IF;

    IF v_formato = 'GRUPOS_Y_LLAVES'
       AND v_tipo_fase NOT IN (
            'GRUPOS',
            'ELIMINACION',
            'FINAL'
       ) THEN

        RAISE EXCEPTION
            'El formato GRUPOS_Y_LLAVES no admite la fase %',
            v_tipo_fase;
    END IF;

    IF v_formato = 'PARTIDO_UNICO' THEN
        SELECT COUNT(*)
        INTO v_cantidad_fases
        FROM competencia.fase_torneo
        WHERE id_torneo = NEW.id_torneo
          AND id_fase_torneo
              <> COALESCE(NEW.id_fase_torneo, 0);

        IF v_cantidad_fases >= 1 THEN
            RAISE EXCEPTION
                'Un torneo de partido unico solo puede tener una fase';
        END IF;
    END IF;

    IF NEW.fecha_inicio IS NOT NULL
       AND NEW.fecha_inicio < v_fecha_inicio_torneo THEN

        RAISE EXCEPTION
            'La fase no puede iniciar antes que el torneo';
    END IF;

    IF NEW.fecha_fin IS NOT NULL
       AND NEW.fecha_fin > v_fecha_fin_torneo THEN

        RAISE EXCEPTION
            'La fase no puede finalizar despues que el torneo';
    END IF;

    RETURN NEW;
END;
$$;


CREATE OR REPLACE FUNCTION competencia.fn_validar_grupo_torneo()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_tipo_fase VARCHAR(40);
BEGIN
    SELECT tipo.codigo
    INTO v_tipo_fase
    FROM competencia.fase_torneo fase
    INNER JOIN catalogo.tipo_fase tipo
        ON tipo.id_tipo_fase = fase.id_tipo_fase
    WHERE fase.id_fase_torneo = NEW.id_fase_torneo;

    IF v_tipo_fase <> 'GRUPOS' THEN
        RAISE EXCEPTION
            'Solo una fase de tipo GRUPOS puede contener grupos';
    END IF;

    RETURN NEW;
END;
$$;


CREATE OR REPLACE FUNCTION competencia.fn_validar_jornada()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_fecha_inicio_fase DATE;
    v_fecha_fin_fase DATE;
BEGIN
    SELECT
        fase.fecha_inicio,
        fase.fecha_fin
    INTO
        v_fecha_inicio_fase,
        v_fecha_fin_fase
    FROM competencia.fase_torneo fase
    WHERE fase.id_fase_torneo = NEW.id_fase_torneo;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'La fase seleccionada no existe';
    END IF;

    IF NEW.fecha_inicio IS NOT NULL
       AND NEW.fecha_inicio::DATE < v_fecha_inicio_fase THEN

        RAISE EXCEPTION
            'La jornada no puede iniciar antes que la fase';
    END IF;

    IF NEW.fecha_fin IS NOT NULL
       AND NEW.fecha_fin::DATE > v_fecha_fin_fase THEN

        RAISE EXCEPTION
            'La jornada no puede finalizar despues que la fase';
    END IF;

    RETURN NEW;
END;
$$;

COMMIT;