BEGIN;

CREATE TABLE IF NOT EXISTS competencia.equipo_grupo (
    id_equipo_grupo BIGINT
        GENERATED ALWAYS AS IDENTITY,

    id_fase_torneo BIGINT NOT NULL,
    id_grupo_torneo BIGINT NOT NULL,
    id_inscripcion BIGINT NOT NULL,

    posicion_sorteo SMALLINT,

    asignado_por BIGINT NOT NULL,

    fecha_asignacion TIMESTAMPTZ
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    observaciones VARCHAR(500),

    CONSTRAINT pk_equipo_grupo
        PRIMARY KEY (id_equipo_grupo),

    CONSTRAINT fk_equipo_grupo_fase
        FOREIGN KEY (id_fase_torneo)
        REFERENCES competencia.fase_torneo (
            id_fase_torneo
        ),

    CONSTRAINT fk_equipo_grupo_grupo
        FOREIGN KEY (id_grupo_torneo)
        REFERENCES competencia.grupo_torneo (
            id_grupo_torneo
        ),

    CONSTRAINT fk_equipo_grupo_inscripcion
        FOREIGN KEY (id_inscripcion)
        REFERENCES competencia.inscripcion (
            id_inscripcion
        ),

    CONSTRAINT fk_equipo_grupo_asignado_por
        FOREIGN KEY (asignado_por)
        REFERENCES seguridad.usuario (
            id_usuario
        ),

    CONSTRAINT uq_equipo_grupo_fase_inscripcion
        UNIQUE (
            id_fase_torneo,
            id_inscripcion
        ),

    CONSTRAINT uq_equipo_grupo_grupo_inscripcion
        UNIQUE (
            id_grupo_torneo,
            id_inscripcion
        ),

    CONSTRAINT ck_equipo_grupo_posicion
        CHECK (
            posicion_sorteo IS NULL
            OR posicion_sorteo > 0
        )
);


CREATE UNIQUE INDEX IF NOT EXISTS
    uq_equipo_grupo_posicion_sorteo
ON competencia.equipo_grupo (
    id_grupo_torneo,
    posicion_sorteo
)
WHERE posicion_sorteo IS NOT NULL;


CREATE TABLE IF NOT EXISTS competencia.partido (
    id_partido BIGINT
        GENERATED ALWAYS AS IDENTITY,

    id_jornada BIGINT NOT NULL,
    id_grupo_torneo BIGINT,
    id_lugar BIGINT,
    id_estado_partido SMALLINT NOT NULL,

    codigo VARCHAR(50) NOT NULL,
    numero_partido SMALLINT NOT NULL,

    nombre_ronda VARCHAR(80),

    fecha_hora_inicio TIMESTAMPTZ,
    fecha_hora_fin TIMESTAMPTZ,

    id_partido_siguiente BIGINT,

    creado_por BIGINT NOT NULL,
    actualizado_por BIGINT,

    observaciones VARCHAR(500),

    fecha_registro TIMESTAMPTZ
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    fecha_actualizacion TIMESTAMPTZ
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_partido
        PRIMARY KEY (id_partido),

    CONSTRAINT fk_partido_jornada
        FOREIGN KEY (id_jornada)
        REFERENCES competencia.jornada (
            id_jornada
        ),

    CONSTRAINT fk_partido_grupo
        FOREIGN KEY (id_grupo_torneo)
        REFERENCES competencia.grupo_torneo (
            id_grupo_torneo
        ),

    CONSTRAINT fk_partido_lugar
        FOREIGN KEY (id_lugar)
        REFERENCES competencia.lugar (
            id_lugar
        ),

    CONSTRAINT fk_partido_estado
        FOREIGN KEY (id_estado_partido)
        REFERENCES catalogo.estado_partido (
            id_estado_partido
        ),

    CONSTRAINT fk_partido_siguiente
        FOREIGN KEY (id_partido_siguiente)
        REFERENCES competencia.partido (
            id_partido
        )
        ON DELETE SET NULL,

    CONSTRAINT fk_partido_creado_por
        FOREIGN KEY (creado_por)
        REFERENCES seguridad.usuario (
            id_usuario
        ),

    CONSTRAINT fk_partido_actualizado_por
        FOREIGN KEY (actualizado_por)
        REFERENCES seguridad.usuario (
            id_usuario
        ),

    CONSTRAINT uq_partido_codigo
        UNIQUE (codigo),

    CONSTRAINT uq_partido_jornada_numero
        UNIQUE (
            id_jornada,
            numero_partido
        ),

    CONSTRAINT ck_partido_codigo
        CHECK (codigo = UPPER(codigo)),

    CONSTRAINT ck_partido_numero
        CHECK (numero_partido > 0),

    CONSTRAINT ck_partido_fechas
        CHECK (
            fecha_hora_inicio IS NULL
            OR fecha_hora_fin IS NULL
            OR fecha_hora_fin > fecha_hora_inicio
        ),

    CONSTRAINT ck_partido_siguiente
        CHECK (
            id_partido_siguiente IS NULL
            OR id_partido_siguiente <> id_partido
        )
);


