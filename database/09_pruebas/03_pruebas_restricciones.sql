\set ON_ERROR_STOP on
\pset pager off

BEGIN;

SELECT SET_CONFIG(
    'app.request_id',
    'PRUEBAS-RESTRICCIONES-001',
    TRUE
);

SELECT SET_CONFIG(
    'app.ip_cliente',
    '127.0.0.1',
    TRUE
);


DO $$
DECLARE
    v_id_admin BIGINT;
    v_id_arbitro BIGINT;
    v_id_jugador BIGINT;

    v_id_equipo_titanes BIGINT;
    v_id_equipo_halcones BIGINT;
    v_id_equipo_prueba_a BIGINT;
    v_id_equipo_prueba_b BIGINT;
    v_id_equipo_prueba_c BIGINT;

    v_id_deporte BIGINT;
    v_id_formato SMALLINT;

    v_id_estado_equipo SMALLINT;
    v_id_estado_membresia SMALLINT;
    v_id_estado_usuario SMALLINT;
    v_id_tipo_documento SMALLINT;

    v_id_estado_borrador SMALLINT;
    v_id_estado_inscripciones_abiertas SMALLINT;
    v_id_estado_inscripciones_cerradas SMALLINT;
    v_id_estado_programado SMALLINT;
    v_id_estado_en_curso SMALLINT;

    v_id_tipo_fase SMALLINT;
    v_id_estado_fase SMALLINT;
    v_id_estado_jornada SMALLINT;

    v_id_rol_arbitro SMALLINT;
    v_id_rol_jugador SMALLINT;
    v_id_rol_general_jugador SMALLINT;

    v_id_estado_perfil SMALLINT;

    v_id_torneo BIGINT;
    v_id_fase BIGINT;
    v_id_jornada BIGINT;

    v_id_lugar_uno BIGINT;
    v_id_lugar_dos BIGINT;

    v_id_inscripcion_titanes BIGINT;
    v_id_inscripcion_halcones BIGINT;
    v_id_inscripcion_prueba_a BIGINT;
    v_id_inscripcion_prueba_b BIGINT;

    v_id_partido_uno BIGINT;
    v_id_partido_dos BIGINT;

    v_id_jugador_inscripcion BIGINT;
    v_id_pago_confirmado BIGINT;

    v_error_detectado BOOLEAN;
