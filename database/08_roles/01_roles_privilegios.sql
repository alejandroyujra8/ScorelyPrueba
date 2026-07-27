\set ON_ERROR_STOP on

\echo ''
\echo '====================================================='
\echo ' SCORELY - CREACION DE ROLES Y PRIVILEGIOS DCL'
\echo '====================================================='
\echo ''

SELECT
    current_database() AS base_datos,
    current_user AS usuario_ejecutor;

-- =====================================================
-- 1. CREACION DE ROLES GRUPALES
-- =====================================================
-- Los roles grupales no pueden iniciar sesion.
-- Se utilizan para agrupar privilegios.

DO
$$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_roles
        WHERE rolname = 'rol_scorely_lectura'
    ) THEN
        CREATE ROLE rol_scorely_lectura
            NOLOGIN
            NOSUPERUSER
            NOCREATEDB
            NOCREATEROLE
            NOREPLICATION
            INHERIT;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_roles
        WHERE rolname = 'rol_scorely_operacion'
    ) THEN
        CREATE ROLE rol_scorely_operacion
            NOLOGIN
            NOSUPERUSER
            NOCREATEDB
            NOCREATEROLE
            NOREPLICATION
            INHERIT;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_roles
        WHERE rolname = 'rol_scorely_auditoria'
    ) THEN
        CREATE ROLE rol_scorely_auditoria
            NOLOGIN
            NOSUPERUSER
            NOCREATEDB
            NOCREATEROLE
            NOREPLICATION
            INHERIT;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_roles
        WHERE rolname = 'rol_scorely_api'
    ) THEN
        CREATE ROLE rol_scorely_api
            NOLOGIN
            NOSUPERUSER
            NOCREATEDB
            NOCREATEROLE
            NOREPLICATION
            INHERIT;
    END IF;
END;
$$;

-- =====================================================
-- 2. CREACION DE USUARIOS LOGIN
-- =====================================================

DO
$$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_roles
        WHERE rolname = 'usuario_fastapi'
    ) THEN
        CREATE ROLE usuario_fastapi
            LOGIN
            NOSUPERUSER
            NOCREATEDB
            NOCREATEROLE
            NOREPLICATION
            INHERIT
            CONNECTION LIMIT 20;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_roles
        WHERE rolname = 'usr_scorely_consulta'
    ) THEN
        CREATE ROLE usr_scorely_consulta
            LOGIN
            NOSUPERUSER
            NOCREATEDB
            NOCREATEROLE
            NOREPLICATION
            INHERIT
            CONNECTION LIMIT 5;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_roles
        WHERE rolname = 'usr_scorely_auditor'
    ) THEN
        CREATE ROLE usr_scorely_auditor
            LOGIN
            NOSUPERUSER
            NOCREATEDB
            NOCREATEROLE
            NOREPLICATION
            INHERIT
            CONNECTION LIMIT 5;
    END IF;
END;
$$;

-- Garantizar atributos seguros incluso al volver a ejecutar el script.

ALTER ROLE usuario_fastapi
    WITH LOGIN
    NOSUPERUSER
    NOCREATEDB
    NOCREATEROLE
    NOREPLICATION
    INHERIT
    CONNECTION LIMIT 20;

ALTER ROLE usr_scorely_consulta
    WITH LOGIN
    NOSUPERUSER
    NOCREATEDB
    NOCREATEROLE
    NOREPLICATION
    INHERIT
    CONNECTION LIMIT 5;

ALTER ROLE usr_scorely_auditor
    WITH LOGIN
    NOSUPERUSER
    NOCREATEDB
    NOCREATEROLE
    NOREPLICATION
    INHERIT
    CONNECTION LIMIT 5;

-- =====================================================
-- 3. CONTRASENAS
-- =====================================================
-- Las claves se solicitan al ejecutar el script con psql.
-- No quedan guardadas dentro del repositorio.

\prompt 'Clave para usuario_fastapi: ' clave_api
\prompt 'Clave para usr_scorely_consulta: ' clave_consulta
\prompt 'Clave para usr_scorely_auditor: ' clave_auditor
ALTER ROLE usuario_fastapi
    PASSWORD :'clave_api';

ALTER ROLE usr_scorely_consulta
    PASSWORD :'clave_consulta';

ALTER ROLE usr_scorely_auditor
    PASSWORD :'clave_auditor';

-- =====================================================
-- 4. HERENCIA ENTRE ROLES
-- =====================================================

-- Operacion incluye los permisos de lectura.
GRANT rol_scorely_lectura
TO rol_scorely_operacion;

-- El usuario de FastAPI puede operar el sistema
-- y consultar la auditoria.
GRANT rol_scorely_operacion,
      rol_scorely_auditoria
TO rol_scorely_api;

-- Asignar roles grupales a usuarios login.
GRANT rol_scorely_api
TO usuario_fastapi;

GRANT rol_scorely_lectura
TO usr_scorely_consulta;

GRANT rol_scorely_auditoria
TO usr_scorely_auditor;

-- =====================================================
-- 5. PRIVILEGIOS SOBRE LA BASE DE DATOS
-- =====================================================

