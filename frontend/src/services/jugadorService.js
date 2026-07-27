import { usarMocks } from "../config/environment";
import { mockDb, nextId } from "../mocks/mockData";
import { filterText, mockError, mockResult } from "../mocks/mockUtils";
import { apiDelete, apiGet, apiPatch, apiPost, crearQueryString } from "./api";

export async function listarJugadores({ estado = "", id_equipo = "", busqueda = "", limite = 40, desplazamiento = 0 } = {}) {
  if (!usarMocks()) return apiGet(`/api/jugadores${crearQueryString({ estado, id_equipo, busqueda, limite, desplazamiento })}`);
  let rows = [...mockDb.jugadores];
  if (estado) rows = rows.filter((item) => item.estado_codigo === estado);
  if (id_equipo) rows = rows.filter((item) => item.id_equipo_actual === Number(id_equipo));
  if (busqueda) rows = rows.filter((item) => filterText(`${item.numero_documento} ${item.nombres} ${item.apellido_paterno} ${item.alias_deportivo || ""}`, busqueda));
  return mockResult({ total: rows.length, limite, desplazamiento, resultados: rows.slice(desplazamiento, desplazamiento + limite) });
}

export async function listarUsuariosDisponiblesJugador() {
  if (!usarMocks()) return apiGet("/api/jugadores/opciones/usuarios");
  const idsJugadores = new Set(
    mockDb.jugadores.map((jugador) => Number(jugador.id_jugador)),
  );
  return mockResult(
    mockDb.usuarios
      .filter(
        (usuario) =>
          usuario.estado_codigo === "ACTIVO" &&
          !idsJugadores.has(Number(usuario.id_usuario)),
      )
      .map((usuario) => ({
        id_usuario: usuario.id_usuario,
        numero_documento: usuario.numero_documento,
        nombre_completo: [
          usuario.nombres,
          usuario.apellido_paterno,
          usuario.apellido_materno,
        ].filter(Boolean).join(" "),
        correo: usuario.correo,
      })),
  );
}

export async function obtenerJugador(id) {
  if (!usarMocks()) return apiGet(`/api/jugadores/${id}`);
  const item = mockDb.jugadores.find((row) => row.id_jugador === Number(id));
  if (!item) mockError("Jugador no encontrado", 404);
  return mockResult(item);
}

export async function crearJugador(data) {
  if (!usarMocks()) return apiPost("/api/jugadores", data);
  const user = mockDb.usuarios.find((item) => item.id_usuario === Number(data.id_usuario));
  if (!user) mockError("No existe un usuario con ese identificador", 404);
  if (mockDb.jugadores.some((row) => row.id_jugador === user.id_usuario)) mockError("El usuario ya tiene un perfil de jugador", 409);
  const item = { id_jugador: user.id_usuario, numero_documento: user.numero_documento, nombres: user.nombres, apellido_paterno: user.apellido_paterno, apellido_materno: user.apellido_materno, alias_deportivo: data.alias_deportivo || null, observaciones: data.observaciones || null, estado_codigo: data.estado_codigo || "ACTIVO", id_membresia_actual: null, id_equipo_actual: null, equipo_actual: null, sigla_equipo_actual: null, numero_camiseta_actual: null, posicion_actual: null, es_delegado_actual: null };
  mockDb.jugadores.unshift(item);
  return mockResult(item);
}

export async function actualizarJugador(id, data) {
  if (!usarMocks()) return apiPatch(`/api/jugadores/${id}`, data);
  const index = mockDb.jugadores.findIndex((row) => row.id_jugador === Number(id));
  if (index < 0) mockError("Jugador no encontrado", 404);
  mockDb.jugadores[index] = { ...mockDb.jugadores[index], ...data };
  return mockResult(mockDb.jugadores[index]);
}

export async function desactivarJugador(id) {
  if (!usarMocks()) return apiDelete(`/api/jugadores/${id}`);
  return actualizarJugador(id, { estado_codigo: "INACTIVO" });
}

export async function listarMembresias(id) {
  if (!usarMocks()) return apiGet(`/api/jugadores/${id}/membresias`);
  return mockResult(mockDb.membresias.filter((item) => item.id_jugador === Number(id)));
}

export async function crearMembresia(idJugador, data) {
  if (!usarMocks()) return apiPost(`/api/jugadores/${idJugador}/membresias`, data);
  const team = mockDb.equipos.find((item) => item.id_equipo === Number(data.id_equipo));
  if (!team) mockError("Equipo no encontrado", 404);
  const item = { id_jugador_equipo: nextId(mockDb.membresias, "id_jugador_equipo"), id_jugador: Number(idJugador), id_equipo: team.id_equipo, equipo: team.nombre, sigla_equipo: team.sigla, fecha_inicio: data.fecha_inicio, fecha_fin: null, numero_camiseta: data.numero_camiseta ? Number(data.numero_camiseta) : null, posicion: data.posicion || null, es_delegado: Boolean(data.es_delegado), estado_codigo: "ACTIVA", registrado_por: 1, observaciones: data.observaciones || null };
  mockDb.membresias.push(item);
  const player = mockDb.jugadores.find((row) => row.id_jugador === Number(idJugador));
  Object.assign(player, { id_membresia_actual: item.id_jugador_equipo, id_equipo_actual: team.id_equipo, equipo_actual: team.nombre, sigla_equipo_actual: team.sigla, numero_camiseta_actual: item.numero_camiseta, posicion_actual: item.posicion, es_delegado_actual: item.es_delegado });
  return mockResult(item);
}

export async function transferirJugador(idJugador, data) {
  if (!usarMocks()) return apiPost(`/api/jugadores/${idJugador}/transferencias`, data);
  const active = mockDb.membresias.find((item) => item.id_jugador === Number(idJugador) && !item.fecha_fin);
  if (!active) mockError("El jugador no tiene una membresía activa", 422);
  active.fecha_fin = data.fecha_transferencia;
  active.estado_codigo = "FINALIZADA";
  const nueva = await crearMembresia(idJugador, { id_equipo: data.id_equipo_destino, fecha_inicio: data.fecha_transferencia, numero_camiseta: data.numero_camiseta, posicion: data.posicion, es_delegado: data.es_delegado, observaciones: data.observaciones });
  return mockResult({ membresia_anterior: active, membresia_nueva: nueva });
}

export async function finalizarMembresia(idJugador, idMembresia, data) {
  if (!usarMocks()) return apiPatch(`/api/jugadores/${idJugador}/membresias/${idMembresia}/finalizar`, data);
  const item = mockDb.membresias.find((row) => row.id_jugador_equipo === Number(idMembresia) && row.id_jugador === Number(idJugador));
  if (!item) mockError("Membresía no encontrada", 404);
  item.fecha_fin = data.fecha_fin;
  item.estado_codigo = "FINALIZADA";
  item.observaciones = data.observaciones || item.observaciones;
  const player = mockDb.jugadores.find((row) => row.id_jugador === Number(idJugador));
  Object.assign(player, { id_membresia_actual: null, id_equipo_actual: null, equipo_actual: null, sigla_equipo_actual: null, numero_camiseta_actual: null, posicion_actual: null, es_delegado_actual: null });
  return mockResult(item);
}
