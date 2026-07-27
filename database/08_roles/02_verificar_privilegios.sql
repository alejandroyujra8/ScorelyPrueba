\set ON_ERROR_STOP on

\pset border 2
\pset null '(null)'

\echo ''
\echo '====================================================='
\echo ' SCORELY - VERIFICACION DE ROLES Y PRIVILEGIOS'
\echo '====================================================='
\echo ''

-- =====================================================
-- 1. USUARIO Y BASE ACTUAL
-- =====================================================

SELECT
    current_database() AS base_datos,
    current_user AS usuario_ejecutor,
    current_timestamp AS fecha_verificacion;

-- =====================================================
-- 2. ROLES CREADOS
-- =====================================================

SELECT
    rolname AS rol,
    rolcanlogin AS puede_iniciar_sesion,
    rolsuper AS es_superusuario,
    rolcreatedb AS puede_crear_bd,
    rolcreaterole AS puede_crear_roles,
    rolconnlimit AS limite_conexiones
FROM pg_roles
WHERE rolname LIKE 'rol_scorely_%'
   OR rolname LIKE 'usr_scorely_%'
ORDER BY rolcanlogin, rolname;

-- =====================================================
-- 3. MEMBRESIAS ENTRE ROLES
-- =====================================================

SELECT
    miembro.rolname AS usuario_o_rol,
    otorgado.rolname AS rol_otorgado
FROM pg_auth_members membresia
INNER JOIN pg_roles miembro
    ON miembro.oid = membresia.member
INNER JOIN pg_roles otorgado
    ON otorgado.oid = membresia.roleid
WHERE miembro.rolname LIKE '%scorely%'
   OR otorgado.rolname LIKE '%scorely%'
ORDER BY miembro.rolname, otorgado.rolname;

-- =====================================================
-- 4. PRIVILEGIO DE CONEXION
-- =====================================================

SELECT
    usuario,
    has_database_privilege(
        usuario,
        current_database(),
        'CONNECT'
    ) AS puede_conectarse
FROM (
    VALUES
        ('usuario_fastapi'),
        ('usr_scorely_consulta'),
        ('usr_scorely_auditor')
) AS usuarios(usuario);

-- =====================================================
-- 5. PRIVILEGIOS SOBRE ESQUEMAS
-- =====================================================

SELECT
    usuario,
    esquema,
    has_schema_privilege(
        usuario,
        esquema,
        'USAGE'
    ) AS puede_usar_esquema,
    has_schema_privilege(
        usuario,
        esquema,
        'CREATE'
    ) AS puede_crear_objetos
FROM (
    VALUES
        ('usuario_fastapi'),
        ('usr_scorely_consulta'),
        ('usr_scorely_auditor')
) AS usuarios(usuario)
CROSS JOIN (
    VALUES
        ('catalogo'),
        ('seguridad'),
        ('participantes'),
        ('competencia'),
        ('finanzas'),
        ('auditoria'),
        ('reportes')
) AS esquemas(esquema)
ORDER BY usuario, esquema;

-- =====================================================
-- 6. PRIVILEGIOS SOBRE UNA TABLA DE CADA ESQUEMA
-- =====================================================

WITH primeras_tablas AS (
    SELECT DISTINCT ON (table_schema)
        table_schema,
        table_name
    FROM information_schema.tables
    WHERE table_schema IN (
        'catalogo',
        'seguridad',
        'participantes',
        'competencia',
        'finanzas',
        'auditoria',
        'reportes'
    )
    ORDER BY table_schema, table_name
),
usuarios AS (
    SELECT usuario
    FROM (
        VALUES
            ('usuario_fastapi'),
            ('usr_scorely_consulta'),
            ('usr_scorely_auditor')
    ) AS lista(usuario)
)
SELECT
    usuarios.usuario,
    primeras_tablas.table_schema AS esquema,
    primeras_tablas.table_name AS tabla,

    has_table_privilege(
        usuarios.usuario,
        format(
            '%I.%I',
            primeras_tablas.table_schema,
            primeras_tablas.table_name
        ),
        'SELECT'
    ) AS puede_select,

    has_table_privilege(
        usuarios.usuario,
        format(
            '%I.%I',
            primeras_tablas.table_schema,
            primeras_tablas.table_name
        ),
        'INSERT'
    ) AS puede_insert,

    has_table_privilege(
        usuarios.usuario,
        format(
            '%I.%I',
            primeras_tablas.table_schema,
            primeras_tablas.table_name
        ),
        'UPDATE'
    ) AS puede_update,

    has_table_privilege(
        usuarios.usuario,
        format(
            '%I.%I',
            primeras_tablas.table_schema,
            primeras_tablas.table_name
        ),
        'DELETE'
    ) AS puede_delete

FROM usuarios
CROSS JOIN primeras_tablas
ORDER BY usuarios.usuario, primeras_tablas.table_schema;

-- =====================================================
-- 7. SEARCH PATH CONFIGURADO
-- =====================================================

SELECT
    rolname AS usuario,
    rolconfig AS configuracion
FROM pg_roles
WHERE rolname IN (
    'usuario_fastapi',
    'usr_scorely_consulta',
    'usr_scorely_auditor'
)
ORDER BY rolname;

\echo ''
\echo '====================================================='
\echo ' VERIFICACION FINALIZADA'
\echo '====================================================='
\echo ''