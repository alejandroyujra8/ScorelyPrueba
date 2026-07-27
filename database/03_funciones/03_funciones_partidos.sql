BEGIN;

CREATE OR REPLACE FUNCTION competencia.fn_torneo_partido(
    p_id_partido BIGINT
)
RETURNS BIGINT
LANGUAGE sql
STABLE
AS $$
    SELECT torneo.id_torneo
    FROM competencia.partido partido
    INNER JOIN competencia.jornada jornada
        ON jornada.id_jornada =
           partido.id_jornada
    INNER JOIN competencia.fase_torneo fase
        ON fase.id_fase_torneo =
           jornada.id_fase_torneo
    INNER JOIN competencia.torneo torneo
        ON torneo.id_torneo =
           fase.id_torneo
    WHERE partido.id_partido =
          p_id_partido;
$$;


CREATE OR REPLACE FUNCTION competencia.fn_validar_equipo_grupo()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_fase_grupo BIGINT;
    v_torneo_fase BIGINT;
    v_tipo_fase VARCHAR(40);
    v_torneo_inscripcion BIGINT;
    v_estado_inscripcion VARCHAR(40);
    v_estado_torneo VARCHAR(40);
    v_maximo_equipos SMALLINT;
    v_cantidad_equipos INTEGER;
BEGIN
    SELECT
        grupo.id_fase_torneo,
        grupo.cantidad_maxima_equipos,
        tipo.codigo,
        torneo.id_torneo,
        estado_torneo.codigo
    INTO
        v_fase_grupo,
        v_maximo_equipos,
        v_tipo_fase,
        v_torneo_fase,
        v_estado_torneo
    FROM competencia.grupo_torneo grupo
    INNER JOIN competencia.fase_torneo fase
        ON fase.id_fase_torneo =
           grupo.id_fase_torneo
    INNER JOIN catalogo.tipo_fase tipo
        ON tipo.id_tipo_fase =
           fase.id_tipo_fase
    INNER JOIN competencia.torneo torneo
        ON torneo.id_torneo =
           fase.id_torneo
    INNER JOIN catalogo.estado_torneo estado_torneo
        ON estado_torneo.id_estado_torneo =
           torneo.id_estado_torneo
    WHERE grupo.id_grupo_torneo =
          NEW.id_grupo_torneo;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'El grupo seleccionado no existe';
    END IF;

    IF NEW.id_fase_torneo <> v_fase_grupo THEN
        RAISE EXCEPTION
            'El grupo no pertenece a la fase seleccionada';
    END IF;

    IF v_tipo_fase <> 'GRUPOS' THEN
        RAISE EXCEPTION
            'Solo una fase de grupos puede recibir equipos';
    END IF;

    SELECT
        inscripcion.id_torneo,
        estado.codigo
    INTO
        v_torneo_inscripcion,
        v_estado_inscripcion
    FROM competencia.inscripcion inscripcion
    INNER JOIN catalogo.estado_inscripcion estado
        ON estado.id_estado_inscripcion =
           inscripcion.id_estado_inscripcion
    WHERE inscripcion.id_inscripcion =
          NEW.id_inscripcion;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'La inscripcion seleccionada no existe';
    END IF;

    IF v_torneo_inscripcion <> v_torneo_fase THEN
        RAISE EXCEPTION
            'La inscripcion no pertenece al torneo de la fase';
    END IF;

    IF v_estado_inscripcion <> 'HABILITADA' THEN
        RAISE EXCEPTION
            'Solo las inscripciones habilitadas pueden asignarse a grupos';
    END IF;

    IF v_estado_torneo NOT IN (
        'INSCRIPCIONES_ABIERTAS',
        'INSCRIPCIONES_CERRADAS'
    ) THEN
        RAISE EXCEPTION
            'No se pueden modificar grupos cuando el torneo esta %',
            v_estado_torneo;
    END IF;

    SELECT COUNT(*)
    INTO v_cantidad_equipos
    FROM competencia.equipo_grupo equipo_grupo
    WHERE equipo_grupo.id_grupo_torneo =
          NEW.id_grupo_torneo
      AND equipo_grupo.id_equipo_grupo <>
          COALESCE(
              NEW.id_equipo_grupo,
              0
          );

    IF v_cantidad_equipos >= v_maximo_equipos THEN
        RAISE EXCEPTION
            'El grupo alcanzo el limite de % equipos',
            v_maximo_equipos;
    END IF;

    RETURN NEW;
END;
$$;


CREATE OR REPLACE FUNCTION competencia.fn_validar_partido()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_fase BIGINT;
    v_id_torneo BIGINT;
    v_fecha_inicio_torneo DATE;
    v_fecha_fin_torneo DATE;
    v_estado_torneo VARCHAR(40);
    v_estado_partido_nuevo VARCHAR(40);
    v_estado_partido_anterior VARCHAR(40);
    v_fecha_inicio_jornada TIMESTAMPTZ;
    v_fecha_fin_jornada TIMESTAMPTZ;
    v_fase_grupo BIGINT;
    v_lugar_activo BOOLEAN;
    v_torneo_siguiente BIGINT;