BEGIN
    -- =====================================================
    -- IDENTIFICADORES BASE
    -- =====================================================

    SELECT id_usuario
    INTO STRICT v_id_admin
    FROM seguridad.usuario
    WHERE numero_documento = '7000001';


    SELECT id_usuario
    INTO STRICT v_id_arbitro
    FROM seguridad.usuario
    WHERE numero_documento = '7000003';


    SELECT id_usuario
    INTO STRICT v_id_jugador
    FROM seguridad.usuario
    WHERE numero_documento = '7100001';


    PERFORM SET_CONFIG(
        'app.usuario_id',
        v_id_admin::TEXT,
        TRUE
    );


    SELECT id_equipo
    INTO STRICT v_id_equipo_titanes
    FROM participantes.equipo
    WHERE nombre = 'Titanes Futsal';


    SELECT id_equipo
    INTO STRICT v_id_equipo_halcones
    FROM participantes.equipo
    WHERE nombre = 'Halcones Futsal';


    SELECT id_deporte
    INTO STRICT v_id_deporte
    FROM competencia.deporte
    WHERE codigo = 'FUTSAL';


    SELECT id_formato_torneo
    INTO STRICT v_id_formato
    FROM catalogo.formato_torneo
    WHERE codigo = 'ELIMINACION_DIRECTA';


    SELECT id_estado_equipo
    INTO STRICT v_id_estado_equipo
    FROM catalogo.estado_equipo
    WHERE codigo = 'ACTIVO';


    SELECT id_estado_membresia
    INTO STRICT v_id_estado_membresia
    FROM catalogo.estado_membresia
    WHERE codigo = 'ACTIVA';


    SELECT id_estado_usuario
    INTO STRICT v_id_estado_usuario
    FROM catalogo.estado_usuario
    WHERE codigo = 'ACTIVO';


    SELECT id_tipo_documento
    INTO STRICT v_id_tipo_documento
    FROM catalogo.tipo_documento
    WHERE codigo = 'CI';


    SELECT id_estado_torneo
    INTO STRICT v_id_estado_borrador
    FROM catalogo.estado_torneo
    WHERE codigo = 'BORRADOR';


    SELECT id_estado_torneo
    INTO STRICT v_id_estado_inscripciones_abiertas
    FROM catalogo.estado_torneo
    WHERE codigo = 'INSCRIPCIONES_ABIERTAS';


    SELECT id_estado_torneo
    INTO STRICT v_id_estado_inscripciones_cerradas
    FROM catalogo.estado_torneo
    WHERE codigo = 'INSCRIPCIONES_CERRADAS';


    SELECT id_estado_torneo
    INTO STRICT v_id_estado_programado
    FROM catalogo.estado_torneo
    WHERE codigo = 'PROGRAMADO';


    SELECT id_estado_torneo
    INTO STRICT v_id_estado_en_curso
    FROM catalogo.estado_torneo
    WHERE codigo = 'EN_CURSO';


    SELECT id_tipo_fase
    INTO STRICT v_id_tipo_fase
    FROM catalogo.tipo_fase
    WHERE codigo = 'ELIMINACION';


    SELECT id_estado_fase
    INTO STRICT v_id_estado_fase
    FROM catalogo.estado_fase
    WHERE codigo = 'PENDIENTE';


    SELECT id_estado_jornada
    INTO STRICT v_id_estado_jornada
    FROM catalogo.estado_jornada
    WHERE codigo = 'PROGRAMADA';


    SELECT id_rol_torneo
    INTO STRICT v_id_rol_arbitro
    FROM catalogo.rol_torneo
    WHERE codigo = 'ARBITRO';


    SELECT id_rol_torneo
    INTO STRICT v_id_rol_jugador
    FROM catalogo.rol_torneo
    WHERE codigo = 'JUGADOR';


    SELECT id_rol
    INTO STRICT v_id_rol_general_jugador
    FROM seguridad.rol
    WHERE codigo = 'JUGADOR';


    SELECT id_estado_perfil
    INTO STRICT v_id_estado_perfil
    FROM catalogo.estado_perfil_deportivo
    WHERE codigo = 'ACTIVO';


    -- =====================================================
    -- EQUIPOS TEMPORALES
    -- =====================================================

    INSERT INTO participantes.equipo (
        nombre,
        sigla,
        fecha_fundacion,
        descripcion,
        id_estado_equipo,
        creado_por
    )
    VALUES (
        'Equipo Restriccion A',
        'ERA',
        DATE '2024-01-01',
        'Equipo temporal para pruebas de restricciones',
        v_id_estado_equipo,
        v_id_admin
    )
    RETURNING id_equipo
    INTO v_id_equipo_prueba_a;


    INSERT INTO participantes.equipo (
        nombre,
        sigla,
        fecha_fundacion,
        descripcion,
        id_estado_equipo,
        creado_por
    )
    VALUES (
        'Equipo Restriccion B',
        'ERB',
        DATE '2024-01-01',
        'Equipo temporal para pruebas de restricciones',
        v_id_estado_equipo,
        v_id_admin
    )
    RETURNING id_equipo
    INTO v_id_equipo_prueba_b;


    INSERT INTO participantes.equipo (
        nombre,
        sigla,
        fecha_fundacion,
        descripcion,
        id_estado_equipo,
        creado_por
    )
    VALUES (
        'Equipo Restriccion C',
        'ERC',
        DATE '2024-01-01',
        'Equipo temporal para probar el limite de inscripciones',
        v_id_estado_equipo,
        v_id_admin
    )
    RETURNING id_equipo
    INTO v_id_equipo_prueba_c;


    -- =====================================================
    -- LUGARES TEMPORALES
    -- =====================================================

    INSERT INTO competencia.lugar (
        nombre,
        direccion,
        zona,
        ciudad,
        capacidad,
        tipo_superficie,
        activo
    )
    VALUES (
        'Cancha Restricciones Uno',
        'Avenida Pruebas 100',
        'Centro',
        'La Paz',
        500,
        'Parquet',
        TRUE
    )
    RETURNING id_lugar
    INTO v_id_lugar_uno;


    INSERT INTO competencia.lugar (
        nombre,
        direccion,
        zona,
        ciudad,
        capacidad,
        tipo_superficie,
        activo
    )
    VALUES (
        'Cancha Restricciones Dos',
        'Avenida Pruebas 200',
        'Centro',
        'La Paz',
        500,
        'Parquet',
        TRUE
    )
    RETURNING id_lugar
    INTO v_id_lugar_dos;


    -- =====================================================
    -- TORNEO TEMPORAL
    -- =====================================================

    INSERT INTO competencia.torneo (
        id_deporte,
        id_formato_torneo,
        id_estado_torneo,
        codigo,
        nombre,
        edicion,
        categoria,
        rama,
        fecha_inicio_inscripcion,
        fecha_fin_inscripcion,
        fecha_inicio_torneo,
        fecha_fin_torneo,
        cantidad_maxima_equipos,
        cantidad_minima_jugadores,
        cantidad_maxima_jugadores,
        costo_inscripcion,
        moneda,
        permite_empate,
        descripcion,
        creado_por
    )
    VALUES (
        v_id_deporte,
        v_id_formato,
        v_id_estado_borrador,
        'TEST-RESTRICCIONES-001',
        'Torneo temporal de restricciones',
        '2026',
        'Libre',
        'ABIERTO',
        DATE '2026-09-01',
        DATE '2026-09-10',
        DATE '2026-09-20',
        DATE '2026-09-21',
        4,
        5,
        7,
        200.00,
        'BOB',
        FALSE,
        'Este torneo sera eliminado mediante ROLLBACK',
        v_id_admin
    )
    RETURNING id_torneo
    INTO v_id_torneo;


    INSERT INTO competencia.fase_torneo (
        id_torneo,
        id_tipo_fase,
        id_estado_fase,
        nombre,
        numero_orden,
        cantidad_clasificados,
        fecha_inicio,
        fecha_fin,
        descripcion
    )
    VALUES (
        v_id_torneo,
        v_id_tipo_fase,
        v_id_estado_fase,
        'Semifinal temporal',
        1,
        2,
        DATE '2026-09-20',
        DATE '2026-09-20',
        'Fase temporal de pruebas'
    )
    RETURNING id_fase_torneo
    INTO v_id_fase;


    INSERT INTO competencia.jornada (
        id_fase_torneo,
        id_estado_jornada,
        numero_jornada,
        nombre,
        fecha_inicio,
        fecha_fin,
        observaciones
    )
    VALUES (
        v_id_fase,
        v_id_estado_jornada,
        1,
        'Jornada temporal',
        TIMESTAMPTZ '2026-09-20 14:00:00-04',
        TIMESTAMPTZ '2026-09-20 20:00:00-04',
        'Jornada utilizada para probar horarios'
    )
    RETURNING id_jornada
    INTO v_id_jornada;


    -- =====================================================
    -- PRUEBA 1: CORREO DUPLICADO SIN DISTINGUIR MAYUSCULAS
    -- =====================================================

    v_error_detectado := FALSE;

    BEGIN
        INSERT INTO seguridad.usuario (
            id_tipo_documento,
            numero_documento,
            nombres,
            apellido_paterno,
            fecha_nacimiento,
            sexo,
            correo,
            telefono,
            contrasenia_hash,
            id_estado_usuario
        )
        VALUES (
            v_id_tipo_documento,
            '7999991',
            'Usuario',
            'Duplicado',
            DATE '2000-01-01',
            'M',
            'ADMIN.DEMO@TORNEOS.TEST',
            '76500991',
            '$2b$12$123456789012345678901234567890123456789012345678901',
            v_id_estado_usuario
        );

    EXCEPTION
        WHEN UNIQUE_VIOLATION THEN
            v_error_detectado := TRUE;

            RAISE NOTICE
                'PRUEBA 1 OK: PostgreSQL rechazo el correo duplicado.';
    END;

    IF v_error_detectado = FALSE THEN
        RAISE EXCEPTION
            'PRUEBA 1 FALLO: se permitio un correo duplicado.';
    END IF;


    -- =====================================================
    -- PREPARAR PERFIL DOBLE DEL ARBITRO
    -- Solo existe durante esta transaccion.
    -- =====================================================

    INSERT INTO seguridad.usuario_rol (
        id_usuario,
        id_rol,
        asignado_por
    )
    SELECT
        v_id_arbitro,
        v_id_rol_general_jugador,
        v_id_admin
    WHERE NOT EXISTS (
        SELECT 1
        FROM seguridad.usuario_rol
        WHERE id_usuario = v_id_arbitro
          AND id_rol = v_id_rol_general_jugador
          AND activo = TRUE
          AND fecha_fin IS NULL
    );


    INSERT INTO participantes.jugador (
        id_usuario,
        alias_deportivo,
        id_estado_perfil,
        observaciones
    )
    VALUES (
        v_id_arbitro,
        'Arbitro jugador temporal',
        v_id_estado_perfil,
        'Perfil creado para probar conflictos de roles'
    )
    ON CONFLICT (id_usuario)
    DO NOTHING;


    INSERT INTO competencia.usuario_torneo_rol (
        id_torneo,
        id_usuario,
        id_rol_torneo,
        asignado_por
    )
    VALUES (
        v_id_torneo,
        v_id_arbitro,
        v_id_rol_arbitro,
        v_id_admin
    );


    -- =====================================================
    -- PRUEBA 2: ROLES INCOMPATIBLES EN EL MISMO TORNEO
    -- =====================================================

    v_error_detectado := FALSE;

    BEGIN
        INSERT INTO competencia.usuario_torneo_rol (
            id_torneo,
            id_usuario,
            id_rol_torneo,
            asignado_por
        )
        VALUES (
            v_id_torneo,
            v_id_arbitro,
            v_id_rol_jugador,
            v_id_admin
        );

    EXCEPTION
        WHEN OTHERS THEN
            v_error_detectado := TRUE;

            RAISE NOTICE
                'PRUEBA 2 OK: PostgreSQL rechazo roles incompatibles: %',
                SQLERRM;
    END;

    IF v_error_detectado = FALSE THEN
        RAISE EXCEPTION
            'PRUEBA 2 FALLO: se permitieron roles incompatibles.';
    END IF;


    -- =====================================================
    -- ABRIR INSCRIPCIONES
    -- =====================================================

    UPDATE competencia.torneo
    SET id_estado_torneo =
        v_id_estado_inscripciones_abiertas
    WHERE id_torneo =
          v_id_torneo;


    -- =====================================================
    -- REGISTRAR CUATRO EQUIPOS
    -- =====================================================

    CALL competencia.sp_registrar_inscripcion(
        v_id_torneo,
        v_id_equipo_titanes,
        v_id_admin,
        'Inscripcion temporal de Titanes'::VARCHAR
    );

    CALL competencia.sp_registrar_inscripcion(
        v_id_torneo,
        v_id_equipo_halcones,
        v_id_admin,
        'Inscripcion temporal de Halcones'::VARCHAR
    );

    CALL competencia.sp_registrar_inscripcion(
        v_id_torneo,
        v_id_equipo_prueba_a,
        v_id_admin,
        'Inscripcion temporal del equipo A'::VARCHAR
    );

    CALL competencia.sp_registrar_inscripcion(
        v_id_torneo,
        v_id_equipo_prueba_b,
        v_id_admin,
        'Inscripcion temporal del equipo B'::VARCHAR
    );


    SELECT id_inscripcion
    INTO STRICT v_id_inscripcion_titanes
    FROM competencia.inscripcion
    WHERE id_torneo = v_id_torneo
      AND id_equipo = v_id_equipo_titanes;


    SELECT id_inscripcion
    INTO STRICT v_id_inscripcion_halcones
    FROM competencia.inscripcion
    WHERE id_torneo = v_id_torneo
      AND id_equipo = v_id_equipo_halcones;


    SELECT id_inscripcion
    INTO STRICT v_id_inscripcion_prueba_a
    FROM competencia.inscripcion
    WHERE id_torneo = v_id_torneo
      AND id_equipo = v_id_equipo_prueba_a;


    SELECT id_inscripcion
    INTO STRICT v_id_inscripcion_prueba_b
    FROM competencia.inscripcion
    WHERE id_torneo = v_id_torneo
      AND id_equipo = v_id_equipo_prueba_b;


    -- =====================================================
    -- PRUEBA 3: LIMITE MAXIMO DE EQUIPOS
    -- =====================================================

    v_error_detectado := FALSE;

    BEGIN
        CALL competencia.sp_registrar_inscripcion(
            v_id_torneo,
            v_id_equipo_prueba_c,
            v_id_admin,
            'Esta inscripcion debe ser rechazada'::VARCHAR
        );

    EXCEPTION
        WHEN OTHERS THEN
            v_error_detectado := TRUE;

            RAISE NOTICE
                'PRUEBA 3 OK: PostgreSQL rechazo el quinto equipo: %',
                SQLERRM;
    END;

    IF v_error_detectado = FALSE THEN
        RAISE EXCEPTION
            'PRUEBA 3 FALLO: se supero el limite de equipos.';
    END IF;


    -- =====================================================
    -- MEMBRESIA ADICIONAL PARA PROBAR DOBLE NOMINA
    -- Se registra mientras las inscripciones estan abiertas.
    -- =====================================================

    INSERT INTO participantes.jugador_equipo (
        id_jugador,
        id_equipo,
        fecha_inicio,
        numero_camiseta,
        posicion,
        es_delegado,
        id_estado_membresia,
        registrado_por,
        observaciones
    )
    VALUES (
        v_id_jugador,
        v_id_equipo_prueba_a,
        DATE '2026-09-01',
        20,
        'Ala',
        FALSE,
        v_id_estado_membresia,
        v_id_admin,
        'Membresia temporal para probar doble nomina'
    );


    CALL competencia.sp_agregar_jugador_inscripcion(
        v_id_inscripcion_titanes,
        v_id_jugador,
        1::SMALLINT,
        TRUE,
        TRUE,
        v_id_admin,
        'Jugador registrado primero con Titanes'::VARCHAR
    );


    SELECT id_jugador_inscripcion
    INTO STRICT v_id_jugador_inscripcion
    FROM competencia.jugador_inscripcion
    WHERE id_inscripcion =
          v_id_inscripcion_titanes
      AND id_jugador =
          v_id_jugador;


    -- =====================================================
    -- PRUEBA 4: MISMO JUGADOR EN DOS EQUIPOS DEL TORNEO
    -- =====================================================

    v_error_detectado := FALSE;

    BEGIN
        CALL competencia.sp_agregar_jugador_inscripcion(
            v_id_inscripcion_prueba_a,
            v_id_jugador,
            20::SMALLINT,
            FALSE,
            FALSE,
            v_id_admin,
            'Esta doble inscripcion debe fallar'::VARCHAR
        );

    EXCEPTION
        WHEN OTHERS THEN
            v_error_detectado := TRUE;

            RAISE NOTICE
                'PRUEBA 4 OK: PostgreSQL rechazo la doble nomina: %',
                SQLERRM;
    END;

    IF v_error_detectado = FALSE THEN
        RAISE EXCEPTION
            'PRUEBA 4 FALLO: el jugador fue registrado en dos equipos.';
    END IF;


    -- =====================================================
    -- PAGAR LAS CUATRO INSCRIPCIONES
    -- =====================================================

    CALL finanzas.sp_registrar_pago(
        v_id_inscripcion_titanes,
        'QR'::VARCHAR,
        'CONFIRMADO'::VARCHAR,
        200.00::NUMERIC,
        'TEST-PAGO-TIT-001'::VARCHAR,
        v_id_admin,
        v_id_admin,
        'Pago completo temporal'::VARCHAR
    );

    CALL finanzas.sp_registrar_pago(
        v_id_inscripcion_halcones,
        'QR'::VARCHAR,
        'CONFIRMADO'::VARCHAR,
        200.00::NUMERIC,
        'TEST-PAGO-HAL-001'::VARCHAR,
        v_id_admin,
        v_id_admin,
        'Pago completo temporal'::VARCHAR
    );

    CALL finanzas.sp_registrar_pago(
        v_id_inscripcion_prueba_a,
        'TRANSFERENCIA'::VARCHAR,
        'CONFIRMADO'::VARCHAR,
        200.00::NUMERIC,
        'TEST-PAGO-ERA-001'::VARCHAR,
        v_id_admin,
        v_id_admin,
        'Pago completo temporal'::VARCHAR
    );

    CALL finanzas.sp_registrar_pago(
        v_id_inscripcion_prueba_b,
        'TRANSFERENCIA'::VARCHAR,
        'CONFIRMADO'::VARCHAR,
        200.00::NUMERIC,
        'TEST-PAGO-ERB-001'::VARCHAR,
        v_id_admin,
        v_id_admin,
        'Pago completo temporal'::VARCHAR
    );


    SELECT pago.id_pago
    INTO STRICT v_id_pago_confirmado
    FROM finanzas.pago pago
    WHERE pago.referencia =
          'TEST-PAGO-TIT-001';


    -- =====================================================
    -- PRUEBA 5: PAGO SUPERIOR AL SALDO
    -- =====================================================

    v_error_detectado := FALSE;

    BEGIN
        CALL finanzas.sp_registrar_pago(
            v_id_inscripcion_titanes,
            'EFECTIVO'::VARCHAR,
            'CONFIRMADO'::VARCHAR,
            1.00::NUMERIC,
            'TEST-PAGO-EXCESO-001'::VARCHAR,
            v_id_admin,
            v_id_admin,
            'Este pago debe exceder el saldo'::VARCHAR
        );

    EXCEPTION
        WHEN OTHERS THEN
            v_error_detectado := TRUE;

            RAISE NOTICE
                'PRUEBA 5 OK: PostgreSQL rechazo el pago excedente: %',
                SQLERRM;
    END;

    IF v_error_detectado = FALSE THEN
        RAISE EXCEPTION
            'PRUEBA 5 FALLO: se permitio un pago superior al saldo.';
    END IF;


    -- =====================================================
    -- PRUEBA 6: PAGO CONFIRMADO INMUTABLE
    -- =====================================================

    v_error_detectado := FALSE;

    BEGIN
        UPDATE finanzas.pago
        SET observaciones =
            'Modificacion que debe ser rechazada'
        WHERE id_pago =
              v_id_pago_confirmado;

    EXCEPTION
        WHEN OTHERS THEN
            v_error_detectado := TRUE;

            RAISE NOTICE
                'PRUEBA 6 OK: PostgreSQL protegio el pago confirmado: %',
                SQLERRM;
    END;

    IF v_error_detectado = FALSE THEN
        RAISE EXCEPTION
            'PRUEBA 6 FALLO: se modifico un pago confirmado.';
    END IF;


    -- =====================================================
    -- PRUEBA 7: LOS PAGOS NO PUEDEN ELIMINARSE
    -- =====================================================

    v_error_detectado := FALSE;

    BEGIN
        DELETE FROM finanzas.pago
        WHERE id_pago =
              v_id_pago_confirmado;

    EXCEPTION
        WHEN OTHERS THEN
            v_error_detectado := TRUE;

            RAISE NOTICE
                'PRUEBA 7 OK: PostgreSQL impidio eliminar el pago: %',
                SQLERRM;
    END;

    IF v_error_detectado = FALSE THEN
        RAISE EXCEPTION
            'PRUEBA 7 FALLO: se elimino un pago.';
    END IF;


    -- =====================================================
    -- CERRAR INSCRIPCIONES
    -- =====================================================

    UPDATE competencia.torneo
    SET id_estado_torneo =
        v_id_estado_inscripciones_cerradas
    WHERE id_torneo =
          v_id_torneo;


    -- =====================================================
    -- PRUEBA 8: CAMBIO DE EQUIPO DURANTE TORNEO VIGENTE
    -- =====================================================

    v_error_detectado := FALSE;

    BEGIN
        INSERT INTO participantes.jugador_equipo (
            id_jugador,
            id_equipo,
            fecha_inicio,
            numero_camiseta,
            posicion,
            es_delegado,
            id_estado_membresia,
            registrado_por,
            observaciones
        )
        VALUES (
            v_id_jugador,
            v_id_equipo_prueba_b,
            DATE '2026-09-15',
            25,
            'Pivot',
            FALSE,
            v_id_estado_membresia,
            v_id_admin,
            'Esta nueva membresia debe ser rechazada'
        );

    EXCEPTION
        WHEN OTHERS THEN
            v_error_detectado := TRUE;

            RAISE NOTICE
                'PRUEBA 8 OK: PostgreSQL bloqueo el cambio de equipo: %',
                SQLERRM;
    END;

    IF v_error_detectado = FALSE THEN
        RAISE EXCEPTION
            'PRUEBA 8 FALLO: se permitio cambiar de equipo.';
    END IF;


    -- =====================================================
    -- PRUEBA 9: TRANSICION DE ESTADO INVALIDA
    -- INSCRIPCIONES_CERRADAS -> BORRADOR
    -- =====================================================

    v_error_detectado := FALSE;

    BEGIN
        UPDATE competencia.torneo
        SET id_estado_torneo =
            v_id_estado_borrador
        WHERE id_torneo =
              v_id_torneo;

    EXCEPTION
        WHEN OTHERS THEN
            v_error_detectado := TRUE;

            RAISE NOTICE
                'PRUEBA 9 OK: PostgreSQL rechazo la transicion invalida: %',
                SQLERRM;
    END;

    IF v_error_detectado = FALSE THEN
        RAISE EXCEPTION
            'PRUEBA 9 FALLO: se permitio una transicion invalida.';
    END IF;


    -- =====================================================
    -- PROGRAMAR PRIMER PARTIDO
    -- =====================================================

    CALL competencia.sp_programar_partido(
        v_id_jornada,
        v_id_lugar_uno,
        'TEST-PARTIDO-001'::VARCHAR,
        1::SMALLINT,
        TIMESTAMPTZ '2026-09-20 15:00:00-04',
        TIMESTAMPTZ '2026-09-20 16:30:00-04',
        v_id_inscripcion_titanes,
        v_id_inscripcion_halcones,
        v_id_admin,
        NULL::BIGINT,
        'Semifinal uno'::VARCHAR,
        'Partido temporal para pruebas'::VARCHAR
    );


    SELECT id_partido
    INTO STRICT v_id_partido_uno
    FROM competencia.partido
    WHERE codigo = 'TEST-PARTIDO-001';


    -- =====================================================
    -- PRUEBA 10: DOS PARTIDOS EN EL MISMO LUGAR Y HORARIO
    -- =====================================================

    v_error_detectado := FALSE;

    BEGIN
        CALL competencia.sp_programar_partido(
            v_id_jornada,
            v_id_lugar_uno,
            'TEST-PARTIDO-002'::VARCHAR,
            2::SMALLINT,
            TIMESTAMPTZ '2026-09-20 15:30:00-04',
            TIMESTAMPTZ '2026-09-20 17:00:00-04',
            v_id_inscripcion_prueba_a,
            v_id_inscripcion_prueba_b,
            v_id_admin,
            NULL::BIGINT,
            'Semifinal dos'::VARCHAR,
            'Debe fallar por superposicion del lugar'::VARCHAR
        );

    EXCEPTION
        WHEN OTHERS THEN
            v_error_detectado := TRUE;

            RAISE NOTICE
                'PRUEBA 10 OK: PostgreSQL detecto la superposicion del lugar: %',
                SQLERRM;
    END;

    IF v_error_detectado = FALSE THEN
        RAISE EXCEPTION
            'PRUEBA 10 FALLO: se permitio usar el mismo lugar.';
    END IF;


    -- =====================================================
    -- PROGRAMAR SEGUNDO PARTIDO EN OTRO LUGAR
    -- =====================================================

    CALL competencia.sp_programar_partido(
        v_id_jornada,
        v_id_lugar_dos,
        'TEST-PARTIDO-002'::VARCHAR,
        2::SMALLINT,
        TIMESTAMPTZ '2026-09-20 15:30:00-04',
        TIMESTAMPTZ '2026-09-20 17:00:00-04',
        v_id_inscripcion_prueba_a,
        v_id_inscripcion_prueba_b,
        v_id_admin,
        NULL::BIGINT,
        'Semifinal dos'::VARCHAR,
        'Partido temporal en una cancha diferente'::VARCHAR
    );


    SELECT id_partido
    INTO STRICT v_id_partido_dos
    FROM competencia.partido
    WHERE codigo = 'TEST-PARTIDO-002';


    -- =====================================================
    -- PASAR TORNEO A PROGRAMADO Y EN CURSO
    -- =====================================================

    UPDATE competencia.torneo
    SET id_estado_torneo =
        v_id_estado_programado
    WHERE id_torneo =
          v_id_torneo;


    UPDATE competencia.torneo
    SET id_estado_torneo =
        v_id_estado_en_curso
    WHERE id_torneo =
          v_id_torneo;


    -- =====================================================
    -- PRUEBA 11: INICIAR PARTIDO SIN ARBITRO PRINCIPAL
    -- =====================================================

    v_error_detectado := FALSE;

    BEGIN
        CALL competencia.sp_iniciar_partido(
            v_id_partido_uno,
            v_id_admin
        );

    EXCEPTION
        WHEN OTHERS THEN
            v_error_detectado := TRUE;

            RAISE NOTICE
                'PRUEBA 11 OK: PostgreSQL exigio arbitro principal: %',
                SQLERRM;
    END;

    IF v_error_detectado = FALSE THEN
        RAISE EXCEPTION
            'PRUEBA 11 FALLO: el partido inicio sin arbitro.';
    END IF;


    -- =====================================================
    -- ASIGNAR ARBITRO AL PRIMER PARTIDO
    -- =====================================================

    CALL competencia.sp_asignar_arbitro_partido(
        v_id_partido_uno,
        v_id_arbitro,
        'PRINCIPAL'::VARCHAR,
        v_id_admin,
        'Arbitro del primer partido temporal'::VARCHAR
    );


    -- =====================================================
    -- PRUEBA 12: ARBITRO EN DOS PARTIDOS SUPERPUESTOS
    -- =====================================================

    v_error_detectado := FALSE;

    BEGIN
        CALL competencia.sp_asignar_arbitro_partido(
            v_id_partido_dos,
            v_id_arbitro,
            'PRINCIPAL'::VARCHAR,
            v_id_admin,
            'Esta asignacion debe fallar por horario'::VARCHAR
        );

    EXCEPTION
        WHEN OTHERS THEN
            v_error_detectado := TRUE;

            RAISE NOTICE
                'PRUEBA 12 OK: PostgreSQL detecto la superposicion del arbitro: %',
                SQLERRM;
    END;

    IF v_error_detectado = FALSE THEN
        RAISE EXCEPTION
            'PRUEBA 12 FALLO: el arbitro fue asignado dos veces.';
    END IF;


    -- =====================================================
    -- INICIAR CORRECTAMENTE EL PRIMER PARTIDO
    -- =====================================================

    CALL competencia.sp_iniciar_partido(
        v_id_partido_uno,
        v_id_admin
    );


    -- =====================================================
    -- PRUEBA 13: TITULAR SIN ASISTENCIA
    -- =====================================================

    v_error_detectado := FALSE;

    BEGIN
        CALL competencia.sp_registrar_participacion_jugador(
            v_id_partido_uno,
            v_id_jugador_inscripcion,
            TRUE,
            FALSE,
            TRUE,
            0::SMALLINT,
            0::INTEGER,
            0::SMALLINT,
            0::SMALLINT,
            FALSE,
            FALSE,
            NULL::NUMERIC,
            '{}'::JSONB,
            v_id_admin,
            'Titular sin asistencia; debe ser rechazado'::VARCHAR
        );

    EXCEPTION
        WHEN OTHERS THEN
            v_error_detectado := TRUE;

            RAISE NOTICE
                'PRUEBA 13 OK: PostgreSQL rechazo titular sin asistencia: %',
                SQLERRM;
    END;

    IF v_error_detectado = FALSE THEN
        RAISE EXCEPTION
            'PRUEBA 13 FALLO: se permitio un titular ausente.';
    END IF;


    RAISE NOTICE
        '=========================================================';

    RAISE NOTICE
        'TODAS LAS PRUEBAS DE RESTRICCIONES FUERON SUPERADAS.';

    RAISE NOTICE
        'Los datos temporales se revertiran con ROLLBACK.';

    RAISE NOTICE
        '=========================================================';