GRANT CONNECT
ON DATABASE sistema_torneos_db
TO rol_scorely_lectura,
   rol_scorely_operacion,
   rol_scorely_auditoria,
   rol_scorely_api;

-- Evita que cualquier usuario cree objetos libremente
-- dentro del esquema public.
REVOKE CREATE
ON SCHEMA public
FROM PUBLIC;

-- =====================================================
-- 6. RETIRAR PRIVILEGIOS GENERALES DE PUBLIC
-- =====================================================

REVOKE ALL
ON SCHEMA
    catalogo,
    seguridad,
    participantes,
    competencia,
    finanzas,
    auditoria,
    reportes
FROM PUBLIC;

REVOKE ALL PRIVILEGES
ON ALL TABLES IN SCHEMA
    catalogo,
    seguridad,
    participantes,
    competencia,
    finanzas,
    auditoria,
    reportes
FROM PUBLIC;

REVOKE ALL PRIVILEGES
ON ALL SEQUENCES IN SCHEMA
    catalogo,
    seguridad,
    participantes,
    competencia,
    finanzas,
    auditoria,
    reportes
FROM PUBLIC;

REVOKE EXECUTE
ON ALL FUNCTIONS IN SCHEMA
    catalogo,
    seguridad,
    participantes,
    competencia,
    finanzas,
    auditoria,
    reportes
FROM PUBLIC;

REVOKE EXECUTE
ON ALL PROCEDURES IN SCHEMA
    catalogo,
    seguridad,
    participantes,
    competencia,
    finanzas,
    auditoria,
    reportes
FROM PUBLIC;

-- =====================================================
-- 7. ROL DE SOLO LECTURA
-- =====================================================
-- No se le permite acceder directamente al esquema
-- seguridad ni al esquema auditoria.

GRANT USAGE
ON SCHEMA
    catalogo,
    participantes,
    competencia,
    finanzas,
    reportes
TO rol_scorely_lectura;

GRANT SELECT
ON ALL TABLES IN SCHEMA
    catalogo,
    participantes,
    competencia,
    finanzas,
    reportes
TO rol_scorely_lectura;

-- Puede ejecutar funciones de consulta y reportes.

GRANT EXECUTE
ON ALL FUNCTIONS IN SCHEMA reportes
TO rol_scorely_lectura;

GRANT EXECUTE
ON ALL PROCEDURES IN SCHEMA reportes
TO rol_scorely_lectura;

-- =====================================================
-- 8. ROL DE OPERACION
-- =====================================================

GRANT USAGE
ON SCHEMA
    catalogo,
    seguridad,
    participantes,
    competencia,
    finanzas,
    auditoria
TO rol_scorely_operacion;

-- Operaciones CRUD en los modulos principales.

GRANT SELECT, INSERT, UPDATE, DELETE
ON ALL TABLES IN SCHEMA
    catalogo,
    participantes,
    competencia,
    finanzas
TO rol_scorely_operacion;

-- Seguridad permite consultar, crear y modificar usuarios,
-- pero no eliminarlos fisicamente.

GRANT SELECT, INSERT, UPDATE
ON ALL TABLES IN SCHEMA seguridad
TO rol_scorely_operacion;

-- Auditoria puede ser consultada e insertar registros,
-- pero no modificarlos ni eliminarlos.

GRANT SELECT, INSERT
ON ALL TABLES IN SCHEMA auditoria
TO rol_scorely_operacion;

-- Permitir utilizar IDs autogenerados.

GRANT USAGE, SELECT
ON ALL SEQUENCES IN SCHEMA
    catalogo,
    seguridad,
    participantes,
    competencia,
    finanzas,
    auditoria
TO rol_scorely_operacion;

-- =====================================================
-- 9. ROL DE AUDITORIA
-- =====================================================

GRANT USAGE
ON SCHEMA
    auditoria,
    reportes
TO rol_scorely_auditoria;

GRANT SELECT
ON ALL TABLES IN SCHEMA
    auditoria,
    reportes
TO rol_scorely_auditoria;

GRANT EXECUTE
ON ALL FUNCTIONS IN SCHEMA
    auditoria,
    reportes
TO rol_scorely_auditoria;

GRANT EXECUTE
ON ALL PROCEDURES IN SCHEMA
    auditoria,
    reportes
TO rol_scorely_auditoria;

-- =====================================================
-- 10. ROL UTILIZADO POR FASTAPI
-- =====================================================

GRANT USAGE
ON SCHEMA
    catalogo,
    seguridad,
    participantes,
    competencia,
    finanzas,
    auditoria,
    reportes
TO rol_scorely_api;

GRANT EXECUTE
ON ALL FUNCTIONS IN SCHEMA
    catalogo,
    seguridad,
    participantes,
    competencia,
    finanzas,
    auditoria,
    reportes
TO rol_scorely_api;

GRANT EXECUTE
ON ALL PROCEDURES IN SCHEMA
    catalogo,
    seguridad,
    participantes,
    competencia,
    finanzas,
    auditoria,
    reportes
