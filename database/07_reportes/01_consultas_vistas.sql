-- =========================================================
-- USUARIOS
-- =========================================================

SELECT *
FROM reportes.vw_usuarios_roles
ORDER BY nombres, apellido_paterno;


SELECT *
FROM reportes.vw_resumen_usuarios_estado
ORDER BY estado_usuario;


-- =========================================================
-- JUGADORES Y EQUIPOS
-- =========================================================

SELECT *
FROM reportes.vw_jugadores_equipo_actual
ORDER BY equipo, nombres;


SELECT *
FROM reportes.vw_historial_jugador_equipo
ORDER BY id_jugador, fecha_inicio DESC;


-- =========================================================
-- DEPORTES Y LUGARES
-- =========================================================

SELECT *
FROM reportes.vw_deportes_configuracion
ORDER BY nombre;


SELECT *
FROM reportes.vw_lugares_programacion
ORDER BY proximo_partido NULLS LAST;


-- =========================================================
-- TORNEOS E INSCRIPCIONES
-- =========================================================

SELECT *
FROM reportes.vw_torneos_resumen
ORDER BY fecha_inicio_torneo DESC;


SELECT *
FROM reportes.vw_inscripciones_resumen
ORDER BY torneo, equipo;


-- =========================================================
-- PARTIDOS Y ASISTENCIA
-- =========================================================

SELECT *
FROM reportes.vw_partidos_detalle
ORDER BY fecha_hora_inicio NULLS LAST;


SELECT *
FROM reportes.vw_asistencia_jugadores
WHERE id_torneo = 1
ORDER BY equipo, nombres;


-- =========================================================
-- PAGOS Y PREMIOS
-- =========================================================

SELECT *
FROM reportes.vw_pagos_resumen
ORDER BY fecha_pago DESC;


SELECT *
FROM reportes.vw_premios_entregas
ORDER BY torneo, posicion_objetivo;


-- =========================================================
-- ESTADISTICAS Y AUDITORIA
-- =========================================================

SELECT *
FROM reportes.vw_estadisticas_jugadores_torneo
ORDER BY torneo, puntos_anotados DESC;


SELECT *
FROM reportes.vw_auditoria_dml_detalle
ORDER BY fecha_evento DESC
LIMIT 100;


-- =========================================================
-- RESULTADOS FINALES
-- =========================================================

SELECT *
FROM reportes.vw_resultados_torneo
ORDER BY torneo, posicion_final;


-- =========================================================
-- FUNCIONES PARAMETRIZADAS
-- =========================================================

SELECT *
FROM reportes.fn_resumen_torneo(1);


SELECT *
FROM reportes.fn_finanzas_torneo(1);


SELECT *
FROM reportes.fn_rendimiento_jugador(1);


SELECT *
FROM reportes.fn_historial_equipo(1);