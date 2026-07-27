BEGIN;

CREATE TABLE IF NOT EXISTS competencia.inscripcion (
    id_inscripcion BIGINT
        GENERATED ALWAYS AS IDENTITY,

    id_torneo BIGINT NOT NULL,
    id_equipo BIGINT NOT NULL,
    id_estado_inscripcion SMALLINT NOT NULL,

    monto_requerido NUMERIC(12, 2) NOT NULL,
    moneda CHAR(3) NOT NULL,

    fecha_inscripcion TIMESTAMPTZ
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    fecha_actualizacion TIMESTAMPTZ
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    registrado_por BIGINT NOT NULL,
    observaciones VARCHAR(500),

    CONSTRAINT pk_inscripcion
        PRIMARY KEY (id_inscripcion),

    CONSTRAINT fk_inscripcion_torneo
        FOREIGN KEY (id_torneo)
        REFERENCES competencia.torneo (id_torneo),

    CONSTRAINT fk_inscripcion_equipo
        FOREIGN KEY (id_equipo)
        REFERENCES participantes.equipo (id_equipo),

    CONSTRAINT fk_inscripcion_estado
        FOREIGN KEY (id_estado_inscripcion)
        REFERENCES catalogo.estado_inscripcion (
            id_estado_inscripcion
        ),

    CONSTRAINT fk_inscripcion_registrado_por
        FOREIGN KEY (registrado_por)
        REFERENCES seguridad.usuario (id_usuario),

    CONSTRAINT uq_inscripcion_torneo_equipo
        UNIQUE (id_torneo, id_equipo),

    CONSTRAINT ck_inscripcion_monto
        CHECK (monto_requerido >= 0),

    CONSTRAINT ck_inscripcion_moneda
        CHECK (
            moneda = UPPER(moneda)
            AND LENGTH(moneda) = 3
        )
);


CREATE TABLE IF NOT EXISTS competencia.jugador_inscripcion (
    id_jugador_inscripcion BIGINT
        GENERATED ALWAYS AS IDENTITY,

    id_inscripcion BIGINT NOT NULL,
    id_jugador BIGINT NOT NULL,
    id_jugador_equipo BIGINT NOT NULL,

    id_estado_jugador_inscripcion SMALLINT NOT NULL,

    numero_camiseta SMALLINT,
    es_capitan BOOLEAN NOT NULL DEFAULT FALSE,
    es_delegado BOOLEAN NOT NULL DEFAULT FALSE,

    fecha_registro TIMESTAMPTZ
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    fecha_baja TIMESTAMPTZ,
    registrado_por BIGINT NOT NULL,
    observaciones VARCHAR(500),

    CONSTRAINT pk_jugador_inscripcion
        PRIMARY KEY (id_jugador_inscripcion),

    CONSTRAINT fk_jugador_inscripcion_inscripcion
        FOREIGN KEY (id_inscripcion)
        REFERENCES competencia.inscripcion (id_inscripcion),

    CONSTRAINT fk_jugador_inscripcion_jugador
        FOREIGN KEY (id_jugador)
        REFERENCES participantes.jugador (id_usuario),

    CONSTRAINT fk_jugador_inscripcion_membresia
        FOREIGN KEY (id_jugador_equipo)
        REFERENCES participantes.jugador_equipo (
            id_jugador_equipo
        ),

    CONSTRAINT fk_jugador_inscripcion_estado
        FOREIGN KEY (id_estado_jugador_inscripcion)
        REFERENCES catalogo.estado_jugador_inscripcion (
            id_estado_jugador_inscripcion
        ),

    CONSTRAINT fk_jugador_inscripcion_registrado_por
        FOREIGN KEY (registrado_por)
        REFERENCES seguridad.usuario (id_usuario),

    CONSTRAINT uq_jugador_inscripcion
        UNIQUE (id_inscripcion, id_jugador),

    CONSTRAINT ck_jugador_inscripcion_camiseta
        CHECK (
            numero_camiseta IS NULL
            OR numero_camiseta BETWEEN 0 AND 999
        ),

    CONSTRAINT ck_jugador_inscripcion_fecha_baja
        CHECK (
            fecha_baja IS NULL
            OR fecha_baja >= fecha_registro
        )
);


