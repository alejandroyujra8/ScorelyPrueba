BEGIN;

CREATE OR REPLACE FUNCTION finanzas.fn_total_pagado_inscripcion(
    p_id_inscripcion BIGINT
)
RETURNS NUMERIC(12, 2)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_total NUMERIC(12, 2);
BEGIN
    SELECT COALESCE(SUM(pago.monto), 0)
    INTO v_total
    FROM finanzas.pago pago
    INNER JOIN catalogo.estado_pago estado
        ON estado.id_estado_pago = pago.id_estado_pago
    WHERE pago.id_inscripcion = p_id_inscripcion
      AND estado.codigo = 'CONFIRMADO';

    RETURN v_total;
END;
$$;


CREATE OR REPLACE FUNCTION finanzas.fn_saldo_inscripcion(
    p_id_inscripcion BIGINT
)
RETURNS NUMERIC(12, 2)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_monto_requerido NUMERIC(12, 2);
    v_total_pagado NUMERIC(12, 2);
BEGIN
    SELECT monto_requerido
    INTO v_monto_requerido
    FROM competencia.inscripcion
    WHERE id_inscripcion = p_id_inscripcion;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'La inscripcion % no existe',
            p_id_inscripcion;
    END IF;

    v_total_pagado :=
        finanzas.fn_total_pagado_inscripcion(
            p_id_inscripcion
        );

    RETURN GREATEST(
        v_monto_requerido - v_total_pagado,
        0
    );
END;
$$;


CREATE OR REPLACE FUNCTION competencia.fn_validar_inscripcion()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado_torneo VARCHAR(40);
    v_estado_equipo VARCHAR(40);
    v_maximo_equipos SMALLINT;
    v_costo_inscripcion NUMERIC(12, 2);
    v_moneda CHAR(3);
    v_cantidad_inscritos INTEGER;
BEGIN
    IF TG_OP = 'UPDATE' THEN
        IF NEW.id_torneo <> OLD.id_torneo
           OR NEW.id_equipo <> OLD.id_equipo THEN

            RAISE EXCEPTION
                'No se puede cambiar el torneo o el equipo de una inscripcion';
        END IF;
    END IF;

    SELECT
        estado.codigo,
        torneo.cantidad_maxima_equipos,
        torneo.costo_inscripcion,
        torneo.moneda
    INTO
        v_estado_torneo,
        v_maximo_equipos,
        v_costo_inscripcion,
        v_moneda
    FROM competencia.torneo torneo
    INNER JOIN catalogo.estado_torneo estado
        ON estado.id_estado_torneo =
           torneo.id_estado_torneo
    WHERE torneo.id_torneo = NEW.id_torneo;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'El torneo seleccionado no existe';
    END IF;

    SELECT estado.codigo
    INTO v_estado_equipo
    FROM participantes.equipo equipo
    INNER JOIN catalogo.estado_equipo estado
        ON estado.id_estado_equipo =
           equipo.id_estado_equipo
    WHERE equipo.id_equipo = NEW.id_equipo;

    IF v_estado_equipo <> 'ACTIVO' THEN
        RAISE EXCEPTION
            'Solo se pueden inscribir equipos activos';
    END IF;

    IF TG_OP = 'INSERT' THEN
        IF v_estado_torneo <> 'INSCRIPCIONES_ABIERTAS' THEN
            RAISE EXCEPTION
                'El torneo no tiene las inscripciones abiertas';
        END IF;

        SELECT COUNT(*)
        INTO v_cantidad_inscritos
        FROM competencia.inscripcion inscripcion
        INNER JOIN catalogo.estado_inscripcion estado
            ON estado.id_estado_inscripcion =
               inscripcion.id_estado_inscripcion
        WHERE inscripcion.id_torneo = NEW.id_torneo
          AND estado.codigo NOT IN (
              'RECHAZADA',
              'RETIRADA'
          );

        IF v_cantidad_inscritos >= v_maximo_equipos THEN
            RAISE EXCEPTION
                'El torneo alcanzo el limite de % equipos',
                v_maximo_equipos;
        END IF;

        NEW.monto_requerido := v_costo_inscripcion;
        NEW.moneda := v_moneda;
    ELSE
        IF NEW.monto_requerido <> OLD.monto_requerido
           OR NEW.moneda <> OLD.moneda THEN

            RAISE EXCEPTION
                'No se puede modificar el monto requerido ni la moneda';
        END IF;
    END IF;

    NEW.fecha_actualizacion := CURRENT_TIMESTAMP;

    RETURN NEW;
