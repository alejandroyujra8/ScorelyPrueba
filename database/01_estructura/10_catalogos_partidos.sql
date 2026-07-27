BEGIN;

CREATE TABLE IF NOT EXISTS catalogo.estado_partido (
    id_estado_partido SMALLINT
        GENERATED ALWAYS AS IDENTITY,

    codigo VARCHAR(40) NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    descripcion VARCHAR(250),
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT pk_estado_partido
        PRIMARY KEY (id_estado_partido),

    CONSTRAINT uq_estado_partido_codigo
        UNIQUE (codigo),

    CONSTRAINT ck_estado_partido_codigo
        CHECK (codigo = UPPER(codigo))
);


CREATE TABLE IF NOT EXISTS catalogo.condicion_equipo_partido (
    id_condicion_equipo SMALLINT
        GENERATED ALWAYS AS IDENTITY,

    codigo VARCHAR(30) NOT NULL,
    nombre VARCHAR(80) NOT NULL,
    descripcion VARCHAR(200),
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT pk_condicion_equipo_partido
        PRIMARY KEY (id_condicion_equipo),

    CONSTRAINT uq_condicion_equipo_partido_codigo
        UNIQUE (codigo),

    CONSTRAINT ck_condicion_equipo_partido_codigo
        CHECK (codigo = UPPER(codigo))
);


CREATE TABLE IF NOT EXISTS catalogo.resultado_equipo_partido (
    id_resultado_equipo_partido SMALLINT
        GENERATED ALWAYS AS IDENTITY,

    codigo VARCHAR(30) NOT NULL,
    nombre VARCHAR(80) NOT NULL,
    descripcion VARCHAR(200),
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT pk_resultado_equipo_partido
        PRIMARY KEY (id_resultado_equipo_partido),

    CONSTRAINT uq_resultado_equipo_partido_codigo
        UNIQUE (codigo),

    CONSTRAINT ck_resultado_equipo_partido_codigo
        CHECK (codigo = UPPER(codigo))
);


CREATE TABLE IF NOT EXISTS catalogo.tipo_arbitro_partido (
    id_tipo_arbitro_partido SMALLINT
        GENERATED ALWAYS AS IDENTITY,

    codigo VARCHAR(40) NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    descripcion VARCHAR(250),
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT pk_tipo_arbitro_partido
        PRIMARY KEY (id_tipo_arbitro_partido),

    CONSTRAINT uq_tipo_arbitro_partido_codigo
        UNIQUE (codigo),

    CONSTRAINT ck_tipo_arbitro_partido_codigo
        CHECK (codigo = UPPER(codigo))
);

COMMIT;