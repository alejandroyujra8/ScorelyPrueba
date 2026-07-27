BEGIN;

-- =========================================================
-- INTEGRANTE 1: USUARIOS Y SEGURIDAD
-- =========================================================

CREATE OR REPLACE VIEW reportes.vw_usuarios_roles AS
SELECT
    usuario.id_usuario,
    usuario.numero_documento,
    usuario.nombres,
    usuario.apellido_paterno,
    usuario.apellido_materno,
    usuario.correo,
    usuario.telefono,

    estado.codigo AS estado_usuario,

    COALESCE(
        STRING_AGG(
            DISTINCT rol.codigo,
            ', '
            ORDER BY rol.codigo
        ) FILTER (
            WHERE usuario_rol.activo = TRUE
              AND usuario_rol.fecha_fin IS NULL
        ),
        'SIN_ROL'
    ) AS roles_activos,

    usuario.ultimo_acceso,
    usuario.fecha_registro

FROM seguridad.usuario usuario

INNER JOIN catalogo.estado_usuario estado
    ON estado.id_estado_usuario =
       usuario.id_estado_usuario

LEFT JOIN seguridad.usuario_rol usuario_rol
    ON usuario_rol.id_usuario =
       usuario.id_usuario

LEFT JOIN seguridad.rol rol
    ON rol.id_rol =
       usuario_rol.id_rol

GROUP BY
    usuario.id_usuario,
    usuario.numero_documento,
    usuario.nombres,
    usuario.apellido_paterno,
    usuario.apellido_materno,
    usuario.correo,
    usuario.telefono,
    estado.codigo,
    usuario.ultimo_acceso,
    usuario.fecha_registro;


CREATE OR REPLACE VIEW reportes.vw_resumen_usuarios_estado AS
SELECT
    estado.id_estado_usuario,
    estado.codigo AS estado_usuario,
    estado.nombre,

    COUNT(usuario.id_usuario) AS cantidad_usuarios,

    COUNT(*) FILTER (
        WHERE usuario.ultimo_acceso IS NOT NULL
    ) AS usuarios_con_acceso,

    COUNT(*) FILTER (
        WHERE usuario.ultimo_acceso IS NULL
    ) AS usuarios_sin_acceso,

    MAX(usuario.fecha_registro) AS ultimo_usuario_registrado

FROM catalogo.estado_usuario estado

LEFT JOIN seguridad.usuario usuario
    ON usuario.id_estado_usuario =
       estado.id_estado_usuario

GROUP BY
    estado.id_estado_usuario,
    estado.codigo,
    estado.nombre;


-- =========================================================
-- INTEGRANTE 2: JUGADORES Y EQUIPOS
-- =========================================================

CREATE OR REPLACE VIEW reportes.vw_jugadores_equipo_actual AS
SELECT
    jugador.id_usuario AS id_jugador,

    usuario.numero_documento,
    usuario.nombres,
    usuario.apellido_paterno,
    usuario.apellido_materno,

    jugador.alias_deportivo,

    membresia.id_jugador_equipo,
    equipo.id_equipo,
    equipo.nombre AS equipo,
    equipo.sigla,

    membresia.numero_camiseta,
    membresia.posicion,
    membresia.es_delegado,
    membresia.fecha_inicio,

    estado_membresia.codigo AS estado_membresia,
    estado_equipo.codigo AS estado_equipo

FROM participantes.jugador jugador

INNER JOIN seguridad.usuario usuario
    ON usuario.id_usuario =
       jugador.id_usuario

LEFT JOIN participantes.jugador_equipo membresia
    ON membresia.id_jugador =
       jugador.id_usuario
   AND membresia.fecha_fin IS NULL

LEFT JOIN catalogo.estado_membresia estado_membresia
    ON estado_membresia.id_estado_membresia =
       membresia.id_estado_membresia

LEFT JOIN participantes.equipo equipo
    ON equipo.id_equipo =
       membresia.id_equipo

LEFT JOIN catalogo.estado_equipo estado_equipo
    ON estado_equipo.id_estado_equipo =
       equipo.id_estado_equipo;