CREATE UNIQUE INDEX IF NOT EXISTS
    uq_jugador_inscripcion_camiseta_activa
ON competencia.jugador_inscripcion (
    id_inscripcion,
    numero_camiseta
)
WHERE fecha_baja IS NULL
  AND numero_camiseta IS NOT NULL;


CREATE UNIQUE INDEX IF NOT EXISTS
    uq_jugador_inscripcion_capitan_activo
ON competencia.jugador_inscripcion (id_inscripcion)
WHERE es_capitan = TRUE
  AND fecha_baja IS NULL;


CREATE UNIQUE INDEX IF NOT EXISTS
    uq_jugador_inscripcion_delegado_activo
ON competencia.jugador_inscripcion (id_inscripcion)
WHERE es_delegado = TRUE
  AND fecha_baja IS NULL;


CREATE TABLE IF NOT EXISTS finanzas.pago (
    id_pago BIGINT
        GENERATED ALWAYS AS IDENTITY,

    id_inscripcion BIGINT NOT NULL,
    id_metodo_pago SMALLINT NOT NULL,
    id_estado_pago SMALLINT NOT NULL,

    monto NUMERIC(12, 2) NOT NULL,
    moneda CHAR(3) NOT NULL,

    referencia VARCHAR(120),
    comprobante_url VARCHAR(500),

    fecha_pago TIMESTAMPTZ
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    fecha_verificacion TIMESTAMPTZ,

    registrado_por BIGINT NOT NULL,
    verificado_por BIGINT,

    observaciones VARCHAR(500),

    fecha_registro TIMESTAMPTZ
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    fecha_actualizacion TIMESTAMPTZ
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_pago
        PRIMARY KEY (id_pago),

    CONSTRAINT fk_pago_inscripcion
        FOREIGN KEY (id_inscripcion)
        REFERENCES competencia.inscripcion (id_inscripcion),

    CONSTRAINT fk_pago_metodo
        FOREIGN KEY (id_metodo_pago)
        REFERENCES catalogo.metodo_pago (id_metodo_pago),

    CONSTRAINT fk_pago_estado
        FOREIGN KEY (id_estado_pago)
        REFERENCES catalogo.estado_pago (id_estado_pago),

    CONSTRAINT fk_pago_registrado_por
        FOREIGN KEY (registrado_por)
        REFERENCES seguridad.usuario (id_usuario),

    CONSTRAINT fk_pago_verificado_por
        FOREIGN KEY (verificado_por)
        REFERENCES seguridad.usuario (id_usuario),

    CONSTRAINT ck_pago_monto
        CHECK (monto > 0),

    CONSTRAINT ck_pago_moneda
        CHECK (
            moneda = UPPER(moneda)
            AND LENGTH(moneda) = 3
        ),

    CONSTRAINT ck_pago_verificacion
        CHECK (
            (
                verificado_por IS NULL
                AND fecha_verificacion IS NULL
            )
            OR
            (
                verificado_por IS NOT NULL
                AND fecha_verificacion IS NOT NULL
            )
        )
);


CREATE UNIQUE INDEX IF NOT EXISTS uq_pago_referencia
    ON finanzas.pago (referencia)
    WHERE referencia IS NOT NULL;


CREATE INDEX IF NOT EXISTS ix_inscripcion_torneo
    ON competencia.inscripcion (id_torneo);


CREATE INDEX IF NOT EXISTS ix_inscripcion_equipo
    ON competencia.inscripcion (id_equipo);


CREATE INDEX IF NOT EXISTS ix_jugador_inscripcion_jugador
    ON competencia.jugador_inscripcion (id_jugador);


CREATE INDEX IF NOT EXISTS ix_pago_inscripcion
    ON finanzas.pago (id_inscripcion);

COMMIT;