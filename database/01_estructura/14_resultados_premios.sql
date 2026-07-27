BEGIN;

CREATE TABLE IF NOT EXISTS competencia.resultado_torneo (
    id_resultado_torneo BIGINT
        GENERATED ALWAYS AS IDENTITY,

    id_torneo BIGINT NOT NULL,
    id_inscripcion BIGINT NOT NULL,

    posicion_final SMALLINT NOT NULL,

    partidos_jugados SMALLINT NOT NULL DEFAULT 0,
    partidos_ganados SMALLINT NOT NULL DEFAULT 0,
    partidos_empatados SMALLINT NOT NULL DEFAULT 0,
    partidos_perdidos SMALLINT NOT NULL DEFAULT 0,

    marcador_favor INTEGER NOT NULL DEFAULT 0,
    marcador_contra INTEGER NOT NULL DEFAULT 0,
    diferencia_marcador INTEGER NOT NULL DEFAULT 0,

    puntos INTEGER NOT NULL DEFAULT 0,

    generado_por BIGINT NOT NULL,

    fecha_generacion TIMESTAMPTZ
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    observaciones VARCHAR(500),

    CONSTRAINT pk_resultado_torneo
        PRIMARY KEY (id_resultado_torneo),

    CONSTRAINT fk_resultado_torneo_torneo
        FOREIGN KEY (id_torneo)
        REFERENCES competencia.torneo (
            id_torneo
        ),

    CONSTRAINT fk_resultado_torneo_inscripcion
        FOREIGN KEY (id_inscripcion)
        REFERENCES competencia.inscripcion (
            id_inscripcion
        ),

    CONSTRAINT fk_resultado_torneo_generado_por
        FOREIGN KEY (generado_por)
        REFERENCES seguridad.usuario (
            id_usuario
        ),

    CONSTRAINT uq_resultado_torneo_inscripcion
        UNIQUE (
            id_torneo,
            id_inscripcion
        ),

    CONSTRAINT uq_resultado_torneo_posicion
        UNIQUE (
            id_torneo,
            posicion_final
        ),

    CONSTRAINT ck_resultado_torneo_posicion
        CHECK (posicion_final > 0),

    CONSTRAINT ck_resultado_torneo_partidos
        CHECK (
            partidos_jugados >= 0
            AND partidos_ganados >= 0
            AND partidos_empatados >= 0
            AND partidos_perdidos >= 0
            AND partidos_jugados =
                partidos_ganados
                + partidos_empatados
                + partidos_perdidos
        ),

    CONSTRAINT ck_resultado_torneo_marcadores
        CHECK (
            marcador_favor >= 0
            AND marcador_contra >= 0
        ),

    CONSTRAINT ck_resultado_torneo_puntos
        CHECK (puntos >= 0)
);


CREATE TABLE IF NOT EXISTS finanzas.premio (
    id_premio BIGINT
        GENERATED ALWAYS AS IDENTITY,

    id_tipo_premio SMALLINT NOT NULL,

    codigo VARCHAR(50) NOT NULL,
    nombre VARCHAR(150) NOT NULL,
    descripcion VARCHAR(500),

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    fecha_registro TIMESTAMPTZ
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_premio
        PRIMARY KEY (id_premio),

    CONSTRAINT fk_premio_tipo
        FOREIGN KEY (id_tipo_premio)
        REFERENCES catalogo.tipo_premio (
            id_tipo_premio
        ),

    CONSTRAINT uq_premio_codigo
        UNIQUE (codigo),

    CONSTRAINT ck_premio_codigo
        CHECK (codigo = UPPER(codigo)),

    CONSTRAINT ck_premio_nombre
        CHECK (LENGTH(BTRIM(nombre)) >= 3)
);