BEGIN
    SELECT
        jornada.id_fase_torneo,
        fase.id_torneo,
        torneo.fecha_inicio_torneo,
        torneo.fecha_fin_torneo,
        estado_torneo.codigo,
        jornada.fecha_inicio,
        jornada.fecha_fin
    INTO
        v_id_fase,
        v_id_torneo,
        v_fecha_inicio_torneo,
        v_fecha_fin_torneo,
        v_estado_torneo,
        v_fecha_inicio_jornada,
        v_fecha_fin_jornada
    FROM competencia.jornada jornada
    INNER JOIN competencia.fase_torneo fase
        ON fase.id_fase_torneo =
           jornada.id_fase_torneo
    INNER JOIN competencia.torneo torneo
        ON torneo.id_torneo =
           fase.id_torneo
    INNER JOIN catalogo.estado_torneo estado_torneo
        ON estado_torneo.id_estado_torneo =
           torneo.id_estado_torneo
    WHERE jornada.id_jornada =
          NEW.id_jornada;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'La jornada seleccionada no existe';
    END IF;

    SELECT codigo
    INTO v_estado_partido_nuevo
    FROM catalogo.estado_partido
    WHERE id_estado_partido =
          NEW.id_estado_partido;

    IF TG_OP = 'UPDATE' THEN
        SELECT codigo
        INTO v_estado_partido_anterior
        FROM catalogo.estado_partido
        WHERE id_estado_partido =
              OLD.id_estado_partido;

        IF v_estado_partido_anterior IN (
            'FINALIZADO',
            'CANCELADO'
        ) THEN
            RAISE EXCEPTION
                'Un partido % no puede modificarse',
                v_estado_partido_anterior;
        END IF;
    END IF;

    IF v_estado_torneo IN (
        'FINALIZADO',
        'CANCELADO'
    ) THEN
        RAISE EXCEPTION
            'No se pueden modificar partidos de un torneo %',
            v_estado_torneo;
    END IF;

    IF NEW.id_grupo_torneo IS NOT NULL THEN
        SELECT id_fase_torneo
        INTO v_fase_grupo
        FROM competencia.grupo_torneo
        WHERE id_grupo_torneo =
              NEW.id_grupo_torneo;

        IF v_fase_grupo <> v_id_fase THEN
            RAISE EXCEPTION
                'El grupo no pertenece a la fase de la jornada';
        END IF;
    END IF;

    IF NEW.id_lugar IS NOT NULL THEN
        SELECT activo
        INTO v_lugar_activo
        FROM competencia.lugar
        WHERE id_lugar = NEW.id_lugar;

        IF v_lugar_activo = FALSE THEN
            RAISE EXCEPTION
                'El lugar seleccionado se encuentra inactivo';
        END IF;
    END IF;

    IF v_estado_partido_nuevo <> 'BORRADOR'
       AND (
            NEW.id_lugar IS NULL
            OR NEW.fecha_hora_inicio IS NULL
            OR NEW.fecha_hora_fin IS NULL
       ) THEN

        RAISE EXCEPTION
            'Un partido no borrador requiere fecha, hora y lugar';
    END IF;

    IF NEW.fecha_hora_inicio IS NOT NULL
       AND NEW.fecha_hora_inicio::DATE <
           v_fecha_inicio_torneo THEN

        RAISE EXCEPTION
            'El partido no puede iniciar antes que el torneo';
    END IF;

    IF NEW.fecha_hora_fin IS NOT NULL
       AND NEW.fecha_hora_fin::DATE >
           v_fecha_fin_torneo THEN

        RAISE EXCEPTION
            'El partido no puede finalizar despues que el torneo';
    END IF;

    IF v_fecha_inicio_jornada IS NOT NULL
       AND NEW.fecha_hora_inicio IS NOT NULL
       AND NEW.fecha_hora_inicio <
           v_fecha_inicio_jornada THEN

        RAISE EXCEPTION
            'El partido no puede iniciar antes que la jornada';
    END IF;

    IF v_fecha_fin_jornada IS NOT NULL
       AND NEW.fecha_hora_fin IS NOT NULL
       AND NEW.fecha_hora_fin >
           v_fecha_fin_jornada THEN

        RAISE EXCEPTION
            'El partido no puede finalizar despues que la jornada';
    END IF;

    IF NEW.id_partido_siguiente IS NOT NULL THEN
        v_torneo_siguiente :=
            competencia.fn_torneo_partido(
                NEW.id_partido_siguiente
            );

        IF v_torneo_siguiente <> v_id_torneo THEN
            RAISE EXCEPTION
                'El partido siguiente debe pertenecer al mismo torneo';
        END IF;
    END IF;

    IF NEW.id_lugar IS NOT NULL
       AND NEW.fecha_hora_inicio IS NOT NULL
       AND NEW.fecha_hora_fin IS NOT NULL
       AND EXISTS (
            SELECT 1
            FROM competencia.partido otro
            INNER JOIN catalogo.estado_partido estado
                ON estado.id_estado_partido =
                   otro.id_estado_partido
            WHERE otro.id_partido <>
                  COALESCE(
                      NEW.id_partido,
                      0
                  )
              AND otro.id_lugar =
                  NEW.id_lugar
              AND estado.codigo <> 'CANCELADO'
              AND otro.fecha_hora_inicio IS NOT NULL
              AND otro.fecha_hora_fin IS NOT NULL
              AND NEW.fecha_hora_inicio <
                  otro.fecha_hora_fin
              AND NEW.fecha_hora_fin >
                  otro.fecha_hora_inicio
       ) THEN

        RAISE EXCEPTION
            'El lugar ya tiene otro partido en ese horario';
    END IF;

    IF NEW.fecha_hora_inicio IS NOT NULL
       AND NEW.fecha_hora_fin IS NOT NULL
       AND EXISTS (
            SELECT 1
            FROM competencia.partido_equipo actual
            INNER JOIN competencia.inscripcion ins_actual
                ON ins_actual.id_inscripcion =
                   actual.id_inscripcion
            INNER JOIN competencia.partido_equipo otro_equipo
                ON otro_equipo.id_partido <>
                   actual.id_partido
            INNER JOIN competencia.inscripcion ins_otro
                ON ins_otro.id_inscripcion =
                   otro_equipo.id_inscripcion
            INNER JOIN competencia.partido otro
                ON otro.id_partido =
                   otro_equipo.id_partido
            INNER JOIN catalogo.estado_partido estado_otro
                ON estado_otro.id_estado_partido =
                   otro.id_estado_partido
            WHERE actual.id_partido =
                  COALESCE(
                      NEW.id_partido,
                      0
                  )
              AND ins_actual.id_equipo =
                  ins_otro.id_equipo
              AND estado_otro.codigo <> 'CANCELADO'
              AND otro.fecha_hora_inicio IS NOT NULL
              AND otro.fecha_hora_fin IS NOT NULL
              AND NEW.fecha_hora_inicio <
                  otro.fecha_hora_fin
              AND NEW.fecha_hora_fin >
                  otro.fecha_hora_inicio
       ) THEN

        RAISE EXCEPTION
            'Uno de los equipos ya tiene otro partido en ese horario';
    END IF;

    IF NEW.fecha_hora_inicio IS NOT NULL
       AND NEW.fecha_hora_fin IS NOT NULL
       AND EXISTS (
            SELECT 1
            FROM competencia.arbitro_partido actual
            INNER JOIN competencia.arbitro_partido otro_arbitro
                ON otro_arbitro.id_arbitro =
                   actual.id_arbitro
               AND otro_arbitro.id_partido <>
                   actual.id_partido
               AND otro_arbitro.activo = TRUE
               AND otro_arbitro.fecha_fin IS NULL
            INNER JOIN competencia.partido otro
                ON otro.id_partido =
                   otro_arbitro.id_partido
            INNER JOIN catalogo.estado_partido estado_otro
                ON estado_otro.id_estado_partido =
                   otro.id_estado_partido
            WHERE actual.id_partido =
                  COALESCE(
                      NEW.id_partido,
                      0
                  )
              AND actual.activo = TRUE
              AND actual.fecha_fin IS NULL
              AND estado_otro.codigo <> 'CANCELADO'
              AND otro.fecha_hora_inicio IS NOT NULL
              AND otro.fecha_hora_fin IS NOT NULL
              AND NEW.fecha_hora_inicio <
                  otro.fecha_hora_fin
              AND NEW.fecha_hora_fin >
                  otro.fecha_hora_inicio
       ) THEN

        RAISE EXCEPTION
            'Uno de los arbitros ya tiene otro partido en ese horario';
    END IF;

    NEW.fecha_actualizacion :=
        CURRENT_TIMESTAMP;

    RETURN NEW;
