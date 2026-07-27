BEGIN;

INSERT INTO catalogo.estado_inscripcion (
    codigo,
    nombre,
    descripcion
)
VALUES
    (
        'PENDIENTE',
        'Pendiente',
        'La inscripcion fue registrada pero aun no tiene pagos confirmados'
    ),
    (
        'PAGO_PENDIENTE',
        'Pago pendiente',
        'La inscripcion tiene un pago parcial confirmado'
    ),
    (
        'HABILITADA',
        'Habilitada',
        'La inscripcion completo el pago requerido'
    ),
    (
        'RECHAZADA',
        'Rechazada',
        'La inscripcion fue rechazada por la organizacion'
    ),
    (
        'RETIRADA',
        'Retirada',
        'El equipo retiro voluntariamente su inscripcion'
    )
ON CONFLICT (codigo) DO NOTHING;


INSERT INTO catalogo.estado_jugador_inscripcion (
    codigo,
    nombre,
    descripcion
)
VALUES
    (
        'HABILITADO',
        'Habilitado',
        'El jugador puede participar en el torneo'
    ),
    (
        'SUSPENDIDO',
        'Suspendido',
        'El jugador se encuentra suspendido temporalmente'
    ),
    (
        'RETIRADO',
        'Retirado',
        'El jugador fue retirado de la nomina'
    )
ON CONFLICT (codigo) DO NOTHING;


INSERT INTO catalogo.estado_pago (
    codigo,
    nombre,
    descripcion
)
VALUES
    (
        'PENDIENTE',
        'Pendiente',
        'El pago fue registrado pero aun no fue verificado'
    ),
    (
        'CONFIRMADO',
        'Confirmado',
        'El pago fue verificado correctamente'
    ),
    (
        'RECHAZADO',
        'Rechazado',
        'El pago no fue aceptado'
    ),
    (
        'ANULADO',
        'Anulado',
        'El pago fue anulado antes de su confirmacion'
    )
ON CONFLICT (codigo) DO NOTHING;


INSERT INTO catalogo.metodo_pago (
    codigo,
    nombre,
    descripcion
)
VALUES
    (
        'EFECTIVO',
        'Efectivo',
        'Pago registrado en efectivo'
    ),
    (
        'TRANSFERENCIA',
        'Transferencia bancaria',
        'Pago mediante transferencia bancaria'
    ),
    (
        'QR',
        'Pago QR',
        'Pago realizado mediante codigo QR'
    ),
    (
        'DEPOSITO',
        'Deposito bancario',
        'Pago realizado mediante deposito'
    ),
    (
        'OTRO',
        'Otro metodo',
        'Metodo diferente a los registrados'
    )
ON CONFLICT (codigo) DO NOTHING;

COMMIT;