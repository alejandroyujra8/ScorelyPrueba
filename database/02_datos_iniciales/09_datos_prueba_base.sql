\set ON_ERROR_STOP on

BEGIN;

SELECT SET_CONFIG(
    'app.request_id',
    'CARGA-DATOS-DEMO-BASE-001',
    TRUE
);

SELECT SET_CONFIG(
    'app.ip_cliente',
    '127.0.0.1',
    TRUE
);


-- =========================================================
-- USUARIOS DE PRUEBA
-- Contrasenia de referencia futura: Demo123*
-- =========================================================

WITH datos_usuario (
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
) AS (
    VALUES
        (
            '7000001',
            'Andrea',
            'Rojas',
            'Mamani',
            DATE '1995-03-10',
            'F',
            'admin.demo@torneos.test',
            '76500001',
            'Calle Demo 101',
            'Centro'
        ),
        (
            '7000002',
            'Marcos',
            'Quispe',
            'Flores',
            DATE '1992-05-15',
            'M',
            'organizador.demo@torneos.test',
            '76500002',
            'Calle Demo 102',
            'Sopocachi'
        ),
        (
            '7000003',
            'Luis',
            'Flores',
            'Condori',
            DATE '1990-08-21',
            'M',
            'arbitro.demo@torneos.test',
            '76500003',
            'Calle Demo 103',
            'Miraflores'
        ),

        (
            '7100001',
            'Carlos',
            'Mendoza',
            'Rojas',
            DATE '2001-01-12',
            'M',
            'titanes1@torneos.test',
            '76500101',
            'Zona Norte 1',
            'Zona Norte'
        ),
        (
            '7100002',
            'Jorge',
            'Paredes',
            'Mamani',
            DATE '2000-02-14',
            'M',
            'titanes2@torneos.test',
            '76500102',
            'Zona Norte 2',
            'Zona Norte'
        ),
        (
            '7100003',
            'Miguel',
            'Lopez',
            'Choque',
            DATE '2002-03-16',
            'M',
            'titanes3@torneos.test',
            '76500103',
            'Zona Norte 3',
            'Zona Norte'
        ),
        (
            '7100004',
            'Daniel',
            'Vargas',
            'Cruz',
            DATE '2001-04-18',
            'M',
            'titanes4@torneos.test',
            '76500104',
            'Zona Norte 4',
            'Zona Norte'
        ),
        (
            '7100005',
            'Pedro',
            'Salazar',
            'Luna',
            DATE '2000-05-20',
            'M',
            'titanes5@torneos.test',
            '76500105',
            'Zona Norte 5',
            'Zona Norte'
        ),

        (
            '7200001',
            'Alejandro',
            'Torrez',
            'Ramos',
            DATE '2001-06-22',
            'M',
            'halcones1@torneos.test',
            '76500201',
            'Zona Sur 1',
            'Zona Sur'
        ),
        (
            '7200002',
            'Rodrigo',
            'Gutierrez',
            'Poma',
            DATE '2002-07-24',
            'M',
            'halcones2@torneos.test',
            '76500202',
            'Zona Sur 2',
            'Zona Sur'
        ),
        (
            '7200003',
            'Fernando',
            'Castro',
            'Mendoza',
            DATE '2000-08-26',
            'M',
            'halcones3@torneos.test',
            '76500203',
            'Zona Sur 3',
            'Zona Sur'
        ),
        (
            '7200004',
            'Ricardo',
            'Soria',
            'Quisbert',
            DATE '2001-09-28',
            'M',
            'halcones4@torneos.test',
            '76500204',
            'Zona Sur 4',
            'Zona Sur'
        ),
        (
            '7200005',
            'Gabriel',
            'Nina',
            'Flores',
            DATE '2002-10-30',
            'M',
            'halcones5@torneos.test',
            '76500205',
            'Zona Sur 5',
            'Zona Sur'
        )
)
INSERT INTO seguridad.usuario (
    id_tipo_documento,
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
    id_estado_usuario
)
SELECT
    tipo_documento.id_tipo_documento,
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

    estado_usuario.id_estado_usuario

FROM datos_usuario datos

INNER JOIN catalogo.tipo_documento tipo_documento
    ON tipo_documento.codigo = 'CI'

INNER JOIN catalogo.estado_usuario estado_usuario
    ON estado_usuario.codigo = 'ACTIVO'

