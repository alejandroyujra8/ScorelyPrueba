BEGIN;

CREATE TABLE IF NOT EXISTS participantes.jugador (
    id_usuario BIGINT NOT NULL,

    alias_deportivo VARCHAR(80),
    id_estado_perfil SMALLINT NOT NULL,

    fecha_registro TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    observaciones VARCHAR(500),

    CONSTRAINT pk_jugador
        PRIMARY KEY (id_usuario),

    CONSTRAINT fk_jugador_usuario
        FOREIGN KEY (id_usuario)
        REFERENCES seguridad.usuario (id_usuario),

    CONSTRAINT fk_jugador_estado_perfil
        FOREIGN KEY (id_estado_perfil)
        REFERENCES catalogo.estado_perfil_deportivo (id_estado_perfil),

    CONSTRAINT ck_jugador_alias
        CHECK (
            alias_deportivo IS NULL
            OR LENGTH(BTRIM(alias_deportivo)) >= 2
        )
);


CREATE TABLE IF NOT EXISTS participantes.arbitro (
    id_usuario BIGINT NOT NULL,

    numero_licencia VARCHAR(50),
    nivel VARCHAR(50),
    anios_experiencia SMALLINT NOT NULL DEFAULT 0,

    id_estado_perfil SMALLINT NOT NULL,

    fecha_registro TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    observaciones VARCHAR(500),

    CONSTRAINT pk_arbitro
        PRIMARY KEY (id_usuario),

    CONSTRAINT fk_arbitro_usuario
        FOREIGN KEY (id_usuario)
        REFERENCES seguridad.usuario (id_usuario),

    CONSTRAINT fk_arbitro_estado_perfil
        FOREIGN KEY (id_estado_perfil)
        REFERENCES catalogo.estado_perfil_deportivo (id_estado_perfil),

    CONSTRAINT uq_arbitro_numero_licencia
        UNIQUE (numero_licencia),

    CONSTRAINT ck_arbitro_anios_experiencia
        CHECK (anios_experiencia >= 0)
);


CREATE TABLE IF NOT EXISTS participantes.organizador (
    id_usuario BIGINT NOT NULL,

    institucion VARCHAR(150),
    cargo VARCHAR(100),
    anios_experiencia SMALLINT NOT NULL DEFAULT 0,

    id_estado_perfil SMALLINT NOT NULL,

    fecha_registro TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    observaciones VARCHAR(500),

    CONSTRAINT pk_organizador
        PRIMARY KEY (id_usuario),

    CONSTRAINT fk_organizador_usuario
        FOREIGN KEY (id_usuario)
        REFERENCES seguridad.usuario (id_usuario),

    CONSTRAINT fk_organizador_estado_perfil
        FOREIGN KEY (id_estado_perfil)
        REFERENCES catalogo.estado_perfil_deportivo (id_estado_perfil),

    CONSTRAINT ck_organizador_anios_experiencia
        CHECK (anios_experiencia >= 0)
);


CREATE TABLE IF NOT EXISTS participantes.equipo (
    id_equipo BIGINT
        GENERATED ALWAYS AS IDENTITY,

    nombre VARCHAR(120) NOT NULL,
    sigla VARCHAR(15),

    fecha_fundacion DATE,
    descripcion VARCHAR(500),
    logo_url VARCHAR(500),

    id_estado_equipo SMALLINT NOT NULL,

    creado_por BIGINT,
    fecha_registro TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_equipo
        PRIMARY KEY (id_equipo),

    CONSTRAINT fk_equipo_estado
        FOREIGN KEY (id_estado_equipo)
        REFERENCES catalogo.estado_equipo (id_estado_equipo),

    CONSTRAINT fk_equipo_creado_por
        FOREIGN KEY (creado_por)
        REFERENCES seguridad.usuario (id_usuario),

    CONSTRAINT uq_equipo_nombre
        UNIQUE (nombre),

    CONSTRAINT uq_equipo_sigla
        UNIQUE (sigla),

    CONSTRAINT ck_equipo_nombre
        CHECK (LENGTH(BTRIM(nombre)) >= 3),

    CONSTRAINT ck_equipo_sigla
        CHECK (
            sigla IS NULL
            OR (
                LENGTH(BTRIM(sigla)) BETWEEN 2 AND 15
                AND sigla = UPPER(sigla)
            )
        ),

    CONSTRAINT ck_equipo_fecha_fundacion
        CHECK (
            fecha_fundacion IS NULL
            OR fecha_fundacion >= DATE '1900-01-01'
        )
);


