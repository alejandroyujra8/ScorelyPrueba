BEGIN;

DROP TRIGGER IF EXISTS
    trg_01_validar_inscripcion
ON competencia.inscripcion;

CREATE TRIGGER trg_01_validar_inscripcion
BEFORE INSERT OR UPDATE
ON competencia.inscripcion
FOR EACH ROW
EXECUTE FUNCTION competencia.fn_validar_inscripcion();


DROP TRIGGER IF EXISTS
    trg_02_validar_transicion_inscripcion
ON competencia.inscripcion;

CREATE TRIGGER trg_02_validar_transicion_inscripcion
BEFORE UPDATE OF id_estado_inscripcion
ON competencia.inscripcion
FOR EACH ROW
EXECUTE FUNCTION competencia.fn_validar_transicion_inscripcion();


DROP TRIGGER IF EXISTS
    trg_03_historial_inscripcion
ON competencia.inscripcion;

CREATE TRIGGER trg_03_historial_inscripcion
AFTER INSERT OR UPDATE OF id_estado_inscripcion
ON competencia.inscripcion
FOR EACH ROW
EXECUTE FUNCTION auditoria.fn_historial_inscripcion();


DROP TRIGGER IF EXISTS
    trg_validar_jugador_inscripcion
ON competencia.jugador_inscripcion;

CREATE TRIGGER trg_validar_jugador_inscripcion
BEFORE INSERT OR UPDATE
ON competencia.jugador_inscripcion
FOR EACH ROW
EXECUTE FUNCTION competencia.fn_validar_jugador_inscripcion();


DROP TRIGGER IF EXISTS
    trg_validar_cambio_jugador_equipo
ON participantes.jugador_equipo;

CREATE TRIGGER trg_validar_cambio_jugador_equipo
BEFORE INSERT OR UPDATE OR DELETE
ON participantes.jugador_equipo
FOR EACH ROW
EXECUTE FUNCTION participantes.fn_validar_cambio_jugador_equipo();


DROP TRIGGER IF EXISTS
    trg_01_validar_pago
ON finanzas.pago;

CREATE TRIGGER trg_01_validar_pago
BEFORE INSERT OR UPDATE OR DELETE
ON finanzas.pago
FOR EACH ROW
EXECUTE FUNCTION finanzas.fn_validar_pago();


DROP TRIGGER IF EXISTS
    trg_02_actualizar_inscripcion_por_pago
ON finanzas.pago;

CREATE TRIGGER trg_02_actualizar_inscripcion_por_pago
AFTER INSERT OR UPDATE OF id_estado_pago
ON finanzas.pago
FOR EACH ROW
EXECUTE FUNCTION finanzas.fn_actualizar_inscripcion_por_pago();


DROP TRIGGER IF EXISTS
    trg_03_historial_pago
ON finanzas.pago;

CREATE TRIGGER trg_03_historial_pago
AFTER INSERT OR UPDATE OF id_estado_pago
ON finanzas.pago
FOR EACH ROW
EXECUTE FUNCTION auditoria.fn_historial_pago();

COMMIT;