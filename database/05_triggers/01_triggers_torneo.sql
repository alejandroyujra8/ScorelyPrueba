BEGIN;

DROP TRIGGER IF EXISTS
    trg_01_validar_torneo
ON competencia.torneo;

CREATE TRIGGER trg_01_validar_torneo
BEFORE INSERT OR UPDATE
ON competencia.torneo
FOR EACH ROW
EXECUTE FUNCTION competencia.fn_validar_torneo();


DROP TRIGGER IF EXISTS
    trg_02_validar_transicion_torneo
ON competencia.torneo;

CREATE TRIGGER trg_02_validar_transicion_torneo
BEFORE UPDATE OF id_estado_torneo
ON competencia.torneo
FOR EACH ROW
EXECUTE FUNCTION competencia.fn_validar_transicion_torneo();


DROP TRIGGER IF EXISTS
    trg_validar_rol_torneo
ON competencia.usuario_torneo_rol;

CREATE TRIGGER trg_validar_rol_torneo
BEFORE INSERT OR UPDATE
ON competencia.usuario_torneo_rol
FOR EACH ROW
EXECUTE FUNCTION competencia.fn_validar_rol_torneo();


DROP TRIGGER IF EXISTS
    trg_validar_fase_torneo
ON competencia.fase_torneo;

CREATE TRIGGER trg_validar_fase_torneo
BEFORE INSERT OR UPDATE
ON competencia.fase_torneo
FOR EACH ROW
EXECUTE FUNCTION competencia.fn_validar_fase_torneo();


DROP TRIGGER IF EXISTS
    trg_validar_grupo_torneo
ON competencia.grupo_torneo;

CREATE TRIGGER trg_validar_grupo_torneo
BEFORE INSERT OR UPDATE
ON competencia.grupo_torneo
FOR EACH ROW
EXECUTE FUNCTION competencia.fn_validar_grupo_torneo();


DROP TRIGGER IF EXISTS
    trg_validar_jornada
ON competencia.jornada;

CREATE TRIGGER trg_validar_jornada
BEFORE INSERT OR UPDATE
ON competencia.jornada
FOR EACH ROW
EXECUTE FUNCTION competencia.fn_validar_jornada();

COMMIT;