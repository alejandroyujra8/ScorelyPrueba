const success = new Set(["ACTIVO", "HABILITADA", "HABILITADO", "CONFIRMADO", "FINALIZADO", "ENTREGADO", "GANADOR", "PAGADO"]);
const info = new Set(["PROGRAMADO", "BORRADOR", "PENDIENTE", "INSCRITO", "ABIERTA"]);
const warning = new Set(["EN_CURSO", "INSCRIPCIONES_ABIERTAS", "SUSPENDIDO", "EN_REVISION"]);
const danger = new Set(["INACTIVO", "RECHAZADO", "CANCELADO", "EXPULSADO", "ANULADO"]);

export function statusTone(status) {
  const normalized = String(status || "").toUpperCase();
  if (success.has(normalized)) return "success";
  if (info.has(normalized)) return "info";
  if (warning.has(normalized)) return "warning";
  if (danger.has(normalized)) return "danger";
  return "neutral";
}

export function humanizeStatus(value) {
  return String(value || "SIN ESTADO").replaceAll("_", " ");
}
