\set ON_ERROR_STOP on

BEGIN;

SELECT SET_CONFIG(
               'app.request_id',
               'CARGA-DEMO-SCORELY-UMSA-2026',
               TRUE
       );

SELECT SET_CONFIG(
               'app.ip_cliente',
               '127.0.0.1',
               TRUE
       );


-- ============================================================
-- FUNCION TEMPORAL PARA BUSCAR CATALOGOS
-- ============================================================
-- Busca el primer codigo disponible.
-- Si ninguno existe, usa el primer registro del catalogo.
-- La funcion desaparece al cerrar la conexion.

CREATE OR REPLACE FUNCTION pg_temp.obtener_id_catalogo(
    p_tabla REGCLASS,
    p_columna_id NAME,
    p_codigos TEXT[]
)
    RETURNS BIGINT
    LANGUAGE plpgsql
AS
$$
DECLARE
    v_id BIGINT;
BEGIN
    EXECUTE FORMAT(
            '
            SELECT %I::BIGINT
            FROM %s
            WHERE codigo::TEXT = ANY ($1)
            ORDER BY ARRAY_POSITION($1, codigo::TEXT)
            LIMIT 1
            ',
            p_columna_id,
            p_tabla
            )
        INTO v_id
        USING p_codigos;

    IF v_id IS NULL THEN
        RAISE EXCEPTION
            'No se encontro ninguno de los codigos % en el catalogo %',
            p_codigos,
            p_tabla;
    END IF;

    RETURN v_id;
END;
$$;


-- ============================================================
-- USUARIO QUE APARECERA EN LA AUDITORIA
-- ============================================================

DO
$$
    DECLARE
        v_id_usuario BIGINT;
    BEGIN
        SELECT id_usuario
        INTO v_id_usuario
        FROM seguridad.usuario
        WHERE numero_documento = '7000001'
        LIMIT 1;

        IF v_id_usuario IS NULL THEN
            SELECT MIN(id_usuario)
            INTO v_id_usuario
            FROM seguridad.usuario;
        END IF;

        IF v_id_usuario IS NULL THEN
            RAISE EXCEPTION
                'Debe existir por lo menos un usuario antes de ejecutar la carga demo.';
        END IF;

        PERFORM SET_CONFIG(
                'app.usuario_id',
                v_id_usuario::TEXT,
                TRUE
                );
    END;
$$;


-- ============================================================
-- USUARIOS PRINCIPALES
-- La contraseña se configurará después con Python y Argon2.
-- ============================================================

WITH parametros AS (SELECT pg_temp.obtener_id_catalogo(
                                   'catalogo.tipo_documento'::REGCLASS,
                                   'id_tipo_documento',
                                   ARRAY ['CI']
                           )::SMALLINT AS id_tipo_documento,

                           pg_temp.obtener_id_catalogo(
                                   'catalogo.estado_usuario'::REGCLASS,
                                   'id_estado_usuario',
                                   ARRAY ['ACTIVO', 'HABILITADO']
                           )::SMALLINT AS id_estado_usuario),
     datos (
            numero_documento,
            nombres,
            apellido_paterno,
            apellido_materno,
            fecha_nacimiento,
            sexo,
            correo,
            telefono,
            direccion,
            zona
         ) AS (VALUES ('90000001',
                       'Valeria Fernanda',
                       'Quispe',
                       'Mendoza',
                       DATE '1994-05-18',
                       'F',
                       'valeria.admin@scorely.test',
                       '76510001',
                       'Avenida Arce 1200',
                       'Sopocachi'),
                      ('90000002',
                       'Diego Alejandro',
                       'Choque',
                       'Flores',
                       DATE '1992-09-08',
                       'M',
                       'diego.admin@scorely.test',
                       '76510002',
                       'Calle Estados Unidos 210',
                       'Miraflores'),
                      ('90000101',
                       'Mariana Alejandra',
                       'Vargas',
                       'Condori',
                       DATE '1991-02-14',
                       'F',
                       'deportes.umsa@scorely.test',
                       '76510101',
                       'Campus Universitario UMSA',
                       'Cota Cota'),
                      ('90000102',
                       'Rodrigo Esteban',
                       'Lima',
                       'Mamani',
                       DATE '1989-11-24',
                       'M',
                       'organizador.liga@scorely.test',
                       '76510102',
                       'Avenida Busch 800',
                       'Miraflores'),
                      ('90000201',
                       'Carlos Eduardo',
                       'Apaza',
                       'Rojas',
                       DATE '1988-03-22',
                       'M',
                       'arbitro.carlos@scorely.test',
                       '76510201',
                       'Calle Murillo 450',
                       'Centro'),
                      ('90000202',
                       'Lucia Fernanda',
                       'Paredes',
                       'Soto',
                       DATE '1993-07-11',
                       'F',
                       'arbitra.lucia@scorely.test',
                       '76510202',
                       'Avenida Saavedra 400',
                       'Miraflores'),
                      ('90000203',
                       'Mateo Sebastian',
                       'Calle',
                       'Nina',
                       DATE '1990-12-02',
                       'M',
                       'arbitro.mateo@scorely.test',
                       '76510203',
                       'Calle 21 de Calacoto',
                       'Calacoto'))
INSERT
INTO seguridad.usuario (id_tipo_documento,
                        numero_documento,
                        nombres,
                        apellido_paterno,
                        apellido_materno,
                        fecha_nacimiento,
                        sexo,
                        correo,
                        telefono,
                        direccion,
                        zona,
                        contrasenia_hash,
                        id_estado_usuario)
SELECT parametros.id_tipo_documento,
       datos.numero_documento,
       datos.nombres,
       datos.apellido_paterno,
       datos.apellido_materno,
       datos.fecha_nacimiento,
       datos.sexo,
       datos.correo,
       datos.telefono,
       datos.direccion,
       datos.zona,

       '$2b$12$LQv3c1yqBWVHxkd0LQ4YCO/4W1y3FjyfJwYhZ2tM1Qj0xP9WvWn6e',

       parametros.id_estado_usuario

FROM datos
         CROSS JOIN parametros

ON CONFLICT (
    id_tipo_documento,
    numero_documento
    )
    DO UPDATE SET nombres             = EXCLUDED.nombres,
                  apellido_paterno    = EXCLUDED.apellido_paterno,
                  apellido_materno    = EXCLUDED.apellido_materno,
                  correo              = EXCLUDED.correo,
                  telefono            = EXCLUDED.telefono,
                  direccion           = EXCLUDED.direccion,
                  zona                = EXCLUDED.zona,
                  id_estado_usuario   = EXCLUDED.id_estado_usuario,
                  fecha_actualizacion = CURRENT_TIMESTAMP;


-- ============================================================
-- 40 JUGADORES
-- ============================================================

