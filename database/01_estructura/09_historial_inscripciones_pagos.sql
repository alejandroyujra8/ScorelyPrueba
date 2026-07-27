BEGIN;

CREATE TABLE IF NOT EXISTS auditoria.historial_estado_inscripcion (
    id_historial_inscripcion BIGINT
        GENERATED ALWAYS AS IDENTITY,

    id_inscripcion BIGINT NOT NULL,

    id_estado_anterior SMALLINT,
    id_estado_nuevo SMALLINT NOT NULL,

    operacion VARCHAR(20) NOT NULL,

    usuario_aplicacion BIGINT,
    usuario_postgresql NAME NOT NULL DEFAULT CURRENT_USER,

    fecha_cambio TIMESTAMPTZ
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    detalle JSONB,

    CONSTRAINT pk_historial_estado_inscripcion
        PRIMARY KEY (id_historial_inscripcion),

    CONSTRAINT fk_historial_inscripcion
        FOREIGN KEY (id_inscripcion)
        REFERENCES competencia.inscripcion (id_inscripcion),

    CONSTRAINT fk_historial_inscripcion_estado_anterior
        FOREIGN KEY (id_estado_anterior)
        REFERENCES catalogo.estado_inscripcion (
            id_estado_inscripcion
        ),

    CONSTRAINT fk_historial_inscripcion_estado_nuevo
        FOREIGN KEY (id_estado_nuevo)
        REFERENCES catalogo.estado_inscripcion (
            id_estado_inscripcion
        ),

    CONSTRAINT fk_historial_inscripcion_usuario
        FOREIGN KEY (usuario_aplicacion)
        REFERENCES seguridad.usuario (id_usuario),

    CONSTRAINT ck_historial_inscripcion_operacion
        CHECK (operacion IN ('INSERT', 'UPDATE'))
);


CREATE TABLE IF NOT EXISTS auditoria.historial_estado_pago (
    id_historial_pago BIGINT
        GENERATED ALWAYS AS IDENTITY,

    id_pago BIGINT NOT NULL,

    id_estado_anterior SMALLINT,
    id_estado_nuevo SMALLINT NOT NULL,

    operacion VARCHAR(20) NOT NULL,

    usuario_aplicacion BIGINT,
    usuario_postgresql NAME NOT NULL DEFAULT CURRENT_USER,

    fecha_cambio TIMESTAMPTZ
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    detalle JSONB,

    CONSTRAINT pk_historial_estado_pago
        PRIMARY KEY (id_historial_pago),

    CONSTRAINT fk_historial_pago
        FOREIGN KEY (id_pago)
        REFERENCES finanzas.pago (id_pago),

    CONSTRAINT fk_historial_pago_estado_anterior
        FOREIGN KEY (id_estado_anterior)
        REFERENCES catalogo.estado_pago (id_estado_pago),

    CONSTRAINT fk_historial_pago_estado_nuevo
        FOREIGN KEY (id_estado_nuevo)
        REFERENCES catalogo.estado_pago (id_estado_pago),

    CONSTRAINT fk_historial_pago_usuario
        FOREIGN KEY (usuario_aplicacion)
        REFERENCES seguridad.usuario (id_usuario),

    CONSTRAINT ck_historial_pago_operacion
        CHECK (operacion IN ('INSERT', 'UPDATE'))
);


CREATE INDEX IF NOT EXISTS ix_historial_inscripcion
    ON auditoria.historial_estado_inscripcion (
        id_inscripcion,
        fecha_cambio
    );


CREATE INDEX IF NOT EXISTS ix_historial_pago
    ON auditoria.historial_estado_pago (
        id_pago,
        fecha_cambio
    );

COMMIT;