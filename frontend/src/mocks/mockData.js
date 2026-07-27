export const mockDb = {
  usuarios: [
    { id_usuario: 1, numero_documento: "7000001", nombres: "Andrea", apellido_paterno: "Rojas", apellido_materno: "Mamani", correo: "admin.demo@torneos.test", estado_codigo: "ACTIVO", roles: ["ADMINISTRADOR"] },
    { id_usuario: 2, numero_documento: "7000002", nombres: "Mateo", apellido_paterno: "Flores", apellido_materno: "Quispe", correo: "organizador.demo@torneos.test", estado_codigo: "ACTIVO", roles: ["ORGANIZADOR"] },
    { id_usuario: 3, numero_documento: "7000003", nombres: "Lucía", apellido_paterno: "Vargas", apellido_materno: "Pérez", correo: "arbitro.demo@torneos.test", estado_codigo: "ACTIVO", roles: ["ARBITRO"] },
    { id_usuario: 4, numero_documento: "7000004", nombres: "Diego", apellido_paterno: "Mendoza", apellido_materno: "López", correo: "titanes1@torneos.test", estado_codigo: "ACTIVO", roles: ["JUGADOR"] },
  ],
  deportes: [
    { id_deporte: 1, codigo: "FUTBOL", nombre: "Fútbol", descripcion: "Competencia de fútbol por equipos.", cantidad_minima_jugadores: 7, cantidad_maxima_jugadores: 25, cantidad_titulares: 11, tipo_marcador: "GOL", permite_empate: true, puntos_victoria: 3, puntos_empate: 1, puntos_derrota: 0, estado_codigo: "ACTIVO", fecha_registro: "2026-01-05T10:00:00" },
    { id_deporte: 2, codigo: "BALONCESTO", nombre: "Baloncesto", descripcion: "Torneo competitivo de baloncesto.", cantidad_minima_jugadores: 5, cantidad_maxima_jugadores: 15, cantidad_titulares: 5, tipo_marcador: "PUNTO", permite_empate: false, puntos_victoria: 2, puntos_empate: 0, puntos_derrota: 1, estado_codigo: "ACTIVO", fecha_registro: "2026-01-06T10:00:00" },
    { id_deporte: 3, codigo: "VOLEIBOL", nombre: "Voleibol", descripcion: "Competencia por sets.", cantidad_minima_jugadores: 6, cantidad_maxima_jugadores: 18, cantidad_titulares: 6, tipo_marcador: "SET", permite_empate: false, puntos_victoria: 3, puntos_empate: 0, puntos_derrota: 0, estado_codigo: "ACTIVO", fecha_registro: "2026-01-07T10:00:00" },
    { id_deporte: 4, codigo: "FUTSAL", nombre: "Futsal", descripcion: "Modalidad de fútbol sala.", cantidad_minima_jugadores: 5, cantidad_maxima_jugadores: 14, cantidad_titulares: 5, tipo_marcador: "GOL", permite_empate: true, puntos_victoria: 3, puntos_empate: 1, puntos_derrota: 0, estado_codigo: "INACTIVO", fecha_registro: "2026-01-08T10:00:00" },
  ],
  equipos: [
    { id_equipo: 1, nombre: "Titanes Universitarios", sigla: "TIT", fecha_fundacion: "2018-03-12", descripcion: "Equipo universitario de alto rendimiento.", estado_codigo: "ACTIVO", creado_por: 1 },
    { id_equipo: 2, nombre: "Cóndores del Sur", sigla: "CDS", fecha_fundacion: "2019-07-21", descripcion: "Disciplina, velocidad y juego colectivo.", estado_codigo: "ACTIVO", creado_por: 1 },
    { id_equipo: 3, nombre: "Andes United", sigla: "AND", fecha_fundacion: "2020-01-14", descripcion: "Club multidisciplinario de La Paz.", estado_codigo: "ACTIVO", creado_por: 2 },
    { id_equipo: 4, nombre: "Rayo Paceño", sigla: "RAY", fecha_fundacion: "2017-11-02", descripcion: "Equipo ofensivo y dinámico.", estado_codigo: "ACTIVO", creado_por: 2 },
    { id_equipo: 5, nombre: "Horizonte FC", sigla: "HOR", fecha_fundacion: "2021-09-05", descripcion: "Talento joven y formación deportiva.", estado_codigo: "ACTIVO", creado_por: 2 },
    { id_equipo: 6, nombre: "Leones Metropolitanos", sigla: "LEO", fecha_fundacion: "2016-05-18", descripcion: "Experiencia y fortaleza defensiva.", estado_codigo: "INACTIVO", creado_por: 1 },
  ],
  jugadores: [
    { id_jugador: 4, numero_documento: "7000004", nombres: "Diego", apellido_paterno: "Mendoza", apellido_materno: "López", alias_deportivo: "D10", observaciones: null, estado_codigo: "ACTIVO", id_membresia_actual: 1, id_equipo_actual: 1, equipo_actual: "Titanes Universitarios", sigla_equipo_actual: "TIT", numero_camiseta_actual: 10, posicion_actual: "Delantero", es_delegado_actual: false },
    { id_jugador: 5, numero_documento: "7000005", nombres: "Bruno", apellido_paterno: "Choque", apellido_materno: "Ramos", alias_deportivo: "B7", observaciones: null, estado_codigo: "ACTIVO", id_membresia_actual: 2, id_equipo_actual: 1, equipo_actual: "Titanes Universitarios", sigla_equipo_actual: "TIT", numero_camiseta_actual: 7, posicion_actual: "Extremo", es_delegado_actual: false },
    { id_jugador: 6, numero_documento: "7000006", nombres: "Martín", apellido_paterno: "Quispe", apellido_materno: "Soto", alias_deportivo: "Muro", observaciones: null, estado_codigo: "ACTIVO", id_membresia_actual: 3, id_equipo_actual: 1, equipo_actual: "Titanes Universitarios", sigla_equipo_actual: "TIT", numero_camiseta_actual: 4, posicion_actual: "Defensa", es_delegado_actual: true },
    { id_jugador: 7, numero_documento: "7000007", nombres: "Santiago", apellido_paterno: "Paredes", apellido_materno: "Lima", alias_deportivo: "Santi", observaciones: null, estado_codigo: "ACTIVO", id_membresia_actual: 4, id_equipo_actual: 2, equipo_actual: "Cóndores del Sur", sigla_equipo_actual: "CDS", numero_camiseta_actual: 9, posicion_actual: "Delantero", es_delegado_actual: false },
    { id_jugador: 8, numero_documento: "7000008", nombres: "Iván", apellido_paterno: "Mamani", apellido_materno: "Cruz", alias_deportivo: "Iva", observaciones: null, estado_codigo: "ACTIVO", id_membresia_actual: 5, id_equipo_actual: 2, equipo_actual: "Cóndores del Sur", sigla_equipo_actual: "CDS", numero_camiseta_actual: 1, posicion_actual: "Arquero", es_delegado_actual: false },
    { id_jugador: 9, numero_documento: "7000009", nombres: "Gabriel", apellido_paterno: "Rojas", apellido_materno: "Nina", alias_deportivo: "Gabo", observaciones: null, estado_codigo: "ACTIVO", id_membresia_actual: 6, id_equipo_actual: 3, equipo_actual: "Andes United", sigla_equipo_actual: "AND", numero_camiseta_actual: 8, posicion_actual: "Mediocampo", es_delegado_actual: false },
    { id_jugador: 10, numero_documento: "7000010", nombres: "Tomás", apellido_paterno: "Apaza", apellido_materno: "Vega", alias_deportivo: "Tomi", observaciones: "En recuperación.", estado_codigo: "INACTIVO", id_membresia_actual: null, id_equipo_actual: null, equipo_actual: null, sigla_equipo_actual: null, numero_camiseta_actual: null, posicion_actual: null, es_delegado_actual: null },
    { id_jugador: 11, numero_documento: "7000011", nombres: "Nicolás", apellido_paterno: "Condori", apellido_materno: "Mora", alias_deportivo: "Nico", observaciones: null, estado_codigo: "ACTIVO", id_membresia_actual: 7, id_equipo_actual: 4, equipo_actual: "Rayo Paceño", sigla_equipo_actual: "RAY", numero_camiseta_actual: 11, posicion_actual: "Delantero", es_delegado_actual: false },
  ],
  membresias: [
    { id_jugador_equipo: 1, id_jugador: 4, id_equipo: 1, equipo: "Titanes Universitarios", sigla_equipo: "TIT", fecha_inicio: "2025-01-10", fecha_fin: null, numero_camiseta: 10, posicion: "Delantero", es_delegado: false, estado_codigo: "ACTIVA", registrado_por: 1, observaciones: null },
    { id_jugador_equipo: 2, id_jugador: 5, id_equipo: 1, equipo: "Titanes Universitarios", sigla_equipo: "TIT", fecha_inicio: "2025-01-10", fecha_fin: null, numero_camiseta: 7, posicion: "Extremo", es_delegado: false, estado_codigo: "ACTIVA", registrado_por: 1, observaciones: null },
    { id_jugador_equipo: 3, id_jugador: 6, id_equipo: 1, equipo: "Titanes Universitarios", sigla_equipo: "TIT", fecha_inicio: "2025-01-10", fecha_fin: null, numero_camiseta: 4, posicion: "Defensa", es_delegado: true, estado_codigo: "ACTIVA", registrado_por: 1, observaciones: null },
    { id_jugador_equipo: 4, id_jugador: 7, id_equipo: 2, equipo: "Cóndores del Sur", sigla_equipo: "CDS", fecha_inicio: "2025-02-03", fecha_fin: null, numero_camiseta: 9, posicion: "Delantero", es_delegado: false, estado_codigo: "ACTIVA", registrado_por: 2, observaciones: null },
    { id_jugador_equipo: 5, id_jugador: 8, id_equipo: 2, equipo: "Cóndores del Sur", sigla_equipo: "CDS", fecha_inicio: "2025-02-03", fecha_fin: null, numero_camiseta: 1, posicion: "Arquero", es_delegado: false, estado_codigo: "ACTIVA", registrado_por: 2, observaciones: null },
    { id_jugador_equipo: 6, id_jugador: 9, id_equipo: 3, equipo: "Andes United", sigla_equipo: "AND", fecha_inicio: "2025-03-12", fecha_fin: null, numero_camiseta: 8, posicion: "Mediocampo", es_delegado: false, estado_codigo: "ACTIVA", registrado_por: 2, observaciones: null },
    { id_jugador_equipo: 7, id_jugador: 11, id_equipo: 4, equipo: "Rayo Paceño", sigla_equipo: "RAY", fecha_inicio: "2025-04-01", fecha_fin: null, numero_camiseta: 11, posicion: "Delantero", es_delegado: false, estado_codigo: "ACTIVA", registrado_por: 2, observaciones: null },
  ],
  torneos: [
    { id_torneo: 1, id_deporte: 1, formato_codigo: "FASE_GRUPOS", codigo: "LPU-2026", nombre: "Liga Premier Universitaria", edicion: "2026", categoria: "Libre", rama: "MASCULINO", deporte: "Fútbol", formato: "Fase de grupos", estado_torneo: "EN_CURSO", fecha_inicio_inscripcion: "2026-02-01", fecha_fin_inscripcion: "2026-03-10", fecha_inicio_torneo: "2026-03-20", fecha_fin_torneo: "2026-08-30", cantidad_maxima_equipos: 16, cantidad_minima_jugadores: 15, cantidad_maxima_jugadores: 25, costo_inscripcion: "650.00", moneda: "BOB", permite_empate: true, descripcion: "Competencia universitaria organizada por grupos.", total_inscripciones: 6, inscripciones_habilitadas: 5, total_fases: 1, total_partidos: 18, partidos_finalizados: 11, total_recaudado: "3250.00" },
    { id_torneo: 2, id_deporte: 1, formato_codigo: "ELIMINACION_DIRECTA", codigo: "COPA-AND-26", nombre: "Copa Andes", edicion: "VIII", categoria: "Sub-23", rama: "MASCULINO", deporte: "Fútbol", formato: "Eliminación directa", estado_torneo: "INSCRIPCIONES_ABIERTAS", fecha_inicio_inscripcion: "2026-07-01", fecha_fin_inscripcion: "2026-08-05", fecha_inicio_torneo: "2026-08-15", fecha_fin_torneo: "2026-10-20", cantidad_maxima_equipos: 12, cantidad_minima_jugadores: 12, cantidad_maxima_jugadores: 22, costo_inscripcion: "500.00", moneda: "BOB", permite_empate: false, descripcion: "Copa universitaria por llaves eliminatorias.", total_inscripciones: 3, inscripciones_habilitadas: 2, total_fases: 0, total_partidos: 0, partidos_finalizados: 0, total_recaudado: "1000.00" },
    { id_torneo: 3, id_deporte: 2, formato_codigo: "FASE_GRUPOS", codigo: "BASKET-LP", nombre: "Circuito Metropolitano", edicion: "2026", categoria: "Libre", rama: "MIXTO", deporte: "Baloncesto", formato: "Fase de grupos", estado_torneo: "BORRADOR", fecha_inicio_inscripcion: "2026-08-10", fecha_fin_inscripcion: "2026-09-05", fecha_inicio_torneo: "2026-09-15", fecha_fin_torneo: "2026-11-30", cantidad_maxima_equipos: 10, cantidad_minima_jugadores: 8, cantidad_maxima_jugadores: 15, costo_inscripcion: "480.00", moneda: "BOB", permite_empate: false, descripcion: "Torneo metropolitano de baloncesto.", total_inscripciones: 0, inscripciones_habilitadas: 0, total_fases: 0, total_partidos: 0, partidos_finalizados: 0, total_recaudado: "0.00" },
    { id_torneo: 4, id_deporte: 3, formato_codigo: "FASE_GRUPOS", codigo: "VOL-INV", nombre: "Vóley Invierno", edicion: "2026", categoria: "Libre", rama: "FEMENINO", deporte: "Voleibol", formato: "Fase de grupos", estado_torneo: "FINALIZADO", fecha_inicio_inscripcion: "2026-03-01", fecha_fin_inscripcion: "2026-03-30", fecha_inicio_torneo: "2026-04-10", fecha_fin_torneo: "2026-06-25", cantidad_maxima_equipos: 8, cantidad_minima_jugadores: 8, cantidad_maxima_jugadores: 16, costo_inscripcion: "420.00", moneda: "BOB", permite_empate: false, descripcion: "Competencia femenina de voleibol.", total_inscripciones: 8, inscripciones_habilitadas: 8, total_fases: 1, total_partidos: 28, partidos_finalizados: 28, total_recaudado: "3360.00" },
  ],
  fases: [
    { id_fase_torneo: 1, id_torneo: 1, tipo_fase: "GRUPOS", estado_fase: "EN_CURSO", nombre: "Fase regular", numero_orden: 1, cantidad_clasificados: 4, fecha_inicio: "2026-03-20", fecha_fin: "2026-08-10", descripcion: "Todos contra todos." },
    { id_fase_torneo: 2, id_torneo: 4, tipo_fase: "FINAL", estado_fase: "FINALIZADA", nombre: "Fase única", numero_orden: 1, cantidad_clasificados: null, fecha_inicio: "2026-04-10", fecha_fin: "2026-06-25", descripcion: null },
  ],
  jornadas: [
    { id_jornada: 1, id_fase_torneo: 1, estado_jornada: "FINALIZADA", numero_jornada: 1, nombre: "Jornada 01", fecha_inicio: "2026-03-20T14:00:00", fecha_fin: "2026-03-22T20:00:00", observaciones: null },
    { id_jornada: 2, id_fase_torneo: 1, estado_jornada: "EN_CURSO", numero_jornada: 4, nombre: "Jornada 04", fecha_inicio: "2026-07-22T14:00:00", fecha_fin: "2026-07-26T20:00:00", observaciones: "Jornada actual." },
    { id_jornada: 3, id_fase_torneo: 1, estado_jornada: "PROGRAMADA", numero_jornada: 5, nombre: "Jornada 05", fecha_inicio: "2026-07-30T14:00:00", fecha_fin: "2026-08-02T20:00:00", observaciones: null },
  ],
  inscripciones: [
    { id_inscripcion: 1, id_torneo: 1, codigo_torneo: "LPU-2026", torneo: "Liga Premier Universitaria", id_equipo: 1, equipo: "Titanes Universitarios", sigla: "TIT", estado_inscripcion: "HABILITADA", monto_requerido: "650.00", moneda: "BOB", total_pagado: "650.00", saldo_pendiente: "0.00", jugadores_nomina: 3, jugadores_habilitados: 3, fecha_inscripcion: "2026-02-12T10:00:00", fecha_actualizacion: "2026-03-01T09:00:00" },
    { id_inscripcion: 2, id_torneo: 1, codigo_torneo: "LPU-2026", torneo: "Liga Premier Universitaria", id_equipo: 2, equipo: "Cóndores del Sur", sigla: "CDS", estado_inscripcion: "HABILITADA", monto_requerido: "650.00", moneda: "BOB", total_pagado: "650.00", saldo_pendiente: "0.00", jugadores_nomina: 2, jugadores_habilitados: 2, fecha_inscripcion: "2026-02-14T10:00:00", fecha_actualizacion: "2026-03-01T09:00:00" },
    { id_inscripcion: 3, id_torneo: 1, codigo_torneo: "LPU-2026", torneo: "Liga Premier Universitaria", id_equipo: 3, equipo: "Andes United", sigla: "AND", estado_inscripcion: "HABILITADA", monto_requerido: "650.00", moneda: "BOB", total_pagado: "650.00", saldo_pendiente: "0.00", jugadores_nomina: 1, jugadores_habilitados: 1, fecha_inscripcion: "2026-02-18T10:00:00", fecha_actualizacion: "2026-03-01T09:00:00" },
    { id_inscripcion: 4, id_torneo: 1, codigo_torneo: "LPU-2026", torneo: "Liga Premier Universitaria", id_equipo: 4, equipo: "Rayo Paceño", sigla: "RAY", estado_inscripcion: "HABILITADA", monto_requerido: "650.00", moneda: "BOB", total_pagado: "650.00", saldo_pendiente: "0.00", jugadores_nomina: 1, jugadores_habilitados: 1, fecha_inscripcion: "2026-02-20T10:00:00", fecha_actualizacion: "2026-03-01T09:00:00" },
    { id_inscripcion: 5, id_torneo: 1, codigo_torneo: "LPU-2026", torneo: "Liga Premier Universitaria", id_equipo: 5, equipo: "Horizonte FC", sigla: "HOR", estado_inscripcion: "PENDIENTE", monto_requerido: "650.00", moneda: "BOB", total_pagado: "0.00", saldo_pendiente: "650.00", jugadores_nomina: 0, jugadores_habilitados: 0, fecha_inscripcion: "2026-02-25T10:00:00", fecha_actualizacion: "2026-02-25T10:00:00" },
    { id_inscripcion: 6, id_torneo: 2, codigo_torneo: "COPA-AND-26", torneo: "Copa Andes", id_equipo: 1, equipo: "Titanes Universitarios", sigla: "TIT", estado_inscripcion: "HABILITADA", monto_requerido: "500.00", moneda: "BOB", total_pagado: "500.00", saldo_pendiente: "0.00", jugadores_nomina: 3, jugadores_habilitados: 3, fecha_inscripcion: "2026-07-04T10:00:00", fecha_actualizacion: "2026-07-05T10:00:00" },
  ],
  nominas: {
    1: [
      { id_jugador_inscripcion: 1, id_inscripcion: 1, id_jugador: 4, numero_documento: "7000004", nombres: "Diego", apellido_paterno: "Mendoza", apellido_materno: "López", numero_camiseta: 10, es_delegado: false, es_capitan: true, estado_codigo: "HABILITADO", fecha_baja: null, observaciones: null },
      { id_jugador_inscripcion: 2, id_inscripcion: 1, id_jugador: 5, numero_documento: "7000005", nombres: "Bruno", apellido_paterno: "Choque", apellido_materno: "Ramos", numero_camiseta: 7, es_delegado: false, es_capitan: false, estado_codigo: "HABILITADO", fecha_baja: null, observaciones: null },
      { id_jugador_inscripcion: 3, id_inscripcion: 1, id_jugador: 6, numero_documento: "7000006", nombres: "Martín", apellido_paterno: "Quispe", apellido_materno: "Soto", numero_camiseta: 4, es_delegado: true, es_capitan: false, estado_codigo: "HABILITADO", fecha_baja: null, observaciones: null },
    ],
    2: [
      { id_jugador_inscripcion: 4, id_inscripcion: 2, id_jugador: 7, numero_documento: "7000007", nombres: "Santiago", apellido_paterno: "Paredes", apellido_materno: "Lima", numero_camiseta: 9, es_delegado: false, es_capitan: true, estado_codigo: "HABILITADO", fecha_baja: null, observaciones: null },
      { id_jugador_inscripcion: 5, id_inscripcion: 2, id_jugador: 8, numero_documento: "7000008", nombres: "Iván", apellido_paterno: "Mamani", apellido_materno: "Cruz", numero_camiseta: 1, es_delegado: false, es_capitan: false, estado_codigo: "HABILITADO", fecha_baja: null, observaciones: null },
    ],
    3: [], 4: [], 5: [], 6: [],
  },
  pagos: {
    1: [{ id_pago: 1, id_inscripcion: 1, id_torneo: 1, torneo: "Liga Premier Universitaria", id_equipo: 1, equipo: "Titanes Universitarios", metodo_pago: "QR", estado_pago: "CONFIRMADO", monto: "650.00", moneda: "BOB", referencia: "QR-TIT-001", fecha_pago: "2026-02-15T12:30:00", fecha_verificacion: "2026-02-15T12:35:00", id_usuario_registro: 2, registrado_por: "Mateo Flores", id_usuario_verificacion: 1, verificado_por: "Andrea Rojas", observaciones: null }],
    2: [{ id_pago: 2, id_inscripcion: 2, id_torneo: 1, torneo: "Liga Premier Universitaria", id_equipo: 2, equipo: "Cóndores del Sur", metodo_pago: "TRANSFERENCIA", estado_pago: "CONFIRMADO", monto: "650.00", moneda: "BOB", referencia: "TR-CDS-002", fecha_pago: "2026-02-17T10:00:00", fecha_verificacion: "2026-02-17T10:10:00", id_usuario_registro: 2, registrado_por: "Mateo Flores", id_usuario_verificacion: 1, verificado_por: "Andrea Rojas", observaciones: null }],
    3: [], 4: [], 5: [], 6: [],
  },
  partidos: [
    { id_partido: 1, codigo: "LPU-J04-P01", numero_partido: 13, nombre_ronda: "Fecha 4", id_torneo: 1, torneo: "Liga Premier Universitaria", fase: "Fase regular", numero_jornada: 4, jornada: "Jornada 04", grupo: null, lugar: "Cancha Central UMSA", direccion_lugar: "Av. Villazón 1995", fecha_hora_inicio: "2026-07-23T15:00:00", fecha_hora_fin: "2026-07-23T17:00:00", estado_partido: "EN_CURSO", equipo_local: "Titanes Universitarios", marcador_local: 2, desempate_local: null, resultado_local: null, equipo_visitante: "Cóndores del Sur", marcador_visitante: 1, desempate_visitante: null, resultado_visitante: null, observaciones: null },
    { id_partido: 2, codigo: "LPU-J04-P02", numero_partido: 14, nombre_ronda: "Fecha 4", id_torneo: 1, torneo: "Liga Premier Universitaria", fase: "Fase regular", numero_jornada: 4, jornada: "Jornada 04", grupo: null, lugar: "Estadio Universitario", direccion_lugar: "Cota Cota", fecha_hora_inicio: "2026-07-24T18:30:00", fecha_hora_fin: "2026-07-24T20:30:00", estado_partido: "PROGRAMADO", equipo_local: "Andes United", marcador_local: null, desempate_local: null, resultado_local: null, equipo_visitante: "Rayo Paceño", marcador_visitante: null, desempate_visitante: null, resultado_visitante: null, observaciones: null },
    { id_partido: 3, codigo: "LPU-J03-P01", numero_partido: 9, nombre_ronda: "Fecha 3", id_torneo: 1, torneo: "Liga Premier Universitaria", fase: "Fase regular", numero_jornada: 3, jornada: "Jornada 03", grupo: null, lugar: "Cancha Central UMSA", direccion_lugar: "Av. Villazón 1995", fecha_hora_inicio: "2026-07-15T15:00:00", fecha_hora_fin: "2026-07-15T17:00:00", estado_partido: "FINALIZADO", equipo_local: "Titanes Universitarios", marcador_local: 3, desempate_local: null, resultado_local: "GANADOR", equipo_visitante: "Andes United", marcador_visitante: 0, desempate_visitante: null, resultado_visitante: "PERDEDOR", observaciones: null },
    { id_partido: 4, codigo: "LPU-J03-P02", numero_partido: 10, nombre_ronda: "Fecha 3", id_torneo: 1, torneo: "Liga Premier Universitaria", fase: "Fase regular", numero_jornada: 3, jornada: "Jornada 03", grupo: null, lugar: "Complejo Deportivo Sur", direccion_lugar: "Zona Sur", fecha_hora_inicio: "2026-07-16T16:00:00", fecha_hora_fin: "2026-07-16T18:00:00", estado_partido: "FINALIZADO", equipo_local: "Cóndores del Sur", marcador_local: 1, desempate_local: null, resultado_local: "EMPATE", equipo_visitante: "Rayo Paceño", marcador_visitante: 1, desempate_visitante: null, resultado_visitante: "EMPATE", observaciones: null },
    { id_partido: 5, codigo: "LPU-J05-P01", numero_partido: 17, nombre_ronda: "Fecha 5", id_torneo: 1, torneo: "Liga Premier Universitaria", fase: "Fase regular", numero_jornada: 5, jornada: "Jornada 05", grupo: null, lugar: "Cancha Central UMSA", direccion_lugar: "Av. Villazón 1995", fecha_hora_inicio: "2026-07-31T15:00:00", fecha_hora_fin: "2026-07-31T17:00:00", estado_partido: "PROGRAMADO", equipo_local: "Titanes Universitarios", marcador_local: null, desempate_local: null, resultado_local: null, equipo_visitante: "Rayo Paceño", marcador_visitante: null, desempate_visitante: null, resultado_visitante: null, observaciones: null },
    { id_partido: 6, codigo: "VOL-FINAL", numero_partido: 28, nombre_ronda: "Final", id_torneo: 4, torneo: "Vóley Invierno", fase: "Fase única", numero_jornada: 7, jornada: "Final", grupo: null, lugar: "Coliseo Cerrado", direccion_lugar: "Centro", fecha_hora_inicio: "2026-06-25T19:00:00", fecha_hora_fin: "2026-06-25T21:00:00", estado_partido: "FINALIZADO", equipo_local: "Cóndores del Sur", marcador_local: 3, desempate_local: null, resultado_local: "GANADOR", equipo_visitante: "Andes United", marcador_visitante: 1, desempate_visitante: null, resultado_visitante: "PERDEDOR", observaciones: null },
  ],
  participaciones: {
    1: [
      { id_jugador_partido: 1, id_torneo: 1, torneo: "Liga Premier Universitaria", id_partido: 1, partido: "LPU-J04-P01", id_equipo: 1, equipo: "Titanes Universitarios", id_jugador: 4, numero_documento: "7000004", nombres: "Diego", apellido_paterno: "Mendoza", apellido_materno: "López", convocado: true, asistio: true, titular: true, minutos_jugados: 70, puntos_anotados: 2, faltas: 1, amonestaciones: 0, expulsado: false, lesionado: false, calificacion: "8.7", estadisticas: {}, fecha_actualizacion: "2026-07-23T16:20:00" },
      { id_jugador_partido: 2, id_torneo: 1, torneo: "Liga Premier Universitaria", id_partido: 1, partido: "LPU-J04-P01", id_equipo: 2, equipo: "Cóndores del Sur", id_jugador: 7, numero_documento: "7000007", nombres: "Santiago", apellido_paterno: "Paredes", apellido_materno: "Lima", convocado: true, asistio: true, titular: true, minutos_jugados: 70, puntos_anotados: 1, faltas: 2, amonestaciones: 1, expulsado: false, lesionado: false, calificacion: "7.8", estadisticas: {}, fecha_actualizacion: "2026-07-23T16:20:00" },
    ],
  },
  lugares: [
    { id_lugar: 1, nombre: "Cancha Central UMSA", direccion: "Av. Villazón 1995", zona: "Centro", ciudad: "La Paz", capacidad: 1200, tipo_superficie: "Césped sintético" },
    { id_lugar: 2, nombre: "Estadio Universitario", direccion: "Cota Cota", zona: "Sur", ciudad: "La Paz", capacidad: 4000, tipo_superficie: "Césped natural" },
    { id_lugar: 3, nombre: "Complejo Deportivo Sur", direccion: "Av. Costanera", zona: "Sur", ciudad: "La Paz", capacidad: 900, tipo_superficie: "Césped sintético" },
  ],
  arbitros: [
    { id_arbitro: 1, numero_licencia: "ARB-001", nombre_completo: "Lucía Vargas Pérez", nivel: "Nacional" },
    { id_arbitro: 2, numero_licencia: "ARB-002", nombre_completo: "Carlos Medina Soto", nivel: "Departamental" },
  ],
  arbitrosPartidos: [
    { id_partido: 1, id_arbitro: 1, tipo_arbitro_codigo: "PRINCIPAL", activo: true },
    { id_partido: 2, id_arbitro: 1, tipo_arbitro_codigo: "PRINCIPAL", activo: true },
  ],
  auditoria: [
    { fecha_evento: "2026-07-23T13:44:10", esquema: "competencia", tabla: "partido", operacion: "UPDATE", identificador_registro: "1", columnas_modificadas: ["estado_partido", "marcador_local"], id_usuario: 3, usuario: "Lucía Vargas Pérez", direccion_ip: "127.0.0.1", request_id: "d7f2a3a1", datos_anteriores: { estado_partido: "PROGRAMADO", marcador_local: null }, datos_nuevos: { estado_partido: "EN_CURSO", marcador_local: 2 } },
    { fecha_evento: "2026-07-22T18:20:03", esquema: "competencia", tabla: "torneo", operacion: "UPDATE", identificador_registro: "1", columnas_modificadas: ["estado_torneo"], id_usuario: 2, usuario: "Mateo Flores Quispe", direccion_ip: "127.0.0.1", request_id: "2c6e92bd", datos_anteriores: { estado_torneo: "INSCRIPCIONES_ABIERTAS" }, datos_nuevos: { estado_torneo: "EN_CURSO" } },
    { fecha_evento: "2026-07-21T09:15:44", esquema: "finanzas", tabla: "pago", operacion: "INSERT", identificador_registro: "2", columnas_modificadas: ["monto", "estado_pago"], id_usuario: 2, usuario: "Mateo Flores Quispe", direccion_ip: "127.0.0.1", request_id: "8ac3d1e0", datos_anteriores: null, datos_nuevos: { monto: "650.00", estado_pago: "CONFIRMADO" } },
  ],
};

