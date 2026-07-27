export const SQL_CATEGORIES = [
  {
    id: "consultas",
    label: "Consultas SQL",
  },
  {
    id: "dml",
    label: "DML",
  },
  {
    id: "ddl",
    label: "DDL",
  },
  {
    id: "funciones",
    label: "Funciones",
  },
  {
    id: "procedimientos",
    label: "Procedimientos",
  },
  {
    id: "triggers",
    label: "Triggers",
  },
  {
    id: "cursores",
    label: "Cursores",
  },
  {
    id: "avanzado",
    label: "SQL avanzado",
  },
];

export const SQL_EXAMPLES = [
  {
    id: "informacion-conexion",
    categoria: "consultas",
    titulo: "Información de PostgreSQL",
    descripcion:
      "Muestra la base de datos, el usuario y la fecha actual.",
    sql: `SELECT
    CURRENT_DATABASE() AS base_datos,
    CURRENT_USER AS usuario_postgresql,
    CURRENT_TIMESTAMP AS fecha_hora_servidor;`,
  },
  {
    id: "listar-tablas",
    categoria: "consultas",
    titulo: "Listar tablas de la base de datos",
    descripcion:
      "Consulta el catálogo interno de PostgreSQL.",
    sql: `SELECT
    table_schema AS esquema,
    table_name AS tabla,
    table_type AS tipo
FROM information_schema.tables
WHERE table_schema NOT IN (
    'pg_catalog',
    'information_schema'
)
ORDER BY
    table_schema,
    table_name;`,
  },
  {
    id: "join",
    categoria: "consultas",
    titulo: "JOIN entre equipos y jugadores",
    descripcion:
      "Demuestra una consulta INNER JOIN con datos temporales.",
    sql: `WITH equipos (
    id_equipo,
    nombre
) AS (
    VALUES
        (1, 'Cóndores'),
        (2, 'Andes United'),
        (3, 'Tigres')
),
jugadores (
    id_jugador,
    nombre,
    id_equipo
) AS (
    VALUES
        (1, 'Carlos Apaza', 1),
        (2, 'Lucía Paredes', 1),
        (3, 'Mario Quispe', 2),
        (4, 'Ana Flores', 3)
)
SELECT
    jugadores.id_jugador,
    jugadores.nombre AS jugador,
    equipos.nombre AS equipo
FROM jugadores
INNER JOIN equipos
    ON equipos.id_equipo =
       jugadores.id_equipo
ORDER BY
    equipos.nombre,
    jugadores.nombre;`,
  },
  {
    id: "dml-completo",
    categoria: "dml",
    titulo: "INSERT, UPDATE y DELETE",
    descripcion:
      "Ejecuta las principales operaciones DML dentro de una tabla temporal.",
    sql: `CREATE TEMP TABLE lab_equipos (
    id_equipo INTEGER
        GENERATED ALWAYS AS IDENTITY
        PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    puntos INTEGER NOT NULL DEFAULT 0,
    activo BOOLEAN NOT NULL DEFAULT TRUE
);

INSERT INTO lab_equipos (
    nombre,
    puntos
)
VALUES
    ('Cóndores', 9),
    ('Andes United', 7),
    ('Tigres', 4)
RETURNING *;

UPDATE lab_equipos
SET puntos = puntos + 3
WHERE nombre = 'Tigres'
RETURNING *;

DELETE FROM lab_equipos
WHERE nombre = 'Andes United'
RETURNING *;

SELECT *
FROM lab_equipos
ORDER BY puntos DESC;`,
  },
  {
    id: "ddl-tabla",
    categoria: "ddl",
    titulo: "CREATE TABLE y ALTER TABLE",
    descripcion:
      "Crea y modifica la estructura de una tabla temporal.",
    sql: `CREATE TEMP TABLE lab_torneos (
    id_torneo INTEGER
        GENERATED ALWAYS AS IDENTITY
        PRIMARY KEY,
    nombre VARCHAR(120) NOT NULL,
    fecha_inicio DATE NOT NULL
);

ALTER TABLE lab_torneos
ADD COLUMN estado VARCHAR(20)
NOT NULL
DEFAULT 'BORRADOR';

ALTER TABLE lab_torneos
ADD CONSTRAINT ck_lab_torneo_estado
CHECK (
    estado IN (
        'BORRADOR',
        'EN_CURSO',
        'FINALIZADO'
    )
);

INSERT INTO lab_torneos (
    nombre,
    fecha_inicio,
    estado
)
VALUES (
    'Torneo Experimental',
    CURRENT_DATE,
    'BORRADOR'
);

SELECT *
FROM lab_torneos;`,
  },
  {
    id: "vista",
    categoria: "ddl",
    titulo: "Crear una vista",
    descripcion:
      "Construye una vista temporal para consultar equipos activos.",
    sql: `CREATE TEMP TABLE lab_equipos (
    id_equipo INTEGER PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    activo BOOLEAN NOT NULL
);

INSERT INTO lab_equipos
VALUES
    (1, 'Cóndores', TRUE),
    (2, 'Andes United', TRUE),
    (3, 'Tigres', FALSE);

CREATE TEMP VIEW vw_lab_equipos_activos AS
SELECT
    id_equipo,
    nombre
FROM lab_equipos
WHERE activo = TRUE;

SELECT *
FROM vw_lab_equipos_activos
ORDER BY nombre;`,
  },
  {
    id: "funcion-puntos",
    categoria: "funciones",
    titulo: "Función para calcular puntos",
    descripcion:
      "Crea una función PL/pgSQL que calcula puntos deportivos.",
    sql: `CREATE OR REPLACE FUNCTION
pg_temp.calcular_puntos_equipo(
    partidos_ganados INTEGER,
    partidos_empatados INTEGER
)
RETURNS INTEGER
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN (
        partidos_ganados * 3
    ) + partidos_empatados;
END;
$$;

SELECT
    pg_temp.calcular_puntos_equipo(
        5,
        2
    ) AS puntos_obtenidos;`,
  },
  {
    id: "funcion-tabla",
    categoria: "funciones",
    titulo: "Función que retorna una tabla",
    descripcion:
      "Crea una función que devuelve varias filas.",
    sql: `CREATE OR REPLACE FUNCTION
pg_temp.clasificar_equipos()
RETURNS TABLE (
    equipo VARCHAR,
    puntos INTEGER,
    posicion INTEGER
)
LANGUAGE sql
AS $$
    SELECT
        datos.equipo,
        datos.puntos,
        ROW_NUMBER() OVER (
            ORDER BY datos.puntos DESC
        )::INTEGER AS posicion
    FROM (
        VALUES
            ('Cóndores'::VARCHAR, 12),
            ('Andes United'::VARCHAR, 9),
            ('Tigres'::VARCHAR, 6)
    ) AS datos (
        equipo,
        puntos
    );
$$;

SELECT *
FROM pg_temp.clasificar_equipos();`,
  },
  {
    id: "procedimiento",
    categoria: "procedimientos",
    titulo: "Procedimiento almacenado",
    descripcion:
      "Crea y ejecuta un procedimiento para registrar equipos.",
    sql: `CREATE TEMP TABLE lab_equipos (
    id_equipo INTEGER
        GENERATED ALWAYS AS IDENTITY
        PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    puntos INTEGER NOT NULL
);

CREATE OR REPLACE PROCEDURE
pg_temp.registrar_equipo(
    nombre_equipo VARCHAR,
    puntos_iniciales INTEGER
)
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO lab_equipos (
        nombre,
        puntos
    )
    VALUES (
        nombre_equipo,
        puntos_iniciales
    );
END;
$$;

CALL pg_temp.registrar_equipo(
    'Cóndores',
    10
);

CALL pg_temp.registrar_equipo(
    'Andes United',
    8
);

SELECT *
FROM lab_equipos
ORDER BY puntos DESC;`,
  },
  {
    id: "trigger-auditoria",
    categoria: "triggers",
    titulo: "Trigger de auditoría",
    descripcion:
      "Registra automáticamente cambios realizados en una tabla.",
    sql: `CREATE TEMP TABLE lab_equipos (
    id_equipo INTEGER
        GENERATED ALWAYS AS IDENTITY
        PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    puntos INTEGER NOT NULL DEFAULT 0
);

CREATE TEMP TABLE lab_auditoria (
    id_auditoria INTEGER
        GENERATED ALWAYS AS IDENTITY,
    operacion VARCHAR(20) NOT NULL,
    id_equipo INTEGER,
    puntos_anteriores INTEGER,
    puntos_nuevos INTEGER,
    fecha_evento TIMESTAMP NOT NULL
        DEFAULT CURRENT_TIMESTAMP
);

CREATE OR REPLACE FUNCTION
pg_temp.auditar_equipo()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO lab_auditoria (
        operacion,
        id_equipo,
        puntos_anteriores,
        puntos_nuevos
    )
    VALUES (
        TG_OP,
        NEW.id_equipo,
        OLD.puntos,
        NEW.puntos
    );

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_lab_auditar_equipo
AFTER UPDATE
ON lab_equipos
FOR EACH ROW
EXECUTE FUNCTION
pg_temp.auditar_equipo();

INSERT INTO lab_equipos (
    nombre,
    puntos
)
VALUES (
    'Cóndores',
    6
);

UPDATE lab_equipos
SET puntos = 9
WHERE nombre = 'Cóndores';

SELECT *
FROM lab_equipos;

SELECT *
FROM lab_auditoria;`,
  },
  {
    id: "cursor",
    categoria: "cursores",
    titulo: "Cursor explícito",
    descripcion:
      "Declara un cursor y recupera registros mediante FETCH.",
    sql: `CREATE TEMP TABLE lab_equipos (
    id_equipo INTEGER PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    puntos INTEGER NOT NULL
);

INSERT INTO lab_equipos
VALUES
    (1, 'Cóndores', 12),
    (2, 'Andes United', 9),
    (3, 'Tigres', 6),
    (4, 'Leones', 3);

DECLARE cursor_clasificacion
CURSOR FOR
SELECT
    id_equipo,
    nombre,
    puntos
FROM lab_equipos
ORDER BY puntos DESC;

FETCH NEXT
FROM cursor_clasificacion;

FETCH ALL
FROM cursor_clasificacion;

CLOSE cursor_clasificacion;`,
  },
  {
    id: "group-by",
    categoria: "avanzado",
    titulo: "GROUP BY y funciones agregadas",
    descripcion:
      "Agrupa resultados y calcula cantidades, sumas y promedios.",
    sql: `WITH resultados (
    torneo,
    equipo,
    puntos
) AS (
    VALUES
        ('Apertura', 'Cóndores', 10),
        ('Apertura', 'Tigres', 7),
        ('Clausura', 'Cóndores', 8),
        ('Clausura', 'Tigres', 9),
        ('Clausura', 'Andes United', 6)
)
SELECT
    torneo,
    COUNT(*) AS equipos,
    SUM(puntos) AS total_puntos,
    ROUND(
        AVG(puntos),
        2
    ) AS promedio_puntos,
    MAX(puntos) AS mayor_puntaje
FROM resultados
GROUP BY torneo
ORDER BY torneo;`,
  },
  {
    id: "window-functions",
    categoria: "avanzado",
    titulo: "Funciones de ventana",
    descripcion:
      "Utiliza ROW_NUMBER, RANK y SUM sin perder las filas originales.",
    sql: `WITH clasificacion (
    equipo,
    puntos
) AS (
    VALUES
        ('Cóndores', 15),
        ('Andes United', 12),
        ('Tigres', 12),
        ('Leones', 8)
)
SELECT
    equipo,
    puntos,
    ROW_NUMBER() OVER (
        ORDER BY puntos DESC
    ) AS numero_fila,
    RANK() OVER (
        ORDER BY puntos DESC
    ) AS posicion,
    SUM(puntos) OVER () AS total_puntos,
    ROUND(
        AVG(puntos) OVER (),
        2
    ) AS promedio_general
FROM clasificacion
ORDER BY
    puntos DESC,
    equipo;`,
  },
  {
    id: "cte-recursivo",
    categoria: "avanzado",
    titulo: "CTE recursivo",
    descripcion:
      "Genera una serie de jornadas mediante una consulta recursiva.",
    sql: `WITH RECURSIVE jornadas AS (
    SELECT
        1 AS numero_jornada

    UNION ALL

    SELECT
        numero_jornada + 1
    FROM jornadas
    WHERE numero_jornada < 5
)
SELECT
    numero_jornada,
    'Jornada ' ||
    numero_jornada AS nombre
FROM jornadas;`,
  },
];

export const DEFAULT_SQL =
  SQL_EXAMPLES[0].sql;