ON CONFLICT (
    id_tipo_documento,
    numero_documento
)
DO NOTHING;


SELECT SET_CONFIG(
    'app.usuario_id',
    usuario.id_usuario::TEXT,
    TRUE
)
FROM seguridad.usuario usuario
WHERE usuario.numero_documento = '7000001';


-- =========================================================
-- ROLES GENERALES
-- =========================================================

WITH asignaciones (
    numero_documento,
    codigo_rol
) AS (
    VALUES
        ('7000001', 'ADMINISTRADOR'),
        ('7000002', 'ORGANIZADOR'),
        ('7000003', 'ARBITRO'),

        ('7100001', 'JUGADOR'),
        ('7100002', 'JUGADOR'),
        ('7100003', 'JUGADOR'),
        ('7100004', 'JUGADOR'),
        ('7100005', 'JUGADOR'),

        ('7200001', 'JUGADOR'),
        ('7200002', 'JUGADOR'),
        ('7200003', 'JUGADOR'),
        ('7200004', 'JUGADOR'),
        ('7200005', 'JUGADOR')
)
INSERT INTO seguridad.usuario_rol (
    id_usuario,
    id_rol,
    asignado_por
)
SELECT
    usuario.id_usuario,
    rol.id_rol,
    administrador.id_usuario

FROM asignaciones asignacion

INNER JOIN seguridad.usuario usuario
    ON usuario.numero_documento =
       asignacion.numero_documento

INNER JOIN seguridad.rol rol
    ON rol.codigo =
       asignacion.codigo_rol

CROSS JOIN seguridad.usuario administrador

WHERE administrador.numero_documento = '7000001'

  AND NOT EXISTS (
      SELECT 1
      FROM seguridad.usuario_rol usuario_rol
      WHERE usuario_rol.id_usuario =
            usuario.id_usuario
        AND usuario_rol.id_rol =
            rol.id_rol
        AND usuario_rol.activo = TRUE
        AND usuario_rol.fecha_fin IS NULL
  );


-- =========================================================
-- PERFILES
-- =========================================================

INSERT INTO participantes.organizador (
    id_usuario,
    institucion,
    cargo,
    anios_experiencia,
    id_estado_perfil,
    observaciones
)
SELECT
    usuario.id_usuario,
    'Universidad Demo',
    'Coordinador deportivo',
    5,
    estado.id_estado_perfil,
    'Organizador utilizado para las pruebas'

FROM seguridad.usuario usuario

INNER JOIN catalogo.estado_perfil_deportivo estado
    ON estado.codigo = 'ACTIVO'

WHERE usuario.numero_documento = '7000002'

ON CONFLICT (id_usuario)
DO NOTHING;


INSERT INTO participantes.arbitro (
    id_usuario,
    numero_licencia,
    nivel,
    anios_experiencia,
    id_estado_perfil,
    observaciones
)
SELECT
    usuario.id_usuario,
    'ARB-DEMO-001',
    'Departamental',
    6,
    estado.id_estado_perfil,
    'Arbitro utilizado para las pruebas'

FROM seguridad.usuario usuario

INNER JOIN catalogo.estado_perfil_deportivo estado
    ON estado.codigo = 'ACTIVO'

WHERE usuario.numero_documento = '7000003'

ON CONFLICT (id_usuario)
DO NOTHING;


INSERT INTO participantes.jugador (
    id_usuario,
    alias_deportivo,
    id_estado_perfil,
    observaciones
)
SELECT
    usuario.id_usuario,
    CONCAT(
        'Jugador ',
        usuario.numero_documento
    ),
    estado.id_estado_perfil,
    'Jugador utilizado para las pruebas'

FROM seguridad.usuario usuario

INNER JOIN catalogo.estado_perfil_deportivo estado
    ON estado.codigo = 'ACTIVO'

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
)

ON CONFLICT (id_usuario)
DO NOTHING;


-- =========================================================
-- EQUIPOS
-- =========================================================

INSERT INTO participantes.equipo (
    nombre,
    sigla,
    fecha_fundacion,
    descripcion,
    id_estado_equipo,
    creado_por
)
SELECT
    datos.nombre,
    datos.sigla,
    datos.fecha_fundacion,
    datos.descripcion,
    estado.id_estado_equipo,
    administrador.id_usuario