END;
$$;


CREATE OR REPLACE FUNCTION competencia.fn_validar_transicion_inscripcion()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado_anterior VARCHAR(40);
    v_estado_nuevo VARCHAR(40);
    v_estado_torneo VARCHAR(40);
    v_total_pagado NUMERIC(12, 2);
BEGIN
    IF NEW.id_estado_inscripcion =
       OLD.id_estado_inscripcion THEN

        RETURN NEW;
    END IF;

    SELECT codigo
    INTO v_estado_anterior
    FROM catalogo.estado_inscripcion
    WHERE id_estado_inscripcion =
          OLD.id_estado_inscripcion;

    SELECT codigo
    INTO v_estado_nuevo
    FROM catalogo.estado_inscripcion
    WHERE id_estado_inscripcion =
          NEW.id_estado_inscripcion;

    SELECT estado.codigo
    INTO v_estado_torneo
    FROM competencia.torneo torneo
    INNER JOIN catalogo.estado_torneo estado
        ON estado.id_estado_torneo =
           torneo.id_estado_torneo
    WHERE torneo.id_torneo = NEW.id_torneo;

    IF v_estado_anterior IN (
        'RECHAZADA',
        'RETIRADA'
    ) THEN
        RAISE EXCEPTION
            'Una inscripcion % no puede cambiar de estado',
            v_estado_anterior;
    END IF;

    IF v_estado_anterior = 'HABILITADA'
       AND v_estado_nuevo NOT IN ('RETIRADA') THEN

        RAISE EXCEPTION
            'Una inscripcion habilitada solo puede retirarse';
    END IF;

    IF v_estado_nuevo = 'HABILITADA' THEN
        v_total_pagado :=
            finanzas.fn_total_pagado_inscripcion(
                NEW.id_inscripcion
            );

        IF v_total_pagado < NEW.monto_requerido THEN
            RAISE EXCEPTION
                'La inscripcion no tiene el pago completo';
        END IF;
    END IF;

    IF v_estado_nuevo = 'RETIRADA'
       AND v_estado_torneo IN (
            'EN_CURSO',
            'FINALIZADO'
       ) THEN

        RAISE EXCEPTION
            'No se puede retirar un equipo de un torneo %',
            v_estado_torneo;
    END IF;

    RETURN NEW;
END;
$$;


CREATE OR REPLACE FUNCTION competencia.fn_validar_jugador_inscripcion()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_torneo BIGINT;
    v_id_equipo BIGINT;
    v_estado_torneo VARCHAR(40);
    v_estado_inscripcion VARCHAR(40);
    v_minimo_jugadores SMALLINT;
    v_maximo_jugadores SMALLINT;
    v_estado_membresia VARCHAR(40);
    v_jugador_membresia BIGINT;
    v_equipo_membresia BIGINT;
    v_fecha_fin_membresia DATE;
    v_cantidad_jugadores INTEGER;