END;
$$;


CREATE OR REPLACE FUNCTION competencia.fn_validar_transicion_partido()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado_anterior VARCHAR(40);
    v_estado_nuevo VARCHAR(40);
    v_estado_torneo VARCHAR(40);
    v_tipo_fase VARCHAR(40);
    v_permite_empate BOOLEAN;
    v_transicion_valida BOOLEAN := FALSE;
    v_cantidad_equipos INTEGER;
    v_cantidad_arbitros_principales INTEGER;
    v_marcadores INTEGER[];
    v_desempates INTEGER[];
BEGIN
    IF NEW.id_estado_partido =
       OLD.id_estado_partido THEN
        RETURN NEW;
    END IF;

    SELECT codigo
    INTO v_estado_anterior
    FROM catalogo.estado_partido
    WHERE id_estado_partido =
          OLD.id_estado_partido;

    SELECT codigo
    INTO v_estado_nuevo
    FROM catalogo.estado_partido
    WHERE id_estado_partido =
          NEW.id_estado_partido;

    SELECT
        estado_torneo.codigo,
        tipo_fase.codigo,
        torneo.permite_empate
    INTO
        v_estado_torneo,
        v_tipo_fase,
        v_permite_empate
    FROM competencia.jornada jornada
    INNER JOIN competencia.fase_torneo fase
        ON fase.id_fase_torneo =
           jornada.id_fase_torneo
    INNER JOIN catalogo.tipo_fase tipo_fase
        ON tipo_fase.id_tipo_fase =
           fase.id_tipo_fase
    INNER JOIN competencia.torneo torneo
        ON torneo.id_torneo =
           fase.id_torneo
    INNER JOIN catalogo.estado_torneo estado_torneo
        ON estado_torneo.id_estado_torneo =
           torneo.id_estado_torneo
    WHERE jornada.id_jornada =
          NEW.id_jornada;

    v_transicion_valida :=
        CASE
            WHEN v_estado_anterior = 'BORRADOR'
                AND v_estado_nuevo IN (
                    'PROGRAMADO',
                    'CANCELADO'
                )
                THEN TRUE

            WHEN v_estado_anterior = 'PROGRAMADO'
                AND v_estado_nuevo IN (
                    'EN_CURSO',
                    'SUSPENDIDO',
                    'CANCELADO'
                )
                THEN TRUE

            WHEN v_estado_anterior = 'SUSPENDIDO'
                AND v_estado_nuevo IN (
                    'PROGRAMADO',
                    'EN_CURSO',
                    'CANCELADO'
                )
                THEN TRUE

            WHEN v_estado_anterior = 'EN_CURSO'
                AND v_estado_nuevo IN (
                    'FINALIZADO',
                    'SUSPENDIDO',
                    'CANCELADO'
                )
                THEN TRUE

            ELSE FALSE
        END;

    IF v_transicion_valida = FALSE THEN
        RAISE EXCEPTION
            'Transicion de partido no permitida: % -> %',
            v_estado_anterior,
            v_estado_nuevo;
    END IF;

    SELECT COUNT(*)
    INTO v_cantidad_equipos
    FROM competencia.partido_equipo
    WHERE id_partido =
          NEW.id_partido;

    IF v_estado_nuevo = 'PROGRAMADO' THEN
        IF v_cantidad_equipos <> 2 THEN
            RAISE EXCEPTION
                'Un partido programado debe tener exactamente 2 equipos';
        END IF;

        IF NEW.id_lugar IS NULL
           OR NEW.fecha_hora_inicio IS NULL
           OR NEW.fecha_hora_fin IS NULL THEN

            RAISE EXCEPTION
                'El partido programado requiere lugar y horario';
        END IF;

        IF v_estado_torneo NOT IN (
            'INSCRIPCIONES_CERRADAS',
            'PROGRAMADO',
            'EN_CURSO'
        ) THEN
            RAISE EXCEPTION
                'El torneo no esta listo para programar partidos';
        END IF;
    END IF;

    IF v_estado_nuevo IN (
        'EN_CURSO',
        'FINALIZADO'
    ) THEN
        IF v_estado_torneo <> 'EN_CURSO' THEN
            RAISE EXCEPTION
                'El torneo debe estar EN_CURSO';
        END IF;

        IF v_cantidad_equipos <> 2 THEN
            RAISE EXCEPTION
                'El partido debe tener exactamente 2 equipos';
        END IF;
    END IF;

    IF v_estado_nuevo = 'EN_CURSO' THEN
        SELECT COUNT(*)
        INTO v_cantidad_arbitros_principales
        FROM competencia.arbitro_partido arbitro
        INNER JOIN catalogo.tipo_arbitro_partido tipo
            ON tipo.id_tipo_arbitro_partido =
               arbitro.id_tipo_arbitro_partido
        WHERE arbitro.id_partido =
              NEW.id_partido
          AND tipo.codigo = 'PRINCIPAL'
          AND arbitro.activo = TRUE
          AND arbitro.fecha_fin IS NULL;

        IF v_cantidad_arbitros_principales <> 1 THEN
            RAISE EXCEPTION
                'El partido requiere exactamente un arbitro principal';
        END IF;
    END IF;

    IF v_estado_nuevo = 'FINALIZADO' THEN
        SELECT
            ARRAY_AGG(
                marcador
                ORDER BY id_partido_equipo
            ),
            ARRAY_AGG(
                COALESCE(
                    marcador_desempate,
                    0
                )
                ORDER BY id_partido_equipo
            )
        INTO
            v_marcadores,
            v_desempates
        FROM competencia.partido_equipo
        WHERE id_partido =
              NEW.id_partido;

        IF v_marcadores[1] IS NULL
           OR v_marcadores[2] IS NULL THEN

            RAISE EXCEPTION
                'Los dos equipos deben tener marcador';
        END IF;

        IF v_marcadores[1] = v_marcadores[2] THEN
            IF v_tipo_fase <> 'GRUPOS'
               OR v_permite_empate = FALSE THEN

                IF v_desempates[1] =
                   v_desempates[2] THEN

                    RAISE EXCEPTION
                        'El partido requiere un marcador de desempate';
                END IF;
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;


