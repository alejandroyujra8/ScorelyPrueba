BEGIN;

DROP TRIGGER IF EXISTS
    trg_validar_equipo_grupo
ON competencia.equipo_grupo;

CREATE TRIGGER trg_validar_equipo_grupo
BEFORE INSERT OR UPDATE
ON competencia.equipo_grupo
FOR EACH ROW
EXECUTE FUNCTION competencia.fn_validar_equipo_grupo();


DROP TRIGGER IF EXISTS
    trg_01_validar_partido
ON competencia.partido;

CREATE TRIGGER trg_01_validar_partido
BEFORE INSERT OR UPDATE
ON competencia.partido
FOR EACH ROW
EXECUTE FUNCTION competencia.fn_validar_partido();


DROP TRIGGER IF EXISTS
    trg_02_validar_transicion_partido
ON competencia.partido;

CREATE TRIGGER trg_02_validar_transicion_partido
BEFORE UPDATE OF id_estado_partido
ON competencia.partido
FOR EACH ROW
EXECUTE FUNCTION competencia.fn_validar_transicion_partido();


DROP TRIGGER IF EXISTS
    trg_03_calcular_resultado_partido
ON competencia.partido;

CREATE TRIGGER trg_03_calcular_resultado_partido
BEFORE UPDATE OF id_estado_partido
ON competencia.partido
FOR EACH ROW
EXECUTE FUNCTION competencia.fn_calcular_resultado_partido();


DROP TRIGGER IF EXISTS
    trg_04_historial_partido
ON competencia.partido;

CREATE TRIGGER trg_04_historial_partido
AFTER INSERT OR UPDATE OF id_estado_partido
ON competencia.partido
FOR EACH ROW
EXECUTE FUNCTION auditoria.fn_historial_partido();


DROP TRIGGER IF EXISTS
    trg_validar_partido_equipo
ON competencia.partido_equipo;

CREATE TRIGGER trg_validar_partido_equipo
BEFORE INSERT OR UPDATE
ON competencia.partido_equipo
FOR EACH ROW
EXECUTE FUNCTION competencia.fn_validar_partido_equipo();


DROP TRIGGER IF EXISTS
    trg_validar_arbitro_partido
ON competencia.arbitro_partido;

CREATE TRIGGER trg_validar_arbitro_partido
BEFORE INSERT OR UPDATE
ON competencia.arbitro_partido
FOR EACH ROW
EXECUTE FUNCTION competencia.fn_validar_arbitro_partido();


DROP TRIGGER IF EXISTS
    trg_validar_jugador_partido
ON competencia.jugador_partido;

CREATE TRIGGER trg_validar_jugador_partido
BEFORE INSERT OR UPDATE
ON competencia.jugador_partido
FOR EACH ROW
EXECUTE FUNCTION competencia.fn_validar_jugador_partido();

COMMIT;