CREATE TABLE IF NOT EXISTS competencia.partido_equipo (
    id_partido_equipo BIGINT
        GENERATED ALWAYS AS IDENTITY,

    id_partido BIGINT NOT NULL,
    id_inscripcion BIGINT NOT NULL,

    id_condicion_equipo SMALLINT NOT NULL,
    id_resultado_equipo_partido SMALLINT NOT NULL,

    marcador INTEGER,
    marcador_desempate INTEGER,

    puntos_tabla SMALLINT NOT NULL DEFAULT 0,
    clasificado BOOLEAN NOT NULL DEFAULT FALSE,

    observaciones VARCHAR(500),

    CONSTRAINT pk_partido_equipo
        PRIMARY KEY (id_partido_equipo),

    CONSTRAINT fk_partido_equipo_partido
        FOREIGN KEY (id_partido)
        REFERENCES competencia.partido (
            id_partido
        ),

    CONSTRAINT fk_partido_equipo_inscripcion
        FOREIGN KEY (id_inscripcion)
        REFERENCES competencia.inscripcion (
            id_inscripcion
        ),

    CONSTRAINT fk_partido_equipo_condicion
        FOREIGN KEY (id_condicion_equipo)
        REFERENCES catalogo.condicion_equipo_partido (
            id_condicion_equipo
        ),

    CONSTRAINT fk_partido_equipo_resultado
        FOREIGN KEY (id_resultado_equipo_partido)
        REFERENCES catalogo.resultado_equipo_partido (
            id_resultado_equipo_partido
        ),

    CONSTRAINT uq_partido_equipo
        UNIQUE (
            id_partido,
            id_inscripcion
        ),

    CONSTRAINT uq_partido_condicion
        UNIQUE (
            id_partido,
            id_condicion_equipo
        ),

    CONSTRAINT ck_partido_equipo_marcador
        CHECK (
            marcador IS NULL
            OR marcador >= 0
        ),

    CONSTRAINT ck_partido_equipo_desempate
        CHECK (
            marcador_desempate IS NULL
            OR marcador_desempate >= 0
        ),

    CONSTRAINT ck_partido_equipo_puntos
        CHECK (puntos_tabla >= 0)
);


CREATE TABLE IF NOT EXISTS competencia.arbitro_partido (
    id_arbitro_partido BIGINT
        GENERATED ALWAYS AS IDENTITY,

    id_partido BIGINT NOT NULL,
    id_arbitro BIGINT NOT NULL,

    id_tipo_arbitro_partido SMALLINT NOT NULL,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    asignado_por BIGINT NOT NULL,

    fecha_asignacion TIMESTAMPTZ
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    fecha_fin TIMESTAMPTZ,

    observaciones VARCHAR(500),

    CONSTRAINT pk_arbitro_partido
        PRIMARY KEY (id_arbitro_partido),

    CONSTRAINT fk_arbitro_partido_partido
        FOREIGN KEY (id_partido)
        REFERENCES competencia.partido (
            id_partido
        ),

    CONSTRAINT fk_arbitro_partido_arbitro
        FOREIGN KEY (id_arbitro)
        REFERENCES participantes.arbitro (
            id_usuario
        ),

    CONSTRAINT fk_arbitro_partido_tipo
        FOREIGN KEY (id_tipo_arbitro_partido)
        REFERENCES catalogo.tipo_arbitro_partido (
            id_tipo_arbitro_partido
        ),

    CONSTRAINT fk_arbitro_partido_asignado_por
        FOREIGN KEY (asignado_por)
        REFERENCES seguridad.usuario (
            id_usuario
        ),

    CONSTRAINT ck_arbitro_partido_fechas
        CHECK (
            fecha_fin IS NULL
            OR fecha_fin >= fecha_asignacion
        ),

    CONSTRAINT ck_arbitro_partido_activo
        CHECK (
            activo = FALSE
            OR fecha_fin IS NULL
        )
);


CREATE UNIQUE INDEX IF NOT EXISTS
    uq_arbitro_partido_tipo_activo
ON competencia.arbitro_partido (
    id_partido,
    id_tipo_arbitro_partido
)
WHERE activo = TRUE
  AND fecha_fin IS NULL;


CREATE UNIQUE INDEX IF NOT EXISTS
    uq_arbitro_partido_arbitro_activo
ON competencia.arbitro_partido (
    id_partido,
    id_arbitro
)
WHERE activo = TRUE
  AND fecha_fin IS NULL;