TO rol_scorely_api;

-- =====================================================
-- 11. PRIVILEGIOS PREDETERMINADOS
-- =====================================================
-- Estos privilegios se aplicaran a objetos nuevos creados
-- posteriormente por el usuario que ejecuta este script.
-- Debe ejecutarse como propietario de los objetos,
-- normalmente postgres.

-- Objetos futuros para lectura.

ALTER DEFAULT PRIVILEGES
IN SCHEMA catalogo
GRANT SELECT ON TABLES
TO rol_scorely_lectura;

ALTER DEFAULT PRIVILEGES
IN SCHEMA participantes
GRANT SELECT ON TABLES
TO rol_scorely_lectura;

ALTER DEFAULT PRIVILEGES
IN SCHEMA competencia
GRANT SELECT ON TABLES
TO rol_scorely_lectura;

ALTER DEFAULT PRIVILEGES
IN SCHEMA finanzas
GRANT SELECT ON TABLES
TO rol_scorely_lectura;

ALTER DEFAULT PRIVILEGES
IN SCHEMA reportes
GRANT SELECT ON TABLES
TO rol_scorely_lectura;

-- Objetos futuros para operacion.

ALTER DEFAULT PRIVILEGES
IN SCHEMA catalogo
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES
TO rol_scorely_operacion;

ALTER DEFAULT PRIVILEGES
IN SCHEMA participantes
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES
TO rol_scorely_operacion;

ALTER DEFAULT PRIVILEGES
IN SCHEMA competencia
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES
TO rol_scorely_operacion;

ALTER DEFAULT PRIVILEGES
IN SCHEMA finanzas
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES
TO rol_scorely_operacion;

ALTER DEFAULT PRIVILEGES
IN SCHEMA seguridad
GRANT SELECT, INSERT, UPDATE ON TABLES
TO rol_scorely_operacion;

ALTER DEFAULT PRIVILEGES
IN SCHEMA auditoria
GRANT SELECT, INSERT ON TABLES
TO rol_scorely_operacion;

-- Secuencias futuras.

ALTER DEFAULT PRIVILEGES
IN SCHEMA catalogo
GRANT USAGE, SELECT ON SEQUENCES
TO rol_scorely_operacion;

ALTER DEFAULT PRIVILEGES
IN SCHEMA seguridad
GRANT USAGE, SELECT ON SEQUENCES
TO rol_scorely_operacion;

ALTER DEFAULT PRIVILEGES
IN SCHEMA participantes
GRANT USAGE, SELECT ON SEQUENCES
TO rol_scorely_operacion;

ALTER DEFAULT PRIVILEGES
IN SCHEMA competencia
GRANT USAGE, SELECT ON SEQUENCES
TO rol_scorely_operacion;

ALTER DEFAULT PRIVILEGES
IN SCHEMA finanzas
GRANT USAGE, SELECT ON SEQUENCES
TO rol_scorely_operacion;

ALTER DEFAULT PRIVILEGES
IN SCHEMA auditoria
GRANT USAGE, SELECT ON SEQUENCES
TO rol_scorely_operacion;

-- Funciones futuras.

ALTER DEFAULT PRIVILEGES
IN SCHEMA catalogo
GRANT EXECUTE ON FUNCTIONS
TO rol_scorely_api;

ALTER DEFAULT PRIVILEGES
IN SCHEMA seguridad
GRANT EXECUTE ON FUNCTIONS
TO rol_scorely_api;

ALTER DEFAULT PRIVILEGES
IN SCHEMA participantes
GRANT EXECUTE ON FUNCTIONS
TO rol_scorely_api;

ALTER DEFAULT PRIVILEGES
IN SCHEMA competencia
GRANT EXECUTE ON FUNCTIONS
TO rol_scorely_api;

ALTER DEFAULT PRIVILEGES
IN SCHEMA finanzas
GRANT EXECUTE ON FUNCTIONS
TO rol_scorely_api;

ALTER DEFAULT PRIVILEGES
IN SCHEMA auditoria
GRANT EXECUTE ON FUNCTIONS
TO rol_scorely_api;

ALTER DEFAULT PRIVILEGES
IN SCHEMA reportes
GRANT EXECUTE ON FUNCTIONS
TO rol_scorely_api;

-- =====================================================
-- 12. SEARCH PATH DE CADA USUARIO
-- =====================================================

ALTER ROLE usuario_fastapi
IN DATABASE sistema_torneos_db
SET search_path =
    seguridad,
    catalogo,
    participantes,
    competencia,
    finanzas,
    auditoria,
    reportes,
    public;

ALTER ROLE usr_scorely_consulta
IN DATABASE sistema_torneos_db
SET search_path =
    catalogo,
    participantes,
    competencia,
    finanzas,
    reportes,
    public;

ALTER ROLE usr_scorely_auditor
IN DATABASE sistema_torneos_db
SET search_path =
    auditoria,
    reportes,
    public;

\echo ''
\echo '====================================================='
\echo ' DCL CREADO CORRECTAMENTE'
\echo '====================================================='
\echo ''