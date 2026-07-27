BEGIN;

CREATE TABLE IF NOT EXISTS auditoria.configuracion_auditoria (
    id_configuracion BIGINT
        GENERATED ALWAYS AS IDENTITY,

    esquema NAME NOT NULL,
    tabla NAME NOT NULL,

    columnas_pk TEXT[] NOT NULL,

    columnas_excluidas TEXT[]
        NOT NULL DEFAULT ARRAY[]::TEXT[],

    auditar_insert BOOLEAN NOT NULL DEFAULT TRUE,
    auditar_update BOOLEAN NOT NULL DEFAULT TRUE,
    auditar_delete BOOLEAN NOT NULL DEFAULT TRUE,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    descripcion VARCHAR(300),

    fecha_registro TIMESTAMPTZ
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_configuracion_auditoria
        PRIMARY KEY (id_configuracion),

    CONSTRAINT uq_configuracion_auditoria_tabla
        UNIQUE (esquema, tabla),

    CONSTRAINT ck_configuracion_auditoria_pk
        CHECK (
            CARDINALITY(columnas_pk) > 0
        )
);


CREATE TABLE IF NOT EXISTS auditoria.auditoria_dml (
    id_auditoria BIGINT
        GENERATED ALWAYS AS IDENTITY,

    esquema NAME NOT NULL,
    tabla NAME NOT NULL,

    operacion VARCHAR(10) NOT NULL,

    identificador_registro JSONB NOT NULL,

    datos_anteriores JSONB,
    datos_nuevos JSONB,
    cambios JSONB,

    columnas_modificadas TEXT[]
        NOT NULL DEFAULT ARRAY[]::TEXT[],

    usuario_aplicacion BIGINT,

    usuario_postgresql NAME
        NOT NULL DEFAULT CURRENT_USER,

    usuario_sesion NAME
        NOT NULL DEFAULT SESSION_USER,

    aplicacion VARCHAR(150),

    ip_cliente VARCHAR(64),
    id_solicitud VARCHAR(120),

    id_transaccion BIGINT
        NOT NULL DEFAULT TXID_CURRENT(),

    pid_backend INTEGER
        NOT NULL DEFAULT PG_BACKEND_PID(),

    fecha_evento TIMESTAMPTZ
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_auditoria_dml
        PRIMARY KEY (id_auditoria),

    CONSTRAINT ck_auditoria_dml_operacion
        CHECK (
            operacion IN (
                'INSERT',
                'UPDATE',
                'DELETE'
            )
        ),

    CONSTRAINT ck_auditoria_dml_identificador
        CHECK (
            JSONB_TYPEOF(identificador_registro)
                = 'object'
        ),

    CONSTRAINT ck_auditoria_dml_datos_anteriores
        CHECK (
            datos_anteriores IS NULL
            OR JSONB_TYPEOF(datos_anteriores)
                = 'object'
        ),

    CONSTRAINT ck_auditoria_dml_datos_nuevos
        CHECK (
            datos_nuevos IS NULL
            OR JSONB_TYPEOF(datos_nuevos)
                = 'object'
        )
);


CREATE INDEX IF NOT EXISTS ix_auditoria_dml_tabla
    ON auditoria.auditoria_dml (
        esquema,
        tabla,
        fecha_evento DESC
    );


CREATE INDEX IF NOT EXISTS ix_auditoria_dml_operacion
    ON auditoria.auditoria_dml (
        operacion,
        fecha_evento DESC
    );


CREATE INDEX IF NOT EXISTS ix_auditoria_dml_usuario
    ON auditoria.auditoria_dml (
        usuario_aplicacion,
        fecha_evento DESC
    );


CREATE INDEX IF NOT EXISTS ix_auditoria_dml_solicitud
    ON auditoria.auditoria_dml (
        id_solicitud
    )
    WHERE id_solicitud IS NOT NULL;


CREATE INDEX IF NOT EXISTS ix_auditoria_dml_transaccion
    ON auditoria.auditoria_dml (
        id_transaccion
    );


CREATE INDEX IF NOT EXISTS ix_auditoria_dml_identificador_gin
    ON auditoria.auditoria_dml
    USING GIN (identificador_registro);


COMMENT ON TABLE auditoria.configuracion_auditoria IS
'Define que tablas son auditadas y que columnas deben excluirse.';


COMMENT ON TABLE auditoria.auditoria_dml IS
'Almacena los cambios INSERT, UPDATE y DELETE realizados sobre las tablas configuradas.';


COMMENT ON COLUMN auditoria.auditoria_dml.identificador_registro IS
'Clave primaria del registro afectado almacenada como JSONB.';


COMMENT ON COLUMN auditoria.auditoria_dml.cambios IS
'Valores anteriores y nuevos de las columnas modificadas.';


COMMENT ON COLUMN auditoria.auditoria_dml.id_solicitud IS
'Identificador de correlacion enviado por FastAPI para rastrear una solicitud completa.';

COMMIT;