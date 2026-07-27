import { usarMocks } from "../config/environment";
import { mockDb, nextId } from "../mocks/mockData";
import { mockError, mockResult } from "../mocks/mockUtils";
import {
  apiGet,
  apiPatch,
  apiPost,
  crearQueryString,
} from "./api";

function findRegistration(tournamentId, teamName) {
  return mockDb.inscripciones.find(
    (item) =>
      item.id_torneo === Number(tournamentId) &&
      item.equipo === teamName,
  );
}

function normalizeMockMatch(item) {
  const local = findRegistration(
    item.id_torneo,
    item.equipo_local,
  );
  const visitor = findRegistration(
    item.id_torneo,
    item.equipo_visitante,
  );

  const tieneArbitro = mockDb.arbitrosPartidos?.some(
    (asignacion) =>
      asignacion.id_partido === Number(item.id_partido) &&
      asignacion.activo,
  );

  return {
    ...item,
    arbitro_actual_asignado:
      item.arbitro_actual_asignado ?? Boolean(tieneArbitro),
    id_inscripcion_local:
      item.id_inscripcion_local ?? local?.id_inscripcion ?? null,
    id_inscripcion_visitante:
      item.id_inscripcion_visitante ??
      visitor?.id_inscripcion ??
      null,
  };
}

export async function listarPartidos({
  id_torneo = "",
  estado = "",
} = {}) {
  if (!usarMocks()) {
    return apiGet(
      `/api/partidos${crearQueryString({
        id_torneo,
        estado,
      })}`,
    );
  }

  let rows = mockDb.partidos.map(normalizeMockMatch);

  if (id_torneo) {
    rows = rows.filter(
      (item) => item.id_torneo === Number(id_torneo),
    );
  }

  if (estado) {
    rows = rows.filter(
      (item) => item.estado_partido === estado,
    );
  }

  return mockResult({
    total: rows.length,
    resultados: rows,
  });
}

export async function obtenerPartido(id) {
  if (!usarMocks()) {
    return apiGet(`/api/partidos/${id}`);
  }

  const item = mockDb.partidos.find(
    (row) => row.id_partido === Number(id),
  );

  if (!item) {
    mockError("Partido no encontrado", 404);
  }

  return mockResult(normalizeMockMatch(item));
}

export async function listarLugares() {
  return usarMocks()
    ? mockResult(mockDb.lugares)
    : apiGet("/api/partidos/opciones/lugares");
}

export async function listarArbitros() {
  return usarMocks()
    ? mockResult(mockDb.arbitros)
    : apiGet("/api/partidos/opciones/arbitros");
}

export async function programarPartido(data) {
  if (!usarMocks()) {
    return apiPost("/api/partidos", data);
  }

  const jornada = mockDb.jornadas.find(
    (item) => item.id_jornada === Number(data.id_jornada),
  );
  const fase = mockDb.fases.find(
    (item) =>
      item.id_fase_torneo === jornada?.id_fase_torneo,
  );
  const torneo = mockDb.torneos.find(
    (item) => item.id_torneo === fase?.id_torneo,
  );
  const lugar = mockDb.lugares.find(
    (item) => item.id_lugar === Number(data.id_lugar),
  );
  const local = mockDb.inscripciones.find(
    (item) =>
      item.id_inscripcion ===
      Number(data.id_inscripcion_local),
  );
  const visitor = mockDb.inscripciones.find(
    (item) =>
      item.id_inscripcion ===
      Number(data.id_inscripcion_visitante),
  );

  if (!jornada || !fase || !torneo || !local || !visitor) {
    mockError(
      "No se pudieron validar los datos del partido",
      422,
    );
  }

  if (local.id_inscripcion === visitor.id_inscripcion) {
    mockError(
      "Un equipo no puede enfrentarse contra sí mismo",
      422,
    );
  }

  if (
    local.id_torneo !== torneo.id_torneo ||
    visitor.id_torneo !== torneo.id_torneo
  ) {
    mockError(
      "Los equipos deben pertenecer al torneo seleccionado",
      422,
    );
  }

  if (
    mockDb.partidos.some(
      (item) => item.codigo === data.codigo,
    )
  ) {
    mockError("Ya existe un partido con ese código", 409);
  }

  const item = {
    id_partido: nextId(mockDb.partidos, "id_partido"),
    codigo: data.codigo,
    numero_partido: Number(data.numero_partido),
    nombre_ronda: data.nombre_ronda || null,
    id_torneo: torneo.id_torneo,
    torneo: torneo.nombre,
    fase: fase.nombre,
    numero_jornada: jornada.numero_jornada,
    jornada: jornada.nombre,
    grupo: null,
    lugar: lugar?.nombre || null,
    direccion_lugar: lugar?.direccion || null,
    fecha_hora_inicio: data.fecha_hora_inicio,
    fecha_hora_fin: data.fecha_hora_fin,
    estado_partido: "PROGRAMADO",
    id_inscripcion_local: local.id_inscripcion,
    equipo_local: local.equipo,
    marcador_local: null,
    desempate_local: null,
    resultado_local: null,
    id_inscripcion_visitante: visitor.id_inscripcion,
    equipo_visitante: visitor.equipo,
    marcador_visitante: null,
    desempate_visitante: null,
    resultado_visitante: null,
    observaciones: data.observaciones || null,
  };

  mockDb.partidos.unshift(item);
  torneo.total_partidos += 1;
  return mockResult(item);
}