CREATE OR REPLACE VIEW reportes.vw_historial_jugador_equipo AS
SELECT
    membresia.id_jugador_equipo,

    usuario.id_usuario AS id_jugador,
    usuario.numero_documento,
    usuario.nombres,
    usuario.apellido_paterno,
    usuario.apellido_materno,

    equipo.id_equipo,
    equipo.nombre AS equipo,
    equipo.sigla,

    membresia.fecha_inicio,
    membresia.fecha_fin,

    CASE
        WHEN membresia.fecha_fin IS NULL
            THEN 'VIGENTE'
        ELSE 'FINALIZADA'
    END AS vigencia,

    membresia.numero_camiseta,
    membresia.posicion,
    membresia.es_delegado,

    estado.codigo AS estado_membresia,
    membresia.observaciones

FROM participantes.jugador_equipo membresia

INNER JOIN seguridad.usuario usuario
    ON usuario.id_usuario =
       membresia.id_jugador

INNER JOIN participantes.equipo equipo
    ON equipo.id_equipo =
       membresia.id_equipo

INNER JOIN catalogo.estado_membresia estado
    ON estado.id_estado_membresia =
       membresia.id_estado_membresia;


-- =========================================================
-- INTEGRANTE 3: DEPORTES Y LUGARES
-- =========================================================

CREATE OR REPLACE VIEW reportes.vw_deportes_configuracion AS
SELECT
    deporte.id_deporte,
    deporte.codigo,
    deporte.nombre,

    deporte.cantidad_minima_jugadores,
    deporte.cantidad_maxima_jugadores,
    deporte.cantidad_titulares,

    deporte.tipo_marcador,
    deporte.permite_empate,

    deporte.puntos_victoria,
    deporte.puntos_empate,
    deporte.puntos_derrota,

    estado.codigo AS estado_deporte,

    COUNT(deporte_regla.id_deporte_regla) FILTER (
        WHERE deporte_regla.activo = TRUE
          AND deporte_regla.fecha_fin IS NULL
    ) AS reglas_activas,

    COUNT(deporte_regla.id_deporte_regla) FILTER (
        WHERE deporte_regla.obligatorio = TRUE
          AND deporte_regla.activo = TRUE
          AND deporte_regla.fecha_fin IS NULL
    ) AS reglas_obligatorias

FROM competencia.deporte deporte

INNER JOIN catalogo.estado_deporte estado
    ON estado.id_estado_deporte =
       deporte.id_estado_deporte

LEFT JOIN competencia.deporte_regla deporte_regla
    ON deporte_regla.id_deporte =
       deporte.id_deporte

GROUP BY
    deporte.id_deporte,
    deporte.codigo,
    deporte.nombre,
    deporte.cantidad_minima_jugadores,
    deporte.cantidad_maxima_jugadores,
    deporte.cantidad_titulares,
    deporte.tipo_marcador,
    deporte.permite_empate,
    deporte.puntos_victoria,
    deporte.puntos_empate,
    deporte.puntos_derrota,
    estado.codigo;


CREATE OR REPLACE VIEW reportes.vw_lugares_programacion AS
SELECT
    lugar.id_lugar,
    lugar.nombre,
    lugar.direccion,
    lugar.zona,
    lugar.ciudad,
    lugar.capacidad,
    lugar.tipo_superficie,
    lugar.activo,

    COUNT(partido.id_partido) AS total_partidos,

    COUNT(partido.id_partido) FILTER (
        WHERE estado_partido.codigo = 'FINALIZADO'
    ) AS partidos_finalizados,

    COUNT(partido.id_partido) FILTER (
        WHERE estado_partido.codigo = 'PROGRAMADO'
    ) AS partidos_programados,

    MIN(partido.fecha_hora_inicio) FILTER (
        WHERE partido.fecha_hora_inicio >= CURRENT_TIMESTAMP
          AND estado_partido.codigo IN (
              'PROGRAMADO',
              'SUSPENDIDO'
          )
    ) AS proximo_partido

FROM competencia.lugar lugar

LEFT JOIN competencia.partido partido
    ON partido.id_lugar =
       lugar.id_lugar

LEFT JOIN catalogo.estado_partido estado_partido
    ON estado_partido.id_estado_partido =
       partido.id_estado_partido

