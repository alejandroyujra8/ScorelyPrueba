BEGIN;

CREATE SCHEMA IF NOT EXISTS catalogo;
CREATE SCHEMA IF NOT EXISTS seguridad;
CREATE SCHEMA IF NOT EXISTS participantes;
CREATE SCHEMA IF NOT EXISTS competencia;
CREATE SCHEMA IF NOT EXISTS finanzas;
CREATE SCHEMA IF NOT EXISTS auditoria;
CREATE SCHEMA IF NOT EXISTS reportes;

COMMENT ON SCHEMA catalogo IS
'Contiene estados, tipos y otros datos de referencia del sistema.';

COMMENT ON SCHEMA seguridad IS
'Contiene usuarios, roles, permisos y datos relacionados con autenticacion.';

COMMENT ON SCHEMA participantes IS
'Contiene perfiles deportivos, equipos y membresias de jugadores.';

COMMENT ON SCHEMA competencia IS
'Contiene deportes, torneos, inscripciones, jornadas y partidos.';

COMMENT ON SCHEMA finanzas IS
'Contiene pagos, premios y entregas de premios.';

COMMENT ON SCHEMA auditoria IS
'Contiene registros de auditoria y seguimiento de operaciones DML.';

COMMENT ON SCHEMA reportes IS
'Contiene vistas y estructuras destinadas a reportes y estadisticas.';

COMMIT;