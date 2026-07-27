\pset pager off

-- ON_ERROR_STOP debe estar desactivado porque provocaremos
-- intencionalmente un error y luego recuperaremos la transaccion.
\set ON_ERROR_STOP off

\echo ''
\echo '========================================================='
\echo 'INICIO DE LA TRANSACCION'
\echo '========================================================='

BEGIN;

SELECT SET_CONFIG(
    'app.request_id',
    'PRUEBA-SAVEPOINT-001',
    TRUE
);


INSERT INTO competencia.regla (
    codigo,
    nombre,
    descripcion,
    categoria
)
VALUES (
    'REGLA_SAVEPOINT_001',
    'Regla temporal para savepoint',
    'Esta regla no debe permanecer en la base de datos',
    'GENERAL'
);


\echo ''
\echo 'Registro creado antes del SAVEPOINT:'

SELECT
    id_regla,
    codigo,
    nombre,
    categoria
FROM competencia.regla
WHERE codigo = 'REGLA_SAVEPOINT_001';


SAVEPOINT antes_del_error;


\echo ''
\echo '========================================================='
\echo 'OPERACION INVALIDA INTENCIONAL'
\echo '========================================================='

-- Esta categoria no esta permitida por el CHECK:
-- ck_regla_categoria.
UPDATE competencia.regla
SET categoria = 'CATEGORIA_INVALIDA'
WHERE codigo = 'REGLA_SAVEPOINT_001';


\echo ''
\echo 'La transaccion queda en estado de error.'
\echo 'Se recupera mediante ROLLBACK TO SAVEPOINT.'

ROLLBACK TO SAVEPOINT antes_del_error;


\echo ''
\echo '========================================================='
\echo 'TRANSACCION RECUPERADA'
\echo '========================================================='

UPDATE competencia.regla
SET
    nombre =
        'Regla modificada despues del rollback parcial',

    descripcion =
        'La transaccion continuo luego de recuperar el savepoint'
WHERE codigo =
      'REGLA_SAVEPOINT_001';


RELEASE SAVEPOINT antes_del_error;


SELECT
    id_regla,
    codigo,
    nombre,
    descripcion,
    categoria
FROM competencia.regla
WHERE codigo = 'REGLA_SAVEPOINT_001';


\echo ''
\echo 'La operacion valida existe dentro de la transaccion.'
\echo 'Ahora se revierte la transaccion completa.'

ROLLBACK;


\echo ''
\echo '========================================================='
\echo 'COMPROBACION FINAL'
\echo '========================================================='

SELECT
    COUNT(*) AS reglas_temporales_restantes
FROM competencia.regla
WHERE codigo = 'REGLA_SAVEPOINT_001';


SELECT
    COUNT(*) AS auditorias_temporales_restantes
FROM auditoria.auditoria_dml
WHERE id_solicitud =
      'PRUEBA-SAVEPOINT-001';


\set ON_ERROR_STOP on