WITH parametros AS (SELECT pg_temp.obtener_id_catalogo(
                                   'catalogo.tipo_documento'::REGCLASS,
                                   'id_tipo_documento',
                                   ARRAY ['CI']
                           )::SMALLINT AS id_tipo_documento,

                           pg_temp.obtener_id_catalogo(
                                   'catalogo.estado_usuario'::REGCLASS,
                                   'id_estado_usuario',
                                   ARRAY ['ACTIVO', 'HABILITADO']
                           )::SMALLINT AS id_estado_usuario),
     numeros AS (SELECT GENERATE_SERIES(1, 40) AS numero),
     datos AS (SELECT numero,

                      '91' || LPAD(numero::TEXT, 6, '0')
                          AS numero_documento,

                      (
                          ARRAY [
                              'Mateo', 'Luis', 'Carlos', 'Daniel', 'Fernando',
                              'Rodrigo', 'Alejandro', 'Gabriel', 'Miguel', 'Jorge',
                              'Camila', 'Lucia', 'Valeria', 'Sofia', 'Andrea',
                              'Mariana', 'Paola', 'Daniela', 'Carla', 'Natalia'
                              ]
                          )[((numero - 1) % 20) + 1]
                          AS nombres,

                      (
                          ARRAY [
                              'Quispe', 'Mamani', 'Choque', 'Flores', 'Condori',
                              'Rojas', 'Vargas', 'Apaza', 'Paredes', 'Lima',
                              'Nina', 'Callisaya', 'Huanca', 'Cruz', 'Mendoza',
                              'Lopez', 'Soria', 'Torrez', 'Gutierrez', 'Salazar'
                              ]
                          )[((numero - 1) % 20) + 1]
                          AS apellido_paterno,

                      (
                          ARRAY [
                              'Mendoza', 'Rojas', 'Flores', 'Condori', 'Mamani',
                              'Quisbert', 'Cruz', 'Nina', 'Luna', 'Poma'
                              ]
                          )[((numero - 1) % 10) + 1]
                          AS apellido_materno,

                      DATE '1998-01-01'
                          + ((numero * 47) % 2500)
                          AS fecha_nacimiento,

                      CASE
                          WHEN numero BETWEEN 11 AND 15 THEN 'F'
                          WHEN numero BETWEEN 26 AND 30 THEN 'F'
                          ELSE 'M'
                          END::CHAR(1)
                          AS sexo,

                      CASE
                          WHEN numero = 1 THEN
                              'capitan.ingenieria@scorely.test'

                          WHEN numero = 11 THEN
                              'capitana.medicina@scorely.test'

                          ELSE
                              'jugador'
                                  || LPAD(numero::TEXT, 2, '0')
                                  || '@scorely.test'
                          END
                          AS correo,

                      '76' || LPAD((500000 + numero)::TEXT, 6, '0')
                          AS telefono

               FROM numeros)
INSERT
INTO seguridad.usuario (id_tipo_documento,
                        numero_documento,
                        nombres,
                        apellido_paterno,
                        apellido_materno,
                        fecha_nacimiento,
                        sexo,
                        correo,
                        telefono,
                        direccion,
                        zona,
                        contrasenia_hash,
                        id_estado_usuario)
SELECT parametros.id_tipo_documento,
       datos.numero_documento,
       datos.nombres,
       datos.apellido_paterno,
       datos.apellido_materno,
       datos.fecha_nacimiento,
       datos.sexo,
       datos.correo,
       datos.telefono,
       'Residencia universitaria o domicilio particular',
       'La Paz',

       '$2b$12$LQv3c1yqBWVHxkd0LQ4YCO/4W1y3FjyfJwYhZ2tM1Qj0xP9WvWn6e',

       parametros.id_estado_usuario

FROM datos
         CROSS JOIN parametros

ON CONFLICT (
    id_tipo_documento,
    numero_documento
    )
    DO NOTHING;


-- ============================================================
-- ROLES GENERALES
-- ============================================================

WITH administrador AS (SELECT id_usuario
                       FROM seguridad.usuario
                       WHERE numero_documento = '7000001'
                       LIMIT 1),
     asignaciones (
                   numero_documento,
                   codigo_rol
         ) AS (VALUES ('90000001', 'ADMINISTRADOR'),
                      ('90000002', 'ADMINISTRADOR'),

                      ('90000101', 'ORGANIZADOR'),
                      ('90000102', 'ORGANIZADOR'),

                      ('90000201', 'ARBITRO'),
                      ('90000202', 'ARBITRO'),
                      ('90000203', 'ARBITRO'))
INSERT
INTO seguridad.usuario_rol (id_usuario,
                            id_rol,
                            asignado_por)
SELECT usuario.id_usuario,
       rol.id_rol,
       administrador.id_usuario

FROM asignaciones asignacion

         INNER JOIN seguridad.usuario usuario
                    ON usuario.numero_documento =
                       asignacion.numero_documento

         INNER JOIN seguridad.rol rol
                    ON rol.codigo =
                       asignacion.codigo_rol

         CROSS JOIN administrador

WHERE NOT EXISTS (SELECT 1
                  FROM seguridad.usuario_rol existente
                  WHERE existente.id_usuario = usuario.id_usuario
                    AND existente.id_rol = rol.id_rol
                    AND existente.activo = TRUE
                    AND existente.fecha_fin IS NULL);


WITH administrador AS (SELECT id_usuario
                       FROM seguridad.usuario
                       WHERE numero_documento = '7000001'
                       LIMIT 1),
     rol_jugador AS (SELECT id_rol
                     FROM seguridad.rol
                     WHERE codigo = 'JUGADOR')
INSERT
INTO seguridad.usuario_rol (id_usuario,
                            id_rol,
                            asignado_por)
SELECT usuario.id_usuario,
       rol_jugador.id_rol,
       administrador.id_usuario

FROM seguridad.usuario usuario
         CROSS JOIN rol_jugador
         CROSS JOIN administrador

WHERE usuario.numero_documento
    BETWEEN '91000001' AND '91000040'

  AND NOT EXISTS (SELECT 1
                  FROM seguridad.usuario_rol existente
                  WHERE existente.id_usuario = usuario.id_usuario
                    AND existente.id_rol = rol_jugador.id_rol
                    AND existente.activo = TRUE
                    AND existente.fecha_fin IS NULL);


-- ============================================================
-- PERFILES DE ORGANIZADOR
-- ============================================================

INSERT INTO participantes.organizador (id_usuario,
                                       institucion,
                                       cargo,
                                       anios_experiencia,
                                       id_estado_perfil,
                                       observaciones)
SELECT usuario.id_usuario,

       CASE
           WHEN usuario.numero_documento = '90000101'
               THEN 'Universidad Mayor de San Andres'
           ELSE 'Liga Deportiva La Paz'
           END,

       CASE
           WHEN usuario.numero_documento = '90000101'
               THEN 'Coordinadora de deportes'
           ELSE 'Coordinador general'
           END,

       CASE
           WHEN usuario.numero_documento = '90000101'
               THEN 7
           ELSE 9
           END,

       pg_temp.obtener_id_catalogo(
               'catalogo.estado_perfil_deportivo'::REGCLASS,
               'id_estado_perfil',
               ARRAY ['ACTIVO', 'HABILITADO']
       )::SMALLINT,

       'Perfil agregado mediante la carga demo Scorely'

FROM seguridad.usuario usuario

WHERE usuario.numero_documento IN (
                                   '90000101',
                                   '90000102'
    )

ON CONFLICT (id_usuario)
    DO NOTHING;


-- ============================================================
-- PERFILES DE ARBITRO
-- ============================================================

INSERT INTO participantes.arbitro (id_usuario,
                                   numero_licencia,
                                   nivel,
                                   anios_experiencia,
                                   id_estado_perfil,
                                   observaciones)
SELECT usuario.id_usuario,

       CASE usuario.numero_documento
           WHEN '90000201' THEN 'ARB-LP-2026-001'
           WHEN '90000202' THEN 'ARB-LP-2026-002'
           WHEN '90000203' THEN 'ARB-LP-2026-003'
           END,

       CASE usuario.numero_documento
           WHEN '90000201' THEN 'Nacional'
           WHEN '90000202' THEN 'Departamental'
           ELSE 'Universitario'
           END,

       CASE usuario.numero_documento
           WHEN '90000201' THEN 11
           WHEN '90000202' THEN 8
           ELSE 6
           END,

       pg_temp.obtener_id_catalogo(
               'catalogo.estado_perfil_deportivo'::REGCLASS,
               'id_estado_perfil',
               ARRAY ['ACTIVO', 'HABILITADO']
       )::SMALLINT,

       'Arbitro disponible para los torneos demo'

FROM seguridad.usuario usuario

WHERE usuario.numero_documento IN (
                                   '90000201',
                                   '90000202',
                                   '90000203'
    )

ON CONFLICT (id_usuario)
    DO NOTHING;


-- ============================================================
-- PERFILES DE JUGADOR
-- ============================================================

