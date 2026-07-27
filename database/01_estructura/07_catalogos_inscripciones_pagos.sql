BEGIN;

CREATE TABLE IF NOT EXISTS catalogo.estado_inscripcion (
    id_estado_inscripcion SMALLINT
        GENERATED ALWAYS AS IDENTITY,

    codigo VARCHAR(40) NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    descripcion VARCHAR(250),
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT pk_estado_inscripcion
        PRIMARY KEY (id_estado_inscripcion),

    CONSTRAINT uq_estado_inscripcion_codigo
        UNIQUE (codigo),

    CONSTRAINT ck_estado_inscripcion_codigo
        CHECK (codigo = UPPER(codigo))
);


CREATE TABLE IF NOT EXISTS catalogo.estado_jugador_inscripcion (
    id_estado_jugador_inscripcion SMALLINT
        GENERATED ALWAYS AS IDENTITY,

    codigo VARCHAR(40) NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    descripcion VARCHAR(250),
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT pk_estado_jugador_inscripcion
        PRIMARY KEY (id_estado_jugador_inscripcion),

    CONSTRAINT uq_estado_jugador_inscripcion_codigo
        UNIQUE (codigo),

    CONSTRAINT ck_estado_jugador_inscripcion_codigo
        CHECK (codigo = UPPER(codigo))
);


CREATE TABLE IF NOT EXISTS catalogo.estado_pago (
    id_estado_pago SMALLINT
        GENERATED ALWAYS AS IDENTITY,

    codigo VARCHAR(40) NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    descripcion VARCHAR(250),
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT pk_estado_pago
        PRIMARY KEY (id_estado_pago),

    CONSTRAINT uq_estado_pago_codigo
        UNIQUE (codigo),

    CONSTRAINT ck_estado_pago_codigo
        CHECK (codigo = UPPER(codigo))
);


CREATE TABLE IF NOT EXISTS catalogo.metodo_pago (
    id_metodo_pago SMALLINT
        GENERATED ALWAYS AS IDENTITY,

    codigo VARCHAR(40) NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    descripcion VARCHAR(250),
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT pk_metodo_pago
        PRIMARY KEY (id_metodo_pago),

    CONSTRAINT uq_metodo_pago_codigo
        UNIQUE (codigo),

    CONSTRAINT ck_metodo_pago_codigo
        CHECK (codigo = UPPER(codigo))
);

COMMIT;