CREATE OR REPLACE FUNCTION competencia.fn_validar_partido_equipo()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_torneo BIGINT;
    v_id_grupo BIGINT;
    v_estado_partido VARCHAR(40);
    v_fecha_inicio TIMESTAMPTZ;
    v_fecha_fin TIMESTAMPTZ;
    v_torneo_inscripcion BIGINT;
    v_id_equipo BIGINT;
    v_estado_inscripcion VARCHAR(40);
    v_cantidad_equipos INTEGER;
BEGIN
    SELECT
        competencia.fn_torneo_partido(
            partido.id_partido
        ),
        partido.id_grupo_torneo,
        estado.codigo,
        partido.fecha_hora_inicio,
        partido.fecha_hora_fin
    INTO
        v_id_torneo,
        v_id_grupo,
        v_estado_partido,
        v_fecha_inicio,
        v_fecha_fin
    FROM competencia.partido partido
    INNER JOIN catalogo.estado_partido estado
        ON estado.id_estado_partido =
           partido.id_estado_partido
    WHERE partido.id_partido =
          NEW.id_partido;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'El partido seleccionado no existe';
    END IF;

    IF v_estado_partido IN (
        'FINALIZADO',
        'CANCELADO'
    ) THEN
        RAISE EXCEPTION
            'No se pueden modificar equipos de un partido %',
            v_estado_partido;
    END IF;

    IF TG_OP = 'UPDATE' THEN
        IF NEW.id_partido <> OLD.id_partido
           OR NEW.id_inscripcion <>
              OLD.id_inscripcion
           OR NEW.id_condicion_equipo <>
              OLD.id_condicion_equipo THEN

            RAISE EXCEPTION
                'No se puede cambiar el partido, equipo o condicion';
        END IF;
    END IF;

    SELECT
        inscripcion.id_torneo,
        inscripcion.id_equipo,
        estado.codigo
    INTO
        v_torneo_inscripcion,
        v_id_equipo,
        v_estado_inscripcion
    FROM competencia.inscripcion inscripcion
    INNER JOIN catalogo.estado_inscripcion estado
        ON estado.id_estado_inscripcion =
           inscripcion.id_estado_inscripcion
    WHERE inscripcion.id_inscripcion =
          NEW.id_inscripcion;

    IF v_torneo_inscripcion <> v_id_torneo THEN
        RAISE EXCEPTION
            'El equipo no esta inscrito en el torneo del partido';
    END IF;

    IF v_estado_inscripcion <> 'HABILITADA' THEN
        RAISE EXCEPTION
            'Solo participan inscripciones habilitadas';
    END IF;

    IF TG_OP = 'INSERT' THEN
        SELECT COUNT(*)
        INTO v_cantidad_equipos
        FROM competencia.partido_equipo
        WHERE id_partido =
              NEW.id_partido;

        IF v_cantidad_equipos >= 2 THEN
            RAISE EXCEPTION
                'El partido ya tiene dos equipos';
        END IF;
    END IF;

    IF v_id_grupo IS NOT NULL
       AND NOT EXISTS (
            SELECT 1
            FROM competencia.equipo_grupo
            WHERE id_grupo_torneo =
                  v_id_grupo
              AND id_inscripcion =
                  NEW.id_inscripcion
       ) THEN

        RAISE EXCEPTION
            'El equipo no pertenece al grupo del partido';
    END IF;

    IF v_fecha_inicio IS NOT NULL
       AND v_fecha_fin IS NOT NULL
       AND EXISTS (
            SELECT 1
            FROM competencia.partido_equipo otro_equipo
            INNER JOIN competencia.inscripcion otra_inscripcion
                ON otra_inscripcion.id_inscripcion =
                   otro_equipo.id_inscripcion
            INNER JOIN competencia.partido otro_partido
                ON otro_partido.id_partido =
                   otro_equipo.id_partido
            INNER JOIN catalogo.estado_partido otro_estado
                ON otro_estado.id_estado_partido =
                   otro_partido.id_estado_partido
            WHERE otra_inscripcion.id_equipo =
                  v_id_equipo
              AND otro_partido.id_partido <>
                  NEW.id_partido
              AND otro_estado.codigo <>
                  'CANCELADO'
              AND otro_partido.fecha_hora_inicio
                  IS NOT NULL
              AND otro_partido.fecha_hora_fin
                  IS NOT NULL
              AND v_fecha_inicio <
                  otro_partido.fecha_hora_fin
              AND v_fecha_fin >
                  otro_partido.fecha_hora_inicio
       ) THEN

        RAISE EXCEPTION
            'El equipo ya tiene otro partido en ese horario';
    END IF;

    RETURN NEW;
