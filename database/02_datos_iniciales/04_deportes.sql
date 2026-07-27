BEGIN;

INSERT INTO competencia.deporte (
    codigo,
    nombre,
    descripcion,
    cantidad_minima_jugadores,
    cantidad_maxima_jugadores,
    cantidad_titulares,
    tipo_marcador,
    permite_empate,
    puntos_victoria,
    puntos_empate,
    puntos_derrota,
    id_estado_deporte
)
SELECT
    datos.codigo,
    datos.nombre,
    datos.descripcion,
    datos.cantidad_minima,
    datos.cantidad_maxima,
    datos.cantidad_titulares,
    datos.tipo_marcador,
    datos.permite_empate,
    datos.puntos_victoria,
    datos.puntos_empate,
    datos.puntos_derrota,
    estado.id_estado_deporte
FROM (
    VALUES
        (
            'FUTBOL',
            'Futbol',
            'Competencia de futbol por equipos',
            11::SMALLINT,
            25::SMALLINT,
            11::SMALLINT,
            'GOL',
            TRUE,
            3::SMALLINT,
            1::SMALLINT,
            0::SMALLINT
        ),
        (
            'FUTSAL',
            'Futsal',
            'Competencia de futsal por equipos',
            5::SMALLINT,
            14::SMALLINT,
            5::SMALLINT,
            'GOL',
            TRUE,
            3::SMALLINT,
            1::SMALLINT,
            0::SMALLINT
        ),
        (
            'BALONCESTO',
            'Baloncesto',
            'Competencia de baloncesto por equipos',
            5::SMALLINT,
            15::SMALLINT,
            5::SMALLINT,
            'PUNTO',
            FALSE,
            2::SMALLINT,
            0::SMALLINT,
            1::SMALLINT
        ),
        (
            'VOLEIBOL',
            'Voleibol',
            'Competencia de voleibol por equipos',
            6::SMALLINT,
            14::SMALLINT,
            6::SMALLINT,
            'SET',
            FALSE,
            3::SMALLINT,
            0::SMALLINT,
            0::SMALLINT
        ),
        (
            'TENIS_EQUIPOS',
            'Tenis por equipos',
            'Competencia de tenis organizada mediante equipos',
            2::SMALLINT,
            10::SMALLINT,
            2::SMALLINT,
            'PARTIDO',
            FALSE,
            1::SMALLINT,
            0::SMALLINT,
            0::SMALLINT
        )
) AS datos (
    codigo,
    nombre,
    descripcion,
    cantidad_minima,
    cantidad_maxima,
    cantidad_titulares,
    tipo_marcador,
    permite_empate,
    puntos_victoria,
    puntos_empate,
    puntos_derrota
)
INNER JOIN catalogo.estado_deporte estado
    ON estado.codigo = 'ACTIVO'
ON CONFLICT (codigo) DO NOTHING;

COMMIT;