GROUP BY
    lugar.id_lugar,
    lugar.nombre,
    lugar.direccion,
    lugar.zona,
    lugar.ciudad,
    lugar.capacidad,
    lugar.tipo_superficie,
    lugar.activo;


-- =========================================================
-- INTEGRANTE 4: TORNEOS E INSCRIPCIONES
-- =========================================================

CREATE OR REPLACE VIEW reportes.vw_torneos_resumen AS
SELECT
    torneo.id_torneo,
    torneo.codigo,
    torneo.nombre,
    torneo.edicion,
    torneo.categoria,
    torneo.rama,

    deporte.nombre AS deporte,
    formato.codigo AS formato,
    estado.codigo AS estado_torneo,

    torneo.fecha_inicio_inscripcion,
    torneo.fecha_fin_inscripcion,
    torneo.fecha_inicio_torneo,
    torneo.fecha_fin_torneo,

    torneo.cantidad_maxima_equipos,
    torneo.cantidad_minima_jugadores,
    torneo.cantidad_maxima_jugadores,

    torneo.costo_inscripcion,
    torneo.moneda,

    (
        SELECT COUNT(*)
        FROM competencia.inscripcion inscripcion
        WHERE inscripcion.id_torneo =
              torneo.id_torneo
    ) AS total_inscripciones,

    (
        SELECT COUNT(*)
        FROM competencia.inscripcion inscripcion
        INNER JOIN catalogo.estado_inscripcion estado_inscripcion
            ON estado_inscripcion.id_estado_inscripcion =
               inscripcion.id_estado_inscripcion
        WHERE inscripcion.id_torneo =
              torneo.id_torneo
          AND estado_inscripcion.codigo =
              'HABILITADA'
    ) AS inscripciones_habilitadas,

    (
        SELECT COUNT(*)
        FROM competencia.fase_torneo fase
        WHERE fase.id_torneo =
              torneo.id_torneo
    ) AS total_fases,

    (
        SELECT COUNT(*)
        FROM competencia.partido partido
        INNER JOIN competencia.jornada jornada
            ON jornada.id_jornada =
               partido.id_jornada
        INNER JOIN competencia.fase_torneo fase
            ON fase.id_fase_torneo =
               jornada.id_fase_torneo
        WHERE fase.id_torneo =
              torneo.id_torneo
    ) AS total_partidos,

    (
        SELECT COUNT(*)
        FROM competencia.partido partido
        INNER JOIN catalogo.estado_partido estado_partido
            ON estado_partido.id_estado_partido =
               partido.id_estado_partido
        INNER JOIN competencia.jornada jornada
            ON jornada.id_jornada =
               partido.id_jornada
        INNER JOIN competencia.fase_torneo fase
            ON fase.id_fase_torneo =
               jornada.id_fase_torneo
        WHERE fase.id_torneo =
              torneo.id_torneo
          AND estado_partido.codigo =
              'FINALIZADO'
    ) AS partidos_finalizados,

    (
        SELECT COALESCE(
            SUM(pago.monto),
            0
        )
        FROM finanzas.pago pago
        INNER JOIN catalogo.estado_pago estado_pago
            ON estado_pago.id_estado_pago =
               pago.id_estado_pago
        INNER JOIN competencia.inscripcion inscripcion
            ON inscripcion.id_inscripcion =
               pago.id_inscripcion
        WHERE inscripcion.id_torneo =
              torneo.id_torneo
          AND estado_pago.codigo =
              'CONFIRMADO'
    ) AS total_recaudado

FROM competencia.torneo torneo

INNER JOIN competencia.deporte deporte
    ON deporte.id_deporte =
       torneo.id_deporte

INNER JOIN catalogo.formato_torneo formato
    ON formato.id_formato_torneo =
       torneo.id_formato_torneo

INNER JOIN catalogo.estado_torneo estado
    ON estado.id_estado_torneo =
       torneo.id_estado_torneo;


