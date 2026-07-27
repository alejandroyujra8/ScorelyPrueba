const dateFormatter = new Intl.DateTimeFormat("es-BO", { dateStyle: "medium" });
const dateTimeFormatter = new Intl.DateTimeFormat("es-BO", { dateStyle: "medium", timeStyle: "short" });

export function formatDate(value, fallback = "—") {
  if (!value) return fallback;
  const date = new Date(value.length === 10 ? `${value}T00:00:00` : value);
  return Number.isNaN(date.getTime()) ? fallback : dateFormatter.format(date);
}

export function formatDateTime(value, fallback = "—") {
  if (!value) return fallback;
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? fallback : dateTimeFormatter.format(date);
}

export function formatMoney(value, currency = "BOB") {
  return new Intl.NumberFormat("es-BO", { style: "currency", currency }).format(Number(value || 0));
}

export function formatNumber(value) {
  return new Intl.NumberFormat("es-BO").format(Number(value || 0));
}

export function fullName(person) {
  if (!person) return "Usuario";
  return [person.nombres, person.apellido_paterno, person.apellido_materno].filter(Boolean).join(" ");
}

export function initials(value = "") {
  return String(value).split(/\s+/).filter(Boolean).slice(0, 2).map((word) => word[0]).join("").toUpperCase() || "SC";
}

export function toInputDate(value) {
  if (!value) return "";
  return String(value).slice(0, 10);
}

export function toInputDateTime(value) {
  if (!value) return "";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "";
  const offset = date.getTimezoneOffset();
  return new Date(date.getTime() - offset * 60000).toISOString().slice(0, 16);
}