BEGIN
    IF TG_OP = 'UPDATE' THEN
        IF NEW.id_inscripcion <> OLD.id_inscripcion
           OR NEW.id_jugador <> OLD.id_jugador
           OR NEW.id_jugador_equipo <>
              OLD.id_jugador_equipo THEN

            RAISE EXCEPTION
                'No se puede cambiar la inscripcion, jugador o membresia';
        END IF;
    END IF;

    SELECT
        inscripcion.id_torneo,
        inscripcion.id_equipo,
        estado_inscripcion.codigo,
        estado_torneo.codigo,
        torneo.cantidad_minima_jugadores,
        torneo.cantidad_maxima_jugadores
    INTO
        v_id_torneo,
        v_id_equipo,
        v_estado_inscripcion,
        v_estado_torneo,
        v_minimo_jugadores,
        v_maximo_jugadores
    FROM competencia.inscripcion inscripcion
    INNER JOIN catalogo.estado_inscripcion estado_inscripcion
        ON estado_inscripcion.id_estado_inscripcion =
           inscripcion.id_estado_inscripcion
    INNER JOIN competencia.torneo torneo
        ON torneo.id_torneo = inscripcion.id_torneo
    INNER JOIN catalogo.estado_torneo estado_torneo
        ON estado_torneo.id_estado_torneo =
           torneo.id_estado_torneo
    WHERE inscripcion.id_inscripcion =
          NEW.id_inscripcion;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'La inscripcion seleccionada no existe';
    END IF;

    IF v_estado_inscripcion IN (
        'RECHAZADA',
        'RETIRADA'
    ) THEN
        RAISE EXCEPTION
            'No se pueden registrar jugadores en una inscripcion %',
            v_estado_inscripcion;
    END IF;

    IF v_estado_torneo IN (
        'PROGRAMADO',
        'EN_CURSO',
        'FINALIZADO',
        'CANCELADO'
    ) THEN
        RAISE EXCEPTION
            'La nomina no puede modificarse cuando el torneo esta %',
            v_estado_torneo;
    END IF;

    SELECT
        membresia.id_jugador,
        membresia.id_equipo,
        membresia.fecha_fin,
        estado.codigo
    INTO
        v_jugador_membresia,
        v_equipo_membresia,
        v_fecha_fin_membresia,
        v_estado_membresia
    FROM participantes.jugador_equipo membresia
    INNER JOIN catalogo.estado_membresia estado
        ON estado.id_estado_membresia =
           membresia.id_estado_membresia
    WHERE membresia.id_jugador_equipo =
          NEW.id_jugador_equipo;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'La membresia del jugador no existe';
    END IF;

    IF v_jugador_membresia <> NEW.id_jugador THEN
        RAISE EXCEPTION
            'La membresia no pertenece al jugador seleccionado';
    END IF;

    IF v_equipo_membresia <> v_id_equipo THEN
        RAISE EXCEPTION
            'El jugador no pertenece al equipo inscrito';
    END IF;

    IF v_fecha_fin_membresia IS NOT NULL
       OR v_estado_membresia <> 'ACTIVA' THEN

        RAISE EXCEPTION
            'La membresia del jugador no se encuentra activa';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM competencia.jugador_inscripcion jugador
        INNER JOIN competencia.inscripcion otra_inscripcion
            ON otra_inscripcion.id_inscripcion =
               jugador.id_inscripcion
        WHERE otra_inscripcion.id_torneo = v_id_torneo
          AND otra_inscripcion.id_equipo <> v_id_equipo
          AND jugador.id_jugador = NEW.id_jugador
          AND jugador.fecha_baja IS NULL
          AND jugador.id_jugador_inscripcion <>
              COALESCE(
                  NEW.id_jugador_inscripcion,
                  0
              )
    ) THEN
        RAISE EXCEPTION
            'El jugador ya pertenece a otro equipo del mismo torneo';
    END IF;

    IF TG_OP = 'INSERT' THEN
        SELECT COUNT(*)
        INTO v_cantidad_jugadores
        FROM competencia.jugador_inscripcion jugador
        WHERE jugador.id_inscripcion =
              NEW.id_inscripcion
          AND jugador.fecha_baja IS NULL;

        IF v_cantidad_jugadores >=
           v_maximo_jugadores THEN

            RAISE EXCEPTION
                'La nomina alcanzo el limite de % jugadores',
                v_maximo_jugadores;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;