END;
$$;


CREATE OR REPLACE FUNCTION competencia.fn_validar_arbitro_partido()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_torneo BIGINT;
    v_estado_partido VARCHAR(40);
    v_fecha_inicio TIMESTAMPTZ;
    v_fecha_fin TIMESTAMPTZ;
BEGIN
    SELECT
        competencia.fn_torneo_partido(
            partido.id_partido
        ),
        estado.codigo,
        partido.fecha_hora_inicio,
        partido.fecha_hora_fin
    INTO
        v_id_torneo,
        v_estado_partido,
        v_fecha_inicio,
        v_fecha_fin
    FROM competencia.partido partido
    INNER JOIN catalogo.estado_partido estado
        ON estado.id_estado_partido =
           partido.id_estado_partido
    WHERE partido.id_partido =
          NEW.id_partido;

    IF v_estado_partido IN (
        'FINALIZADO',
        'CANCELADO'
    ) THEN
        RAISE EXCEPTION
            'No se pueden asignar arbitros a un partido %',
            v_estado_partido;
    END IF;

    IF TG_OP = 'UPDATE'
       AND (
            NEW.id_partido <>
            OLD.id_partido
            OR NEW.id_arbitro <>
               OLD.id_arbitro
       ) THEN

        RAISE EXCEPTION
            'No se puede cambiar el partido o el arbitro de la asignacion';
    END IF;

    IF NEW.activo = TRUE
       AND NOT EXISTS (
            SELECT 1
            FROM competencia.usuario_torneo_rol asignacion
            INNER JOIN catalogo.rol_torneo rol
                ON rol.id_rol_torneo =
                   asignacion.id_rol_torneo
            WHERE asignacion.id_torneo =
                  v_id_torneo
              AND asignacion.id_usuario =
                  NEW.id_arbitro
              AND rol.codigo = 'ARBITRO'
              AND asignacion.activo = TRUE
              AND asignacion.fecha_fin IS NULL
       ) THEN

        RAISE EXCEPTION
            'El usuario no tiene rol de arbitro en este torneo';
    END IF;

    IF NEW.activo = TRUE
       AND v_fecha_inicio IS NOT NULL
       AND v_fecha_fin IS NOT NULL
       AND EXISTS (
            SELECT 1
            FROM competencia.arbitro_partido otro_arbitro
            INNER JOIN competencia.partido otro_partido
                ON otro_partido.id_partido =
                   otro_arbitro.id_partido
            INNER JOIN catalogo.estado_partido otro_estado
                ON otro_estado.id_estado_partido =
                   otro_partido.id_estado_partido
            WHERE otro_arbitro.id_arbitro =
                  NEW.id_arbitro
              AND otro_arbitro.activo = TRUE
              AND otro_arbitro.fecha_fin IS NULL
              AND otro_arbitro.id_arbitro_partido <>
                  COALESCE(
                      NEW.id_arbitro_partido,
                      0
                  )
              AND otro_partido.id_partido <>
                  NEW.id_partido
              AND otro_estado.codigo <>
                  'CANCELADO'
              AND otro_partido.fecha_hora_inicio
                  IS NOT NULL
              AND otro_partido.fecha_hora_fin
                  IS NOT NULL
              AND v_fecha_inicio <
                  otro_partido.fecha_hora_fin
              AND v_fecha_fin >
                  otro_partido.fecha_hora_inicio
       ) THEN

        RAISE EXCEPTION
            'El arbitro ya tiene otro partido en ese horario';
    END IF;

    RETURN NEW;
