BEGIN;

INSERT INTO catalogo.estado_partido (
    codigo,
    nombre,
    descripcion
)
VALUES
    (
        'BORRADOR',
        'Borrador',
        'El partido se encuentra en configuracion'
    ),
    (
        'PROGRAMADO',
        'Programado',
        'El partido tiene equipos, fecha y lugar definidos'
    ),
    (
        'EN_CURSO',
        'En curso',
        'El partido se encuentra en desarrollo'
    ),
    (
        'FINALIZADO',
        'Finalizado',
        'El partido concluyo y tiene resultado definitivo'
    ),
    (
        'SUSPENDIDO',
        'Suspendido',
        'El partido fue suspendido temporalmente'
    ),
    (
        'CANCELADO',
        'Cancelado',
        'El partido fue cancelado'
    )
ON CONFLICT (codigo) DO NOTHING;


INSERT INTO catalogo.condicion_equipo_partido (
    codigo,
    nombre,
    descripcion
)
VALUES
    (
        'LOCAL',
        'Local',
        'Equipo registrado como local para el enfrentamiento'
    ),
    (
        'VISITANTE',
        'Visitante',
        'Equipo registrado como visitante para el enfrentamiento'
    )
ON CONFLICT (codigo) DO NOTHING;


INSERT INTO catalogo.resultado_equipo_partido (
    codigo,
    nombre,
    descripcion
)
VALUES
    (
        'PENDIENTE',
        'Pendiente',
        'El partido todavia no tiene un resultado definitivo'
    ),
    (
        'GANADOR',
        'Ganador',
        'El equipo gano el partido'
    ),
    (
        'PERDEDOR',
        'Perdedor',
        'El equipo perdio el partido'
    ),
    (
        'EMPATE',
        'Empate',
        'El equipo empato el partido'
    )
ON CONFLICT (codigo) DO NOTHING;


INSERT INTO catalogo.tipo_arbitro_partido (
    codigo,
    nombre,
    descripcion
)
VALUES
    (
        'PRINCIPAL',
        'Arbitro principal',
        'Responsable principal de dirigir el partido'
    ),
    (
        'ASISTENTE_1',
        'Primer asistente',
        'Primer arbitro asistente'
    ),
    (
        'ASISTENTE_2',
        'Segundo asistente',
        'Segundo arbitro asistente'
    ),
    (
        'MESA',
        'Arbitro de mesa',
        'Responsable del control de mesa o planilla'
    )
ON CONFLICT (codigo) DO NOTHING;

COMMIT;