CREATE OR REPLACE FUNCTION participantes.fn_validar_cambio_jugador_equipo()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_jugador BIGINT;
    v_id_equipo_actual BIGINT;
BEGIN
    IF TG_OP = 'DELETE' THEN
        v_id_jugador := OLD.id_jugador;
        v_id_equipo_actual := OLD.id_equipo;

        IF EXISTS (
            SELECT 1
            FROM competencia.jugador_inscripcion jugador
            INNER JOIN competencia.inscripcion inscripcion
                ON inscripcion.id_inscripcion =
                   jugador.id_inscripcion
            INNER JOIN competencia.torneo torneo
                ON torneo.id_torneo =
                   inscripcion.id_torneo
            INNER JOIN catalogo.estado_torneo estado
                ON estado.id_estado_torneo =
                   torneo.id_estado_torneo
            WHERE jugador.id_jugador =
                  v_id_jugador
              AND inscripcion.id_equipo =
                  v_id_equipo_actual
              AND jugador.fecha_baja IS NULL
              AND estado.codigo IN (
                  'INSCRIPCIONES_CERRADAS',
                  'PROGRAMADO',
                  'EN_CURSO'
              )
        ) THEN
            RAISE EXCEPTION
                'No se puede eliminar la membresia: el jugador participa en un torneo vigente';
        END IF;

        RETURN OLD;
    END IF;

    IF TG_OP = 'INSERT'
       AND NEW.fecha_fin IS NULL THEN

        IF EXISTS (
            SELECT 1
            FROM competencia.jugador_inscripcion jugador
            INNER JOIN competencia.inscripcion inscripcion
                ON inscripcion.id_inscripcion =
                   jugador.id_inscripcion
            INNER JOIN competencia.torneo torneo
                ON torneo.id_torneo =
                   inscripcion.id_torneo
            INNER JOIN catalogo.estado_torneo estado
                ON estado.id_estado_torneo =
                   torneo.id_estado_torneo
            WHERE jugador.id_jugador =
                  NEW.id_jugador
              AND inscripcion.id_equipo <>
                  NEW.id_equipo
              AND jugador.fecha_baja IS NULL
              AND estado.codigo IN (
                  'INSCRIPCIONES_CERRADAS',
                  'PROGRAMADO',
                  'EN_CURSO'
              )
        ) THEN
            RAISE EXCEPTION
                'El jugador no puede cambiar de equipo durante un torneo vigente';
        END IF;
    END IF;

    IF TG_OP = 'UPDATE' THEN
        IF (
            OLD.fecha_fin IS NULL
            AND NEW.fecha_fin IS NOT NULL
        )
        OR NEW.id_equipo <> OLD.id_equipo THEN

            IF EXISTS (
                SELECT 1
                FROM competencia.jugador_inscripcion jugador
                INNER JOIN competencia.inscripcion inscripcion
                    ON inscripcion.id_inscripcion =
                       jugador.id_inscripcion
                INNER JOIN competencia.torneo torneo
                    ON torneo.id_torneo =
                       inscripcion.id_torneo
                INNER JOIN catalogo.estado_torneo estado
                    ON estado.id_estado_torneo =
                       torneo.id_estado_torneo
                WHERE jugador.id_jugador =
                      OLD.id_jugador
                  AND inscripcion.id_equipo =
                      OLD.id_equipo
                  AND jugador.fecha_baja IS NULL
                  AND estado.codigo IN (
                      'INSCRIPCIONES_CERRADAS',
                      'PROGRAMADO',
                      'EN_CURSO'
                  )
            ) THEN
                RAISE EXCEPTION
                    'El jugador no puede abandonar el equipo durante un torneo vigente';
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;