END;
$$;


CREATE OR REPLACE FUNCTION competencia.fn_validar_jugador_partido()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_partido_equipo BIGINT;
    v_inscripcion_partido BIGINT;
    v_estado_partido VARCHAR(40);
    v_inscripcion_jugador BIGINT;
    v_estado_jugador VARCHAR(40);
    v_fecha_baja TIMESTAMPTZ;
BEGIN
    SELECT
        equipo.id_partido,
        equipo.id_inscripcion,
        estado.codigo
    INTO
        v_partido_equipo,
        v_inscripcion_partido,
        v_estado_partido
    FROM competencia.partido_equipo equipo
    INNER JOIN competencia.partido partido
        ON partido.id_partido =
           equipo.id_partido
    INNER JOIN catalogo.estado_partido estado
        ON estado.id_estado_partido =
           partido.id_estado_partido
    WHERE equipo.id_partido_equipo =
          NEW.id_partido_equipo;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'El equipo del partido no existe';
    END IF;

    IF NEW.id_partido <> v_partido_equipo THEN
        RAISE EXCEPTION
            'El equipo seleccionado no pertenece al partido';
    END IF;

    IF v_estado_partido NOT IN (
        'PROGRAMADO',
        'EN_CURSO'
    ) THEN
        RAISE EXCEPTION
            'No se puede modificar participacion en un partido %',
            v_estado_partido;
    END IF;

    IF TG_OP = 'UPDATE'
       AND (
            NEW.id_partido <>
            OLD.id_partido
            OR NEW.id_partido_equipo <>
               OLD.id_partido_equipo
            OR NEW.id_jugador_inscripcion <>
               OLD.id_jugador_inscripcion
       ) THEN

        RAISE EXCEPTION
            'No se puede cambiar el partido, equipo o jugador';
    END IF;

    SELECT
        jugador.id_inscripcion,
        estado.codigo,
        jugador.fecha_baja
    INTO
        v_inscripcion_jugador,
        v_estado_jugador,
        v_fecha_baja
    FROM competencia.jugador_inscripcion jugador
    INNER JOIN catalogo.estado_jugador_inscripcion estado
        ON estado.id_estado_jugador_inscripcion =
           jugador.id_estado_jugador_inscripcion
    WHERE jugador.id_jugador_inscripcion =
          NEW.id_jugador_inscripcion;

    IF v_inscripcion_jugador <>
       v_inscripcion_partido THEN

        RAISE EXCEPTION
            'El jugador no pertenece al equipo del partido';
    END IF;

    IF v_estado_jugador <> 'HABILITADO'
       OR v_fecha_baja IS NOT NULL THEN

        RAISE EXCEPTION
            'El jugador no se encuentra habilitado en la nomina';
    END IF;

    IF NEW.asistio = TRUE
       AND NEW.convocado = FALSE THEN

        RAISE EXCEPTION
            'Un jugador que asistio debe estar convocado';
    END IF;

    IF NEW.titular = TRUE
       AND (
            NEW.convocado = FALSE
            OR NEW.asistio = FALSE
       ) THEN

        RAISE EXCEPTION
            'Un titular debe estar convocado y haber asistido';
    END IF;

    NEW.fecha_actualizacion :=
        CURRENT_TIMESTAMP;

    RETURN NEW;
