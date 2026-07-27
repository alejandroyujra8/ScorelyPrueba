BEGIN;

INSERT INTO auditoria.configuracion_auditoria (
    esquema,
    tabla,
    columnas_pk,
    columnas_excluidas,
    descripcion
)
VALUES
    (
        'seguridad',
        'usuario',
        ARRAY['id_usuario'],
        ARRAY['contrasenia_hash'],
        'Auditoria de usuarios sin almacenar el hash de contrasenia'
    ),
    (
        'seguridad',
        'rol',
        ARRAY['id_rol'],
        ARRAY[]::TEXT[],
        'Auditoria de roles generales'
    ),
    (
        'seguridad',
        'usuario_rol',
        ARRAY['id_usuario_rol'],
        ARRAY[]::TEXT[],
        'Auditoria de roles asignados a usuarios'
    ),

    (
        'participantes',
        'jugador',
        ARRAY['id_usuario'],
        ARRAY[]::TEXT[],
        'Auditoria de perfiles de jugadores'
    ),
    (
        'participantes',
        'arbitro',
        ARRAY['id_usuario'],
        ARRAY[]::TEXT[],
        'Auditoria de perfiles de arbitros'
    ),
    (
        'participantes',
        'organizador',
        ARRAY['id_usuario'],
        ARRAY[]::TEXT[],
        'Auditoria de perfiles de organizadores'
    ),
    (
        'participantes',
        'equipo',
        ARRAY['id_equipo'],
        ARRAY[]::TEXT[],
        'Auditoria de equipos'
    ),
    (
        'participantes',
        'jugador_equipo',
        ARRAY['id_jugador_equipo'],
        ARRAY[]::TEXT[],
        'Auditoria del historial de jugadores en equipos'
    ),

    (
        'competencia',
        'deporte',
        ARRAY['id_deporte'],
        ARRAY[]::TEXT[],
        'Auditoria de deportes'
    ),
    (
        'competencia',
        'regla',
        ARRAY['id_regla'],
        ARRAY[]::TEXT[],
        'Auditoria de reglas'
    ),
    (
        'competencia',
        'deporte_regla',
        ARRAY['id_deporte_regla'],
        ARRAY[]::TEXT[],
        'Auditoria de reglas por deporte'
    ),
    (
        'competencia',
        'lugar',
        ARRAY['id_lugar'],
        ARRAY[]::TEXT[],
        'Auditoria de lugares'
    ),
    (
        'competencia',
        'torneo',
        ARRAY['id_torneo'],
        ARRAY[]::TEXT[],
        'Auditoria de torneos'
    ),
    (
        'competencia',
        'torneo_regla',
        ARRAY['id_torneo_regla'],
        ARRAY[]::TEXT[],
        'Auditoria de reglas de torneos'
    ),
    (
        'competencia',
        'fase_torneo',
        ARRAY['id_fase_torneo'],
        ARRAY[]::TEXT[],
        'Auditoria de fases'
    ),
    (
        'competencia',
        'grupo_torneo',
        ARRAY['id_grupo_torneo'],
        ARRAY[]::TEXT[],
        'Auditoria de grupos'
    ),
    (
        'competencia',
        'jornada',
        ARRAY['id_jornada'],
        ARRAY[]::TEXT[],
        'Auditoria de jornadas'
    ),
    (
        'competencia',
        'usuario_torneo_rol',
        ARRAY['id_usuario_torneo_rol'],
        ARRAY[]::TEXT[],
        'Auditoria de roles por torneo'
    ),
    (
        'competencia',
        'inscripcion',
        ARRAY['id_inscripcion'],
        ARRAY[]::TEXT[],
        'Auditoria de inscripciones'
    ),
    (
        'competencia',
        'jugador_inscripcion',
        ARRAY['id_jugador_inscripcion'],
        ARRAY[]::TEXT[],
        'Auditoria de nominas'
    ),
    (
        'competencia',
        'equipo_grupo',
        ARRAY['id_equipo_grupo'],
        ARRAY[]::TEXT[],
        'Auditoria de equipos asignados a grupos'
    ),
    (
        'competencia',
        'partido',
        ARRAY['id_partido'],
        ARRAY[]::TEXT[],
        'Auditoria de partidos'
    ),
    (
        'competencia',
        'partido_equipo',
        ARRAY['id_partido_equipo'],
        ARRAY[]::TEXT[],
        'Auditoria de equipos de partidos'
    ),
    (
        'competencia',
        'arbitro_partido',
        ARRAY['id_arbitro_partido'],
        ARRAY[]::TEXT[],
        'Auditoria de arbitros asignados'
    ),
    (
        'competencia',
        'jugador_partido',
        ARRAY['id_jugador_partido'],
        ARRAY[]::TEXT[],
        'Auditoria de asistencia y estadisticas'
    ),
    (
        'competencia',
        'resultado_torneo',
        ARRAY['id_resultado_torneo'],
        ARRAY[]::TEXT[],
        'Auditoria de resultados finales'
    ),

    (
        'finanzas',
        'pago',
        ARRAY['id_pago'],
        ARRAY[]::TEXT[],
        'Auditoria de pagos'
    ),
    (
        'finanzas',
        'premio',
        ARRAY['id_premio'],
        ARRAY[]::TEXT[],
        'Auditoria de premios'
    ),
    (
        'finanzas',
        'torneo_premio',
        ARRAY['id_torneo_premio'],
        ARRAY[]::TEXT[],
        'Auditoria de premios configurados por torneo'
    ),
    (
        'finanzas',
        'entrega_premio',
        ARRAY['id_entrega_premio'],
        ARRAY[]::TEXT[],
        'Auditoria de entregas de premios'
    )

ON CONFLICT (esquema, tabla)
DO UPDATE SET
    columnas_pk =
        EXCLUDED.columnas_pk,

    columnas_excluidas =
        EXCLUDED.columnas_excluidas,

    auditar_insert = TRUE,
    auditar_update = TRUE,
    auditar_delete = TRUE,
    activo = TRUE,

    descripcion =
        EXCLUDED.descripcion;

COMMIT;