CREATE OR REPLACE VIEW reportes.vw_inscripciones_resumen AS
SELECT
    inscripcion.id_inscripcion,

    torneo.id_torneo,
    torneo.codigo AS codigo_torneo,
    torneo.nombre AS torneo,

    equipo.id_equipo,
    equipo.nombre AS equipo,
    equipo.sigla,

    estado.codigo AS estado_inscripcion,

    inscripcion.monto_requerido,
    inscripcion.moneda,

    finanzas.fn_total_pagado_inscripcion(
        inscripcion.id_inscripcion
    ) AS total_pagado,

    finanzas.fn_saldo_inscripcion(
        inscripcion.id_inscripcion
    ) AS saldo_pendiente,

    (
        SELECT COUNT(*)
        FROM competencia.jugador_inscripcion jugador
        WHERE jugador.id_inscripcion =
              inscripcion.id_inscripcion
          AND jugador.fecha_baja IS NULL
    ) AS jugadores_nomina,

    (
        SELECT COUNT(*)
        FROM competencia.jugador_inscripcion jugador
        INNER JOIN catalogo.estado_jugador_inscripcion estado_jugador
            ON estado_jugador.id_estado_jugador_inscripcion =
               jugador.id_estado_jugador_inscripcion
        WHERE jugador.id_inscripcion =
              inscripcion.id_inscripcion
          AND jugador.fecha_baja IS NULL
          AND estado_jugador.codigo =
              'HABILITADO'
    ) AS jugadores_habilitados,

    inscripcion.fecha_inscripcion,
    inscripcion.fecha_actualizacion

FROM competencia.inscripcion inscripcion

INNER JOIN competencia.torneo torneo
    ON torneo.id_torneo =
       inscripcion.id_torneo

INNER JOIN participantes.equipo equipo
    ON equipo.id_equipo =
       inscripcion.id_equipo

INNER JOIN catalogo.estado_inscripcion estado
    ON estado.id_estado_inscripcion =
       inscripcion.id_estado_inscripcion;


-- =========================================================
-- INTEGRANTE 5: PARTIDOS Y ASISTENCIA
-- =========================================================

CREATE OR REPLACE VIEW reportes.vw_partidos_detalle AS
SELECT
    partido.id_partido,
    partido.codigo,
    partido.numero_partido,
    partido.nombre_ronda,

    torneo.id_torneo,
    torneo.nombre AS torneo,

    fase.nombre AS fase,
    jornada.numero_jornada,
    jornada.nombre AS jornada,

    grupo.codigo AS grupo,

    lugar.nombre AS lugar,
    lugar.direccion AS direccion_lugar,

    partido.fecha_hora_inicio,
    partido.fecha_hora_fin,

    estado_partido.codigo AS estado_partido,

    MAX(equipo.nombre) FILTER (
        WHERE condicion.codigo = 'LOCAL'
    ) AS equipo_local,

    MAX(partido_equipo.marcador) FILTER (
        WHERE condicion.codigo = 'LOCAL'
    ) AS marcador_local,

    MAX(partido_equipo.marcador_desempate) FILTER (
        WHERE condicion.codigo = 'LOCAL'
    ) AS desempate_local,

    MAX(resultado.codigo) FILTER (
        WHERE condicion.codigo = 'LOCAL'
    ) AS resultado_local,

    MAX(equipo.nombre) FILTER (
        WHERE condicion.codigo = 'VISITANTE'
    ) AS equipo_visitante,

    MAX(partido_equipo.marcador) FILTER (
        WHERE condicion.codigo = 'VISITANTE'
    ) AS marcador_visitante,

    MAX(partido_equipo.marcador_desempate) FILTER (
        WHERE condicion.codigo = 'VISITANTE'
    ) AS desempate_visitante,

    MAX(resultado.codigo) FILTER (
        WHERE condicion.codigo = 'VISITANTE'
    ) AS resultado_visitante,

    partido.observaciones

FROM competencia.partido partido

INNER JOIN competencia.jornada jornada
    ON jornada.id_jornada =
       partido.id_jornada

INNER JOIN competencia.fase_torneo fase
    ON fase.id_fase_torneo =
       jornada.id_fase_torneo

INNER JOIN competencia.torneo torneo
    ON torneo.id_torneo =
       fase.id_torneo

INNER JOIN catalogo.estado_partido estado_partido
    ON estado_partido.id_estado_partido =
       partido.id_estado_partido

