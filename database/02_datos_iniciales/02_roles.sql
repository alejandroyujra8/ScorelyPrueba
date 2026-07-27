BEGIN;

INSERT INTO seguridad.rol (
    codigo,
    nombre,
    descripcion
)
VALUES
    (
        'ADMINISTRADOR',
        'Administrador',
        'Gestiona la configuracion general del sistema'
    ),
    (
        'ORGANIZADOR',
        'Organizador',
        'Gestiona torneos, inscripciones y programacion'
    ),
    (
        'ARBITRO',
        'Arbitro',
        'Dirige y registra resultados de partidos asignados'
    ),
    (
        'JUGADOR',
        'Jugador',
        'Participa como integrante de un equipo'
    ),
    (
        'CONSULTA',
        'Usuario de consulta',
        'Puede visualizar informacion publica y reportes permitidos'
    )
ON CONFLICT (codigo) DO NOTHING;

COMMIT;