INSERT INTO participantes.jugador (id_usuario,
                                   alias_deportivo,
                                   id_estado_perfil,
                                   observaciones)
SELECT usuario.id_usuario,

       CONCAT(
               SPLIT_PART(usuario.nombres, ' ', 1),
               ' ',
               RIGHT(usuario.numero_documento, 2)
       ),

       pg_temp.obtener_id_catalogo(
               'catalogo.estado_perfil_deportivo'::REGCLASS,
               'id_estado_perfil',
               ARRAY ['ACTIVO', 'HABILITADO']
       )::SMALLINT,

       'Jugador universitario generado para la demostracion'

FROM seguridad.usuario usuario

WHERE usuario.numero_documento
          BETWEEN '91000001' AND '91000040'

ON CONFLICT (id_usuario)
    DO NOTHING;


-- ============================================================
-- DEPORTES
-- ============================================================

WITH estado AS (SELECT pg_temp.obtener_id_catalogo(
                               'catalogo.estado_deporte'::REGCLASS,
                               'id_estado_deporte',
                               ARRAY ['ACTIVO', 'HABILITADO']
                       )::SMALLINT AS id_estado_deporte),
     datos (
            codigo,
            nombre,
            descripcion,
            minimo,
            maximo,
            titulares,
            tipo_marcador,
            permite_empate,
            puntos_victoria,
            puntos_empate,
            puntos_derrota
         ) AS (VALUES ('FUTBOL',
                       'Futbol',
                       'Futbol de campo por equipos',
                       11::SMALLINT,
                       25::SMALLINT,
                       11::SMALLINT,
                       'GOLES',
                       TRUE,
                       3::SMALLINT,
                       1::SMALLINT,
                       0::SMALLINT),
                      ('FUTSAL',
                       'Futsal',
                       'Futbol de salon',
                       5::SMALLINT,
                       14::SMALLINT,
                       5::SMALLINT,
                       'GOLES',
                       TRUE,
                       3::SMALLINT,
                       1::SMALLINT,
                       0::SMALLINT),
                      ('BALONCESTO',
                       'Baloncesto',
                       'Baloncesto universitario',
                       5::SMALLINT,
                       15::SMALLINT,
                       5::SMALLINT,
                       'PUNTOS',
                       FALSE,
                       2::SMALLINT,
                       0::SMALLINT,
                       1::SMALLINT),
                      ('VOLEIBOL',
                       'Voleibol',
                       'Voleibol por equipos',
                       6::SMALLINT,
                       18::SMALLINT,
                       6::SMALLINT,
                       'SETS',
                       FALSE,
                       3::SMALLINT,
                       0::SMALLINT,
                       0::SMALLINT),
                      ('TENIS',
                       'Tenis',
                       'Tenis individual o por parejas',
                       1::SMALLINT,
                       2::SMALLINT,
                       1::SMALLINT,
                       'SETS',
                       FALSE,
                       2::SMALLINT,
                       0::SMALLINT,
                       0::SMALLINT))
INSERT
INTO competencia.deporte (codigo,
                          nombre,
                          descripcion,
                          cantidad_minima_jugadores,
                          cantidad_maxima_jugadores,
                          cantidad_titulares,
                          tipo_marcador,
                          permite_empate,
                          puntos_victoria,
                          puntos_empate,
                          puntos_derrota,
                          id_estado_deporte)
SELECT datos.codigo,
       datos.nombre,
       datos.descripcion,
       datos.minimo,
       datos.maximo,
       datos.titulares,
       datos.tipo_marcador,
       datos.permite_empate,
       datos.puntos_victoria,
       datos.puntos_empate,
       datos.puntos_derrota,
       estado.id_estado_deporte

FROM datos
         CROSS JOIN estado

ON CONFLICT (codigo)
DO UPDATE SET
    nombre = EXCLUDED.nombre,
    descripcion = EXCLUDED.descripcion,
    cantidad_minima_jugadores =
        EXCLUDED.cantidad_minima_jugadores,
    cantidad_maxima_jugadores =
        EXCLUDED.cantidad_maxima_jugadores,
    cantidad_titulares =
        EXCLUDED.cantidad_titulares,
    tipo_marcador =
        EXCLUDED.tipo_marcador,
    permite_empate =
        EXCLUDED.permite_empate,
    puntos_victoria =
        EXCLUDED.puntos_victoria,
    puntos_empate =
        EXCLUDED.puntos_empate,
    puntos_derrota =
        EXCLUDED.puntos_derrota,
    id_estado_deporte =
        EXCLUDED.id_estado_deporte;
-- ============================================================
-- EQUIPOS
-- ============================================================

WITH administrador AS (SELECT id_usuario
                       FROM seguridad.usuario
                       WHERE numero_documento = '90000001'),
     datos (
            nombre,
            sigla,
            fecha_fundacion,
            descripcion
         ) AS (VALUES ('Facultad de Ingenieria UMSA',
                       'ING-UMSA',
                       DATE '1950-04-01',
                       'Seleccion deportiva de la Facultad de Ingenieria'),
                      ('Facultad de Ciencias Puras UMSA',
                       'CPN-UMSA',
                       DATE '1966-05-25',
                       'Seleccion de Ciencias Puras y Naturales'),
                      ('Facultad de Medicina UMSA',
                       'MED-UMSA',
                       DATE '1904-04-05',
                       'Seleccion deportiva de Medicina'),
                      ('Facultad de Derecho UMSA',
                       'DER-UMSA',
                       DATE '1900-11-30',
                       'Seleccion de Derecho y Ciencias Politicas'),
                      ('Facultad de Ciencias Economicas UMSA',
                       'ECO-UMSA',
                       DATE '1930-05-12',
                       'Seleccion de Ciencias Economicas y Financieras'),
                      ('Facultad de Humanidades UMSA',
                       'HUM-UMSA',
                       DATE '1944-07-18',
                       'Seleccion deportiva de Humanidades'),
                      ('Facultad de Arquitectura UMSA',
                       'ARQ-UMSA',
                       DATE '1942-08-15',
                       'Seleccion de Arquitectura, Artes y Urbanismo'),
                      ('Facultad de Ciencias Sociales UMSA',
                       'SOC-UMSA',
                       DATE '1967-10-20',
                       'Seleccion deportiva de Ciencias Sociales'),

                      ('Titanes Futsal La Paz',
                       'TIT-FUT',
                       DATE '2018-02-10',
                       'Club competitivo de futsal'),
                      ('Halcones Futsal La Paz',
                       'HAL-FUT',
                       DATE '2019-06-14',
                       'Club universitario de futsal'),
                      ('Condores Basket',
                       'CON-BAS',
                       DATE '2017-03-11',
                       'Equipo de baloncesto'),
                      ('Lobos Basket',
                       'LOB-BAS',
                       DATE '2020-09-21',
                       'Equipo juvenil de baloncesto'),
                      ('Panteras Voleibol',
                       'PAN-VOL',
                       DATE '2016-04-13',
                       'Club femenino de voleibol'),
                      ('Aguilas Voleibol',
                       'AGU-VOL',
                       DATE '2018-07-22',
                       'Club mixto de voleibol'),
                      ('Raquetas Andinas',
                       'RAQ-TEN',
                       DATE '2021-01-18',
                       'Club de tenis de La Paz'),
                      ('Smash La Paz',
                       'SMA-TEN',
                       DATE '2022-10-08',
                       'Academia y equipo de tenis'))
INSERT
INTO participantes.equipo (nombre,
                           sigla,
                           fecha_fundacion,
                           descripcion,
                           id_estado_equipo,
                           creado_por)
SELECT datos.nombre,
       datos.sigla,
       datos.fecha_fundacion,
       datos.descripcion,

       pg_temp.obtener_id_catalogo(
               'catalogo.estado_equipo'::REGCLASS,
               'id_estado_equipo',
               ARRAY ['ACTIVO', 'HABILITADO']
       )::SMALLINT,

       administrador.id_usuario

