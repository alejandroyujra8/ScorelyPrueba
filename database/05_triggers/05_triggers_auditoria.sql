BEGIN;

DROP TRIGGER IF EXISTS
    trg_proteger_auditoria_dml
ON auditoria.auditoria_dml;


CREATE TRIGGER trg_proteger_auditoria_dml
BEFORE UPDATE OR DELETE
ON auditoria.auditoria_dml
FOR EACH ROW
EXECUTE FUNCTION auditoria.fn_proteger_auditoria_dml();


CALL auditoria.sp_instalar_triggers_auditoria();

COMMIT;