CREATE TABLE IF NOT EXISTS participantes.jugador_equipo (
    id_jugador_equipo BIGINT
        GENERATED ALWAYS AS IDENTITY,

    id_jugador BIGINT NOT NULL,
    id_equipo BIGINT NOT NULL,

    fecha_inicio DATE NOT NULL DEFAULT CURRENT_DATE,
    fecha_fin DATE,

    numero_camiseta SMALLINT,
    posicion VARCHAR(80),
    es_delegado BOOLEAN NOT NULL DEFAULT FALSE,

    id_estado_membresia SMALLINT NOT NULL,

    registrado_por BIGINT,
    fecha_registro TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    observaciones VARCHAR(500),

    CONSTRAINT pk_jugador_equipo
        PRIMARY KEY (id_jugador_equipo),

    CONSTRAINT fk_jugador_equipo_jugador
        FOREIGN KEY (id_jugador)
        REFERENCES participantes.jugador (id_usuario),

    CONSTRAINT fk_jugador_equipo_equipo
        FOREIGN KEY (id_equipo)
        REFERENCES participantes.equipo (id_equipo),

    CONSTRAINT fk_jugador_equipo_estado
        FOREIGN KEY (id_estado_membresia)
        REFERENCES catalogo.estado_membresia (id_estado_membresia),

    CONSTRAINT fk_jugador_equipo_registrado_por
        FOREIGN KEY (registrado_por)
        REFERENCES seguridad.usuario (id_usuario),

    CONSTRAINT ck_jugador_equipo_fechas
        CHECK (
            fecha_fin IS NULL
            OR fecha_fin >= fecha_inicio
        ),

    CONSTRAINT ck_jugador_equipo_camiseta
        CHECK (
            numero_camiseta IS NULL
            OR numero_camiseta BETWEEN 0 AND 999
        )
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_jugador_equipo_membresia_activa
    ON participantes.jugador_equipo (
        id_jugador,
        id_equipo
    )
    WHERE fecha_fin IS NULL;


CREATE UNIQUE INDEX IF NOT EXISTS uq_equipo_delegado_activo
    ON participantes.jugador_equipo (id_equipo)
    WHERE es_delegado = TRUE AND fecha_fin IS NULL;


CREATE INDEX IF NOT EXISTS ix_jugador_equipo_jugador
    ON participantes.jugador_equipo (id_jugador);


CREATE INDEX IF NOT EXISTS ix_jugador_equipo_equipo
    ON participantes.jugador_equipo (id_equipo);


COMMENT ON TABLE participantes.jugador IS
'Perfil deportivo de los usuarios que pueden participar como jugadores.';

COMMENT ON TABLE participantes.arbitro IS
'Perfil de los usuarios habilitados para actuar como arbitros.';

COMMENT ON TABLE participantes.organizador IS
'Perfil de los usuarios que pueden organizar torneos.';

COMMENT ON TABLE participantes.equipo IS
'Equipos deportivos registrados en el sistema.';

COMMENT ON TABLE participantes.jugador_equipo IS
'Historial de pertenencia de los jugadores a los equipos.';

COMMENT ON COLUMN participantes.jugador_equipo.fecha_fin IS
'Cuando es nula, la membresia se considera vigente.';

COMMENT ON COLUMN participantes.jugador_equipo.es_delegado IS
'Indica si el jugador actua como delegado actual del equipo.';

COMMIT;