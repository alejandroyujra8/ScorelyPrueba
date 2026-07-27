BEGIN;

INSERT INTO catalogo.tipo_premio (
    codigo,
    nombre,
    descripcion
)
VALUES
    (
        'ECONOMICO',
        'Premio economico',
        'Premio representado por una cantidad monetaria'
    ),
    (
        'TROFEO',
        'Trofeo',
        'Trofeo fisico entregado al equipo ganador'
    ),
    (
        'MEDALLA',
        'Medalla',
        'Medallas entregadas a los integrantes del equipo'
    ),
    (
        'RECONOCIMIENTO',
        'Reconocimiento',
        'Diploma, certificado u otro reconocimiento'
    ),
    (
        'OTRO',
        'Otro premio',
        'Premio diferente a los tipos registrados'
    )
ON CONFLICT (codigo) DO NOTHING;


INSERT INTO catalogo.estado_entrega_premio (
    codigo,
    nombre,
    descripcion
)
VALUES
    (
        'PENDIENTE',
        'Pendiente',
        'La entrega fue generada pero todavia no fue autorizada'
    ),
    (
        'AUTORIZADO',
        'Autorizado',
        'La entrega fue aprobada por un usuario responsable'
    ),
    (
        'ENTREGADO',
        'Entregado',
        'El premio fue entregado al equipo correspondiente'
    ),
    (
        'ANULADO',
        'Anulado',
        'La entrega fue anulada'
    )
ON CONFLICT (codigo) DO NOTHING;

COMMIT;