CREATE OR REPLACE FUNCTION finanzas.fn_validar_pago()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_estado_pago_nuevo VARCHAR(40);
    v_estado_pago_anterior VARCHAR(40);
    v_estado_inscripcion VARCHAR(40);
    v_monto_requerido NUMERIC(12, 2);
    v_moneda CHAR(3);
    v_total_confirmado NUMERIC(12, 2);
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION
            'Los pagos no se eliminan; deben conservarse por auditoria';
    END IF;

    SELECT codigo
    INTO v_estado_pago_nuevo
    FROM catalogo.estado_pago
    WHERE id_estado_pago = NEW.id_estado_pago;

    SELECT
        estado.codigo,
        inscripcion.monto_requerido,
        inscripcion.moneda
    INTO
        v_estado_inscripcion,
        v_monto_requerido,
        v_moneda
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

    IF v_estado_inscripcion IN (
        'RECHAZADA',
        'RETIRADA'
    ) THEN
        RAISE EXCEPTION
            'No se pueden registrar pagos para una inscripcion %',
            v_estado_inscripcion;
    END IF;

    IF TG_OP = 'UPDATE' THEN
        SELECT codigo
        INTO v_estado_pago_anterior
        FROM catalogo.estado_pago
        WHERE id_estado_pago =
              OLD.id_estado_pago;

        IF v_estado_pago_anterior = 'CONFIRMADO' THEN
            RAISE EXCEPTION
                'Un pago confirmado no puede modificarse';
        END IF;

        IF NEW.id_inscripcion <>
           OLD.id_inscripcion THEN

            RAISE EXCEPTION
                'No se puede cambiar la inscripcion de un pago';
        END IF;

        IF NEW.monto <> OLD.monto
           OR NEW.moneda <> OLD.moneda THEN

            RAISE EXCEPTION
                'No se puede modificar el monto ni la moneda del pago';
        END IF;

        IF v_estado_pago_anterior IN (
            'RECHAZADO',
            'ANULADO'
        ) THEN
            RAISE EXCEPTION
                'Un pago % no puede cambiar de estado',
                v_estado_pago_anterior;
        END IF;
    END IF;

    NEW.moneda := v_moneda;
    NEW.fecha_actualizacion := CURRENT_TIMESTAMP;

    IF v_estado_pago_nuevo = 'CONFIRMADO' THEN
        IF NEW.verificado_por IS NULL THEN
            RAISE EXCEPTION
                'Un pago confirmado requiere un usuario verificador';
        END IF;

        IF NEW.fecha_verificacion IS NULL THEN
            NEW.fecha_verificacion :=
                CURRENT_TIMESTAMP;
        END IF;

        SELECT COALESCE(SUM(pago.monto), 0)
        INTO v_total_confirmado
        FROM finanzas.pago pago
        INNER JOIN catalogo.estado_pago estado
            ON estado.id_estado_pago =
               pago.id_estado_pago
        WHERE pago.id_inscripcion =
              NEW.id_inscripcion
          AND estado.codigo = 'CONFIRMADO'
          AND pago.id_pago <>
              COALESCE(NEW.id_pago, 0);

        IF v_total_confirmado + NEW.monto >
           v_monto_requerido THEN

            RAISE EXCEPTION
                'El pago excede el saldo pendiente de la inscripcion';
        END IF;
    ELSE
        NEW.verificado_por := NULL;
        NEW.fecha_verificacion := NULL;
    END IF;

    RETURN NEW;
END;
$$;


CREATE OR REPLACE FUNCTION finanzas.fn_actualizar_inscripcion_por_pago()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_total_pagado NUMERIC(12, 2);
    v_monto_requerido NUMERIC(12, 2);
    v_estado_actual VARCHAR(40);
    v_nuevo_estado VARCHAR(40);
    v_id_nuevo_estado SMALLINT;