LEFT JOIN competencia.grupo_torneo grupo
    ON grupo.id_grupo_torneo =
       partido.id_grupo_torneo

LEFT JOIN competencia.lugar lugar
    ON lugar.id_lugar =
       partido.id_lugar

LEFT JOIN competencia.partido_equipo partido_equipo
    ON partido_equipo.id_partido =
       partido.id_partido

LEFT JOIN competencia.inscripcion inscripcion
    ON inscripcion.id_inscripcion =
       partido_equipo.id_inscripcion

LEFT JOIN participantes.equipo equipo
    ON equipo.id_equipo =
       inscripcion.id_equipo

LEFT JOIN catalogo.condicion_equipo_partido condicion
    ON condicion.id_condicion_equipo =
       partido_equipo.id_condicion_equipo

LEFT JOIN catalogo.resultado_equipo_partido resultado
    ON resultado.id_resultado_equipo_partido =
       partido_equipo.id_resultado_equipo_partido

GROUP BY
    partido.id_partido,
    partido.codigo,
    partido.numero_partido,
    partido.nombre_ronda,
    torneo.id_torneo,
    torneo.nombre,
    fase.nombre,
    jornada.numero_jornada,
    jornada.nombre,
    grupo.codigo,
    lugar.nombre,
    lugar.direccion,
    partido.fecha_hora_inicio,
    partido.fecha_hora_fin,
    estado_partido.codigo,
    partido.observaciones;


CREATE OR REPLACE VIEW reportes.vw_asistencia_jugadores AS
SELECT
    participacion.id_jugador_partido,

    torneo.id_torneo,
    torneo.nombre AS torneo,

    partido.id_partido,
    partido.codigo AS partido,

    equipo.id_equipo,
    equipo.nombre AS equipo,

    usuario.id_usuario AS id_jugador,
    usuario.numero_documento,
    usuario.nombres,
    usuario.apellido_paterno,
    usuario.apellido_materno,

    participacion.convocado,
    participacion.asistio,
    participacion.titular,

    participacion.minutos_jugados,
    participacion.puntos_anotados,
    participacion.faltas,
    participacion.amonestaciones,

    participacion.expulsado,
    participacion.lesionado,
    participacion.calificacion,
    participacion.estadisticas,

    participacion.fecha_actualizacion

FROM competencia.jugador_partido participacion

INNER JOIN competencia.jugador_inscripcion jugador_nomina
    ON jugador_nomina.id_jugador_inscripcion =
       participacion.id_jugador_inscripcion

INNER JOIN seguridad.usuario usuario
    ON usuario.id_usuario =
       jugador_nomina.id_jugador

INNER JOIN competencia.partido partido
    ON partido.id_partido =
       participacion.id_partido

INNER JOIN competencia.partido_equipo partido_equipo
    ON partido_equipo.id_partido_equipo =
       participacion.id_partido_equipo

INNER JOIN competencia.inscripcion inscripcion
    ON inscripcion.id_inscripcion =
       partido_equipo.id_inscripcion

INNER JOIN participantes.equipo equipo
    ON equipo.id_equipo =
       inscripcion.id_equipo

INNER JOIN competencia.torneo torneo
    ON torneo.id_torneo =
       inscripcion.id_torneo;


-- =========================================================
-- INTEGRANTE 6: PAGOS Y PREMIOS
-- =========================================================

CREATE OR REPLACE VIEW reportes.vw_pagos_resumen AS
SELECT
    pago.id_pago,

    inscripcion.id_inscripcion,

    torneo.id_torneo,
    torneo.nombre AS torneo,

    equipo.id_equipo,
    equipo.nombre AS equipo,

    metodo.codigo AS metodo_pago,
    estado.codigo AS estado_pago,

    pago.monto,
    pago.moneda,
    pago.referencia,

    pago.fecha_pago,
    pago.fecha_verificacion,

    usuario_registro.id_usuario AS id_usuario_registro,

    CONCAT_WS(
        ' ',
        usuario_registro.nombres,
        usuario_registro.apellido_paterno,
        usuario_registro.apellido_materno
    ) AS registrado_por,

    usuario_verificacion.id_usuario AS id_usuario_verificacion,

    CONCAT_WS(
        ' ',
        usuario_verificacion.nombres,
        usuario_verificacion.apellido_paterno,
        usuario_verificacion.apellido_materno
    ) AS verificado_por,

    pago.observaciones

