BEGIN;

CREATE OR REPLACE PROCEDURE competencia.sp_registrar_inscripcion(
    IN p_id_torneo BIGINT,
    IN p_id_equipo BIGINT,
    IN p_registrado_por BIGINT,
    IN p_observaciones VARCHAR DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_estado SMALLINT;
BEGIN
    SELECT id_estado_inscripcion
    INTO v_id_estado
    FROM catalogo.estado_inscripcion
    WHERE codigo = 'PENDIENTE';

    INSERT INTO competencia.inscripcion (
        id_torneo,
        id_equipo,
        id_estado_inscripcion,
        monto_requerido,
        moneda,
        registrado_por,
        observaciones
    )
    VALUES (
        p_id_torneo,
        p_id_equipo,
        v_id_estado,
        0,
        'BOB',
        p_registrado_por,
        p_observaciones
    );
END;
$$;


CREATE OR REPLACE PROCEDURE competencia.sp_agregar_jugador_inscripcion(
    IN p_id_inscripcion BIGINT,
    IN p_id_jugador BIGINT,
    IN p_numero_camiseta SMALLINT,
    IN p_es_capitan BOOLEAN,
    IN p_es_delegado BOOLEAN,
    IN p_registrado_por BIGINT,
    IN p_observaciones VARCHAR DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_equipo BIGINT;
    v_id_jugador_equipo BIGINT;
    v_id_estado SMALLINT;
BEGIN
    SELECT id_equipo
    INTO v_id_equipo
    FROM competencia.inscripcion
    WHERE id_inscripcion =
          p_id_inscripcion;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'La inscripcion % no existe',
            p_id_inscripcion;
    END IF;

    SELECT membresia.id_jugador_equipo
    INTO v_id_jugador_equipo
    FROM participantes.jugador_equipo membresia
    INNER JOIN catalogo.estado_membresia estado
        ON estado.id_estado_membresia =
           membresia.id_estado_membresia
    WHERE membresia.id_jugador =
          p_id_jugador
      AND membresia.id_equipo =
          v_id_equipo
      AND membresia.fecha_fin IS NULL
      AND estado.codigo = 'ACTIVA';

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'El jugador no tiene una membresia activa con el equipo';
    END IF;

    SELECT id_estado_jugador_inscripcion
    INTO v_id_estado
    FROM catalogo.estado_jugador_inscripcion
    WHERE codigo = 'HABILITADO';

    INSERT INTO competencia.jugador_inscripcion (
        id_inscripcion,
        id_jugador,
        id_jugador_equipo,
        id_estado_jugador_inscripcion,
        numero_camiseta,
        es_capitan,
        es_delegado,
        registrado_por,
        observaciones
    )
    VALUES (
        p_id_inscripcion,
        p_id_jugador,
        v_id_jugador_equipo,
        v_id_estado,
        p_numero_camiseta,
        p_es_capitan,
        p_es_delegado,
        p_registrado_por,
        p_observaciones
    );
END;
$$;


CREATE OR REPLACE PROCEDURE finanzas.sp_registrar_pago(
    IN p_id_inscripcion BIGINT,
    IN p_metodo_pago VARCHAR,
    IN p_estado_pago VARCHAR,
    IN p_monto NUMERIC,
    IN p_referencia VARCHAR,
    IN p_registrado_por BIGINT,
    IN p_verificado_por BIGINT DEFAULT NULL,
    IN p_observaciones VARCHAR DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_metodo_pago SMALLINT;
    v_id_estado_pago SMALLINT;
    v_moneda CHAR(3);
BEGIN
    SELECT id_metodo_pago
    INTO v_id_metodo_pago
    FROM catalogo.metodo_pago
    WHERE codigo = UPPER(p_metodo_pago)
      AND activo = TRUE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'El metodo de pago % no existe',
            p_metodo_pago;
    END IF;

    SELECT id_estado_pago
    INTO v_id_estado_pago
    FROM catalogo.estado_pago
    WHERE codigo = UPPER(p_estado_pago)
      AND activo = TRUE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'El estado de pago % no existe',
            p_estado_pago;
    END IF;

    SELECT moneda
    INTO v_moneda
    FROM competencia.inscripcion
    WHERE id_inscripcion =
          p_id_inscripcion;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'La inscripcion % no existe',
            p_id_inscripcion;
    END IF;

    INSERT INTO finanzas.pago (
        id_inscripcion,
        id_metodo_pago,
        id_estado_pago,
        monto,
        moneda,
        referencia,
        registrado_por,
        verificado_por,
        fecha_verificacion,
        observaciones
    )
    VALUES (
        p_id_inscripcion,
        v_id_metodo_pago,
        v_id_estado_pago,
        p_monto,
        v_moneda,
        p_referencia,
        p_registrado_por,
        p_verificado_por,
        CASE
            WHEN UPPER(p_estado_pago) = 'CONFIRMADO'
                THEN CURRENT_TIMESTAMP
            ELSE NULL
        END,
        p_observaciones
    );
END;
$$;


CREATE OR REPLACE PROCEDURE finanzas.sp_confirmar_pago(
    IN p_id_pago BIGINT,
    IN p_verificado_por BIGINT,
    IN p_observaciones VARCHAR DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_estado_confirmado SMALLINT;
    v_estado_actual VARCHAR(40);
BEGIN
    SELECT estado.codigo
    INTO v_estado_actual
    FROM finanzas.pago pago
    INNER JOIN catalogo.estado_pago estado
        ON estado.id_estado_pago =
           pago.id_estado_pago
    WHERE pago.id_pago = p_id_pago;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'El pago % no existe',
            p_id_pago;
    END IF;

    IF v_estado_actual <> 'PENDIENTE' THEN
        RAISE EXCEPTION
            'Solo los pagos pendientes pueden confirmarse';
    END IF;

    SELECT id_estado_pago
    INTO v_id_estado_confirmado
    FROM catalogo.estado_pago
    WHERE codigo = 'CONFIRMADO';

    UPDATE finanzas.pago
    SET
        id_estado_pago =
            v_id_estado_confirmado,
        verificado_por =
            p_verificado_por,
        fecha_verificacion =
            CURRENT_TIMESTAMP,
        observaciones =
            COALESCE(
                p_observaciones,
                observaciones
            )
    WHERE id_pago = p_id_pago;
END;
$$;

COMMIT;