BEGIN;

INSERT INTO catalogo.estado_deporte (
    codigo,
    nombre,
    descripcion
)
VALUES
    (
        'ACTIVO',
        'Activo',
        'El deporte esta disponible para crear torneos'
    ),
    (
        'INACTIVO',
        'Inactivo',
        'El deporte no esta disponible temporalmente'
    )
ON CONFLICT (codigo) DO NOTHING;


INSERT INTO catalogo.formato_torneo (
    codigo,
    nombre,
    descripcion
)
VALUES
    (
        'PARTIDO_UNICO',
        'Partido unico',
        'Torneo compuesto por un solo enfrentamiento'
    ),
    (
        'FASE_GRUPOS',
        'Fase de grupos',
        'Torneo compuesto solamente por grupos'
    ),
    (
        'ELIMINACION_DIRECTA',
        'Eliminacion directa',
        'Torneo desarrollado mediante llaves eliminatorias'
    ),
    (
        'GRUPOS_Y_LLAVES',
        'Grupos y llaves',
        'Torneo con fase de grupos y eliminacion directa'
    )
ON CONFLICT (codigo) DO NOTHING;


INSERT INTO catalogo.estado_torneo (
    codigo,
    nombre,
    descripcion
)
VALUES
    (
        'BORRADOR',
        'Borrador',
        'El torneo se encuentra en configuracion'
    ),
    (
        'INSCRIPCIONES_ABIERTAS',
        'Inscripciones abiertas',
        'Los equipos pueden solicitar su inscripcion'
    ),
    (
        'INSCRIPCIONES_CERRADAS',
        'Inscripciones cerradas',
        'Ya no se reciben nuevas inscripciones'
    ),
    (
        'PROGRAMADO',
        'Programado',
        'El torneo esta preparado para iniciar'
    ),
    (
        'EN_CURSO',
        'En curso',
        'El torneo se encuentra en desarrollo'
    ),
    (
        'FINALIZADO',
        'Finalizado',
        'El torneo concluyo correctamente'
    ),
    (
        'CANCELADO',
        'Cancelado',
        'El torneo fue cancelado'
    )
ON CONFLICT (codigo) DO NOTHING;


INSERT INTO catalogo.tipo_fase (
    codigo,
    nombre,
    descripcion
)
VALUES
    (
        'PARTIDO_UNICO',
        'Partido unico',
        'Fase con un unico enfrentamiento'
    ),
    (
        'GRUPOS',
        'Grupos',
        'Fase de competencia organizada por grupos'
    ),
    (
        'ELIMINACION',
        'Eliminacion',
        'Fase compuesta por llaves eliminatorias'
    ),
    (
        'FINAL',
        'Final',
        'Fase final del torneo'
    )
ON CONFLICT (codigo) DO NOTHING;


INSERT INTO catalogo.estado_fase (
    codigo,
    nombre,
    descripcion
)
VALUES
    (
        'PENDIENTE',
        'Pendiente',
        'La fase todavia no inicio'
    ),
    (
        'EN_CURSO',
        'En curso',
        'La fase se encuentra en desarrollo'
    ),
    (
        'FINALIZADA',
        'Finalizada',
        'La fase concluyo'
    ),
    (
        'CANCELADA',
        'Cancelada',
        'La fase fue cancelada'
    )
ON CONFLICT (codigo) DO NOTHING;


INSERT INTO catalogo.estado_jornada (
    codigo,
    nombre,
    descripcion
)
VALUES
    (
        'PROGRAMADA',
        'Programada',
        'La jornada se encuentra programada'
    ),
    (
        'EN_CURSO',
        'En curso',
        'La jornada se encuentra en desarrollo'
    ),
    (
        'FINALIZADA',
        'Finalizada',
        'La jornada concluyo'
    ),
    (
        'SUSPENDIDA',
        'Suspendida',
        'La jornada fue suspendida'
    ),
    (
        'CANCELADA',
        'Cancelada',
        'La jornada fue cancelada'
    )
ON CONFLICT (codigo) DO NOTHING;


INSERT INTO catalogo.rol_torneo (
    codigo,
    nombre,
    descripcion
)
VALUES
    (
        'JUGADOR',
        'Jugador',
        'Participa como jugador dentro del torneo'
    ),
    (
        'ARBITRO',
        'Arbitro',
        'Puede dirigir partidos del torneo'
    ),
    (
        'ORGANIZADOR',
        'Organizador',
        'Administra la organizacion del torneo'
    )
ON CONFLICT (codigo) DO NOTHING;


WITH pares (
    codigo_a,
    codigo_b,
    motivo
) AS (
    VALUES
        (
            'JUGADOR',
            'ARBITRO',
            'Un jugador no puede arbitrar el mismo torneo'
        ),
        (
            'JUGADOR',
            'ORGANIZADOR',
            'Un jugador no puede organizar el mismo torneo'
        ),
        (
            'ARBITRO',
            'ORGANIZADOR',
            'Un arbitro debe ser ajeno a la organizacion del torneo'
        )
)
INSERT INTO catalogo.conflicto_rol_torneo (
    id_rol_torneo_a,
    id_rol_torneo_b,
    motivo
)
SELECT
    LEAST(rol_a.id_rol_torneo, rol_b.id_rol_torneo),
    GREATEST(rol_a.id_rol_torneo, rol_b.id_rol_torneo),
    pares.motivo
FROM pares
INNER JOIN catalogo.rol_torneo rol_a
    ON rol_a.codigo = pares.codigo_a
INNER JOIN catalogo.rol_torneo rol_b
    ON rol_b.codigo = pares.codigo_b
ON CONFLICT (
    id_rol_torneo_a,
    id_rol_torneo_b
)
DO NOTHING;

COMMIT;