FROM (
    VALUES
        (
            'Titanes Futsal',
            'TIT',
            DATE '2020-01-10',
            'Equipo de prueba Titanes'
        ),
        (
            'Halcones Futsal',
            'HAL',
            DATE '2021-02-15',
            'Equipo de prueba Halcones'
        )
) AS datos (
    nombre,
    sigla,
    fecha_fundacion,
    descripcion
)

INNER JOIN catalogo.estado_equipo estado
    ON estado.codigo = 'ACTIVO'

CROSS JOIN seguridad.usuario administrador

WHERE administrador.numero_documento = '7000001'

ON CONFLICT (nombre)
DO NOTHING;


-- =========================================================
-- MEMBRESIAS DE JUGADORES
-- =========================================================

WITH membresias (
    numero_documento,
    nombre_equipo,
    numero_camiseta,
    posicion,
    es_delegado
) AS (
    VALUES
        (
            '7100001',
            'Titanes Futsal',
            1::SMALLINT,
            'Arquero',
            TRUE
        ),
        (
            '7100002',
            'Titanes Futsal',
            4::SMALLINT,
            'Cierre',
            FALSE
        ),
        (
            '7100003',
            'Titanes Futsal',
            7::SMALLINT,
            'Ala',
            FALSE
        ),
        (
            '7100004',
            'Titanes Futsal',
            9::SMALLINT,
            'Pivot',
            FALSE
        ),
        (
            '7100005',
            'Titanes Futsal',
            10::SMALLINT,
            'Ala',
            FALSE
        ),

        (
            '7200001',
            'Halcones Futsal',
            1::SMALLINT,
            'Arquero',
            TRUE
        ),
        (
            '7200002',
            'Halcones Futsal',
            3::SMALLINT,
            'Cierre',
            FALSE
        ),
        (
            '7200003',
            'Halcones Futsal',
            6::SMALLINT,
            'Ala',
            FALSE
        ),
        (
            '7200004',
            'Halcones Futsal',
            8::SMALLINT,
            'Pivot',
            FALSE
        ),
        (
            '7200005',
            'Halcones Futsal',
            11::SMALLINT,
            'Ala',
            FALSE
        )
)
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
SELECT
    jugador.id_usuario,
    equipo.id_equipo,
    DATE '2026-01-01',
    membresia.numero_camiseta,
    membresia.posicion,
    membresia.es_delegado,
    estado.id_estado_membresia,
    administrador.id_usuario,
    'Membresia inicial de prueba'

FROM membresias membresia

INNER JOIN seguridad.usuario jugador
    ON jugador.numero_documento =
       membresia.numero_documento

INNER JOIN participantes.equipo equipo
    ON equipo.nombre =
       membresia.nombre_equipo

INNER JOIN catalogo.estado_membresia estado
    ON estado.codigo = 'ACTIVA'

CROSS JOIN seguridad.usuario administrador

WHERE administrador.numero_documento = '7000001'

  AND NOT EXISTS (
      SELECT 1
      FROM participantes.jugador_equipo existente
      WHERE existente.id_jugador =
            jugador.id_usuario
        AND existente.id_equipo =
            equipo.id_equipo
        AND existente.fecha_fin IS NULL
  );


-- =========================================================
-- LUGAR
-- =========================================================

INSERT INTO competencia.lugar (
    nombre,
    direccion,
    zona,
    ciudad,
    capacidad,
    tipo_superficie,
    activo
)
SELECT
    'Coliseo Demo Central',
    'Avenida Deportiva 500',
    'Centro',
    'La Paz',
    800,
    'Parquet',
    TRUE

WHERE NOT EXISTS (
    SELECT 1
    FROM competencia.lugar lugar
    WHERE LOWER(lugar.nombre) =
          LOWER('Coliseo Demo Central')
      AND LOWER(lugar.direccion) =
          LOWER('Avenida Deportiva 500')
);


-- =========================================================
-- PREMIO GENERAL
-- =========================================================

INSERT INTO finanzas.premio (
    id_tipo_premio,
    codigo,
    nombre,
    descripcion
)
SELECT
    tipo.id_tipo_premio,
    'PREMIO_CAMPEON_DEMO',
    'Premio economico al campeon demo',
    'Premio de prueba para el equipo campeon'

FROM catalogo.tipo_premio tipo

WHERE tipo.codigo = 'ECONOMICO'

ON CONFLICT (codigo)
DO NOTHING;

COMMIT;