BEGIN;

DROP TRIGGER IF EXISTS
    trg_validar_resultado_torneo
ON competencia.resultado_torneo;

CREATE TRIGGER trg_validar_resultado_torneo
BEFORE INSERT OR UPDATE
ON competencia.resultado_torneo
FOR EACH ROW
EXECUTE FUNCTION competencia.fn_validar_resultado_torneo();


DROP TRIGGER IF EXISTS
    trg_validar_torneo_premio
ON finanzas.torneo_premio;

CREATE TRIGGER trg_validar_torneo_premio
BEFORE INSERT OR UPDATE
ON finanzas.torneo_premio
FOR EACH ROW
EXECUTE FUNCTION finanzas.fn_validar_torneo_premio();


DROP TRIGGER IF EXISTS
    trg_01_validar_entrega_premio
ON finanzas.entrega_premio;

CREATE TRIGGER trg_01_validar_entrega_premio
BEFORE INSERT OR UPDATE OR DELETE
ON finanzas.entrega_premio
FOR EACH ROW
EXECUTE FUNCTION finanzas.fn_validar_entrega_premio();


DROP TRIGGER IF EXISTS
    trg_02_historial_entrega_premio
ON finanzas.entrega_premio;

CREATE TRIGGER trg_02_historial_entrega_premio
AFTER INSERT OR UPDATE OF id_estado_entrega_premio
ON finanzas.entrega_premio
FOR EACH ROW
EXECUTE FUNCTION auditoria.fn_historial_entrega_premio();

COMMIT;