BEGIN
    SELECT
        inscripcion.monto_requerido,
        estado.codigo
    INTO
        v_monto_requerido,
        v_estado_actual
    FROM competencia.inscripcion inscripcion
    INNER JOIN catalogo.estado_inscripcion estado
        ON estado.id_estado_inscripcion =
           inscripcion.id_estado_inscripcion
    WHERE inscripcion.id_inscripcion =
          NEW.id_inscripcion;

    IF v_estado_actual IN (
        'RECHAZADA',
        'RETIRADA'
    ) THEN
        RETURN NEW;
    END IF;

    v_total_pagado :=
        finanzas.fn_total_pagado_inscripcion(
            NEW.id_inscripcion
        );

    IF v_total_pagado >= v_monto_requerido THEN
        v_nuevo_estado := 'HABILITADA';
    ELSIF v_total_pagado > 0 THEN
        v_nuevo_estado := 'PAGO_PENDIENTE';
    ELSE
        v_nuevo_estado := 'PENDIENTE';
    END IF;

    IF v_estado_actual <> v_nuevo_estado THEN
        SELECT id_estado_inscripcion
        INTO v_id_nuevo_estado
        FROM catalogo.estado_inscripcion
        WHERE codigo = v_nuevo_estado;

        UPDATE competencia.inscripcion
        SET
            id_estado_inscripcion =
                v_id_nuevo_estado,
            fecha_actualizacion =
                CURRENT_TIMESTAMP
        WHERE id_inscripcion =
              NEW.id_inscripcion;
    END IF;

    RETURN NEW;
END;
$$;


CREATE OR REPLACE FUNCTION auditoria.fn_historial_inscripcion()
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
            NEW.registrado_por
        );

    IF TG_OP = 'INSERT' THEN
        INSERT INTO auditoria.historial_estado_inscripcion (
            id_inscripcion,
            id_estado_anterior,
            id_estado_nuevo,
            operacion,
            usuario_aplicacion,
            detalle
        )
        VALUES (
            NEW.id_inscripcion,
            NULL,
            NEW.id_estado_inscripcion,
            'INSERT',
            v_usuario_aplicacion,
            JSONB_BUILD_OBJECT(
                'monto_requerido',
                NEW.monto_requerido,
                'moneda',
                NEW.moneda
            )
        );

    ELSIF NEW.id_estado_inscripcion <>
          OLD.id_estado_inscripcion THEN

        INSERT INTO auditoria.historial_estado_inscripcion (
            id_inscripcion,
            id_estado_anterior,
            id_estado_nuevo,
            operacion,
            usuario_aplicacion,
            detalle
        )
        VALUES (
            NEW.id_inscripcion,
            OLD.id_estado_inscripcion,
            NEW.id_estado_inscripcion,
            'UPDATE',
            v_usuario_aplicacion,
            JSONB_BUILD_OBJECT(
                'fecha_actualizacion',
                NEW.fecha_actualizacion
            )
        );
    END IF;

    RETURN NEW;
END;
$$;


CREATE OR REPLACE FUNCTION auditoria.fn_historial_pago()
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
            NEW.verificado_por,
            NEW.registrado_por
        );

    IF TG_OP = 'INSERT' THEN
        INSERT INTO auditoria.historial_estado_pago (
            id_pago,
            id_estado_anterior,
            id_estado_nuevo,
            operacion,
            usuario_aplicacion,
            detalle
        )
        VALUES (
            NEW.id_pago,
            NULL,
            NEW.id_estado_pago,
            'INSERT',
            v_usuario_aplicacion,
            JSONB_BUILD_OBJECT(
                'monto',
                NEW.monto,
                'moneda',
                NEW.moneda,
                'referencia',
                NEW.referencia
            )
        );

    ELSIF NEW.id_estado_pago <>
          OLD.id_estado_pago THEN

        INSERT INTO auditoria.historial_estado_pago (
            id_pago,
            id_estado_anterior,
            id_estado_nuevo,
            operacion,
            usuario_aplicacion,
            detalle
        )
        VALUES (
            NEW.id_pago,
            OLD.id_estado_pago,
            NEW.id_estado_pago,
            'UPDATE',
            v_usuario_aplicacion,
            JSONB_BUILD_OBJECT(
                'fecha_verificacion',
                NEW.fecha_verificacion
            )
        );
    END IF;

    RETURN NEW;
END;
$$;

COMMIT;