\set
ON_ERROR_STOP on

BEGIN;

SELECT SET_CONFIG(
               'app.request_id',
               'FLUJO-DEMO-FUTSAL-2026-001',
               TRUE
       );

SELECT SET_CONFIG(
               'app.ip_cliente',
               '127.0.0.1',
               TRUE
       );


DO
$$
DECLARE
v_id_admin BIGINT;
    v_id_organizador
BIGINT;
    v_id_arbitro
BIGINT;

    v_id_equipo_titanes
BIGINT;
    v_id_equipo_halcones
BIGINT;

    v_id_deporte
BIGINT;
    v_id_formato
SMALLINT;

    v_id_estado_borrador
SMALLINT;
    v_id_estado_inscripciones_abiertas
SMALLINT;
    v_id_estado_inscripciones_cerradas
SMALLINT;
    v_id_estado_programado
SMALLINT;
    v_id_estado_en_curso
SMALLINT;

    v_id_tipo_fase
SMALLINT;
    v_id_estado_fase_pendiente
SMALLINT;
    v_id_estado_fase_en_curso
SMALLINT;

    v_id_estado_jornada_programada
SMALLINT;
    v_id_estado_jornada_en_curso
SMALLINT;
    v_id_estado_jornada_finalizada
SMALLINT;

    v_id_rol_jugador
SMALLINT;
    v_id_rol_arbitro
SMALLINT;
    v_id_rol_organizador
SMALLINT;

    v_id_lugar
BIGINT;
    v_id_premio
BIGINT;

    v_id_torneo
BIGINT;
    v_id_fase
BIGINT;
    v_id_jornada
BIGINT;

    v_id_inscripcion_titanes
BIGINT;
    v_id_inscripcion_halcones
BIGINT;

    v_id_partido
BIGINT;
    v_id_entrega_premio
BIGINT;

    v_fila
RECORD;

    v_puntos_anotados
INTEGER;
    v_asistencias
INTEGER;
BEGIN
    -- =====================================================
    -- IDENTIFICADORES BASE
    -- =====================================================

SELECT id_usuario
INTO STRICT v_id_admin
FROM seguridad.usuario
WHERE numero_documento = '7000001';

SELECT id_usuario
INTO STRICT v_id_organizador
FROM seguridad.usuario
WHERE numero_documento = '7000002';

SELECT id_usuario
INTO STRICT v_id_arbitro
FROM seguridad.usuario
WHERE numero_documento = '7000003';


