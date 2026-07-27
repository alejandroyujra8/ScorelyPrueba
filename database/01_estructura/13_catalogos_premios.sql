BEGIN;

CREATE TABLE IF NOT EXISTS catalogo.tipo_premio (
    id_tipo_premio SMALLINT
        GENERATED ALWAYS AS IDENTITY,

    codigo VARCHAR(40) NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    descripcion VARCHAR(250),
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT pk_tipo_premio
        PRIMARY KEY (id_tipo_premio),

    CONSTRAINT uq_tipo_premio_codigo
        UNIQUE (codigo),

    CONSTRAINT ck_tipo_premio_codigo
        CHECK (codigo = UPPER(codigo))
);


CREATE TABLE IF NOT EXISTS catalogo.estado_entrega_premio (
    id_estado_entrega_premio SMALLINT
        GENERATED ALWAYS AS IDENTITY,

    codigo VARCHAR(40) NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    descripcion VARCHAR(250),
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT pk_estado_entrega_premio
        PRIMARY KEY (id_estado_entrega_premio),

    CONSTRAINT uq_estado_entrega_premio_codigo
        UNIQUE (codigo),

    CONSTRAINT ck_estado_entrega_premio_codigo
        CHECK (codigo = UPPER(codigo))
);

COMMIT;