CREATE TABLE IF NOT EXISTS finanzas.torneo_premio (
    id_torneo_premio BIGINT
        GENERATED ALWAYS AS IDENTITY,

    id_torneo BIGINT NOT NULL,
    id_premio BIGINT NOT NULL,

    posicion_objetivo SMALLINT NOT NULL,

    valor_economico NUMERIC(12, 2)
        NOT NULL DEFAULT 0,

    moneda CHAR(3) NOT NULL DEFAULT 'BOB',

    descripcion_entrega VARCHAR(500),

    registrado_por BIGINT NOT NULL,

    fecha_registro TIMESTAMPTZ
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_torneo_premio
        PRIMARY KEY (id_torneo_premio),

    CONSTRAINT fk_torneo_premio_torneo
        FOREIGN KEY (id_torneo)
        REFERENCES competencia.torneo (
            id_torneo
        ),

    CONSTRAINT fk_torneo_premio_premio
        FOREIGN KEY (id_premio)
        REFERENCES finanzas.premio (
            id_premio
        ),

    CONSTRAINT fk_torneo_premio_registrado_por
        FOREIGN KEY (registrado_por)
        REFERENCES seguridad.usuario (
            id_usuario
        ),

    CONSTRAINT uq_torneo_premio
        UNIQUE (
            id_torneo,
            id_premio,
            posicion_objetivo
        ),

    CONSTRAINT ck_torneo_premio_posicion
        CHECK (posicion_objetivo > 0),

    CONSTRAINT ck_torneo_premio_valor
        CHECK (valor_economico >= 0),

    CONSTRAINT ck_torneo_premio_moneda
        CHECK (
            moneda = UPPER(moneda)
            AND LENGTH(moneda) = 3
        )
);


CREATE TABLE IF NOT EXISTS finanzas.entrega_premio (
    id_entrega_premio BIGINT
        GENERATED ALWAYS AS IDENTITY,

    id_torneo_premio BIGINT NOT NULL,
    id_resultado_torneo BIGINT NOT NULL,

    id_estado_entrega_premio SMALLINT NOT NULL,

    autorizado_por BIGINT,
    entregado_por BIGINT,

    fecha_autorizacion TIMESTAMPTZ,
    fecha_entrega TIMESTAMPTZ,

    fecha_registro TIMESTAMPTZ
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    fecha_actualizacion TIMESTAMPTZ
        NOT NULL DEFAULT CURRENT_TIMESTAMP,

    observaciones VARCHAR(500),

    CONSTRAINT pk_entrega_premio
        PRIMARY KEY (id_entrega_premio),

    CONSTRAINT fk_entrega_premio_torneo_premio
        FOREIGN KEY (id_torneo_premio)
        REFERENCES finanzas.torneo_premio (
            id_torneo_premio
        ),

    CONSTRAINT fk_entrega_premio_resultado
        FOREIGN KEY (id_resultado_torneo)
        REFERENCES competencia.resultado_torneo (
            id_resultado_torneo
        ),

    CONSTRAINT fk_entrega_premio_estado
        FOREIGN KEY (id_estado_entrega_premio)
        REFERENCES catalogo.estado_entrega_premio (
            id_estado_entrega_premio
        ),

    CONSTRAINT fk_entrega_premio_autorizado_por
        FOREIGN KEY (autorizado_por)
        REFERENCES seguridad.usuario (
            id_usuario
        ),

    CONSTRAINT fk_entrega_premio_entregado_por
        FOREIGN KEY (entregado_por)
        REFERENCES seguridad.usuario (
            id_usuario
        ),

    CONSTRAINT uq_entrega_premio_torneo_premio
        UNIQUE (id_torneo_premio),

    CONSTRAINT ck_entrega_premio_autorizacion
        CHECK (
            (
                autorizado_por IS NULL
                AND fecha_autorizacion IS NULL
            )
            OR
            (
                autorizado_por IS NOT NULL
                AND fecha_autorizacion IS NOT NULL
            )
        ),

    CONSTRAINT ck_entrega_premio_entrega
        CHECK (
            (
                entregado_por IS NULL
                AND fecha_entrega IS NULL
            )
            OR
            (
                entregado_por IS NOT NULL
                AND fecha_entrega IS NOT NULL
            )
        )
);


CREATE INDEX IF NOT EXISTS ix_resultado_torneo_torneo
    ON competencia.resultado_torneo (
        id_torneo
    );


CREATE INDEX IF NOT EXISTS ix_torneo_premio_torneo
    ON finanzas.torneo_premio (
        id_torneo
    );


CREATE INDEX IF NOT EXISTS ix_entrega_premio_resultado
    ON finanzas.entrega_premio (
        id_resultado_torneo
    );

COMMIT;