FROM finanzas.pago pago

INNER JOIN competencia.inscripcion inscripcion
    ON inscripcion.id_inscripcion =
       pago.id_inscripcion

INNER JOIN competencia.torneo torneo
    ON torneo.id_torneo =
       inscripcion.id_torneo

INNER JOIN participantes.equipo equipo
    ON equipo.id_equipo =
       inscripcion.id_equipo

INNER JOIN catalogo.metodo_pago metodo
    ON metodo.id_metodo_pago =
       pago.id_metodo_pago

INNER JOIN catalogo.estado_pago estado
    ON estado.id_estado_pago =
       pago.id_estado_pago

INNER JOIN seguridad.usuario usuario_registro
    ON usuario_registro.id_usuario =
       pago.registrado_por

LEFT JOIN seguridad.usuario usuario_verificacion
    ON usuario_verificacion.id_usuario =
       pago.verificado_por;


CREATE OR REPLACE VIEW reportes.vw_premios_entregas AS
SELECT
    torneo_premio.id_torneo_premio,

    torneo.id_torneo,
    torneo.nombre AS torneo,

    torneo_premio.posicion_objetivo,

    premio.id_premio,
    premio.nombre AS premio,

    tipo.codigo AS tipo_premio,

    torneo_premio.valor_economico,
    torneo_premio.moneda,

    resultado.id_resultado_torneo,
    resultado.posicion_final,

    equipo.id_equipo,
    equipo.nombre AS equipo_ganador,

    entrega.id_entrega_premio,

    estado_entrega.codigo AS estado_entrega,

    entrega.fecha_autorizacion,
    entrega.fecha_entrega,

    entrega.autorizado_por,
    entrega.entregado_por,

    entrega.observaciones

FROM finanzas.torneo_premio torneo_premio

INNER JOIN competencia.torneo torneo
    ON torneo.id_torneo =
       torneo_premio.id_torneo

INNER JOIN finanzas.premio premio
    ON premio.id_premio =
       torneo_premio.id_premio

INNER JOIN catalogo.tipo_premio tipo
    ON tipo.id_tipo_premio =
       premio.id_tipo_premio

LEFT JOIN competencia.resultado_torneo resultado
    ON resultado.id_torneo =
       torneo_premio.id_torneo
   AND resultado.posicion_final =
       torneo_premio.posicion_objetivo

LEFT JOIN competencia.inscripcion inscripcion
    ON inscripcion.id_inscripcion =
       resultado.id_inscripcion

LEFT JOIN participantes.equipo equipo
    ON equipo.id_equipo =
       inscripcion.id_equipo

LEFT JOIN finanzas.entrega_premio entrega
    ON entrega.id_torneo_premio =
       torneo_premio.id_torneo_premio

LEFT JOIN catalogo.estado_entrega_premio estado_entrega
    ON estado_entrega.id_estado_entrega_premio =
       entrega.id_estado_entrega_premio;


-- =========================================================
-- INTEGRANTE 7: ESTADISTICAS Y AUDITORIA
-- =========================================================

CREATE OR REPLACE VIEW reportes.vw_estadisticas_jugadores_torneo AS
SELECT
    torneo.id_torneo,
    torneo.nombre AS torneo,

    usuario.id_usuario AS id_jugador,
    usuario.numero_documento,

    usuario.nombres,
    usuario.apellido_paterno,
    usuario.apellido_materno,

    equipo.id_equipo,
    equipo.nombre AS equipo,

    COUNT(DISTINCT participacion.id_partido)
        AS partidos_registrados,

    COUNT(*) FILTER (
        WHERE participacion.convocado = TRUE
    ) AS veces_convocado,

    COUNT(*) FILTER (
        WHERE participacion.asistio = TRUE
    ) AS asistencias,

    COUNT(*) FILTER (
        WHERE participacion.titular = TRUE
    ) AS titularidades,

    ROUND(
        (
            COUNT(*) FILTER (
                WHERE participacion.asistio = TRUE
            )::NUMERIC
            /
            NULLIF(
                COUNT(*) FILTER (
                    WHERE participacion.convocado = TRUE
                ),
                0
            )
        ) * 100,
        2
    ) AS porcentaje_asistencia,

    SUM(participacion.minutos_jugados)
        AS minutos_jugados,

    SUM(participacion.puntos_anotados)
        AS puntos_anotados,

    SUM(participacion.faltas)
        AS faltas,

    SUM(participacion.amonestaciones)
        AS amonestaciones,

    COUNT(*) FILTER (
        WHERE participacion.expulsado = TRUE
    ) AS expulsiones,

    COUNT(*) FILTER (
        WHERE participacion.lesionado = TRUE
    ) AS lesiones,

    ROUND(
        AVG(participacion.calificacion),
        2
    ) AS calificacion_promedio