export const catalogosMock = {
  "estados-torneo": [
    "BORRADOR",
    "INSCRIPCIONES_ABIERTAS",
    "INSCRIPCIONES_CERRADAS",
    "PROGRAMADO",
    "EN_CURSO",
    "FINALIZADO",
    "CANCELADO",
  ],
  "formatos-torneo": [
    "PARTIDO_UNICO",
    "FASE_GRUPOS",
    "ELIMINACION_DIRECTA",
    "GRUPOS_Y_LLAVES",
  ],
  "estados-inscripcion": [
    "PENDIENTE",
    "PAGO_PENDIENTE",
    "HABILITADA",
    "RECHAZADA",
    "RETIRADA",
  ],
  "metodos-pago": [
    "EFECTIVO",
    "TRANSFERENCIA",
    "QR",
    "DEPOSITO",
    "OTRO",
  ],
  "estados-pago": [
    "PENDIENTE",
    "CONFIRMADO",
    "RECHAZADO",
    "ANULADO",
  ],
  "estados-partido": [
    "BORRADOR",
    "PROGRAMADO",
    "EN_CURSO",
    "FINALIZADO",
    "SUSPENDIDO",
    "CANCELADO",
  ],
  "tipos-fase": [
    "PARTIDO_UNICO",
    "GRUPOS",
    "ELIMINACION",
    "FINAL",
  ],
  "estados-fase": [
    "PENDIENTE",
    "EN_CURSO",
    "FINALIZADA",
    "CANCELADA",
  ],
  "estados-jornada": [
    "PROGRAMADA",
    "EN_CURSO",
    "FINALIZADA",
    "SUSPENDIDA",
    "CANCELADA",
  ],
  "roles-torneo": ["JUGADOR", "ARBITRO", "ORGANIZADOR"],
  "tipos-premio": [
    "ECONOMICO",
    "TROFEO",
    "MEDALLA",
    "RECONOCIMIENTO",
    "OTRO",
  ],
  "tipos-documento": ["CI", "PASAPORTE", "OTRO"],
  "estados-usuario": ["ACTIVO", "INACTIVO", "BLOQUEADO"],
  "estados-perfil": ["ACTIVO", "INACTIVO", "SUSPENDIDO"],
  "roles-sistema": [
    "ADMINISTRADOR",
    "ORGANIZADOR",
    "ARBITRO",
    "JUGADOR",
    "CONSULTA",
  ],
  "tipos-arbitro-partido": [
    "PRINCIPAL",
    "ASISTENTE_1",
    "ASISTENTE_2",
    "MESA",
  ],
  "estados-equipo": ["ACTIVO", "INACTIVO", "SUSPENDIDO"],
  "estados-deporte": ["ACTIVO", "INACTIVO"],
};

export function nextId(collection, key) {
  return Math.max(0, ...collection.map((item) => Number(item[key]) || 0)) + 1;
}