END;
$$;


CREATE OR REPLACE FUNCTION competencia.fn_calcular_resultado_partido()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado_nuevo VARCHAR(40);
    v_tipo_fase VARCHAR(40);

    v_puntos_victoria SMALLINT;
    v_puntos_empate SMALLINT;
    v_puntos_derrota SMALLINT;

    v_id_equipo_a BIGINT;
    v_marcador_a INTEGER;
    v_desempate_a INTEGER;

    v_id_equipo_b BIGINT;
    v_marcador_b INTEGER;
    v_desempate_b INTEGER;

    v_id_ganador SMALLINT;
    v_id_perdedor SMALLINT;
    v_id_empate SMALLINT;

    v_clasifica_ganador BOOLEAN;
BEGIN
    SELECT codigo
    INTO v_estado_nuevo
    FROM catalogo.estado_partido
    WHERE id_estado_partido =
          NEW.id_estado_partido;

    IF v_estado_nuevo <> 'FINALIZADO' THEN
        RETURN NEW;
    END IF;

    SELECT
        tipo.codigo,
        deporte.puntos_victoria,
        deporte.puntos_empate,
        deporte.puntos_derrota
    INTO
        v_tipo_fase,
        v_puntos_victoria,
        v_puntos_empate,
        v_puntos_derrota
    FROM competencia.jornada jornada
    INNER JOIN competencia.fase_torneo fase
        ON fase.id_fase_torneo =
           jornada.id_fase_torneo
    INNER JOIN catalogo.tipo_fase tipo
        ON tipo.id_tipo_fase =
           fase.id_tipo_fase
    INNER JOIN competencia.torneo torneo
        ON torneo.id_torneo =
           fase.id_torneo
    INNER JOIN competencia.deporte deporte
        ON deporte.id_deporte =
           torneo.id_deporte
    WHERE jornada.id_jornada =
          NEW.id_jornada;

    SELECT
        id_resultado_equipo_partido
    INTO v_id_ganador
    FROM catalogo.resultado_equipo_partido
    WHERE codigo = 'GANADOR';

    SELECT
        id_resultado_equipo_partido
    INTO v_id_perdedor
    FROM catalogo.resultado_equipo_partido
    WHERE codigo = 'PERDEDOR';

    SELECT
        id_resultado_equipo_partido
    INTO v_id_empate
    FROM catalogo.resultado_equipo_partido
    WHERE codigo = 'EMPATE';

    SELECT
        id_partido_equipo,
        marcador,
        COALESCE(
            marcador_desempate,
            0
        )
    INTO
        v_id_equipo_a,
        v_marcador_a,
        v_desempate_a
    FROM competencia.partido_equipo
    WHERE id_partido =
          NEW.id_partido
    ORDER BY id_partido_equipo
    LIMIT 1;

    SELECT
        id_partido_equipo,
        marcador,
        COALESCE(
            marcador_desempate,
            0
        )
    INTO
        v_id_equipo_b,
        v_marcador_b,
        v_desempate_b
    FROM competencia.partido_equipo
    WHERE id_partido =
          NEW.id_partido
    ORDER BY id_partido_equipo
    OFFSET 1
    LIMIT 1;

    v_clasifica_ganador :=
        v_tipo_fase IN (
            'PARTIDO_UNICO',
            'ELIMINACION',
            'FINAL'
        );

    IF v_marcador_a > v_marcador_b
       OR (
            v_marcador_a = v_marcador_b
            AND v_desempate_a > v_desempate_b
       ) THEN

        UPDATE competencia.partido_equipo
        SET
            id_resultado_equipo_partido =
                v_id_ganador,
            puntos_tabla =
                v_puntos_victoria,
            clasificado =
                v_clasifica_ganador
        WHERE id_partido_equipo =
              v_id_equipo_a;

        UPDATE competencia.partido_equipo
        SET
            id_resultado_equipo_partido =
                v_id_perdedor,
            puntos_tabla =
                v_puntos_derrota,
            clasificado = FALSE
        WHERE id_partido_equipo =
              v_id_equipo_b;

    ELSIF v_marcador_b > v_marcador_a
       OR (
            v_marcador_a = v_marcador_b
            AND v_desempate_b > v_desempate_a
       ) THEN

        UPDATE competencia.partido_equipo
        SET
            id_resultado_equipo_partido =
                v_id_perdedor,
            puntos_tabla =
                v_puntos_derrota,
            clasificado = FALSE
        WHERE id_partido_equipo =
              v_id_equipo_a;

        UPDATE competencia.partido_equipo
        SET
            id_resultado_equipo_partido =
                v_id_ganador,
            puntos_tabla =
                v_puntos_victoria,
            clasificado =
                v_clasifica_ganador
        WHERE id_partido_equipo =
              v_id_equipo_b;

    ELSE
        UPDATE competencia.partido_equipo
        SET
            id_resultado_equipo_partido =
                v_id_empate,
            puntos_tabla =
                v_puntos_empate,
            clasificado = FALSE
        WHERE id_partido =
              NEW.id_partido;
    END IF;

    RETURN NEW;
