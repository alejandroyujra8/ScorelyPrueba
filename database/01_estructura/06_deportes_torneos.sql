BEGIN;

CREATE TABLE IF NOT EXISTS competencia.deporte (
    id_deporte BIGINT
        GENERATED ALWAYS AS IDENTITY,

    codigo VARCHAR(40) NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    descripcion VARCHAR(500),

    cantidad_minima_jugadores SMALLINT NOT NULL,
    cantidad_maxima_jugadores SMALLINT NOT NULL,
    cantidad_titulares SMALLINT NOT NULL,

    tipo_marcador VARCHAR(30) NOT NULL,
    permite_empate BOOLEAN NOT NULL DEFAULT FALSE,

    puntos_victoria SMALLINT NOT NULL DEFAULT 3,
    puntos_empate SMALLINT NOT NULL DEFAULT 1,
    puntos_derrota SMALLINT NOT NULL DEFAULT 0,

    id_estado_deporte SMALLINT NOT NULL,

    fecha_registro TIMESTAMPTZ
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_deporte
        PRIMARY KEY (id_deporte),

    CONSTRAINT fk_deporte_estado
        FOREIGN KEY (id_estado_deporte)
        REFERENCES catalogo.estado_deporte (id_estado_deporte),

    CONSTRAINT uq_deporte_codigo
        UNIQUE (codigo),

    CONSTRAINT ck_deporte_codigo
        CHECK (codigo = UPPER(codigo)),

    CONSTRAINT ck_deporte_nombre
        CHECK (LENGTH(BTRIM(nombre)) >= 3),

    CONSTRAINT ck_deporte_cantidad_jugadores
        CHECK (
            cantidad_minima_jugadores > 0
            AND cantidad_maxima_jugadores >= cantidad_minima_jugadores
            AND cantidad_titulares >= cantidad_minima_jugadores
            AND cantidad_titulares <= cantidad_maxima_jugadores
        ),

    CONSTRAINT ck_deporte_tipo_marcador
        CHECK (tipo_marcador = UPPER(tipo_marcador)),

    CONSTRAINT ck_deporte_puntos
        CHECK (
            puntos_victoria >= 0
            AND puntos_empate >= 0
            AND puntos_derrota >= 0
        )
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_deporte_nombre_minuscula
    ON competencia.deporte (LOWER(nombre));


CREATE TABLE IF NOT EXISTS competencia.regla (
    id_regla BIGINT
        GENERATED ALWAYS AS IDENTITY,

    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(150) NOT NULL,
    descripcion TEXT NOT NULL,

    categoria VARCHAR(30) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    fecha_registro TIMESTAMPTZ
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_regla
        PRIMARY KEY (id_regla),

    CONSTRAINT uq_regla_codigo
        UNIQUE (codigo),

    CONSTRAINT ck_regla_codigo
        CHECK (codigo = UPPER(codigo)),

    CONSTRAINT ck_regla_nombre
        CHECK (LENGTH(BTRIM(nombre)) >= 3),

    CONSTRAINT ck_regla_categoria
        CHECK (
            categoria IN (
                'GENERAL',
                'INSCRIPCION',
                'DISCIPLINA',
                'PUNTUACION',
                'SEGURIDAD',
                'PARTIDO'
            )
        )
);


CREATE TABLE IF NOT EXISTS competencia.deporte_regla (
    id_deporte_regla BIGINT
        GENERATED ALWAYS AS IDENTITY,

    id_deporte BIGINT NOT NULL,
    id_regla BIGINT NOT NULL,

    valor_configurado VARCHAR(300),
    obligatorio BOOLEAN NOT NULL DEFAULT TRUE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    fecha_inicio DATE NOT NULL DEFAULT CURRENT_DATE,
    fecha_fin DATE,

    CONSTRAINT pk_deporte_regla
        PRIMARY KEY (id_deporte_regla),

    CONSTRAINT fk_deporte_regla_deporte
        FOREIGN KEY (id_deporte)
        REFERENCES competencia.deporte (id_deporte),

    CONSTRAINT fk_deporte_regla_regla
        FOREIGN KEY (id_regla)
        REFERENCES competencia.regla (id_regla),

    CONSTRAINT ck_deporte_regla_fechas
        CHECK (
            fecha_fin IS NULL
            OR fecha_fin >= fecha_inicio
        )
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_deporte_regla_activa
    ON competencia.deporte_regla (
        id_deporte,
        id_regla
    )
    WHERE activo = TRUE AND fecha_fin IS NULL;


CREATE TABLE IF NOT EXISTS competencia.lugar (
    id_lugar BIGINT
        GENERATED ALWAYS AS IDENTITY,

    nombre VARCHAR(150) NOT NULL,
    direccion VARCHAR(250) NOT NULL,
    zona VARCHAR(100),
    ciudad VARCHAR(100) NOT NULL DEFAULT 'La Paz',

    capacidad INTEGER,
    tipo_superficie VARCHAR(100),

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    fecha_registro TIMESTAMPTZ
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_lugar
        PRIMARY KEY (id_lugar),

    CONSTRAINT ck_lugar_nombre
        CHECK (LENGTH(BTRIM(nombre)) >= 3),

    CONSTRAINT ck_lugar_direccion
        CHECK (LENGTH(BTRIM(direccion)) >= 5),

    CONSTRAINT ck_lugar_capacidad
        CHECK (
            capacidad IS NULL
            OR capacidad >= 0
        )
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_lugar_nombre_direccion
    ON competencia.lugar (
        LOWER(nombre),
        LOWER(direccion)
    );


CREATE TABLE IF NOT EXISTS competencia.torneo (
    id_torneo BIGINT
        GENERATED ALWAYS AS IDENTITY,

    id_deporte BIGINT NOT NULL,
    id_formato_torneo SMALLINT NOT NULL,
    id_estado_torneo SMALLINT NOT NULL,

    codigo VARCHAR(40) NOT NULL,
    nombre VARCHAR(150) NOT NULL,
    edicion VARCHAR(50),
    categoria VARCHAR(100),

    rama VARCHAR(20) NOT NULL DEFAULT 'ABIERTO',

    fecha_inicio_inscripcion DATE NOT NULL,
    fecha_fin_inscripcion DATE NOT NULL,
    fecha_inicio_torneo DATE NOT NULL,
    fecha_fin_torneo DATE NOT NULL,

    cantidad_maxima_equipos SMALLINT NOT NULL,
    cantidad_minima_jugadores SMALLINT NOT NULL,
    cantidad_maxima_jugadores SMALLINT NOT NULL,

    costo_inscripcion NUMERIC(12, 2) NOT NULL DEFAULT 0,
    moneda CHAR(3) NOT NULL DEFAULT 'BOB',

    permite_empate BOOLEAN NOT NULL DEFAULT FALSE,

    descripcion TEXT,

    creado_por BIGINT NOT NULL,

    fecha_registro TIMESTAMPTZ
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    fecha_actualizacion TIMESTAMPTZ
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_torneo
        PRIMARY KEY (id_torneo),

    CONSTRAINT fk_torneo_deporte
        FOREIGN KEY (id_deporte)
        REFERENCES competencia.deporte (id_deporte),

    CONSTRAINT fk_torneo_formato
        FOREIGN KEY (id_formato_torneo)
        REFERENCES catalogo.formato_torneo (id_formato_torneo),

    CONSTRAINT fk_torneo_estado
        FOREIGN KEY (id_estado_torneo)
        REFERENCES catalogo.estado_torneo (id_estado_torneo),

    CONSTRAINT fk_torneo_creado_por
        FOREIGN KEY (creado_por)
        REFERENCES seguridad.usuario (id_usuario),

    CONSTRAINT uq_torneo_codigo
        UNIQUE (codigo),

    CONSTRAINT ck_torneo_codigo
        CHECK (codigo = UPPER(codigo)),

    CONSTRAINT ck_torneo_nombre
        CHECK (LENGTH(BTRIM(nombre)) >= 4),

    CONSTRAINT ck_torneo_rama
        CHECK (
            rama IN (
                'MASCULINO',
                'FEMENINO',
                'MIXTO',
                'ABIERTO'
            )
        ),

    CONSTRAINT ck_torneo_fechas
        CHECK (
            fecha_inicio_inscripcion <= fecha_fin_inscripcion
            AND fecha_fin_inscripcion <= fecha_inicio_torneo
            AND fecha_inicio_torneo <= fecha_fin_torneo
        ),

    CONSTRAINT ck_torneo_cantidad_equipos
        CHECK (cantidad_maxima_equipos >= 2),

    CONSTRAINT ck_torneo_cantidad_jugadores
        CHECK (
            cantidad_minima_jugadores > 0
            AND cantidad_maxima_jugadores
                >= cantidad_minima_jugadores
        ),

    CONSTRAINT ck_torneo_costo
        CHECK (costo_inscripcion >= 0),

    CONSTRAINT ck_torneo_moneda
        CHECK (moneda = UPPER(moneda))
);


CREATE TABLE IF NOT EXISTS competencia.torneo_regla (
    id_torneo_regla BIGINT
        GENERATED ALWAYS AS IDENTITY,

    id_torneo BIGINT NOT NULL,
    id_regla BIGINT NOT NULL,

    valor_configurado VARCHAR(300),
    obligatorio BOOLEAN NOT NULL DEFAULT TRUE,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    fecha_registro TIMESTAMPTZ
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_torneo_regla
        PRIMARY KEY (id_torneo_regla),

    CONSTRAINT fk_torneo_regla_torneo
        FOREIGN KEY (id_torneo)
        REFERENCES competencia.torneo (id_torneo),

    CONSTRAINT fk_torneo_regla_regla
        FOREIGN KEY (id_regla)
        REFERENCES competencia.regla (id_regla),

    CONSTRAINT uq_torneo_regla
        UNIQUE (id_torneo, id_regla)
);


CREATE TABLE IF NOT EXISTS competencia.fase_torneo (
    id_fase_torneo BIGINT
        GENERATED ALWAYS AS IDENTITY,

    id_torneo BIGINT NOT NULL,
    id_tipo_fase SMALLINT NOT NULL,
    id_estado_fase SMALLINT NOT NULL,

    nombre VARCHAR(120) NOT NULL,
    numero_orden SMALLINT NOT NULL,

    cantidad_clasificados SMALLINT,

    fecha_inicio DATE,
    fecha_fin DATE,

    descripcion VARCHAR(500),

    CONSTRAINT pk_fase_torneo
        PRIMARY KEY (id_fase_torneo),

    CONSTRAINT fk_fase_torneo_torneo
        FOREIGN KEY (id_torneo)
        REFERENCES competencia.torneo (id_torneo),

    CONSTRAINT fk_fase_torneo_tipo
        FOREIGN KEY (id_tipo_fase)
        REFERENCES catalogo.tipo_fase (id_tipo_fase),

    CONSTRAINT fk_fase_torneo_estado
        FOREIGN KEY (id_estado_fase)
        REFERENCES catalogo.estado_fase (id_estado_fase),

    CONSTRAINT uq_fase_torneo_orden
        UNIQUE (id_torneo, numero_orden),

    CONSTRAINT uq_fase_torneo_nombre
        UNIQUE (id_torneo, nombre),

    CONSTRAINT ck_fase_torneo_orden
        CHECK (numero_orden > 0),

    CONSTRAINT ck_fase_torneo_clasificados
        CHECK (
            cantidad_clasificados IS NULL
            OR cantidad_clasificados > 0
        ),

    CONSTRAINT ck_fase_torneo_fechas
        CHECK (
            fecha_inicio IS NULL
            OR fecha_fin IS NULL
            OR fecha_fin >= fecha_inicio
        )
);


CREATE TABLE IF NOT EXISTS competencia.grupo_torneo (
    id_grupo_torneo BIGINT
        GENERATED ALWAYS AS IDENTITY,

    id_fase_torneo BIGINT NOT NULL,

    codigo VARCHAR(20) NOT NULL,
    nombre VARCHAR(100) NOT NULL,

    cantidad_maxima_equipos SMALLINT NOT NULL,
    cantidad_clasificados SMALLINT NOT NULL,

    CONSTRAINT pk_grupo_torneo
        PRIMARY KEY (id_grupo_torneo),

    CONSTRAINT fk_grupo_torneo_fase
        FOREIGN KEY (id_fase_torneo)
        REFERENCES competencia.fase_torneo (id_fase_torneo),

    CONSTRAINT uq_grupo_torneo_codigo
        UNIQUE (id_fase_torneo, codigo),

    CONSTRAINT uq_grupo_torneo_nombre
        UNIQUE (id_fase_torneo, nombre),

    CONSTRAINT ck_grupo_torneo_codigo
        CHECK (codigo = UPPER(codigo)),

    CONSTRAINT ck_grupo_torneo_cantidades
        CHECK (
            cantidad_maxima_equipos >= 2
            AND cantidad_clasificados > 0
            AND cantidad_clasificados
                <= cantidad_maxima_equipos
        )
);


CREATE TABLE IF NOT EXISTS competencia.jornada (
    id_jornada BIGINT
        GENERATED ALWAYS AS IDENTITY,

    id_fase_torneo BIGINT NOT NULL,
    id_estado_jornada SMALLINT NOT NULL,

    numero_jornada SMALLINT NOT NULL,
    nombre VARCHAR(120),

    fecha_inicio TIMESTAMPTZ,
    fecha_fin TIMESTAMPTZ,

    observaciones VARCHAR(500),

    CONSTRAINT pk_jornada
        PRIMARY KEY (id_jornada),

    CONSTRAINT fk_jornada_fase
        FOREIGN KEY (id_fase_torneo)
        REFERENCES competencia.fase_torneo (id_fase_torneo),

    CONSTRAINT fk_jornada_estado
        FOREIGN KEY (id_estado_jornada)
        REFERENCES catalogo.estado_jornada (id_estado_jornada),

    CONSTRAINT uq_jornada_numero
        UNIQUE (id_fase_torneo, numero_jornada),

    CONSTRAINT ck_jornada_numero
        CHECK (numero_jornada > 0),

    CONSTRAINT ck_jornada_fechas
        CHECK (
            fecha_inicio IS NULL
            OR fecha_fin IS NULL
            OR fecha_fin >= fecha_inicio
        )
);


CREATE TABLE IF NOT EXISTS competencia.usuario_torneo_rol (
    id_usuario_torneo_rol BIGINT
        GENERATED ALWAYS AS IDENTITY,

    id_torneo BIGINT NOT NULL,
    id_usuario BIGINT NOT NULL,
    id_rol_torneo SMALLINT NOT NULL,

    fecha_asignacion TIMESTAMPTZ
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    fecha_fin TIMESTAMPTZ,
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    asignado_por BIGINT,

    CONSTRAINT pk_usuario_torneo_rol
        PRIMARY KEY (id_usuario_torneo_rol),

    CONSTRAINT fk_usuario_torneo_rol_torneo
        FOREIGN KEY (id_torneo)
        REFERENCES competencia.torneo (id_torneo),

    CONSTRAINT fk_usuario_torneo_rol_usuario
        FOREIGN KEY (id_usuario)
        REFERENCES seguridad.usuario (id_usuario),

    CONSTRAINT fk_usuario_torneo_rol_rol
        FOREIGN KEY (id_rol_torneo)
        REFERENCES catalogo.rol_torneo (id_rol_torneo),

    CONSTRAINT fk_usuario_torneo_rol_asignado_por
        FOREIGN KEY (asignado_por)
        REFERENCES seguridad.usuario (id_usuario),

    CONSTRAINT ck_usuario_torneo_rol_fechas
        CHECK (
            fecha_fin IS NULL
            OR fecha_fin >= fecha_asignacion
        ),

    CONSTRAINT ck_usuario_torneo_rol_activo
        CHECK (
            activo = FALSE
            OR fecha_fin IS NULL
        )
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_usuario_torneo_rol_activo
    ON competencia.usuario_torneo_rol (
        id_torneo,
        id_usuario,
        id_rol_torneo
    )
    WHERE activo = TRUE AND fecha_fin IS NULL;


CREATE INDEX IF NOT EXISTS ix_torneo_deporte
    ON competencia.torneo (id_deporte);

CREATE INDEX IF NOT EXISTS ix_fase_torneo_torneo
    ON competencia.fase_torneo (id_torneo);

CREATE INDEX IF NOT EXISTS ix_grupo_torneo_fase
    ON competencia.grupo_torneo (id_fase_torneo);

CREATE INDEX IF NOT EXISTS ix_jornada_fase
    ON competencia.jornada (id_fase_torneo);

CREATE INDEX IF NOT EXISTS ix_usuario_torneo_rol_usuario
    ON competencia.usuario_torneo_rol (id_usuario);

COMMIT;