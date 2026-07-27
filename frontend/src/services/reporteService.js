import { usarMocks } from "../config/environment";
import { mockDb } from "../mocks/mockData";
import { mockError, mockResult } from "../mocks/mockUtils";
import { apiGet, crearQueryString } from "./api";

export async function obtenerDashboard() {
  if (!usarMocks()) return apiGet("/api/reportes/dashboard");
  return mockResult({
    total_usuarios: mockDb.usuarios.length,
    total_equipos: mockDb.equipos.length,
    total_jugadores: mockDb.jugadores.length,
    total_torneos: mockDb.torneos.length,
    torneos_en_curso: mockDb.torneos.filter((item) => item.estado_torneo === "EN_CURSO").length,
    total_partidos: mockDb.partidos.length,
    partidos_finalizados: mockDb.partidos.filter((item) => item.estado_partido === "FINALIZADO").length,
    total_recaudado: mockDb.torneos.reduce((sum, item) => sum + Number(item.total_recaudado || 0), 0).toFixed(2),
    premios_entregados: 3,
  });
}

function tournamentOrError(id) {
  const tournament = mockDb.torneos.find((item) => item.id_torneo === Number(id));
  if (!tournament) mockError("Torneo no encontrado", 404);
  return tournament;
}

export async function obtenerResumenTorneo(id) {
  if (!usarMocks()) return apiGet(`/api/reportes/torneos/${id}/resumen`);
  const tournament = tournamentOrError(id);
  return mockResult({ datos: tournament });
}

export async function obtenerFinanzasTorneo(id) {
  if (!usarMocks()) return apiGet(`/api/reportes/torneos/${id}/finanzas`);
  const tournament = tournamentOrError(id);
  const registrations = mockDb.inscripciones.filter((item) => item.id_torneo === Number(id));
  return mockResult({ datos: { id_torneo: tournament.id_torneo, torneo: tournament.nombre, moneda: tournament.moneda, monto_total_requerido: registrations.reduce((sum, item) => sum + Number(item.monto_requerido), 0).toFixed(2), total_pagado: tournament.total_recaudado, saldo_pendiente: registrations.reduce((sum, item) => sum + Number(item.saldo_pendiente), 0).toFixed(2), pagos_confirmados: registrations.filter((item) => Number(item.saldo_pendiente) === 0).length } });
}

export async function obtenerResultadosTorneo(id) {
  if (!usarMocks()) return apiGet(`/api/reportes/torneos/${id}/resultados`);
  tournamentOrError(id);
  const registrations = mockDb.inscripciones.filter((item) => item.id_torneo === Number(id) && item.estado_inscripcion === "HABILITADA");
  const data = registrations.map((item, index) => ({
    id_resultado_torneo: index + 1,
    id_torneo: Number(id),
    codigo_torneo: item.codigo_torneo,
    torneo: item.torneo,
    deporte: mockDb.torneos.find((row) => row.id_torneo === Number(id))?.deporte,
    posicion_final: index + 1,
    id_equipo: item.id_equipo,
    equipo: item.equipo,
    sigla: item.sigla,
    partidos_jugados: Math.max(0, 4 - index),
    partidos_ganados: Math.max(0, 3 - index),
    partidos_empatados: index % 2,
    partidos_perdidos: index,
    marcador_favor: Math.max(1, 10 - index * 2),
    marcador_contra: 2 + index,
    diferencia_marcador: 8 - index * 3,
    puntos: Math.max(0, 10 - index * 2),
    fecha_generacion: new Date().toISOString(),
    observaciones: null,
  }));
  return mockResult({ total: data.length, datos: data });
}

export async function obtenerJugadoresTorneo(id) {
  if (!usarMocks()) return apiGet(`/api/reportes/torneos/${id}/jugadores`);
  const registrationIds = new Set(mockDb.inscripciones.filter((item) => item.id_torneo === Number(id)).map((item) => item.id_inscripcion));
  const roster = Object.entries(mockDb.nominas).filter(([key]) => registrationIds.has(Number(key))).flatMap(([, rows]) => rows);
  const data = roster.map((item) => {
    const participations = Object.values(mockDb.participaciones).flat().filter((row) => row.id_jugador === item.id_jugador && row.id_torneo === Number(id));
    const registration = mockDb.inscripciones.find((row) => row.id_inscripcion === item.id_inscripcion);
    return { id_torneo: Number(id), torneo: registration?.torneo, id_jugador: item.id_jugador, numero_documento: item.numero_documento, nombres: item.nombres, apellido_paterno: item.apellido_paterno, apellido_materno: item.apellido_materno, id_equipo: registration?.id_equipo, equipo: registration?.equipo, partidos_registrados: participations.length, veces_convocado: participations.filter((row) => row.convocado).length, asistencias: participations.filter((row) => row.asistio).length, titularidades: participations.filter((row) => row.titular).length, porcentaje_asistencia: participations.length ? 100 : 0, minutos_jugados: participations.reduce((sum, row) => sum + row.minutos_jugados, 0), puntos_anotados: participations.reduce((sum, row) => sum + row.puntos_anotados, 0), faltas: participations.reduce((sum, row) => sum + row.faltas, 0), amonestaciones: participations.reduce((sum, row) => sum + row.amonestaciones, 0), expulsiones: participations.filter((row) => row.expulsado).length, lesiones: participations.filter((row) => row.lesionado).length, calificacion_promedio: participations.length ? (participations.reduce((sum, row) => sum + Number(row.calificacion || 0), 0) / participations.length).toFixed(1) : null };
  });
  return mockResult({ total: data.length, datos: data });
}

