BEGIN;

CREATE TABLE IF NOT EXISTS catalogo.tipo_documento (
    id_tipo_documento SMALLINT
        GENERATED ALWAYS AS IDENTITY,
    codigo VARCHAR(30) NOT NULL,
    nombre VARCHAR(80) NOT NULL,
    descripcion VARCHAR(200),
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT pk_tipo_documento
        PRIMARY KEY (id_tipo_documento),

    CONSTRAINT uq_tipo_documento_codigo
        UNIQUE (codigo),

    CONSTRAINT ck_tipo_documento_codigo
        CHECK (codigo = UPPER(codigo)),

    CONSTRAINT ck_tipo_documento_nombre
        CHECK (LENGTH(BTRIM(nombre)) >= 2)
);

CREATE TABLE IF NOT EXISTS catalogo.estado_usuario (
    id_estado_usuario SMALLINT
        GENERATED ALWAYS AS IDENTITY,
    codigo VARCHAR(30) NOT NULL,
    nombre VARCHAR(80) NOT NULL,
    descripcion VARCHAR(200),
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT pk_estado_usuario
        PRIMARY KEY (id_estado_usuario),

    CONSTRAINT uq_estado_usuario_codigo
        UNIQUE (codigo),

    CONSTRAINT ck_estado_usuario_codigo
        CHECK (codigo = UPPER(codigo))
);

CREATE TABLE IF NOT EXISTS catalogo.estado_perfil_deportivo (
    id_estado_perfil SMALLINT
        GENERATED ALWAYS AS IDENTITY,
    codigo VARCHAR(30) NOT NULL,
    nombre VARCHAR(80) NOT NULL,
    descripcion VARCHAR(200),
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT pk_estado_perfil_deportivo
        PRIMARY KEY (id_estado_perfil),

    CONSTRAINT uq_estado_perfil_deportivo_codigo
        UNIQUE (codigo),

    CONSTRAINT ck_estado_perfil_deportivo_codigo
        CHECK (codigo = UPPER(codigo))
);

CREATE TABLE IF NOT EXISTS catalogo.estado_equipo (
    id_estado_equipo SMALLINT
        GENERATED ALWAYS AS IDENTITY,
    codigo VARCHAR(30) NOT NULL,
    nombre VARCHAR(80) NOT NULL,
    descripcion VARCHAR(200),
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT pk_estado_equipo
        PRIMARY KEY (id_estado_equipo),

    CONSTRAINT uq_estado_equipo_codigo
        UNIQUE (codigo),

    CONSTRAINT ck_estado_equipo_codigo
        CHECK (codigo = UPPER(codigo))
);

CREATE TABLE IF NOT EXISTS catalogo.estado_membresia (
    id_estado_membresia SMALLINT
        GENERATED ALWAYS AS IDENTITY,
    codigo VARCHAR(30) NOT NULL,
    nombre VARCHAR(80) NOT NULL,
    descripcion VARCHAR(200),
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT pk_estado_membresia
        PRIMARY KEY (id_estado_membresia),

    CONSTRAINT uq_estado_membresia_codigo
        UNIQUE (codigo),

    CONSTRAINT ck_estado_membresia_codigo
        CHECK (codigo = UPPER(codigo))
);

COMMENT ON TABLE catalogo.tipo_documento IS
'Tipos de documento de identificacion admitidos por el sistema.';

COMMENT ON TABLE catalogo.estado_usuario IS
'Estados permitidos para las cuentas de usuario.';

COMMENT ON TABLE catalogo.estado_perfil_deportivo IS
'Estados aplicables a jugadores, arbitros y organizadores.';

COMMENT ON TABLE catalogo.estado_equipo IS
'Estados permitidos para los equipos deportivos.';

COMMENT ON TABLE catalogo.estado_membresia IS
'Estados del historial de pertenencia de un jugador a un equipo.';

COMMIT;