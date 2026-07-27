BEGIN;

CREATE TABLE IF NOT EXISTS seguridad.usuario (
    id_usuario BIGINT
        GENERATED ALWAYS AS IDENTITY,

    id_tipo_documento SMALLINT NOT NULL,
    numero_documento VARCHAR(30) NOT NULL,

    nombres VARCHAR(100) NOT NULL,
    apellido_paterno VARCHAR(80),
    apellido_materno VARCHAR(80),

    fecha_nacimiento DATE NOT NULL,
    sexo CHAR(1),

    correo VARCHAR(150) NOT NULL,
    telefono VARCHAR(20),
    direccion VARCHAR(200),
    zona VARCHAR(100),

    contrasenia_hash VARCHAR(255) NOT NULL,

    id_estado_usuario SMALLINT NOT NULL,

    intentos_fallidos SMALLINT NOT NULL DEFAULT 0,
    ultimo_acceso TIMESTAMPTZ,

    fecha_registro TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_usuario
        PRIMARY KEY (id_usuario),

    CONSTRAINT fk_usuario_tipo_documento
        FOREIGN KEY (id_tipo_documento)
        REFERENCES catalogo.tipo_documento (id_tipo_documento),

    CONSTRAINT fk_usuario_estado
        FOREIGN KEY (id_estado_usuario)
        REFERENCES catalogo.estado_usuario (id_estado_usuario),

    CONSTRAINT uq_usuario_documento
        UNIQUE (id_tipo_documento, numero_documento),

    CONSTRAINT ck_usuario_numero_documento
        CHECK (LENGTH(BTRIM(numero_documento)) >= 4),

    CONSTRAINT ck_usuario_nombres
        CHECK (LENGTH(BTRIM(nombres)) >= 2),

    CONSTRAINT ck_usuario_fecha_nacimiento
        CHECK (fecha_nacimiento >= DATE '1900-01-01'),

    CONSTRAINT ck_usuario_sexo
        CHECK (
            sexo IS NULL
            OR sexo IN ('M', 'F', 'O', 'N')
        ),

    CONSTRAINT ck_usuario_correo
        CHECK (
            correo ~* '^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$'
        ),

    CONSTRAINT ck_usuario_telefono
        CHECK (
            telefono IS NULL
            OR telefono ~ '^\+?[0-9]{7,15}$'
        ),

    CONSTRAINT ck_usuario_contrasenia_hash
        CHECK (LENGTH(BTRIM(contrasenia_hash)) >= 20),

    CONSTRAINT ck_usuario_intentos_fallidos
        CHECK (intentos_fallidos >= 0)
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_usuario_correo_minuscula
    ON seguridad.usuario (LOWER(correo));


CREATE TABLE IF NOT EXISTS seguridad.rol (
    id_rol SMALLINT
        GENERATED ALWAYS AS IDENTITY,

    codigo VARCHAR(40) NOT NULL,
    nombre VARCHAR(80) NOT NULL,
    descripcion VARCHAR(250),
    activo BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT pk_rol
        PRIMARY KEY (id_rol),

    CONSTRAINT uq_rol_codigo
        UNIQUE (codigo),

    CONSTRAINT ck_rol_codigo
        CHECK (codigo = UPPER(codigo)),

    CONSTRAINT ck_rol_nombre
        CHECK (LENGTH(BTRIM(nombre)) >= 2)
);


CREATE TABLE IF NOT EXISTS seguridad.usuario_rol (
    id_usuario_rol BIGINT
        GENERATED ALWAYS AS IDENTITY,

    id_usuario BIGINT NOT NULL,
    id_rol SMALLINT NOT NULL,

    fecha_inicio DATE NOT NULL DEFAULT CURRENT_DATE,
    fecha_fin DATE,

    activo BOOLEAN NOT NULL DEFAULT TRUE,

    asignado_por BIGINT,
    fecha_asignacion TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT pk_usuario_rol
        PRIMARY KEY (id_usuario_rol),

    CONSTRAINT fk_usuario_rol_usuario
        FOREIGN KEY (id_usuario)
        REFERENCES seguridad.usuario (id_usuario),

    CONSTRAINT fk_usuario_rol_rol
        FOREIGN KEY (id_rol)
        REFERENCES seguridad.rol (id_rol),

    CONSTRAINT fk_usuario_rol_asignado_por
        FOREIGN KEY (asignado_por)
        REFERENCES seguridad.usuario (id_usuario),

    CONSTRAINT ck_usuario_rol_fechas
        CHECK (
            fecha_fin IS NULL
            OR fecha_fin >= fecha_inicio
        ),

    CONSTRAINT ck_usuario_rol_activo_fechas
        CHECK (
            activo = FALSE
            OR fecha_fin IS NULL
        )
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_usuario_rol_activo
    ON seguridad.usuario_rol (id_usuario, id_rol)
    WHERE activo = TRUE AND fecha_fin IS NULL;


COMMENT ON TABLE seguridad.usuario IS
'Datos personales y credenciales de las personas registradas en el sistema.';

COMMENT ON COLUMN seguridad.usuario.contrasenia_hash IS
'Hash de la contrasenia. Nunca debe almacenarse la contrasenia en texto plano.';

COMMENT ON TABLE seguridad.rol IS
'Roles generales que una persona puede desempeñar dentro del sistema.';

COMMENT ON TABLE seguridad.usuario_rol IS
'Historial de roles generales asignados a cada usuario.';

COMMIT;