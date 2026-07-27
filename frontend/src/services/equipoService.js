import { usarMocks } from "../config/environment";
import { mockDb, nextId } from "../mocks/mockData";
import { filterText, mockError, mockResult } from "../mocks/mockUtils";
import { apiDelete, apiGet, apiPatch, apiPost, crearQueryString } from "./api";

export async function listarEquipos({ estado = "", busqueda = "", limite = 30, desplazamiento = 0 } = {}) {
  if (!usarMocks()) return apiGet(`/api/equipos${crearQueryString({ estado, busqueda, limite, desplazamiento })}`);
  let rows = [...mockDb.equipos];
  if (estado) rows = rows.filter((item) => item.estado_codigo === estado);
  if (busqueda) rows = rows.filter((item) => filterText(`${item.nombre} ${item.sigla}`, busqueda));
  return mockResult({ total: rows.length, limite, desplazamiento, resultados: rows.slice(desplazamiento, desplazamiento + limite) });
}

export async function obtenerEquipo(id) {
  if (!usarMocks()) return apiGet(`/api/equipos/${id}`);
  const item = mockDb.equipos.find((row) => row.id_equipo === Number(id));
  if (!item) mockError("Equipo no encontrado", 404);
  return mockResult(item);
}

export async function crearEquipo(data) {
  if (!usarMocks()) return apiPost("/api/equipos", data);
  if (mockDb.equipos.some((row) => row.sigla === data.sigla)) mockError("Ya existe un equipo con esa sigla", 409);
  const item = { ...data, id_equipo: nextId(mockDb.equipos, "id_equipo"), creado_por: 1 };
  mockDb.equipos.unshift(item);
  return mockResult(item);
}

export async function actualizarEquipo(id, data) {
  if (!usarMocks()) return apiPatch(`/api/equipos/${id}`, data);
  const index = mockDb.equipos.findIndex((row) => row.id_equipo === Number(id));
  if (index < 0) mockError("Equipo no encontrado", 404);
  mockDb.equipos[index] = { ...mockDb.equipos[index], ...data };
  return mockResult(mockDb.equipos[index]);
}

export async function desactivarEquipo(id) {
  if (!usarMocks()) return apiDelete(`/api/equipos/${id}`);
  return actualizarEquipo(id, { estado_codigo: "INACTIVO" });
}