FROM competencia.jugador_partido participacion

INNER JOIN competencia.jugador_inscripcion jugador_nomina
    ON jugador_nomina.id_jugador_inscripcion =
       participacion.id_jugador_inscripcion

INNER JOIN seguridad.usuario usuario
    ON usuario.id_usuario =
       jugador_nomina.id_jugador

INNER JOIN competencia.inscripcion inscripcion
    ON inscripcion.id_inscripcion =
       jugador_nomina.id_inscripcion

INNER JOIN participantes.equipo equipo
    ON equipo.id_equipo =
       inscripcion.id_equipo

INNER JOIN competencia.torneo torneo
    ON torneo.id_torneo =
       inscripcion.id_torneo

GROUP BY
    torneo.id_torneo,
    torneo.nombre,
    usuario.id_usuario,
    usuario.numero_documento,
    usuario.nombres,
    usuario.apellido_paterno,
    usuario.apellido_materno,
    equipo.id_equipo,
    equipo.nombre;


CREATE OR REPLACE VIEW reportes.vw_auditoria_dml_detalle AS
SELECT
    auditoria.id_auditoria,
    auditoria.fecha_evento,

    auditoria.esquema,
    auditoria.tabla,
    auditoria.operacion,

    auditoria.identificador_registro,
    auditoria.columnas_modificadas,

    auditoria.datos_anteriores,
    auditoria.datos_nuevos,
    auditoria.cambios,

    auditoria.usuario_aplicacion,

    CONCAT_WS(
        ' ',
        usuario.nombres,
        usuario.apellido_paterno,
        usuario.apellido_materno
    ) AS usuario_aplicacion_nombre,

    auditoria.usuario_postgresql,
    auditoria.usuario_sesion,

    auditoria.ip_cliente,
    auditoria.id_solicitud,
    auditoria.id_transaccion,
    auditoria.aplicacion

FROM auditoria.auditoria_dml auditoria

LEFT JOIN seguridad.usuario usuario
    ON usuario.id_usuario =
       auditoria.usuario_aplicacion;


-- =========================================================
-- VISTA ADICIONAL: RESULTADOS FINALES
-- =========================================================

CREATE OR REPLACE VIEW reportes.vw_resultados_torneo AS
SELECT
    resultado.id_resultado_torneo,

    torneo.id_torneo,
    torneo.codigo AS codigo_torneo,
    torneo.nombre AS torneo,

    deporte.nombre AS deporte,

    resultado.posicion_final,

    equipo.id_equipo,
    equipo.nombre AS equipo,
    equipo.sigla,

    resultado.partidos_jugados,
    resultado.partidos_ganados,
    resultado.partidos_empatados,
    resultado.partidos_perdidos,

    resultado.marcador_favor,
    resultado.marcador_contra,
    resultado.diferencia_marcador,
    resultado.puntos,

    resultado.fecha_generacion,
    resultado.observaciones

FROM competencia.resultado_torneo resultado

INNER JOIN competencia.torneo torneo
    ON torneo.id_torneo =
       resultado.id_torneo

INNER JOIN competencia.deporte deporte
    ON deporte.id_deporte =
       torneo.id_deporte

INNER JOIN competencia.inscripcion inscripcion
    ON inscripcion.id_inscripcion =
       resultado.id_inscripcion

INNER JOIN participantes.equipo equipo
    ON equipo.id_equipo =
       inscripcion.id_equipo;

COMMIT;