CREATE TABLE IF NOT EXISTS competencia.jugador_partido (
    id_jugador_partido BIGINT
        GENERATED ALWAYS AS IDENTITY,

    id_partido BIGINT NOT NULL,
    id_partido_equipo BIGINT NOT NULL,
    id_jugador_inscripcion BIGINT NOT NULL,

    convocado BOOLEAN NOT NULL DEFAULT TRUE,
    asistio BOOLEAN NOT NULL DEFAULT FALSE,
    titular BOOLEAN NOT NULL DEFAULT FALSE,

    minutos_jugados SMALLINT NOT NULL DEFAULT 0,
    puntos_anotados INTEGER NOT NULL DEFAULT 0,
    faltas SMALLINT NOT NULL DEFAULT 0,
    amonestaciones SMALLINT NOT NULL DEFAULT 0,

    expulsado BOOLEAN NOT NULL DEFAULT FALSE,
    lesionado BOOLEAN NOT NULL DEFAULT FALSE,

    calificacion NUMERIC(4, 2),

    estadisticas JSONB
        NOT NULL DEFAULT '{}'::JSONB,

    registrado_por BIGINT NOT NULL,

    fecha_registro TIMESTAMPTZ
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    fecha_actualizacion TIMESTAMPTZ
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    observaciones VARCHAR(500),

    CONSTRAINT pk_jugador_partido
        PRIMARY KEY (id_jugador_partido),

    CONSTRAINT fk_jugador_partido_partido
        FOREIGN KEY (id_partido)
        REFERENCES competencia.partido (
            id_partido
        ),

    CONSTRAINT fk_jugador_partido_equipo
        FOREIGN KEY (id_partido_equipo)
        REFERENCES competencia.partido_equipo (
            id_partido_equipo
        ),

    CONSTRAINT fk_jugador_partido_inscripcion
        FOREIGN KEY (id_jugador_inscripcion)
        REFERENCES competencia.jugador_inscripcion (
            id_jugador_inscripcion
        ),

    CONSTRAINT fk_jugador_partido_registrado_por
        FOREIGN KEY (registrado_por)
        REFERENCES seguridad.usuario (
            id_usuario
        ),

    CONSTRAINT uq_jugador_partido
        UNIQUE (
            id_partido,
            id_jugador_inscripcion
        ),

    CONSTRAINT ck_jugador_partido_minutos
        CHECK (minutos_jugados >= 0),

    CONSTRAINT ck_jugador_partido_puntos
        CHECK (puntos_anotados >= 0),

    CONSTRAINT ck_jugador_partido_faltas
        CHECK (faltas >= 0),

    CONSTRAINT ck_jugador_partido_amonestaciones
        CHECK (amonestaciones >= 0),

    CONSTRAINT ck_jugador_partido_calificacion
        CHECK (
            calificacion IS NULL
            OR calificacion BETWEEN 0 AND 10
        ),

    CONSTRAINT ck_jugador_partido_estadisticas
        CHECK (
            JSONB_TYPEOF(estadisticas) = 'object'
        ),

    CONSTRAINT ck_jugador_partido_asistencia
        CHECK (
            asistio = FALSE
            OR convocado = TRUE
        ),

    CONSTRAINT ck_jugador_partido_titular
        CHECK (
            titular = FALSE
            OR (
                convocado = TRUE
                AND asistio = TRUE
            )
        ),

    CONSTRAINT ck_jugador_partido_sin_asistencia
        CHECK (
            asistio = TRUE
            OR (
                titular = FALSE
                AND minutos_jugados = 0
                AND puntos_anotados = 0
                AND faltas = 0
                AND amonestaciones = 0
                AND expulsado = FALSE
                AND lesionado = FALSE
            )
        )
);


CREATE INDEX IF NOT EXISTS ix_equipo_grupo_grupo
    ON competencia.equipo_grupo (
        id_grupo_torneo
    );


CREATE INDEX IF NOT EXISTS ix_partido_jornada
    ON competencia.partido (
        id_jornada
    );


CREATE INDEX IF NOT EXISTS ix_partido_lugar
    ON competencia.partido (
        id_lugar
    );


CREATE INDEX IF NOT EXISTS ix_partido_equipo_partido
    ON competencia.partido_equipo (
        id_partido
    );


CREATE INDEX IF NOT EXISTS ix_partido_equipo_inscripcion
    ON competencia.partido_equipo (
        id_inscripcion
    );


CREATE INDEX IF NOT EXISTS ix_arbitro_partido_arbitro
    ON competencia.arbitro_partido (
        id_arbitro
    );


CREATE INDEX IF NOT EXISTS ix_jugador_partido_partido
    ON competencia.jugador_partido (
        id_partido
    );

COMMIT;