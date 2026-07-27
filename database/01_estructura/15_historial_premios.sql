BEGIN;

CREATE TABLE IF NOT EXISTS auditoria.historial_entrega_premio (
    id_historial_entrega BIGINT
        GENERATED ALWAYS AS IDENTITY,

    id_entrega_premio BIGINT NOT NULL,

    id_estado_anterior SMALLINT,
    id_estado_nuevo SMALLINT NOT NULL,

    operacion VARCHAR(20) NOT NULL,

    usuario_aplicacion BIGINT,

    usuario_postgresql NAME
        NOT NULL DEFAULT CURRENT_USER,

    fecha_cambio TIMESTAMPTZ
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    detalle JSONB,

    CONSTRAINT pk_historial_entrega_premio
        PRIMARY KEY (id_historial_entrega),

    CONSTRAINT fk_historial_entrega
        FOREIGN KEY (id_entrega_premio)
        REFERENCES finanzas.entrega_premio (
            id_entrega_premio
        ),

    CONSTRAINT fk_historial_entrega_estado_anterior
        FOREIGN KEY (id_estado_anterior)
        REFERENCES catalogo.estado_entrega_premio (
            id_estado_entrega_premio
        ),

    CONSTRAINT fk_historial_entrega_estado_nuevo
        FOREIGN KEY (id_estado_nuevo)
        REFERENCES catalogo.estado_entrega_premio (
            id_estado_entrega_premio
        ),

    CONSTRAINT fk_historial_entrega_usuario
        FOREIGN KEY (usuario_aplicacion)
        REFERENCES seguridad.usuario (
            id_usuario
        ),

    CONSTRAINT ck_historial_entrega_operacion
        CHECK (
            operacion IN (
                'INSERT',
                'UPDATE'
            )
        )
);


CREATE INDEX IF NOT EXISTS ix_historial_entrega_premio
    ON auditoria.historial_entrega_premio (
        id_entrega_premio,
        fecha_cambio
    );

COMMIT;