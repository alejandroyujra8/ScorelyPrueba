BEGIN;

CREATE TABLE IF NOT EXISTS catalogo.estado_deporte (
    id_estado_deporte SMALLINT
        GENERATED ALWAYS AS IDENTITY,

    codigo VARCHAR(30) NOT NULL,
    nombre VARCHAR(80) NOT NULL,
    descripcion VARCHAR(200),
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT pk_estado_deporte
        PRIMARY KEY (id_estado_deporte),

    CONSTRAINT uq_estado_deporte_codigo
        UNIQUE (codigo),

    CONSTRAINT ck_estado_deporte_codigo
        CHECK (codigo = UPPER(codigo))
);


CREATE TABLE IF NOT EXISTS catalogo.formato_torneo (
    id_formato_torneo SMALLINT
        GENERATED ALWAYS AS IDENTITY,

    codigo VARCHAR(40) NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    descripcion VARCHAR(250),
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT pk_formato_torneo
        PRIMARY KEY (id_formato_torneo),

    CONSTRAINT uq_formato_torneo_codigo
        UNIQUE (codigo),

    CONSTRAINT ck_formato_torneo_codigo
        CHECK (codigo = UPPER(codigo))
);


CREATE TABLE IF NOT EXISTS catalogo.estado_torneo (
    id_estado_torneo SMALLINT
        GENERATED ALWAYS AS IDENTITY,

    codigo VARCHAR(40) NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    descripcion VARCHAR(250),
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT pk_estado_torneo
        PRIMARY KEY (id_estado_torneo),

    CONSTRAINT uq_estado_torneo_codigo
        UNIQUE (codigo),

    CONSTRAINT ck_estado_torneo_codigo
        CHECK (codigo = UPPER(codigo))
);


CREATE TABLE IF NOT EXISTS catalogo.tipo_fase (
    id_tipo_fase SMALLINT
        GENERATED ALWAYS AS IDENTITY,

    codigo VARCHAR(40) NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    descripcion VARCHAR(250),
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT pk_tipo_fase
        PRIMARY KEY (id_tipo_fase),

    CONSTRAINT uq_tipo_fase_codigo
        UNIQUE (codigo),

    CONSTRAINT ck_tipo_fase_codigo
        CHECK (codigo = UPPER(codigo))
);


CREATE TABLE IF NOT EXISTS catalogo.estado_fase (
    id_estado_fase SMALLINT
        GENERATED ALWAYS AS IDENTITY,

    codigo VARCHAR(40) NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    descripcion VARCHAR(250),
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT pk_estado_fase
        PRIMARY KEY (id_estado_fase),

    CONSTRAINT uq_estado_fase_codigo
        UNIQUE (codigo),

    CONSTRAINT ck_estado_fase_codigo
        CHECK (codigo = UPPER(codigo))
);


CREATE TABLE IF NOT EXISTS catalogo.estado_jornada (
    id_estado_jornada SMALLINT
        GENERATED ALWAYS AS IDENTITY,

    codigo VARCHAR(40) NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    descripcion VARCHAR(250),
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT pk_estado_jornada
        PRIMARY KEY (id_estado_jornada),

    CONSTRAINT uq_estado_jornada_codigo
        UNIQUE (codigo),

    CONSTRAINT ck_estado_jornada_codigo
        CHECK (codigo = UPPER(codigo))
);


CREATE TABLE IF NOT EXISTS catalogo.rol_torneo (
    id_rol_torneo SMALLINT
        GENERATED ALWAYS AS IDENTITY,

    codigo VARCHAR(40) NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    descripcion VARCHAR(250),
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT pk_rol_torneo
        PRIMARY KEY (id_rol_torneo),

    CONSTRAINT uq_rol_torneo_codigo
        UNIQUE (codigo),

    CONSTRAINT ck_rol_torneo_codigo
        CHECK (codigo = UPPER(codigo))
);


CREATE TABLE IF NOT EXISTS catalogo.conflicto_rol_torneo (
    id_conflicto BIGINT
        GENERATED ALWAYS AS IDENTITY,

    id_rol_torneo_a SMALLINT NOT NULL,
    id_rol_torneo_b SMALLINT NOT NULL,
    motivo VARCHAR(300) NOT NULL,

    CONSTRAINT pk_conflicto_rol_torneo
        PRIMARY KEY (id_conflicto),

    CONSTRAINT fk_conflicto_rol_a
        FOREIGN KEY (id_rol_torneo_a)
        REFERENCES catalogo.rol_torneo (id_rol_torneo),

    CONSTRAINT fk_conflicto_rol_b
        FOREIGN KEY (id_rol_torneo_b)
        REFERENCES catalogo.rol_torneo (id_rol_torneo),

    CONSTRAINT uq_conflicto_rol_torneo
        UNIQUE (id_rol_torneo_a, id_rol_torneo_b),

    CONSTRAINT ck_conflicto_roles_diferentes
        CHECK (id_rol_torneo_a <> id_rol_torneo_b),

    CONSTRAINT ck_conflicto_roles_orden
        CHECK (id_rol_torneo_a < id_rol_torneo_b)
);

COMMIT;