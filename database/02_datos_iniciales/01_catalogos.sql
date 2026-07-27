BEGIN;

INSERT INTO catalogo.tipo_documento (
    codigo,
    nombre,
    descripcion
)
VALUES
    (
        'CI',
        'Cedula de identidad',
        'Documento de identidad nacional'
    ),
    (
        'PASAPORTE',
        'Pasaporte',
        'Documento internacional de identificacion'
    ),
    (
        'OTRO',
        'Otro documento',
        'Documento diferente a CI o pasaporte'
    )
ON CONFLICT (codigo) DO NOTHING;


INSERT INTO catalogo.estado_usuario (
    codigo,
    nombre,
    descripcion
)
VALUES
    (
        'ACTIVO',
        'Activo',
        'El usuario puede ingresar y utilizar el sistema'
    ),
    (
        'INACTIVO',
        'Inactivo',
        'La cuenta fue desactivada de manera administrativa'
    ),
    (
        'BLOQUEADO',
        'Bloqueado',
        'La cuenta fue bloqueada por seguridad'
    )
ON CONFLICT (codigo) DO NOTHING;


INSERT INTO catalogo.estado_perfil_deportivo (
    codigo,
    nombre,
    descripcion
)
VALUES
    (
        'ACTIVO',
        'Activo',
        'El perfil deportivo se encuentra habilitado'
    ),
    (
        'INACTIVO',
        'Inactivo',
        'El perfil deportivo no se encuentra habilitado'
    ),
    (
        'SUSPENDIDO',
        'Suspendido',
        'El perfil fue suspendido temporalmente'
    )
ON CONFLICT (codigo) DO NOTHING;


INSERT INTO catalogo.estado_equipo (
    codigo,
    nombre,
    descripcion
)
VALUES
    (
        'ACTIVO',
        'Activo',
        'El equipo se encuentra habilitado'
    ),
    (
        'INACTIVO',
        'Inactivo',
        'El equipo no se encuentra participando'
    ),
    (
        'SUSPENDIDO',
        'Suspendido',
        'El equipo fue suspendido temporalmente'
    )
ON CONFLICT (codigo) DO NOTHING;


INSERT INTO catalogo.estado_membresia (
    codigo,
    nombre,
    descripcion
)
VALUES
    (
        'ACTIVA',
        'Activa',
        'El jugador pertenece actualmente al equipo'
    ),
    (
        'FINALIZADA',
        'Finalizada',
        'La pertenencia del jugador al equipo termino'
    ),
    (
        'SUSPENDIDA',
        'Suspendida',
        'La membresia fue suspendida temporalmente'
    )
ON CONFLICT (codigo) DO NOTHING;

COMMIT;