FROM datos
         CROSS JOIN administrador

ON CONFLICT (nombre)
    DO UPDATE SET descripcion         = EXCLUDED.descripcion,
                  id_estado_equipo    = EXCLUDED.id_estado_equipo,
                  fecha_actualizacion = CURRENT_TIMESTAMP;


-- ============================================================
-- MEMBRESIAS
-- Cinco jugadores por facultad
-- ============================================================

WITH jugadores AS (SELECT usuario.id_usuario,
                          usuario.numero_documento,

                          ROW_NUMBER() OVER (
                              ORDER BY usuario.numero_documento
                              ) AS numero_orden

                   FROM seguridad.usuario usuario

                   WHERE usuario.numero_documento
                             BETWEEN '91000001' AND '91000040'),
     equipos (
              numero_equipo,
              sigla
         ) AS (VALUES (1, 'ING-UMSA'),
                      (2, 'CPN-UMSA'),
                      (3, 'MED-UMSA'),
                      (4, 'DER-UMSA'),
                      (5, 'ECO-UMSA'),
                      (6, 'HUM-UMSA'),
                      (7, 'ARQ-UMSA'),
                      (8, 'SOC-UMSA')),
     administrador AS (SELECT id_usuario
                       FROM seguridad.usuario
                       WHERE numero_documento = '90000001')
INSERT
INTO participantes.jugador_equipo (id_jugador,
                                   id_equipo,
                                   fecha_inicio,
                                   numero_camiseta,
                                   posicion,
                                   es_delegado,
                                   id_estado_membresia,
                                   registrado_por,
                                   observaciones)
SELECT jugador.id_usuario,
       equipo.id_equipo,
       DATE '2026-01-15',

       (((jugador.numero_orden - 1) % 5) + 1)::SMALLINT,

       CASE ((jugador.numero_orden - 1) % 5)
           WHEN 0 THEN 'Arquero'
           WHEN 1 THEN 'Defensa central'
           WHEN 2 THEN 'Volante'
           WHEN 3 THEN 'Delantero'
           ELSE 'Polifuncional'
           END,

       ((jugador.numero_orden - 1) % 5) = 0,

       pg_temp.obtener_id_catalogo(
               'catalogo.estado_membresia'::REGCLASS,
               'id_estado_membresia',
               ARRAY ['ACTIVA', 'ACTIVO', 'VIGENTE']
       )::SMALLINT,

       administrador.id_usuario,

       'Membresia creada para el Interfacultativo UMSA'

FROM jugadores jugador

         INNER JOIN equipos mapa
                    ON mapa.numero_equipo =
                       (((jugador.numero_orden - 1) / 5) + 1)

         INNER JOIN participantes.equipo equipo
                    ON equipo.sigla = mapa.sigla

         CROSS JOIN administrador

WHERE NOT EXISTS (SELECT 1
                  FROM participantes.jugador_equipo existente
                  WHERE existente.id_jugador = jugador.id_usuario
                    AND existente.id_equipo = equipo.id_equipo
                    AND existente.fecha_fin IS NULL);


-- ============================================================
-- LUGARES
-- ============================================================

WITH datos (
            nombre,
            direccion,
            zona,
            ciudad,
            capacidad,
            superficie
    ) AS (VALUES ('Cancha UMSA Cota Cota',
                  'Campus Universitario UMSA, calle 30',
                  'Cota Cota',
                  'La Paz',
                  1200,
                  'Cesped sintetico'),
                 ('Estadio Hernando Siles',
                  'Avenida Saavedra',
                  'Miraflores',
                  'La Paz',
                  41000,
                  'Cesped natural'),
                 ('Coliseo Universitario UMSA',
                  'Avenida del Poeta',
                  'Centro',
                  'La Paz',
                  1800,
                  'Parquet'),
                 ('Coliseo Julio Borelli Viteritto',
                  'Calle Mexico',
                  'Centro',
                  'La Paz',
                  2500,
                  'Parquet'),
                 ('Complejo Deportivo Los Sargentos',
                  'Avenida Costanera',
                  'Bajo Seguencoma',
                  'La Paz',
                  900,
                  'Cesped sintetico'),
                 ('Club de Tenis La Paz',
                  'Avenida Arequipa',
                  'La Florida',
                  'La Paz',
                  600,
                  'Arcilla'))
INSERT
INTO competencia.lugar (nombre,
                        direccion,
                        zona,
                        ciudad,
                        capacidad,
                        tipo_superficie,
                        activo)
SELECT datos.nombre,
       datos.direccion,
       datos.zona,
       datos.ciudad,
       datos.capacidad,
       datos.superficie,
       TRUE

FROM datos

WHERE NOT EXISTS (SELECT 1
                  FROM competencia.lugar existente
                  WHERE LOWER(existente.nombre) =
                        LOWER(datos.nombre)
                    AND LOWER(existente.direccion) =
                        LOWER(datos.direccion));


-- ============================================================
-- TORNEOS
-- ============================================================

WITH administrador AS (SELECT id_usuario
                       FROM seguridad.usuario
                       WHERE numero_documento = '90000001'),
     datos (
            codigo,
            codigo_deporte,
            codigos_formato,
            codigos_estado,
            nombre,
            edicion,
            categoria,
            rama,
            inicio_inscripcion,
            fin_inscripcion,
            inicio_torneo,
            fin_torneo,
            maximo_equipos,
            minimo_jugadores,
            maximo_jugadores,
            costo,
            permite_empate,
            descripcion
         ) AS (VALUES ('UMSA-FUT-2026',
                       'FUTBOL',
                       ARRAY['GRUPOS_Y_LLAVES']::TEXT[], ARRAY['INSCRIPCIONES_ABIERTAS']::TEXT[],
                       'Interfacultativo UMSA de Futbol 2026',
                       'Gestion 2026',
                       'Universitario',
                       'MASCULINO',
                       DATE '2026-06-01',
                       DATE '2026-06-30',
                       DATE '2026-07-10',
                       DATE '2026-08-30',
                       16::SMALLINT,
                       11::SMALLINT,
                       22::SMALLINT,
                       350.00,
                       TRUE,
                       'Torneo central entre facultades de la Universidad Mayor de San Andres'),
                      ('COPA-INVIERNO-FUTSAL-2026',
                       'FUTSAL',
                       ARRAY['ELIMINACION_DIRECTA']::TEXT[], ARRAY['INSCRIPCIONES_ABIERTAS']::TEXT[],
                       'Copa Invierno de Futsal 2026',
                       'Primera edicion',
                       'Libre',
                       'MIXTO',
                       DATE '2026-07-01',
                       DATE '2026-07-15',
                       DATE '2026-07-25',
                       DATE '2026-07-30',
                       8::SMALLINT,
                       5::SMALLINT,
                       12::SMALLINT,
                       200.00,
                       FALSE,
                       'Competencia corta de eliminacion directa'),
                      ('LIGA-BASKET-2026',
                       'BALONCESTO',
                       ARRAY['FASE_GRUPOS']::TEXT[], ARRAY['INSCRIPCIONES_ABIERTAS']::TEXT[],
                       'Liga Universitaria de Baloncesto 2026',
                       'Temporada 2026',
                       'Universitario',
                       'MIXTO',
                       DATE '2026-07-15',
                       DATE '2026-08-10',
                       DATE '2026-08-15',
                       DATE '2026-09-30',
                       10::SMALLINT,
                       5::SMALLINT,
                       15::SMALLINT,
                       280.00,
                       FALSE,
                       'Liga regular universitaria de baloncesto'),
                      ('COPA-RECTORA-VOLEY-2026',
                       'VOLEIBOL',
                       ARRAY['FASE_GRUPOS']::TEXT[], ARRAY['INSCRIPCIONES_ABIERTAS']::TEXT[],
                       'Copa Rectora de Voleibol Femenino',
                       'Gestion 2026',
                       'Universitario',
                       'FEMENINO',
                       DATE '2026-07-20',
                       DATE '2026-08-20',
                       DATE '2026-08-25',
                       DATE '2026-09-20',
                       12::SMALLINT,
                       6::SMALLINT,
                       16::SMALLINT,
                       250.00,
                       FALSE,
                       'Torneo femenino con fase de grupos'),
                      ('OPEN-TENIS-LP-2026',
                       'TENIS',
                       ARRAY['ELIMINACION_DIRECTA']::TEXT[], ARRAY['INSCRIPCIONES_ABIERTAS']::TEXT[],
                       'Open Paceno de Tenis 2026',
                       'Primera edicion',
                       'Individual',
                       'ABIERTO',
                       DATE '2026-08-01',
                       DATE '2026-08-30',
                       DATE '2026-09-05',
                       DATE '2026-09-15',
                       16::SMALLINT,
                       1::SMALLINT,
                       2::SMALLINT,
                       150.00,
                       FALSE,
                       'Torneo individual de tenis por llaves'),
                      ('RELAMPAGO-MIXTO-2026',
                       'FUTSAL',
                       ARRAY['ELIMINACION_DIRECTA']::TEXT[], ARRAY['INSCRIPCIONES_ABIERTAS']::TEXT[],
                       'Copa Relampago Mixta Scorely',
                       'Edicion julio 2026',
                       'Libre',
                       'MIXTO',
                       DATE '2026-07-10',
                       DATE '2026-07-20',
                       DATE '2026-08-02',
                       DATE '2026-08-02',
                       4::SMALLINT,
                       5::SMALLINT,
                       10::SMALLINT,
                       100.00,
                       FALSE,
                       'Torneo de un solo dia'),
                      ('LIGA-BARRIAL-FUT-2026',
                       'FUTBOL',
                       ARRAY['FASE_GRUPOS']::TEXT[], ARRAY['BORRADOR']::TEXT[],
                       'Liga Barrial La Paz 2026',
                       'Temporada primavera',
                       'Libre',
                       'MASCULINO',
                       DATE '2026-07-20',
                       DATE '2026-08-25',
                       DATE '2026-09-01',
                       DATE '2026-11-30',
                       20::SMALLINT,
                       11::SMALLINT,
                       25::SMALLINT,
                       500.00,
                       TRUE,
                       'Liga extensa de futbol barrial'))