export async function asignarArbitro(id, data) {
  if (!usarMocks()) {
    return apiPost(`/api/partidos/${id}/arbitros`, data);
  }

  const match = mockDb.partidos.find(
    (item) => item.id_partido === Number(id),
  );
  const referee = mockDb.arbitros.find(
    (item) => item.id_arbitro === Number(data.id_arbitro),
  );

  if (!match) {
    mockError("Partido no encontrado", 404);
  }

  if (!referee) {
    mockError("Árbitro no encontrado", 404);
  }

  if (!["BORRADOR", "PROGRAMADO"].includes(match.estado_partido)) {
    mockError("Solo se puede asignar árbitros antes de iniciar el partido", 422);
  }

  mockDb.arbitrosPartidos ||= [];
  if (
    mockDb.arbitrosPartidos.some(
      (asignacion) =>
        asignacion.id_partido === Number(id) &&
        asignacion.id_arbitro === Number(data.id_arbitro) &&
        asignacion.activo,
    )
  ) {
    mockError("El árbitro ya está asignado al partido", 409);
  }

  mockDb.arbitrosPartidos.push({
    id_partido: Number(id),
    id_arbitro: Number(data.id_arbitro),
    tipo_arbitro_codigo: data.tipo_arbitro_codigo,
    activo: true,
  });
  match.arbitro_actual_asignado = true;

  return mockResult({
    mensaje: "Árbitro asignado correctamente",
    id_partido: Number(id),
  });
}

export async function iniciarPartido(id) {
  if (!usarMocks()) {
    return apiPatch(`/api/partidos/${id}/iniciar`);
  }

  const match = mockDb.partidos.find(
    (item) => item.id_partido === Number(id),
  );

  if (!match) {
    mockError("Partido no encontrado", 404);
  }

  if (match.estado_partido !== "PROGRAMADO") {
    mockError(
      "Solo se puede iniciar un partido PROGRAMADO",
      422,
    );
  }

  if (
    !mockDb.arbitrosPartidos?.some(
      (asignacion) =>
        asignacion.id_partido === Number(id) &&
        asignacion.activo,
    )
  ) {
    mockError("El partido necesita al menos un árbitro activo", 422);
  }

  match.estado_partido = "EN_CURSO";
  match.marcador_local = 0;
  match.marcador_visitante = 0;

  return mockResult({
    mensaje: "Partido iniciado correctamente",
    id_partido: Number(id),
  });
}

export async function listarParticipaciones(id) {
  if (!usarMocks()) {
    return apiGet(`/api/partidos/${id}/participaciones`);
  }

  return mockResult(mockDb.participaciones[Number(id)] || []);
}

