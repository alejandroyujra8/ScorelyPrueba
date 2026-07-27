import {usarMocks} from "../config/environment";
import {mockDb, nextId} from "../mocks/mockData";
import {filterText, mockError, mockResult} from "../mocks/mockUtils";
import {apiGet, apiPost, crearQueryString} from "./api";

export async function listarInscripciones({id_torneo = "", estado = "", busqueda = ""} = {}) {
    if (!usarMocks()) return apiGet(`/api/inscripciones${crearQueryString({id_torneo, estado, busqueda})}`);
    let rows = [...mockDb.inscripciones];
    if (id_torneo) rows = rows.filter((item) => item.id_torneo === Number(id_torneo));
    if (estado) rows = rows.filter((item) => item.estado_inscripcion === estado);
    if (busqueda) rows = rows.filter((item) => filterText(`${item.torneo} ${item.equipo} ${item.sigla}`, busqueda));
    return mockResult({total: rows.length, resultados: rows});
}

export async function obtenerInscripcion(id) {
    if (!usarMocks()) return apiGet(`/api/inscripciones/${id}`);
    const item = mockDb.inscripciones.find((row) => row.id_inscripcion === Number(id));
    if (!item) mockError("Inscripción no encontrada", 404);
    return mockResult(item);
}

export async function crearInscripcion(data) {
    if (!usarMocks()) return apiPost("/api/inscripciones", data);
    if (mockDb.inscripciones.some((item) => item.id_torneo === Number(data.id_torneo) && item.id_equipo === Number(data.id_equipo))) mockError("El equipo ya se encuentra inscrito", 409);
    const torneo = mockDb.torneos.find((item) => item.id_torneo === Number(data.id_torneo));
    const equipo = mockDb.equipos.find((item) => item.id_equipo === Number(data.id_equipo));
    if (!torneo || !equipo) mockError("Torneo o equipo no encontrado", 404);
    const item = {
        id_inscripcion: nextId(mockDb.inscripciones, "id_inscripcion"),
        id_torneo: torneo.id_torneo,
        codigo_torneo: torneo.codigo,
        torneo: torneo.nombre,
        id_equipo: equipo.id_equipo,
        equipo: equipo.nombre,
        sigla: equipo.sigla,
        estado_inscripcion: "PENDIENTE",
        monto_requerido: torneo.costo_inscripcion,
        moneda: torneo.moneda,
        total_pagado: "0.00",
        saldo_pendiente: torneo.costo_inscripcion,
        jugadores_nomina: 0,
        jugadores_habilitados: 0,
        fecha_inscripcion: new Date().toISOString(),
        fecha_actualizacion: new Date().toISOString()
    };
    mockDb.inscripciones.unshift(item);
    mockDb.nominas[item.id_inscripcion] = [];
    mockDb.pagos[item.id_inscripcion] = [];
    torneo.total_inscripciones += 1;
    return mockResult(item);
}

export async function listarNomina(id) {
    if (!usarMocks()) return apiGet(`/api/inscripciones/${id}/nomina`);
    return mockResult(mockDb.nominas[Number(id)] || []);
}

export async function agregarJugadorNomina(id, data) {
    if (!usarMocks()) return apiPost(`/api/inscripciones/${id}/nomina`, data);
    const player = mockDb.jugadores.find((item) => item.id_jugador === Number(data.id_jugador));
    if (!player) mockError("Jugador no encontrado", 404);
    const list = mockDb.nominas[Number(id)] || (mockDb.nominas[Number(id)] = []);
    if (list.some((item) => item.id_jugador === player.id_jugador)) mockError("El jugador ya está en la nómina", 409);
    const item = {
        id_jugador_inscripcion: nextId(Object.values(mockDb.nominas).flat(), "id_jugador_inscripcion"),
        id_inscripcion: Number(id),
        id_jugador: player.id_jugador,
        numero_documento: player.numero_documento,
        nombres: player.nombres,
        apellido_paterno: player.apellido_paterno,
        apellido_materno: player.apellido_materno,
        numero_camiseta: data.numero_camiseta ? Number(data.numero_camiseta) : null,
        es_delegado: Boolean(data.es_delegado),
        es_capitan: Boolean(data.es_capitan),
        estado_codigo: "HABILITADO",
        fecha_baja: null,
        observaciones: data.observaciones || null
    };
    list.push(item);
    const registration = mockDb.inscripciones.find((row) => row.id_inscripcion === Number(id));
    if (registration) {
        registration.jugadores_nomina = list.length;
        registration.jugadores_habilitados = list.filter((row) => row.estado_codigo === "HABILITADO").length;
    }
    return mockResult(item);
}

export async function listarPagos(id) {
    if (!usarMocks()) return apiGet(`/api/inscripciones/${id}/pagos`);
    return mockResult(mockDb.pagos[Number(id)] || []);
}

export async function registrarPago(id, data) {
    if (!usarMocks()) return apiPost(`/api/inscripciones/${id}/pagos`, data);
    const registration = mockDb.inscripciones.find((row) => row.id_inscripcion === Number(id));
    if (!registration) mockError("Inscripción no encontrada", 404);
    const list = mockDb.pagos[Number(id)] || (mockDb.pagos[Number(id)] = []);
    const amount = Number(data.monto);
    const item = {
        id_pago: nextId(Object.values(mockDb.pagos).flat(), "id_pago"),
        id_inscripcion: registration.id_inscripcion,
        id_torneo: registration.id_torneo,
        torneo: registration.torneo,
        id_equipo: registration.id_equipo,
        equipo: registration.equipo,
        metodo_pago: data.metodo_codigo,
        estado_pago: data.estado_codigo || "PENDIENTE",
        monto: amount.toFixed(2),
        moneda: registration.moneda,
        referencia: data.referencia || null,
        fecha_pago: new Date().toISOString(),
        fecha_verificacion: data.estado_codigo === "CONFIRMADO" ? new Date().toISOString() : null,
        id_usuario_registro: 1,
        registrado_por: "Andrea Rojas",
        id_usuario_verificacion: data.estado_codigo === "CONFIRMADO" ? 1 : null,
        verificado_por: data.estado_codigo === "CONFIRMADO" ? "Andrea Rojas" : null,
        observaciones: data.observaciones || null
    };
    list.unshift(item);
    if (item.estado_pago === "CONFIRMADO") {
        registration.total_pagado = (Number(registration.total_pagado) + amount).toFixed(2);
        registration.saldo_pendiente = Math.max(0, Number(registration.monto_requerido) - Number(registration.total_pagado)).toFixed(2);
        if (Number(registration.saldo_pendiente) === 0) registration.estado_inscripcion = "HABILITADA";
    }
    return mockResult(item);
}