INSERT
INTO competencia.torneo (id_deporte,
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
SELECT deporte.id_deporte,

       pg_temp.obtener_id_catalogo(
               'catalogo.formato_torneo'::REGCLASS,
               'id_formato_torneo',
               datos.codigos_formato
       )::SMALLINT,

       pg_temp.obtener_id_catalogo(
               'catalogo.estado_torneo'::REGCLASS,
               'id_estado_torneo',
               datos.codigos_estado
       )::SMALLINT,

       datos.codigo,
       datos.nombre,
       datos.edicion,
       datos.categoria,
       datos.rama,
       datos.inicio_inscripcion,
       datos.fin_inscripcion,
       datos.inicio_torneo,
       datos.fin_torneo,
       datos.maximo_equipos,
       datos.minimo_jugadores,
       datos.maximo_jugadores,
       datos.costo,
       'BOB',
       datos.permite_empate,
       datos.descripcion,
       administrador.id_usuario

FROM datos

         INNER JOIN competencia.deporte deporte
                    ON deporte.codigo = datos.codigo_deporte

         CROSS JOIN administrador

ON CONFLICT (codigo)
    DO UPDATE SET nombre              = EXCLUDED.nombre,
                  descripcion         = EXCLUDED.descripcion,
                  id_estado_torneo    = EXCLUDED.id_estado_torneo,
                  fecha_actualizacion = CURRENT_TIMESTAMP;


-- ============================================================
-- FASES
-- ============================================================

WITH datos (
            codigo_torneo,
            codigos_tipo_fase,
            codigos_estado,
            nombre,
            numero_orden,
            clasificados,
            fecha_inicio,
            fecha_fin,
            descripcion
    ) AS (VALUES ('UMSA-FUT-2026',
                  ARRAY ['GRUPOS']::TEXT[],
                  ARRAY ['EN_CURSO', 'PENDIENTE']::TEXT[],
                  'Fase de grupos',
                  1::SMALLINT,
                  4::SMALLINT,
                  DATE '2026-07-10',
                  DATE '2026-08-05',
                  'Dos grupos de cuatro facultades'),
                 ('UMSA-FUT-2026',
                  ARRAY ['ELIMINACION']::TEXT[],
                  ARRAY ['PENDIENTE']::TEXT[],
                  'Fase eliminatoria',
                  2::SMALLINT,
                  1::SMALLINT,
                  DATE '2026-08-10',
                  DATE '2026-08-30',
                  'Semifinales y final'),
                 ('COPA-INVIERNO-FUTSAL-2026',
                  ARRAY ['ELIMINACION']::TEXT[],
                  ARRAY ['EN_CURSO', 'PENDIENTE']::TEXT[],
                  'Llaves de eliminacion',
                  1::SMALLINT,
                  1::SMALLINT,
                  DATE '2026-07-25',
                  DATE '2026-07-30',
                  'Partidos de eliminacion directa'),
                 ('LIGA-BASKET-2026',
                  ARRAY ['GRUPOS']::TEXT[],
                  ARRAY ['PENDIENTE']::TEXT[],
                  'Temporada regular',
                  1::SMALLINT,
                  4::SMALLINT,
                  DATE '2026-08-15',
                  DATE '2026-09-30',
                  'Todos contra todos'),
                 ('COPA-RECTORA-VOLEY-2026',
                  ARRAY ['GRUPOS']::TEXT[],
                  ARRAY ['PENDIENTE']::TEXT[],
                  'Grupos clasificatorios',
                  1::SMALLINT,
                  4::SMALLINT,
                  DATE '2026-08-25',
                  DATE '2026-09-10',
                  'Clasifican dos equipos de cada grupo'),
                 ('OPEN-TENIS-LP-2026',
                  ARRAY ['ELIMINACION']::TEXT[],
                  ARRAY ['PENDIENTE']::TEXT[],
                  'Llave principal',
                  1::SMALLINT,
                  1::SMALLINT,
                  DATE '2026-09-05',
                  DATE '2026-09-15',
                  'Llave de eliminacion individual'),
                 ('RELAMPAGO-MIXTO-2026',
                  ARRAY ['ELIMINACION']::TEXT[],
                  ARRAY ['PENDIENTE']::TEXT[],
                  'Jornada relampago',
                  1::SMALLINT,
                  1::SMALLINT,
                  DATE '2026-08-02',
                  DATE '2026-08-02',
                  'Partidos desarrollados en un solo dia'))
INSERT
INTO competencia.fase_torneo (id_torneo,
                              id_tipo_fase,
                              id_estado_fase,
                              nombre,
                              numero_orden,
                              cantidad_clasificados,
                              fecha_inicio,
                              fecha_fin,
                              descripcion)
SELECT torneo.id_torneo,

       pg_temp.obtener_id_catalogo(
               'catalogo.tipo_fase'::REGCLASS,
               'id_tipo_fase',
               datos.codigos_tipo_fase
       )::SMALLINT,

       pg_temp.obtener_id_catalogo(
               'catalogo.estado_fase'::REGCLASS,
               'id_estado_fase',
               datos.codigos_estado
       )::SMALLINT,

       datos.nombre,
       datos.numero_orden,
       datos.clasificados,
       datos.fecha_inicio,
       datos.fecha_fin,
       datos.descripcion

FROM datos

         INNER JOIN competencia.torneo torneo
                    ON torneo.codigo = datos.codigo_torneo

ON CONFLICT (
    id_torneo,
    numero_orden
    )
    DO UPDATE SET nombre      = EXCLUDED.nombre,
                  descripcion = EXCLUDED.descripcion;


-- ============================================================
-- GRUPOS
-- ============================================================

WITH datos (
            codigo_torneo,
            numero_fase,
            codigo,
            nombre,
            maximo,
            clasificados
    ) AS (VALUES ('UMSA-FUT-2026',
                  1::SMALLINT,
                  'A',
                  'Grupo A',
                  4::SMALLINT,
                  2::SMALLINT),
                 ('UMSA-FUT-2026',
                  1::SMALLINT,
                  'B',
                  'Grupo B',
                  4::SMALLINT,
                  2::SMALLINT),
                 ('COPA-RECTORA-VOLEY-2026',
                  1::SMALLINT,
                  'A',
                  'Grupo A',
                  4::SMALLINT,
                  2::SMALLINT),
                 ('COPA-RECTORA-VOLEY-2026',
                  1::SMALLINT,
                  'B',
                  'Grupo B',
                  4::SMALLINT,
                  2::SMALLINT))
INSERT
INTO competencia.grupo_torneo (id_fase_torneo,
                               codigo,
                               nombre,
                               cantidad_maxima_equipos,
                               cantidad_clasificados)
SELECT fase.id_fase_torneo,
       datos.codigo,
       datos.nombre,
       datos.maximo,
       datos.clasificados

FROM datos

         INNER JOIN competencia.torneo torneo
                    ON torneo.codigo = datos.codigo_torneo

         INNER JOIN competencia.fase_torneo fase
                    ON fase.id_torneo = torneo.id_torneo
                        AND fase.numero_orden = datos.numero_fase

ON CONFLICT (
    id_fase_torneo,
    codigo
    )
    DO UPDATE SET nombre                  = EXCLUDED.nombre,
                  cantidad_maxima_equipos =
                      EXCLUDED.cantidad_maxima_equipos,
                  cantidad_clasificados   =
                      EXCLUDED.cantidad_clasificados;


-- ============================================================
-- JORNADAS
-- ============================================================

WITH datos (
            codigo_torneo,
            numero_fase,
            numero_jornada,
            nombre,
            codigos_estado,
            fecha_inicio,
            fecha_fin
    ) AS (VALUES ('UMSA-FUT-2026',
                  1::SMALLINT,
                  1::SMALLINT,
                  'Primera fecha de grupos',
                  ARRAY ['FINALIZADA', 'EN_CURSO']::TEXT[],
                  TIMESTAMPTZ '2026-07-12 09:00:00-04',
                  TIMESTAMPTZ '2026-07-12 18:00:00-04'),
                 ('UMSA-FUT-2026',
                  1::SMALLINT,
                  2::SMALLINT,
                  'Segunda fecha de grupos',
                  ARRAY ['EN_CURSO', 'PROGRAMADA']::TEXT[],
                  TIMESTAMPTZ '2026-07-26 09:00:00-04',
                  TIMESTAMPTZ '2026-07-26 18:00:00-04'),
                 ('UMSA-FUT-2026',
                  1::SMALLINT,
                  3::SMALLINT,
                  'Tercera fecha de grupos',
                  ARRAY ['PROGRAMADA', 'PENDIENTE']::TEXT[],
                  TIMESTAMPTZ '2026-08-02 09:00:00-04',
                  TIMESTAMPTZ '2026-08-02 18:00:00-04'),
                 ('UMSA-FUT-2026',
                  2::SMALLINT,
                  1::SMALLINT,
                  'Semifinales',
                  ARRAY ['PROGRAMADA', 'PENDIENTE']::TEXT[],
                  TIMESTAMPTZ '2026-08-16 10:00:00-04',
                  TIMESTAMPTZ '2026-08-16 16:00:00-04'),
                 ('UMSA-FUT-2026',
                  2::SMALLINT,
                  2::SMALLINT,
                  'Gran final',
                  ARRAY ['PROGRAMADA', 'PENDIENTE']::TEXT[],
                  TIMESTAMPTZ '2026-08-30 14:00:00-04',
                  TIMESTAMPTZ '2026-08-30 18:00:00-04'),
                 ('COPA-INVIERNO-FUTSAL-2026',
                  1::SMALLINT,
                  1::SMALLINT,
                  'Cuartos y semifinales',
                  ARRAY ['EN_CURSO', 'PROGRAMADA']::TEXT[],
                  TIMESTAMPTZ '2026-07-26 08:00:00-04',
                  TIMESTAMPTZ '2026-07-26 18:00:00-04'),
                 ('LIGA-BASKET-2026',
                  1::SMALLINT,
                  1::SMALLINT,
                  'Primera fecha de basket',
                  ARRAY ['PROGRAMADA', 'PENDIENTE']::TEXT[],
                  TIMESTAMPTZ '2026-08-16 09:00:00-04',
                  TIMESTAMPTZ '2026-08-16 17:00:00-04'),
                 ('COPA-RECTORA-VOLEY-2026',
                  1::SMALLINT,
                  1::SMALLINT,
                  'Primera fecha de voleibol',
                  ARRAY ['PROGRAMADA', 'PENDIENTE']::TEXT[],
                  TIMESTAMPTZ '2026-08-29 09:00:00-04',
                  TIMESTAMPTZ '2026-08-29 18:00:00-04'),
                 ('OPEN-TENIS-LP-2026',
                  1::SMALLINT,
                  1::SMALLINT,
                  'Primera ronda de tenis',
                  ARRAY ['PROGRAMADA', 'PENDIENTE']::TEXT[],
                  TIMESTAMPTZ '2026-09-05 08:00:00-04',
                  TIMESTAMPTZ '2026-09-05 18:00:00-04'),
                 ('RELAMPAGO-MIXTO-2026',
                  1::SMALLINT,
                  1::SMALLINT,
                  'Jornada unica',
                  ARRAY ['PROGRAMADA', 'PENDIENTE']::TEXT[],
                  TIMESTAMPTZ '2026-08-02 08:00:00-04',
                  TIMESTAMPTZ '2026-08-02 20:00:00-04'))
INSERT
INTO competencia.jornada (id_fase_torneo,
                          id_estado_jornada,
                          numero_jornada,
                          nombre,
                          fecha_inicio,
                          fecha_fin,
                          observaciones)
SELECT fase.id_fase_torneo,

       pg_temp.obtener_id_catalogo(
               'catalogo.estado_jornada'::REGCLASS,
               'id_estado_jornada',
               datos.codigos_estado
       )::SMALLINT,

       datos.numero_jornada,
       datos.nombre,
       datos.fecha_inicio,
       datos.fecha_fin,
       'Jornada generada por la carga demo Scorely'

FROM datos

         INNER JOIN competencia.torneo torneo
                    ON torneo.codigo = datos.codigo_torneo

         INNER JOIN competencia.fase_torneo fase
                    ON fase.id_torneo = torneo.id_torneo
                        AND fase.numero_orden = datos.numero_fase

ON CONFLICT (
    id_fase_torneo,
    numero_jornada
    )
    DO UPDATE SET nombre       = EXCLUDED.nombre,
                  fecha_inicio = EXCLUDED.fecha_inicio,
                  fecha_fin    = EXCLUDED.fecha_fin;


-- ============================================================
-- ROLES DENTRO DE LOS TORNEOS
-- ============================================================

WITH administrador AS (SELECT id_usuario
                       FROM seguridad.usuario
                       WHERE numero_documento = '90000001'),
     asignaciones (
                   codigo_torneo,
                   numero_documento,
                   codigo_rol
         ) AS (VALUES ('UMSA-FUT-2026',
                       '90000101',
                       'ORGANIZADOR'),
                      ('UMSA-FUT-2026',
                       '90000201',
                       'ARBITRO'),
                      ('UMSA-FUT-2026',
                       '90000202',
                       'ARBITRO'),
                      ('COPA-INVIERNO-FUTSAL-2026',
                       '90000102',
                       'ORGANIZADOR'),
                      ('COPA-INVIERNO-FUTSAL-2026',
                       '90000203',
                       'ARBITRO'),
                      ('LIGA-BASKET-2026',
                       '90000102',
                       'ORGANIZADOR'),
                      ('COPA-RECTORA-VOLEY-2026',
                       '90000101',
                       'ORGANIZADOR'),
                      ('OPEN-TENIS-LP-2026',
                       '90000102',
                       'ORGANIZADOR'),
                      ('RELAMPAGO-MIXTO-2026',
                       '90000101',
                       'ORGANIZADOR'),
                      ('LIGA-BARRIAL-FUT-2026',
                       '90000102',
                       'ORGANIZADOR'))
INSERT
INTO competencia.usuario_torneo_rol (id_torneo,
                                     id_usuario,
                                     id_rol_torneo,
                                     asignado_por)
SELECT torneo.id_torneo,
       usuario.id_usuario,
       rol.id_rol_torneo,
       administrador.id_usuario

FROM asignaciones asignacion

         INNER JOIN competencia.torneo torneo
                    ON torneo.codigo =
                       asignacion.codigo_torneo

         INNER JOIN seguridad.usuario usuario
                    ON usuario.numero_documento =
                       asignacion.numero_documento

         INNER JOIN catalogo.rol_torneo rol
                    ON rol.codigo =
                       asignacion.codigo_rol

         CROSS JOIN administrador

WHERE NOT EXISTS (SELECT 1
                  FROM competencia.usuario_torneo_rol existente
                  WHERE existente.id_torneo = torneo.id_torneo
                    AND existente.id_usuario = usuario.id_usuario
                    AND existente.id_rol_torneo = rol.id_rol_torneo
                    AND existente.activo = TRUE
                    AND existente.fecha_fin IS NULL);


-- Jugadores asignados al Interfacultativo UMSA.

WITH administrador AS (SELECT id_usuario
                       FROM seguridad.usuario
                       WHERE numero_documento = '90000001'),
     torneo AS (SELECT id_torneo
                FROM competencia.torneo
                WHERE codigo = 'UMSA-FUT-2026'),
     rol AS (SELECT id_rol_torneo
             FROM catalogo.rol_torneo
             WHERE codigo = 'JUGADOR')
INSERT
INTO competencia.usuario_torneo_rol (id_torneo,
                                     id_usuario,
                                     id_rol_torneo,
                                     asignado_por)
SELECT torneo.id_torneo,
       usuario.id_usuario,
       rol.id_rol_torneo,
       administrador.id_usuario

FROM seguridad.usuario usuario
         CROSS JOIN torneo
         CROSS JOIN rol
         CROSS JOIN administrador

WHERE usuario.numero_documento
    BETWEEN '91000001' AND '91000040'

  AND NOT EXISTS (SELECT 1
                  FROM competencia.usuario_torneo_rol existente
                  WHERE existente.id_torneo = torneo.id_torneo
                    AND existente.id_usuario = usuario.id_usuario
                    AND existente.id_rol_torneo = rol.id_rol_torneo
                    AND existente.activo = TRUE
                    AND existente.fecha_fin IS NULL);


-- ============================================================
-- INSCRIPCIONES
-- ============================================================

WITH administrador AS (SELECT id_usuario
                       FROM seguridad.usuario
                       WHERE numero_documento = '90000001'),
     datos (
            codigo_torneo,
            sigla_equipo
         ) AS (VALUES ('UMSA-FUT-2026', 'ING-UMSA'),
                      ('UMSA-FUT-2026', 'CPN-UMSA'),
                      ('UMSA-FUT-2026', 'MED-UMSA'),
                      ('UMSA-FUT-2026', 'DER-UMSA'),
                      ('UMSA-FUT-2026', 'ECO-UMSA'),
                      ('UMSA-FUT-2026', 'HUM-UMSA'),
                      ('UMSA-FUT-2026', 'ARQ-UMSA'),
                      ('UMSA-FUT-2026', 'SOC-UMSA'),

                      ('COPA-INVIERNO-FUTSAL-2026', 'TIT-FUT'),
                      ('COPA-INVIERNO-FUTSAL-2026', 'HAL-FUT'),

                      ('LIGA-BASKET-2026', 'CON-BAS'),
                      ('LIGA-BASKET-2026', 'LOB-BAS'),

                      ('COPA-RECTORA-VOLEY-2026', 'PAN-VOL'),
                      ('COPA-RECTORA-VOLEY-2026', 'AGU-VOL'),

                      ('OPEN-TENIS-LP-2026', 'RAQ-TEN'),
                      ('OPEN-TENIS-LP-2026', 'SMA-TEN'),

                      ('RELAMPAGO-MIXTO-2026', 'ING-UMSA'),
                      ('RELAMPAGO-MIXTO-2026', 'MED-UMSA'))
INSERT
INTO competencia.inscripcion (id_torneo,
                              id_equipo,
                              id_estado_inscripcion,
                              monto_requerido,
                              moneda,
                              registrado_por,
                              observaciones)
SELECT torneo.id_torneo,
       equipo.id_equipo,

       pg_temp.obtener_id_catalogo(
        'catalogo.estado_inscripcion'::REGCLASS,
        'id_estado_inscripcion',
        ARRAY['PAGO_PENDIENTE']
    )::SMALLINT,

       torneo.costo_inscripcion,
       torneo.moneda,
       administrador.id_usuario,

       'Inscripcion generada para los datos demo'

FROM datos

         INNER JOIN competencia.torneo torneo
                    ON torneo.codigo = datos.codigo_torneo

         INNER JOIN participantes.equipo equipo
                    ON equipo.sigla = datos.sigla_equipo

         CROSS JOIN administrador

ON CONFLICT (
    id_torneo,
    id_equipo
    )
    DO NOTHING;


-- ============================================================
-- NOMINAS DEL INTERFACULTATIVO UMSA
-- ============================================================

WITH administrador AS (SELECT id_usuario
                       FROM seguridad.usuario
                       WHERE numero_documento = '90000001'),
     torneo AS (SELECT id_torneo
                FROM competencia.torneo
                WHERE codigo = 'UMSA-FUT-2026')
INSERT
INTO competencia.jugador_inscripcion (id_inscripcion,
                                      id_jugador,
                                      id_jugador_equipo,
                                      id_estado_jugador_inscripcion,
                                      numero_camiseta,
                                      es_capitan,
                                      es_delegado,
                                      registrado_por,
                                      observaciones)
SELECT inscripcion.id_inscripcion,
       membresia.id_jugador,
       membresia.id_jugador_equipo,

       pg_temp.obtener_id_catalogo(
               'catalogo.estado_jugador_inscripcion'::REGCLASS,
               'id_estado_jugador_inscripcion',
               ARRAY [
                   'HABILITADO',
                   'ACTIVO',
                   'INSCRITO',
                   'APROBADO'
                   ]
       )::SMALLINT,

       membresia.numero_camiseta,
       membresia.es_delegado,
       membresia.es_delegado,
       administrador.id_usuario,

       'Nomina oficial del Interfacultativo UMSA'

FROM torneo

         INNER JOIN competencia.inscripcion inscripcion
                    ON inscripcion.id_torneo = torneo.id_torneo

         INNER JOIN participantes.jugador_equipo membresia
                    ON membresia.id_equipo = inscripcion.id_equipo
                        AND membresia.fecha_fin IS NULL

         CROSS JOIN administrador

WHERE NOT EXISTS (SELECT 1
                  FROM competencia.jugador_inscripcion existente
                  WHERE existente.id_inscripcion =
                        inscripcion.id_inscripcion
                    AND existente.id_jugador =
                        membresia.id_jugador);


-- ============================================================
-- PAGOS DEL INTERFACULTATIVO
-- Seis pagos completos y dos pagos parciales.
-- ============================================================

WITH administrador AS (SELECT id_usuario
                       FROM seguridad.usuario
                       WHERE numero_documento = '90000001'),
     pagos AS (SELECT inscripcion.id_inscripcion,
                      equipo.sigla,
                      torneo.costo_inscripcion,

                      ROW_NUMBER() OVER (
                          ORDER BY equipo.sigla
                          ) AS numero_orden

               FROM competencia.inscripcion inscripcion

                        INNER JOIN competencia.torneo torneo
                                   ON torneo.id_torneo =
                                      inscripcion.id_torneo

                        INNER JOIN participantes.equipo equipo
                                   ON equipo.id_equipo =
                                      inscripcion.id_equipo

               WHERE torneo.codigo = 'UMSA-FUT-2026')
INSERT
INTO finanzas.pago (id_inscripcion,
                    id_metodo_pago,
                    id_estado_pago,
                    monto,
                    moneda,
                    referencia,
                    fecha_verificacion,
                    registrado_por,
                    verificado_por,
                    observaciones)
SELECT pagos.id_inscripcion,

       pg_temp.obtener_id_catalogo(
               'catalogo.metodo_pago'::REGCLASS,
               'id_metodo_pago',
               ARRAY ['QR', 'TRANSFERENCIA', 'DEPOSITO']
       )::SMALLINT,

       pg_temp.obtener_id_catalogo(
               'catalogo.estado_pago'::REGCLASS,
               'id_estado_pago',
               ARRAY ['CONFIRMADO', 'VERIFICADO', 'APROBADO']
       )::SMALLINT,

       pagos.costo_inscripcion,

       'BOB',
       'UMSA-PAGO-' || pagos.sigla,
       CURRENT_TIMESTAMP,
       administrador.id_usuario,
       administrador.id_usuario,

       'Pago completo confirmado'

FROM pagos
         CROSS JOIN administrador

ON CONFLICT (referencia)
WHERE referencia IS NOT NULL
DO NOTHING;


-- ============================================================
-- EQUIPOS EN GRUPOS DEL INTERFACULTATIVO
-- ============================================================

WITH administrador AS (SELECT id_usuario
                       FROM seguridad.usuario
                       WHERE numero_documento = '90000001'),
     datos (
            sigla,
            codigo_grupo,
            posicion
         ) AS (VALUES ('ING-UMSA', 'A', 1::SMALLINT),
                      ('CPN-UMSA', 'A', 2::SMALLINT),
                      ('MED-UMSA', 'A', 3::SMALLINT),
                      ('DER-UMSA', 'A', 4::SMALLINT),

                      ('ECO-UMSA', 'B', 1::SMALLINT),
                      ('HUM-UMSA', 'B', 2::SMALLINT),
                      ('ARQ-UMSA', 'B', 3::SMALLINT),
                      ('SOC-UMSA', 'B', 4::SMALLINT)),
     torneo AS (SELECT id_torneo
                FROM competencia.torneo
                WHERE codigo = 'UMSA-FUT-2026'),
     fase AS (SELECT fase.id_fase_torneo
              FROM competencia.fase_torneo fase
                       CROSS JOIN torneo
              WHERE fase.id_torneo = torneo.id_torneo
                AND fase.numero_orden = 1)
INSERT
INTO competencia.equipo_grupo (id_fase_torneo,
                               id_grupo_torneo,
                               id_inscripcion,
                               posicion_sorteo,
                               asignado_por,
                               observaciones)
SELECT fase.id_fase_torneo,
       grupo.id_grupo_torneo,
       inscripcion.id_inscripcion,
       datos.posicion,
       administrador.id_usuario,
       'Sorteo oficial del Interfacultativo UMSA'

FROM datos

         INNER JOIN participantes.equipo equipo
                    ON equipo.sigla = datos.sigla

         CROSS JOIN torneo
         CROSS JOIN fase
         CROSS JOIN administrador

         INNER JOIN competencia.inscripcion inscripcion
                    ON inscripcion.id_torneo = torneo.id_torneo
                        AND inscripcion.id_equipo = equipo.id_equipo

         INNER JOIN competencia.grupo_torneo grupo
                    ON grupo.id_fase_torneo =
                       fase.id_fase_torneo
                        AND grupo.codigo =
                            datos.codigo_grupo

ON CONFLICT (
    id_fase_torneo,
    id_inscripcion
    )
    DO NOTHING;


-- ============================================================
-- PREMIOS
-- ============================================================

INSERT INTO finanzas.premio (id_tipo_premio,
                             codigo,
                             nombre,
                             descripcion)
SELECT pg_temp.obtener_id_catalogo(
               'catalogo.tipo_premio'::REGCLASS,
               'id_tipo_premio',
               ARRAY ['ECONOMICO', 'TROFEO', 'MEDALLA']
       )::SMALLINT,

       'PREMIO_CAMPEON_UMSA_2026',
       'Premio al campeon Interfacultativo UMSA',
       'Trofeo, medallas y reconocimiento economico'

ON CONFLICT (codigo)
    DO NOTHING;


WITH administrador AS (SELECT id_usuario
                       FROM seguridad.usuario
                       WHERE numero_documento = '90000001')
INSERT
INTO finanzas.torneo_premio (id_torneo,
                             id_premio,
                             posicion_objetivo,
                             valor_economico,
                             moneda,
                             descripcion_entrega,
                             registrado_por)
SELECT torneo.id_torneo,
       premio.id_premio,
       1,
       2500.00,
       'BOB',
       'Trofeo, medallas y premio de Bs 2500',
       administrador.id_usuario

FROM competencia.torneo torneo

         CROSS JOIN finanzas.premio premio
         CROSS JOIN administrador

WHERE torneo.codigo = 'UMSA-FUT-2026'
  AND premio.codigo = 'PREMIO_CAMPEON_UMSA_2026'

ON CONFLICT (
    id_torneo,
    id_premio,
    posicion_objetivo
    )
    DO NOTHING;


COMMIT;


-- ============================================================
-- RESUMEN
-- ============================================================

SELECT 'Usuarios nuevos' AS elemento,
       COUNT(*)          AS cantidad
FROM seguridad.usuario
WHERE numero_documento
          BETWEEN '90000001' AND '91000040'

UNION ALL

SELECT 'Jugadores UMSA',
       COUNT(*)
FROM participantes.jugador jugador
         INNER JOIN seguridad.usuario usuario
                    ON usuario.id_usuario = jugador.id_usuario
WHERE usuario.numero_documento
          BETWEEN '91000001' AND '91000040'

UNION ALL

SELECT 'Equipos',
       COUNT(*)
FROM participantes.equipo

UNION ALL

SELECT 'Torneos',
       COUNT(*)
FROM competencia.torneo

UNION ALL

SELECT 'Inscripciones',
       COUNT(*)
FROM competencia.inscripcion

UNION ALL

SELECT 'Pagos',
       COUNT(*)
FROM finanzas.pago

ORDER BY elemento;


SELECT torneo.codigo,
       torneo.nombre,
       deporte.nombre AS deporte,
       formato.codigo AS formato,
       estado.codigo  AS estado,
       torneo.fecha_inicio_torneo,
       torneo.fecha_fin_torneo

FROM competencia.torneo torneo

         INNER JOIN competencia.deporte deporte
                    ON deporte.id_deporte = torneo.id_deporte

         INNER JOIN catalogo.formato_torneo formato
                    ON formato.id_formato_torneo =
                       torneo.id_formato_torneo

         INNER JOIN catalogo.estado_torneo estado
                    ON estado.id_estado_torneo =
                       torneo.id_estado_torneo

WHERE torneo.codigo IN (
                        'UMSA-FUT-2026',
                        'COPA-INVIERNO-FUTSAL-2026',
                        'LIGA-BASKET-2026',
                        'COPA-RECTORA-VOLEY-2026',
                        'OPEN-TENIS-LP-2026',
                        'RELAMPAGO-MIXTO-2026',
                        'LIGA-BARRIAL-FUT-2026'
    )

ORDER BY torneo.fecha_inicio_torneo;