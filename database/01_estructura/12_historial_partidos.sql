BEGIN;

CREATE TABLE IF NOT EXISTS auditoria.historial_estado_partido (
    id_historial_partido BIGINT
        GENERATED ALWAYS AS IDENTITY,

    id_partido BIGINT NOT NULL,

    id_estado_anterior SMALLINT,
    id_estado_nuevo SMALLINT NOT NULL,

    operacion VARCHAR(20) NOT NULL,

    usuario_aplicacion BIGINT,
    usuario_postgresql NAME
        NOT NULL DEFAULT CURRENT_USER,

    fecha_cambio TIMESTAMPTZ
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    detalle JSONB,

    CONSTRAINT pk_historial_estado_partido
        PRIMARY KEY (id_historial_partido),

    CONSTRAINT fk_historial_partido
        FOREIGN KEY (id_partido)
        REFERENCES competencia.partido (
            id_partido
        ),

    CONSTRAINT fk_historial_partido_estado_anterior
        FOREIGN KEY (id_estado_anterior)
        REFERENCES catalogo.estado_partido (
            id_estado_partido
        ),

    CONSTRAINT fk_historial_partido_estado_nuevo
        FOREIGN KEY (id_estado_nuevo)
        REFERENCES catalogo.estado_partido (
            id_estado_partido
        ),

    CONSTRAINT fk_historial_partido_usuario
        FOREIGN KEY (usuario_aplicacion)
        REFERENCES seguridad.usuario (
            id_usuario
        ),

    CONSTRAINT ck_historial_partido_operacion
        CHECK (
            operacion IN (
                'INSERT',
                'UPDATE'
            )
        )
);


CREATE INDEX IF NOT EXISTS ix_historial_partido
    ON auditoria.historial_estado_partido (
        id_partido,
        fecha_cambio
    );

COMMIT;