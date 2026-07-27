import { usarMocks } from "../config/environment";
import { mockDb, nextId } from "../mocks/mockData";
import { mockError, mockResult } from "../mocks/mockUtils";
import { apiDelete, apiGet, apiPatch, apiPost, crearQueryString } from "./api";

export async function listarDeportes({ estado = "", limite = 20, desplazamiento = 0 } = {}) {
  if (!usarMocks()) return apiGet(`/api/deportes${crearQueryString({ estado, limite, desplazamiento })}`);
  let rows = [...mockDb.deportes];
  if (estado) rows = rows.filter((item) => item.estado_codigo === estado);
  return mockResult({ total: rows.length, limite, desplazamiento, resultados: rows.slice(desplazamiento, desplazamiento + limite) });
}

export async function obtenerDeporte(id) {
  if (!usarMocks()) return apiGet(`/api/deportes/${id}`);
  const item = mockDb.deportes.find((row) => row.id_deporte === Number(id));
  if (!item) mockError("Deporte no encontrado", 404);
  return mockResult(item);
}

export async function crearDeporte(data) {
  if (!usarMocks()) return apiPost("/api/deportes", data);
  if (mockDb.deportes.some((row) => row.codigo === data.codigo)) mockError("Ya existe un deporte con ese código", 409);
  const item = { ...data, id_deporte: nextId(mockDb.deportes, "id_deporte"), fecha_registro: new Date().toISOString() };
  mockDb.deportes.unshift(item);
  return mockResult(item);
}

export async function actualizarDeporte(id, data) {
  if (!usarMocks()) return apiPatch(`/api/deportes/${id}`, data);
  const index = mockDb.deportes.findIndex((row) => row.id_deporte === Number(id));
  if (index < 0) mockError("Deporte no encontrado", 404);
  mockDb.deportes[index] = { ...mockDb.deportes[index], ...data };
  return mockResult(mockDb.deportes[index]);
}

export async function desactivarDeporte(id) {
  if (!usarMocks()) return apiDelete(`/api/deportes/${id}`);
  return actualizarDeporte(id, { estado_codigo: "INACTIVO" });
}