END;
$$;


\echo ''
\echo '========================================================='
\echo 'DATOS TEMPORALES ANTES DEL ROLLBACK'
\echo '========================================================='

SELECT
    COUNT(*) AS torneos_temporales
FROM competencia.torneo
WHERE codigo = 'TEST-RESTRICCIONES-001';


SELECT
    COUNT(*) AS partidos_temporales
FROM competencia.partido
WHERE codigo IN (
    'TEST-PARTIDO-001',
    'TEST-PARTIDO-002'
);


SELECT
    COUNT(*) AS auditorias_temporales
FROM auditoria.auditoria_dml
WHERE id_solicitud =
      'PRUEBAS-RESTRICCIONES-001';


ROLLBACK;


\echo ''
\echo '========================================================='
\echo 'COMPROBACION DESPUES DEL ROLLBACK'
\echo '========================================================='

SELECT
    COUNT(*) AS torneos_temporales_restantes
FROM competencia.torneo
WHERE codigo = 'TEST-RESTRICCIONES-001';


SELECT
    COUNT(*) AS equipos_temporales_restantes
FROM participantes.equipo
WHERE nombre IN (
    'Equipo Restriccion A',
    'Equipo Restriccion B',
    'Equipo Restriccion C'
);


SELECT
    COUNT(*) AS lugares_temporales_restantes
FROM competencia.lugar
WHERE nombre IN (
    'Cancha Restricciones Uno',
    'Cancha Restricciones Dos'
);


SELECT
    COUNT(*) AS auditorias_temporales_restantes
FROM auditoria.auditoria_dml
WHERE id_solicitud =
      'PRUEBAS-RESTRICCIONES-001';