export async function registrarParticipacion(id, data) {
  if (!usarMocks()) {
    return apiPost(
      `/api/partidos/${id}/participaciones`,
      data,
    );
  }

  const roster = Object.values(mockDb.nominas)
    .flat()
    .find(
      (item) =>
        item.id_jugador_inscripcion ===
        Number(data.id_jugador_inscripcion),
    );
  const match = mockDb.partidos.find(
    (item) => item.id_partido === Number(id),
  );

  if (!roster) {
    mockError("Jugador de nómina no encontrado", 404);
  }

  if (!match) {
    mockError("Partido no encontrado", 404);
  }

  if (match.estado_partido !== "EN_CURSO") {
    mockError(
      "Solo se puede registrar participación en un partido EN_CURSO",
      422,
    );
  }

  const registration = mockDb.inscripciones.find(
    (item) => item.id_inscripcion === roster.id_inscripcion,
  );
  const validRegistrationIds = new Set([
    normalizeMockMatch(match).id_inscripcion_local,
    normalizeMockMatch(match).id_inscripcion_visitante,
  ]);

  if (
    !registration ||
    !validRegistrationIds.has(registration.id_inscripcion)
  ) {
    mockError(
      "El equipo del jugador no participa en el partido",
      422,
    );
  }

  const list =
    mockDb.participaciones[Number(id)] ||
    (mockDb.participaciones[Number(id)] = []);

  if (
    list.some(
      (item) => item.id_jugador === roster.id_jugador,
    )
  ) {
    mockError(
      "La participación del jugador ya fue registrada",
      409,
    );
  }

  const item = {
    id_jugador_partido: nextId(
      Object.values(mockDb.participaciones).flat(),
      "id_jugador_partido",
    ),
    id_torneo: match.id_torneo,
    torneo: match.torneo,
    id_partido: match.id_partido,
    partido: match.codigo,
    id_equipo: registration.id_equipo,
    equipo: registration.equipo,
    id_jugador: roster.id_jugador,
    numero_documento: roster.numero_documento,
    nombres: roster.nombres,
    apellido_paterno: roster.apellido_paterno,
    apellido_materno: roster.apellido_materno,
    convocado: Boolean(data.convocado),
    asistio: Boolean(data.asistio),
    titular: Boolean(data.titular),
    minutos_jugados: Number(data.minutos_jugados || 0),
    puntos_anotados: Number(data.puntos_anotados || 0),
    faltas: Number(data.faltas || 0),
    amonestaciones: Number(data.amonestaciones || 0),
    expulsado: Boolean(data.expulsado),
    lesionado: Boolean(data.lesionado),
    calificacion: data.calificacion ?? null,
    estadisticas: data.estadisticas || {},
    fecha_actualizacion: new Date().toISOString(),
  };

  list.push(item);
  return mockResult(item);
}

export async function finalizarPartido(id, data) {
  if (!usarMocks()) {
    return apiPatch(`/api/partidos/${id}/finalizar`, data);
  }

  const match = mockDb.partidos.find(
    (item) => item.id_partido === Number(id),
  );

  if (!match) {
    mockError("Partido no encontrado", 404);
  }

  if (match.estado_partido !== "EN_CURSO") {
    mockError(
      "Solo se puede finalizar un partido EN_CURSO",
      422,
    );
  }

  Object.assign(match, {
    estado_partido: "FINALIZADO",
    marcador_local: Number(data.marcador_local),
    marcador_visitante: Number(data.marcador_visitante),
    desempate_local:
      data.desempate_local === null
        ? null
        : Number(data.desempate_local),
    desempate_visitante:
      data.desempate_visitante === null
        ? null
        : Number(data.desempate_visitante),
    observaciones: data.observaciones || match.observaciones,
  });

  if (match.marcador_local > match.marcador_visitante) {
    match.resultado_local = "GANADOR";
    match.resultado_visitante = "PERDEDOR";
  } else if (
    match.marcador_local < match.marcador_visitante
  ) {
    match.resultado_local = "PERDEDOR";
    match.resultado_visitante = "GANADOR";
  } else {
    match.resultado_local = "EMPATE";
    match.resultado_visitante = "EMPATE";
  }

  return mockResult({
    mensaje: "Partido finalizado correctamente",
    id_partido: Number(id),
  });
}