export async function obtenerPremiosTorneo(id) {
  if (!usarMocks()) return apiGet(`/api/reportes/torneos/${id}/premios`);
  tournamentOrError(id);
  const data = Number(id) === 4 ? [
    { tipo_premio: "ECONOMICO", premio: "Premio al campeón", equipo_ganador: "Cóndores del Sur", estado_entrega: "ENTREGADO", valor_economico: "1500.00", moneda: "BOB" },
    { tipo_premio: "TROFEO", premio: "Trofeo al subcampeón", equipo_ganador: "Andes United", estado_entrega: "ENTREGADO", valor_economico: "800.00", moneda: "BOB" },
  ] : [
    { tipo_premio: "ECONOMICO", premio: "Premio al campeón", equipo_ganador: null, estado_entrega: "PENDIENTE", valor_economico: "2000.00", moneda: "BOB" },
  ];
  return mockResult({ total: data.length, datos: data });
}

export async function obtenerRendimientoJugador(id) {
  if (!usarMocks()) return apiGet(`/api/reportes/jugadores/${id}/rendimiento`);
  const player = mockDb.jugadores.find((item) => item.id_jugador === Number(id));
  if (!player) mockError("Jugador no encontrado", 404);
  const participations = Object.values(mockDb.participaciones).flat().filter((item) => item.id_jugador === Number(id));
  const grouped = new Map();
  participations.forEach((item) => {
    const current = grouped.get(item.id_torneo) || { id_torneo: item.id_torneo, torneo: item.torneo, equipo: item.equipo, partidos_registrados: 0, veces_convocado: 0, asistencias: 0, titularidades: 0, minutos_jugados: 0, puntos_anotados: 0, faltas: 0, amonestaciones: 0, expulsiones: 0, lesiones: 0, calificaciones: [] };
    current.partidos_registrados += 1;
    current.veces_convocado += item.convocado ? 1 : 0;
    current.asistencias += item.asistio ? 1 : 0;
    current.titularidades += item.titular ? 1 : 0;
    current.minutos_jugados += item.minutos_jugados;
    current.puntos_anotados += item.puntos_anotados;
    current.faltas += item.faltas;
    current.amonestaciones += item.amonestaciones;
    current.expulsiones += item.expulsado ? 1 : 0;
    current.lesiones += item.lesionado ? 1 : 0;
    if (item.calificacion != null) current.calificaciones.push(Number(item.calificacion));
    grouped.set(item.id_torneo, current);
  });
  const data = [...grouped.values()].map((row) => ({ ...row, porcentaje_asistencia: row.veces_convocado ? ((row.asistencias / row.veces_convocado) * 100).toFixed(2) : "0.00", calificacion_promedio: row.calificaciones.length ? (row.calificaciones.reduce((sum, value) => sum + value, 0) / row.calificaciones.length).toFixed(2) : null, calificaciones: undefined }));
  return mockResult({ total: data.length, datos: data });
}

export async function obtenerHistorialEquipo(id) {
  if (!usarMocks()) return apiGet(`/api/reportes/equipos/${id}/historial`);
  const team = mockDb.equipos.find((item) => item.id_equipo === Number(id));
  if (!team) mockError("Equipo no encontrado", 404);
  const registrations = mockDb.inscripciones.filter((item) => item.id_equipo === Number(id));
  const data = registrations.map((item, index) => ({ id_torneo: item.id_torneo, torneo: item.torneo, estado_torneo: mockDb.torneos.find((row) => row.id_torneo === item.id_torneo)?.estado_torneo, estado_inscripcion: item.estado_inscripcion, posicion_final: index + 1, partidos_jugados: Math.max(0, 4 - index), partidos_ganados: Math.max(0, 3 - index), partidos_empatados: index % 2, partidos_perdidos: index, puntos: Math.max(0, 10 - index * 2) }));
  return mockResult({ total: data.length, datos: data });
}

export async function consultarAuditoria(filters = {}) {
  if (!usarMocks()) return apiGet(`/api/reportes/auditoria${crearQueryString(filters)}`);
  let rows = [...mockDb.auditoria];
  if (filters.esquema) rows = rows.filter((item) => item.esquema.includes(filters.esquema));
  if (filters.tabla) rows = rows.filter((item) => item.tabla.includes(filters.tabla));
  if (filters.operacion) rows = rows.filter((item) => item.operacion === filters.operacion);
  rows = rows.slice(0, Number(filters.limite || 100));
  return mockResult({ total: rows.length, datos: rows });
}
