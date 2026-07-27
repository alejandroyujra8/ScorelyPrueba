import { environment } from "../config/environment";

export const EVENTO_SESION_EXPIRADA = "scorely:sesion-expirada";

export class ApiError extends Error {
  constructor(message, { status = 0, data = null, code = null } = {}) {
    super(message);
    this.name = "ApiError";
    this.status = status;
    this.data = data;
    this.code = code;
  }
}

export const obtenerToken = () => localStorage.getItem("access_token");

export function guardarSesion(accessToken, usuario) {
  localStorage.setItem("access_token", accessToken);
  localStorage.setItem("usuario", JSON.stringify(usuario));
}

export function guardarUsuario(usuario) {
  localStorage.setItem("usuario", JSON.stringify(usuario));
}

export function eliminarSesion() {
  localStorage.removeItem("access_token");
  localStorage.removeItem("usuario");
}

export function obtenerUsuarioGuardado() {
  const stored = localStorage.getItem("usuario");
  if (!stored) return null;
  try {
    return JSON.parse(stored);
  } catch {
    eliminarSesion();
    return null;
  }
}

export function crearQueryString(params = {}) {
  const query = new URLSearchParams();
  Object.entries(params).forEach(([key, value]) => {
    if (value === undefined || value === null || value === "") return;
    if (Array.isArray(value)) value.forEach((item) => query.append(key, item));
    else query.set(key, value);
  });
  return query.toString() ? `?${query}` : "";
}

export function obtenerMensajeError(data, fallback = "Ocurrió un error al comunicarse con el servidor") {
  if (!data) return fallback;
  if (typeof data === "string") return data;
  if (typeof data.detail === "string") return data.detail;
  if (Array.isArray(data.detail)) {
    return data.detail.map((error) => {
      const field = Array.isArray(error.loc) ? error.loc.filter((part) => !["body", "query", "path"].includes(part)).join(".") : "";
      return field ? `${field}: ${error.msg}` : error.msg;
    }).join("\n");
  }
  return data.message || fallback;
}

async function parseResponse(response) {
  if ([204, 205].includes(response.status)) return null;
  const text = await response.text();
  if (!text) return null;
  try { return JSON.parse(text); } catch { return text; }
}

export async function apiFetch(path, options = {}) {
  const token = obtenerToken();
  const headers = new Headers(options.headers || {});
  headers.set("Accept", "application/json");
  let body = options.body;
  const isFormData = typeof FormData !== "undefined" && body instanceof FormData;
  if (body !== undefined && body !== null && !isFormData && typeof body !== "string") {
    headers.set("Content-Type", "application/json");
    body = JSON.stringify(body);
  } else if (typeof body === "string" && !headers.has("Content-Type")) {
    headers.set("Content-Type", "application/json");
  }
  if (token) headers.set("Authorization", `Bearer ${token}`);

  let response;
  try {
    response = await fetch(`${environment.apiUrl}${path.startsWith("/") ? path : `/${path}`}`, { ...options, headers, body });
  } catch {
    throw new ApiError("No se pudo conectar con el servidor. Revisa que FastAPI esté iniciado.", { code: "NETWORK_ERROR" });
  }

  const data = await parseResponse(response);
  if (!response.ok) {
    const message = obtenerMensajeError(data);
    if (
      response.status === 401 &&
      path !== "/api/auth/login"
    ) {
      eliminarSesion();

      window.dispatchEvent(
        new CustomEvent(
          EVENTO_SESION_EXPIRADA,
          {
            detail: {
              mensaje:
                "Tu sesión ya no es válida. Inicia sesión nuevamente.",
            },
          },
        ),
      );
    }
    throw new ApiError(message, { status: response.status, data, code: `HTTP_${response.status}` });
  }
  return data;
}

export const apiGet = (path, options = {}) => apiFetch(path, { ...options, method: "GET" });
export const apiPost = (path, data, options = {}) => apiFetch(path, { ...options, method: "POST", body: data });
export const apiPatch = (path, data = null, options = {}) => apiFetch(path, { ...options, method: "PATCH", body: data ?? undefined });
export const apiDelete = (path, options = {}) => apiFetch(path, { ...options, method: "DELETE" });