PERFORM
SET_CONFIG(
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
WHERE codigo = 'PARTIDO_UNICO';


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
WHERE codigo = 'PARTIDO_UNICO';

SELECT id_estado_fase
INTO STRICT v_id_estado_fase_pendiente
FROM catalogo.estado_fase
WHERE codigo = 'PENDIENTE';

SELECT id_estado_fase
INTO STRICT v_id_estado_fase_en_curso
FROM catalogo.estado_fase
WHERE codigo = 'EN_CURSO';


SELECT id_estado_jornada
INTO STRICT v_id_estado_jornada_programada
FROM catalogo.estado_jornada
WHERE codigo = 'PROGRAMADA';

SELECT id_estado_jornada
INTO STRICT v_id_estado_jornada_en_curso
FROM catalogo.estado_jornada
WHERE codigo = 'EN_CURSO';

SELECT id_estado_jornada
INTO STRICT v_id_estado_jornada_finalizada
FROM catalogo.estado_jornada
WHERE codigo = 'FINALIZADA';


SELECT id_rol_torneo
INTO STRICT v_id_rol_jugador
FROM catalogo.rol_torneo
WHERE codigo = 'JUGADOR';

SELECT id_rol_torneo
INTO STRICT v_id_rol_arbitro
FROM catalogo.rol_torneo
WHERE codigo = 'ARBITRO';

SELECT id_rol_torneo
INTO STRICT v_id_rol_organizador
FROM catalogo.rol_torneo
WHERE codigo = 'ORGANIZADOR';


SELECT id_lugar
INTO STRICT v_id_lugar
FROM competencia.lugar
WHERE nombre = 'Coliseo Demo Central';

SELECT id_premio
INTO STRICT v_id_premio
FROM finanzas.premio
WHERE codigo = 'PREMIO_CAMPEON_DEMO';


IF
EXISTS (
        SELECT 1
        FROM competencia.torneo
        WHERE codigo = 'FTS-DEMO-2026-01'
    ) THEN
        RAISE EXCEPTION
            'El flujo demo ya fue ejecutado. El torneo FTS-DEMO-2026-01 ya existe.';
END IF;


    -- =====================================================
    -- CREAR TORNEO
    -- =====================================================

INSERT INTO competencia.torneo (id_deporte,
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
                                creado_por)
VALUES (v_id_deporte,
        v_id_formato,
        v_id_estado_borrador,
        'FTS-DEMO-2026-01',
        'Copa Demo de Futsal 2026',
        '2026',
        'Libre',
        'MASCULINO',
        DATE '2026-08-01',
        DATE '2026-08-10',
        DATE '2026-08-20',
        DATE '2026-08-20',
        2,
        5,
        7,
        200.00,
        'BOB',
        FALSE,
        'Torneo de demostracion para probar el flujo completo',
        v_id_admin) RETURNING id_torneo
INTO v_id_torneo;


-- =====================================================
-- FASE Y JORNADA
-- =====================================================

INSERT INTO competencia.fase_torneo (id_torneo,
                                     id_tipo_fase,
                                     id_estado_fase,
                                     nombre,
                                     numero_orden,
                                     cantidad_clasificados,
                                     fecha_inicio,
                                     fecha_fin,
                                     descripcion)
VALUES (v_id_torneo,
        v_id_tipo_fase,
        v_id_estado_fase_pendiente,
        'Final unica',
        1,
        1,
        DATE '2026-08-20',
        DATE '2026-08-20',
        'Fase compuesta por un solo partido') RETURNING id_fase_torneo
INTO v_id_fase;


INSERT INTO competencia.jornada (id_fase_torneo,
                                 id_estado_jornada,
                                 numero_jornada,
                                 nombre,
                                 fecha_inicio,
                                 fecha_fin,
                                 observaciones)
VALUES (v_id_fase,
        v_id_estado_jornada_programada,
        1,
        'Jornada final',
        TIMESTAMPTZ '2026-08-20 14:00:00-04',
        TIMESTAMPTZ '2026-08-20 18:00:00-04',
        'Jornada del partido unico') RETURNING id_jornada
INTO v_id_jornada;


-- =====================================================
-- CONFIGURAR PREMIO ANTES DE FINALIZAR EL TORNEO
-- =====================================================

CALL finanzas.sp_configurar_premio_torneo(
    v_id_torneo,
    v_id_premio,
    1::SMALLINT,
    1000.00::NUMERIC,
    'BOB'::CHAR(3),
    v_id_admin,
    'Premio economico para el campeon'::VARCHAR
);


-- =====================================================
-- ROLES DENTRO DEL TORNEO
-- =====================================================

INSERT INTO competencia.usuario_torneo_rol (id_torneo,
                                            id_usuario,
                                            id_rol_torneo,
                                            asignado_por)
VALUES (v_id_torneo,
        v_id_organizador,
        v_id_rol_organizador,
        v_id_admin),
       (v_id_torneo,
        v_id_arbitro,
        v_id_rol_arbitro,
        v_id_admin);


INSERT INTO competencia.usuario_torneo_rol (id_torneo,
                                            id_usuario,
                                            id_rol_torneo,
                                            asignado_por)
SELECT v_id_torneo,
       usuario.id_usuario,
       v_id_rol_jugador,
       v_id_admin

FROM seguridad.usuario usuario

WHERE usuario.numero_documento IN (
                                   '7100001',
                                   '7100002',
                                   '7100003',
                                   '7100004',
                                   '7100005',
                                   '7200001',
                                   '7200002',
                                   '7200003',
                                   '7200004',
                                   '7200005'
    );


-- =====================================================
-- ABRIR INSCRIPCIONES
-- =====================================================

UPDATE competencia.torneo
SET id_estado_torneo    =
        v_id_estado_inscripciones_abiertas,
    fecha_actualizacion =
        CURRENT_TIMESTAMP
WHERE id_torneo =
      v_id_torneo;


-- =====================================================
-- INSCRIBIR EQUIPOS
-- =====================================================

CALL competencia.sp_registrar_inscripcion(
        v_id_torneo,
        v_id_equipo_titanes,
        v_id_admin,
        'Inscripcion de Titanes Futsal'
    );

CALL competencia.sp_registrar_inscripcion(
        v_id_torneo,
        v_id_equipo_halcones,
        v_id_admin,
        'Inscripcion de Halcones Futsal'
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


-- =====================================================
-- NOMINA DE TITANES
-- =====================================================

FOR v_fila IN
SELECT usuario.id_usuario,
       membresia.numero_camiseta,
       membresia.es_delegado

FROM participantes.jugador_equipo membresia

         INNER JOIN seguridad.usuario usuario
                    ON usuario.id_usuario =
                       membresia.id_jugador

WHERE membresia.id_equipo =
      v_id_equipo_titanes
  AND membresia.fecha_fin IS NULL

ORDER BY usuario.numero_documento LOOP
        CALL competencia.sp_agregar_jugador_inscripcion(
            v_id_inscripcion_titanes,
            v_fila.id_usuario,
            v_fila.numero_camiseta,
            v_fila.es_delegado,
            v_fila.es_delegado,
            v_id_admin,
            'Jugador titular de Titanes'
        );
END LOOP;


    -- =====================================================
    -- NOMINA DE HALCONES
    -- =====================================================

FOR v_fila IN
SELECT usuario.id_usuario,
       membresia.numero_camiseta,
       membresia.es_delegado

FROM participantes.jugador_equipo membresia

         INNER JOIN seguridad.usuario usuario
                    ON usuario.id_usuario =
                       membresia.id_jugador

WHERE membresia.id_equipo =
      v_id_equipo_halcones
  AND membresia.fecha_fin IS NULL

ORDER BY usuario.numero_documento LOOP
        CALL competencia.sp_agregar_jugador_inscripcion(
            v_id_inscripcion_halcones,
            v_fila.id_usuario,
            v_fila.numero_camiseta,
            v_fila.es_delegado,
            v_fila.es_delegado,
            v_id_admin,
            'Jugador titular de Halcones'
        );
END LOOP;


    -- =====================================================
    -- PAGOS
    -- Titanes paga en dos partes.
    -- Halcones paga en una sola parte.
    -- =====================================================

CALL finanzas.sp_registrar_pago(
        v_id_inscripcion_titanes,
        'QR',
        'CONFIRMADO',
        100.00,
        'DEMO-TIT-001',
        v_id_admin,
        v_id_admin,
        'Primer pago parcial de Titanes'
    );

CALL finanzas.sp_registrar_pago(
        v_id_inscripcion_titanes,
        'TRANSFERENCIA',
        'CONFIRMADO',
        100.00,
        'DEMO-TIT-002',
        v_id_admin,
        v_id_admin,
        'Segundo pago de Titanes'
    );

CALL finanzas.sp_registrar_pago(
        v_id_inscripcion_halcones,
        'DEPOSITO',
        'CONFIRMADO',
        200.00,
        'DEMO-HAL-001',
        v_id_admin,
        v_id_admin,
        'Pago completo de Halcones'
    );


IF
EXISTS (
        SELECT 1
        FROM competencia.inscripcion inscripcion

        INNER JOIN catalogo.estado_inscripcion estado
            ON estado.id_estado_inscripcion =
               inscripcion.id_estado_inscripcion

        WHERE inscripcion.id_torneo =
              v_id_torneo
          AND estado.codigo <>
              'HABILITADA'
    ) THEN
        RAISE EXCEPTION
            'Las dos inscripciones deben estar habilitadas';
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
-- PROGRAMAR PARTIDO
-- =====================================================

CALL competencia.sp_programar_partido(
    v_id_jornada,
    v_id_lugar,
    'FTS-DEMO-P001'::VARCHAR,
    1::SMALLINT,
    TIMESTAMPTZ '2026-08-20 15:00:00-04',
    TIMESTAMPTZ '2026-08-20 16:30:00-04',
    v_id_inscripcion_titanes,
    v_id_inscripcion_halcones,
    v_id_admin,
    NULL::BIGINT,
    'Final'::VARCHAR,
    'Partido unico de la Copa Demo'::VARCHAR
);


SELECT id_partido
INTO STRICT v_id_partido
FROM competencia.partido
WHERE codigo = 'FTS-DEMO-P001';


-- =====================================================
-- ASIGNAR ARBITRO
-- =====================================================

CALL competencia.sp_asignar_arbitro_partido(
        v_id_partido,
        v_id_arbitro,
        'PRINCIPAL',
        v_id_admin,
        'Arbitro principal del partido demo'
    );


-- =====================================================
-- PROGRAMAR E INICIAR TORNEO
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


UPDATE competencia.fase_torneo
SET id_estado_fase =
        v_id_estado_fase_en_curso
WHERE id_fase_torneo =
      v_id_fase;


UPDATE competencia.jornada
SET id_estado_jornada =
        v_id_estado_jornada_en_curso
WHERE id_jornada =
      v_id_jornada;


CALL competencia.sp_iniciar_partido(
        v_id_partido,
        v_id_admin
    );


-- =====================================================
-- ASISTENCIA Y ESTADISTICAS
-- Marcador esperado:
-- Titanes 4 - 3 Halcones
-- =====================================================

FOR v_fila IN
SELECT jugador_nomina.id_jugador_inscripcion,
       equipo.nombre AS equipo,

       ROW_NUMBER()     OVER (
                PARTITION BY equipo.id_equipo
                ORDER BY usuario.numero_documento
            ) AS numero_orden

FROM competencia.jugador_inscripcion jugador_nomina

         INNER JOIN competencia.inscripcion inscripcion
                    ON inscripcion.id_inscripcion =
                       jugador_nomina.id_inscripcion

         INNER JOIN participantes.equipo equipo
                    ON equipo.id_equipo =
                       inscripcion.id_equipo

         INNER JOIN seguridad.usuario usuario
                    ON usuario.id_usuario =
                       jugador_nomina.id_jugador

WHERE inscripcion.id_torneo =
      v_id_torneo
  AND jugador_nomina.fecha_baja IS NULL

ORDER BY equipo.nombre,
         usuario.numero_documento LOOP
        v_puntos_anotados :=
            CASE
                WHEN v_fila.equipo = 'Titanes Futsal'
                     AND v_fila.numero_orden = 1
                    THEN 2

                WHEN v_fila.equipo = 'Titanes Futsal'
                     AND v_fila.numero_orden IN (2, 3)
                    THEN 1

                WHEN v_fila.equipo = 'Halcones Futsal'
                     AND v_fila.numero_orden = 1
                    THEN 2

                WHEN v_fila.equipo = 'Halcones Futsal'
                     AND v_fila.numero_orden = 2
                    THEN 1

                ELSE 0
END;


        v_asistencias
:=
            CASE
                WHEN v_fila.numero_orden IN (1, 2)
                    THEN 1
                ELSE 0
END;


CALL competencia.sp_registrar_participacion_jugador(
    v_id_partido,
    v_fila.id_jugador_inscripcion,
    TRUE,
    TRUE,
    TRUE,
    40::SMALLINT,
    v_puntos_anotados,
    (
        CASE
            WHEN v_fila.numero_orden = 4
                THEN 1
            ELSE 0
        END
    )::SMALLINT,
    0::SMALLINT,
    FALSE,
    FALSE,
    (
        CASE
            WHEN v_puntos_anotados >= 2
                THEN 9.00
            WHEN v_puntos_anotados = 1
                THEN 8.00
            ELSE 7.00
        END
    )::NUMERIC,
    JSONB_BUILD_OBJECT(
        'goles',
        v_puntos_anotados,
        'asistencias',
        v_asistencias,
        'atajadas',
        CASE
            WHEN v_fila.numero_orden = 1
                THEN 5
            ELSE 0
        END
    ),
    v_id_admin,
    'Participacion registrada en el flujo demo'::VARCHAR
);
END LOOP;


    -- =====================================================
    -- FINALIZAR PARTIDO
    -- =====================================================

CALL competencia.sp_finalizar_partido(
    v_id_partido,
    4::INTEGER,
    3::INTEGER,
    NULL::INTEGER,
    NULL::INTEGER,
    v_id_admin,
    'Titanes gana por cuatro goles contra tres'::VARCHAR
);


UPDATE competencia.jornada
SET id_estado_jornada =
        v_id_estado_jornada_finalizada
WHERE id_jornada =
      v_id_jornada;


-- =====================================================
-- FINALIZAR FASE Y TORNEO
-- =====================================================

CALL competencia.sp_finalizar_fase(
        v_id_fase,
        v_id_admin
    );


CALL competencia.sp_finalizar_torneo(
        v_id_torneo,
        v_id_admin
    );


-- =====================================================
-- GENERAR Y ENTREGAR PREMIO
-- =====================================================

CALL finanzas.sp_generar_entregas_premios(
        v_id_torneo,
        v_id_admin
    );


SELECT entrega.id_entrega_premio
INTO STRICT v_id_entrega_premio

FROM finanzas.entrega_premio entrega
    INNER JOIN finanzas.torneo_premio torneo_premio
ON torneo_premio.id_torneo_premio =
    entrega.id_torneo_premio

WHERE torneo_premio.id_torneo =
    v_id_torneo;


CALL finanzas.sp_autorizar_entrega_premio(
        v_id_entrega_premio,
        v_id_admin,
        'Premio autorizado en la demostracion'
    );


CALL finanzas.sp_entregar_premio(
        v_id_entrega_premio,
        v_id_admin,
        'Premio entregado al delegado de Titanes'
    );


RAISE
NOTICE
        'Flujo completado. Torneo: %, partido: %, entrega: %',
        v_id_torneo,
        v_id_partido,
        v_id_entrega_premio;
END;
$$;

COMMIT;