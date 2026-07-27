\pset pager off

\echo ''
\echo '========================================================='
\echo '1. RESUMEN DEL TORNEO'
\echo '========================================================='

SELECT
    id_torneo,
    codigo,
    nombre,
    deporte,
    formato,
    estado_torneo,
    total_inscripciones,
    inscripciones_habilitadas,
    total_partidos,
    partidos_finalizados,
    total_recaudado

FROM reportes.vw_torneos_resumen

WHERE codigo = 'FTS-DEMO-2026-01';


\echo ''
\echo '========================================================='
\echo '2. INSCRIPCIONES'
\echo '========================================================='

SELECT
    id_inscripcion,
    equipo,
    estado_inscripcion,
    monto_requerido,
    total_pagado,
    saldo_pendiente,
    jugadores_nomina,
    jugadores_habilitados

FROM reportes.vw_inscripciones_resumen

WHERE codigo_torneo = 'FTS-DEMO-2026-01'

ORDER BY equipo;


\echo ''
\echo '========================================================='
\echo '3. PAGOS'
\echo '========================================================='

SELECT
    equipo,
    metodo_pago,
    estado_pago,
    monto,
    moneda,
    referencia,
    fecha_verificacion

FROM reportes.vw_pagos_resumen

WHERE torneo = 'Copa Demo de Futsal 2026'

ORDER BY equipo, id_pago;


\echo ''
\echo '========================================================='
\echo '4. PARTIDO Y MARCADOR'
\echo '========================================================='

SELECT
    codigo,
    torneo,
    fase,
    jornada,
    equipo_local,
    marcador_local,
    resultado_local,
    equipo_visitante,
    marcador_visitante,
    resultado_visitante,
    estado_partido

FROM reportes.vw_partidos_detalle

WHERE codigo = 'FTS-DEMO-P001';


\echo ''
\echo '========================================================='
\echo '5. ASISTENCIA Y ESTADISTICAS'
\echo '========================================================='

SELECT
    equipo,
    nombres,
    apellido_paterno,
    convocado,
    asistio,
    titular,
    minutos_jugados,
    puntos_anotados,
    calificacion,
    estadisticas

FROM reportes.vw_asistencia_jugadores

WHERE partido = 'FTS-DEMO-P001'

ORDER BY equipo, nombres;


\echo ''
\echo '========================================================='
\echo '6. RESULTADOS FINALES'
\echo '========================================================='

SELECT
    posicion_final,
    equipo,
    partidos_jugados,
    partidos_ganados,
    partidos_empatados,
    partidos_perdidos,
    marcador_favor,
    marcador_contra,
    diferencia_marcador,
    puntos

FROM reportes.vw_resultados_torneo

WHERE codigo_torneo = 'FTS-DEMO-2026-01'

ORDER BY posicion_final;


\echo ''
\echo '========================================================='
\echo '7. PREMIO'
\echo '========================================================='

SELECT
    torneo,
    posicion_objetivo,
    premio,
    tipo_premio,
    valor_economico,
    moneda,
    equipo_ganador,
    estado_entrega,
    fecha_autorizacion,
    fecha_entrega

FROM reportes.vw_premios_entregas

WHERE torneo = 'Copa Demo de Futsal 2026';


\echo ''
\echo '========================================================='
\echo '8. HISTORIAL DE ESTADOS DEL TORNEO'
\echo '========================================================='

SELECT
    auditoria.operacion,
    auditoria.columnas_modificadas,
    auditoria.cambios,
    auditoria.usuario_aplicacion,
    auditoria.id_solicitud,
    auditoria.fecha_evento

FROM reportes.vw_auditoria_dml_detalle auditoria

WHERE auditoria.esquema = 'competencia'
  AND auditoria.tabla = 'torneo'
  AND auditoria.identificador_registro @> (
      SELECT JSONB_BUILD_OBJECT(
          'id_torneo',
          torneo.id_torneo
      )
      FROM competencia.torneo torneo
      WHERE torneo.codigo = 'FTS-DEMO-2026-01'
  )

ORDER BY auditoria.fecha_evento;


\echo ''
\echo '========================================================='
\echo '9. AUDITORIA DEL FLUJO COMPLETO'
\echo '========================================================='

SELECT
    esquema,
    tabla,
    operacion,
    identificador_registro,
    columnas_modificadas,
    usuario_aplicacion,
    id_transaccion,
    fecha_evento

FROM auditoria.auditoria_dml

WHERE id_solicitud =
      'FLUJO-DEMO-FUTSAL-2026-001'

ORDER BY id_auditoria;


\echo ''
\echo '========================================================='
\echo '10. CANTIDADES GENERADAS'
\echo '========================================================='

SELECT
    (
        SELECT COUNT(*)
        FROM competencia.inscripcion inscripcion
        INNER JOIN competencia.torneo torneo
            ON torneo.id_torneo =
               inscripcion.id_torneo
        WHERE torneo.codigo =
              'FTS-DEMO-2026-01'
    ) AS inscripciones,

    (
        SELECT COUNT(*)
        FROM competencia.jugador_inscripcion jugador
        INNER JOIN competencia.inscripcion inscripcion
            ON inscripcion.id_inscripcion =
               jugador.id_inscripcion
        INNER JOIN competencia.torneo torneo
            ON torneo.id_torneo =
               inscripcion.id_torneo
        WHERE torneo.codigo =
              'FTS-DEMO-2026-01'
    ) AS jugadores_nomina,

    (
        SELECT COUNT(*)
        FROM finanzas.pago pago
        INNER JOIN competencia.inscripcion inscripcion
            ON inscripcion.id_inscripcion =
               pago.id_inscripcion
        INNER JOIN competencia.torneo torneo
            ON torneo.id_torneo =
               inscripcion.id_torneo
        WHERE torneo.codigo =
              'FTS-DEMO-2026-01'
    ) AS pagos,

    (
        SELECT COUNT(*)
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
        WHERE torneo.codigo =
              'FTS-DEMO-2026-01'
    ) AS partidos,

    (
        SELECT COUNT(*)
        FROM competencia.jugador_partido participacion
        INNER JOIN competencia.partido partido
            ON partido.id_partido =
               participacion.id_partido
        WHERE partido.codigo =
              'FTS-DEMO-P001'
    ) AS participaciones,

    (
        SELECT COUNT(*)
        FROM competencia.resultado_torneo resultado
        INNER JOIN competencia.torneo torneo
            ON torneo.id_torneo =
               resultado.id_torneo
        WHERE torneo.codigo =
              'FTS-DEMO-2026-01'
    ) AS resultados,

    (
        SELECT COUNT(*)
        FROM finanzas.entrega_premio entrega
        INNER JOIN finanzas.torneo_premio torneo_premio
            ON torneo_premio.id_torneo_premio =
               entrega.id_torneo_premio
        INNER JOIN competencia.torneo torneo
            ON torneo.id_torneo =
               torneo_premio.id_torneo
        WHERE torneo.codigo =
              'FTS-DEMO-2026-01'
    ) AS entregas_premio;