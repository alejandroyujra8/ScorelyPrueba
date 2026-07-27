import { usarMocks } from "../config/environment";
import { mockDb, nextId } from "../mocks/mockData";
import { filterText, mockError, mockResult } from "../mocks/mockUtils";
import { apiGet, apiPatch, apiPost, crearQueryString } from "./api";

function normalizarTorneoMock(torneo) {
  const deporte = mockDb.deportes.find(
    (item) => item.nombre === torneo.deporte,
  );
  const mapaFormatos = {
    LIGA: "FASE_GRUPOS",
    GRUPOS: "FASE_GRUPOS",
    "FASE DE GRUPOS": "FASE_GRUPOS",
    "ELIMINACIÓN DIRECTA": "ELIMINACION_DIRECTA",
    "ELIMINACION DIRECTA": "ELIMINACION_DIRECTA",
    "GRUPOS Y LLAVES": "GRUPOS_Y_LLAVES",
    "PARTIDO ÚNICO": "PARTIDO_UNICO",
    "PARTIDO UNICO": "PARTIDO_UNICO",
  };
  const formatoCodigo =
    torneo.formato_codigo ||
    mapaFormatos[String(torneo.formato || "").toUpperCase()] ||
    "PARTIDO_UNICO";

  return {
    id_deporte: deporte?.id_deporte || torneo.id_deporte || 1,
    formato_codigo: formatoCodigo,
    permite_empate: torneo.permite_empate ?? true,
    descripcion: torneo.descripcion || null,
    ...torneo,
  };
}

export async function listarTorneos({ estado = "", busqueda = "" } = {}) {
  if (!usarMocks()) return apiGet(`/api/torneos${crearQueryString({ estado, busqueda })}`);
  let rows = mockDb.torneos.map(normalizarTorneoMock);
  if (estado) rows = rows.filter((item) => item.estado_torneo === estado);
  if (busqueda) rows = rows.filter((item) => filterText(`${item.nombre} ${item.codigo}`, busqueda));
  return mockResult({ total: rows.length, resultados: rows });
}

export async function obtenerTorneo(id) {
  if (!usarMocks()) return apiGet(`/api/torneos/${id}`);
  const item = mockDb.torneos.find((row) => row.id_torneo === Number(id));
  if (!item) mockError("Torneo no encontrado", 404);
  return mockResult(normalizarTorneoMock(item));
}

export async function crearTorneo(data) {
  if (!usarMocks()) return apiPost("/api/torneos", data);
  if (mockDb.torneos.some((row) => row.codigo === data.codigo)) mockError("Ya existe un torneo con ese código", 409);
  const sport = mockDb.deportes.find((row) => row.id_deporte === Number(data.id_deporte));
  const item = {
    id_torneo: nextId(mockDb.torneos, "id_torneo"),
    id_deporte: Number(data.id_deporte),
    formato_codigo: data.formato_codigo,
    codigo: data.codigo,
    nombre: data.nombre,
    edicion: data.edicion || null,
    categoria: data.categoria,
    rama: data.rama,
    deporte: sport?.nombre || "Deporte",
    formato: data.formato_codigo,
    estado_torneo: "BORRADOR",
    fecha_inicio_inscripcion: data.fecha_inicio_inscripcion,
    fecha_fin_inscripcion: data.fecha_fin_inscripcion,
    fecha_inicio_torneo: data.fecha_inicio_torneo,
    fecha_fin_torneo: data.fecha_fin_torneo,
    cantidad_maxima_equipos: Number(data.cantidad_maxima_equipos),
    cantidad_minima_jugadores: Number(data.cantidad_minima_jugadores),
    cantidad_maxima_jugadores: Number(data.cantidad_maxima_jugadores),
    costo_inscripcion: String(data.costo_inscripcion),
    moneda: data.moneda,
    permite_empate: Boolean(data.permite_empate),
    descripcion: data.descripcion || null,
    total_inscripciones: 0,
    inscripciones_habilitadas: 0,
    total_fases: 0,
    total_partidos: 0,
    partidos_finalizados: 0,
    total_recaudado: "0.00",
  };
  mockDb.torneos.unshift(item);
  return mockResult(item);
}


export async function actualizarTorneo(id, data) {
  if (!usarMocks()) return apiPatch(`/api/torneos/${id}`, data);
  const index = mockDb.torneos.findIndex(
    (row) => row.id_torneo === Number(id),
  );
  if (index < 0) mockError("Torneo no encontrado", 404);
  if (mockDb.torneos[index].estado_torneo !== "BORRADOR") {
    mockError("Solo se puede editar un torneo en estado BORRADOR", 409);
  }
  const sport = mockDb.deportes.find(
    (row) => row.id_deporte === Number(data.id_deporte),
  );
  mockDb.torneos[index] = {
    ...mockDb.torneos[index],
    ...data,
    id_deporte: Number(data.id_deporte),
    deporte: sport?.nombre || mockDb.torneos[index].deporte,
    formato: data.formato_codigo,
    cantidad_maxima_equipos: Number(data.cantidad_maxima_equipos),
    cantidad_minima_jugadores: Number(data.cantidad_minima_jugadores),
    cantidad_maxima_jugadores: Number(data.cantidad_maxima_jugadores),
    costo_inscripcion: String(data.costo_inscripcion),
  };
  return mockResult(mockDb.torneos[index]);
}

export async function cambiarEstadoTorneo(id, estado_codigo) {
  if (!usarMocks()) return apiPatch(`/api/torneos/${id}/estado`, { estado_codigo });
  const item = mockDb.torneos.find((row) => row.id_torneo === Number(id));
  if (!item) mockError("Torneo no encontrado", 404);
  item.estado_torneo = estado_codigo;
  return mockResult(item);
}

export async function obtenerEstructura(id) {
  if (!usarMocks()) return apiGet(`/api/torneos/${id}/estructura`);
  const fases = mockDb.fases.filter((item) => item.id_torneo === Number(id));
  const ids = new Set(fases.map((item) => item.id_fase_torneo));
  return mockResult({ fases, jornadas: mockDb.jornadas.filter((item) => ids.has(item.id_fase_torneo)) });
}

export async function crearFase(idTorneo, data) {
  if (!usarMocks()) return apiPost(`/api/torneos/${idTorneo}/fases`, data);
  const item = { id_fase_torneo: nextId(mockDb.fases, "id_fase_torneo"), id_torneo: Number(idTorneo), tipo_fase: data.tipo_fase_codigo, estado_fase: "PENDIENTE", nombre: data.nombre, numero_orden: Number(data.numero_orden), cantidad_clasificados: data.cantidad_clasificados ? Number(data.cantidad_clasificados) : null, fecha_inicio: data.fecha_inicio, fecha_fin: data.fecha_fin, descripcion: data.descripcion || null };
  mockDb.fases.push(item);
  const torneo = mockDb.torneos.find((row) => row.id_torneo === Number(idTorneo));
  if (torneo) torneo.total_fases += 1;
  return mockResult(item);
}

export async function crearJornada(idFase, data) {
  if (!usarMocks()) return apiPost(`/api/torneos/fases/${idFase}/jornadas`, data);
  const item = { id_jornada: nextId(mockDb.jornadas, "id_jornada"), id_fase_torneo: Number(idFase), estado_jornada: "PROGRAMADA", numero_jornada: Number(data.numero_jornada), nombre: data.nombre, fecha_inicio: data.fecha_inicio, fecha_fin: data.fecha_fin, observaciones: data.observaciones || null };
  mockDb.jornadas.push(item);
  return mockResult(item);
}