END;
$$;


CREATE OR REPLACE FUNCTION auditoria.fn_historial_partido()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_usuario_aplicacion BIGINT;
    v_detalle_equipos JSONB;
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
            NEW.actualizado_por,
            NEW.creado_por
        );

    SELECT COALESCE(
        JSONB_AGG(
            JSONB_BUILD_OBJECT(
                'id_partido_equipo',
                equipo.id_partido_equipo,
                'id_inscripcion',
                equipo.id_inscripcion,
                'marcador',
                equipo.marcador,
                'marcador_desempate',
                equipo.marcador_desempate,
                'puntos_tabla',
                equipo.puntos_tabla,
                'clasificado',
                equipo.clasificado
            )
            ORDER BY equipo.id_partido_equipo
        ),
        '[]'::JSONB
    )
    INTO v_detalle_equipos
    FROM competencia.partido_equipo equipo
    WHERE equipo.id_partido =
          NEW.id_partido;

    IF TG_OP = 'INSERT' THEN
        INSERT INTO auditoria.historial_estado_partido (
            id_partido,
            id_estado_anterior,
            id_estado_nuevo,
            operacion,
            usuario_aplicacion,
            detalle
        )
        VALUES (
            NEW.id_partido,
            NULL,
            NEW.id_estado_partido,
            'INSERT',
            v_usuario_aplicacion,
            JSONB_BUILD_OBJECT(
                'codigo',
                NEW.codigo,
                'fecha_hora_inicio',
                NEW.fecha_hora_inicio,
                'fecha_hora_fin',
                NEW.fecha_hora_fin,
                'equipos',
                v_detalle_equipos
            )
        );

    ELSIF NEW.id_estado_partido <>
          OLD.id_estado_partido THEN

        INSERT INTO auditoria.historial_estado_partido (
            id_partido,
            id_estado_anterior,
            id_estado_nuevo,
            operacion,
            usuario_aplicacion,
            detalle
        )
        VALUES (
            NEW.id_partido,
            OLD.id_estado_partido,
            NEW.id_estado_partido,
            'UPDATE',
            v_usuario_aplicacion,
            JSONB_BUILD_OBJECT(
                'fecha_hora_inicio',
                NEW.fecha_hora_inicio,
                'fecha_hora_fin',
                NEW.fecha_hora_fin,
                'equipos',
                v_detalle_equipos
            )
        );
    END IF;

    RETURN NEW;
END;
$$;

COMMIT;