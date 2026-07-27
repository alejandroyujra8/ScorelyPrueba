from typing import Any

from psycopg import AsyncConnection

from app.schemas.deporte import DeporteCrear


FilaDeporte = dict[str, Any]


class RepositorioDeportes:
    _columnas_consulta = """
        SELECT
            deporte.id_deporte,
            deporte.codigo,
            deporte.nombre,
            deporte.descripcion,
            deporte.cantidad_minima_jugadores,
            deporte.cantidad_maxima_jugadores,
            deporte.cantidad_titulares,
            deporte.tipo_marcador,
            deporte.permite_empate,
            deporte.puntos_victoria,
            deporte.puntos_empate,
            deporte.puntos_derrota,
            estado.codigo AS estado_codigo,
            deporte.fecha_registro
        FROM competencia.deporte deporte
        INNER JOIN catalogo.estado_deporte estado
            ON estado.id_estado_deporte =
               deporte.id_estado_deporte
    """

    async def listar(
        self,
        conexion: AsyncConnection,
        estado_codigo: str | None,
        limite: int,
        desplazamiento: int,
    ) -> tuple[list[FilaDeporte], int]:
        cursor_total = await conexion.execute(
            """
            SELECT COUNT(*) AS total
            FROM competencia.deporte deporte
            INNER JOIN catalogo.estado_deporte estado
                ON estado.id_estado_deporte =
                   deporte.id_estado_deporte
            WHERE (
                %s::text IS NULL
                OR estado.codigo = %s
            )
            """,
            (
                estado_codigo,
                estado_codigo,
            ),
        )

        fila_total = await cursor_total.fetchone()

        total = (
            int(fila_total["total"])
            if fila_total is not None
            else 0
        )

        consulta = (
            self._columnas_consulta
            + """
            WHERE (
                %s::text IS NULL
                OR estado.codigo = %s
            )
            ORDER BY deporte.nombre
            LIMIT %s
            OFFSET %s
            """
        )

        cursor = await conexion.execute(
            consulta,
            (
                estado_codigo,
                estado_codigo,
                limite,
                desplazamiento,
            ),
        )

        filas = await cursor.fetchall()

        return list(filas), total
    async def obtener_por_id(
        self,
        conexion: AsyncConnection,
        id_deporte: int,
    ) -> FilaDeporte | None:
        consulta = (
            self._columnas_consulta
            + """
            WHERE deporte.id_deporte = %s
            """
        )

        cursor = await conexion.execute(
            consulta,
            (id_deporte,),
        )

        return await cursor.fetchone()

    async def crear(
        self,
        conexion: AsyncConnection,
        datos: DeporteCrear,
    ) -> FilaDeporte | None:
        cursor = await conexion.execute(
            """
            WITH estado_seleccionado AS (
                SELECT
                    id_estado_deporte
                FROM catalogo.estado_deporte
                WHERE codigo = %s
                  AND activo = TRUE
            ),
            deporte_insertado AS (
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
                    %s,
                    %s,
                    %s,
                    %s,
                    %s,
                    %s,
                    %s,
                    %s,
                    %s,
                    %s,
                    %s,
                    estado_seleccionado.id_estado_deporte
                FROM estado_seleccionado
                RETURNING *
            )
            SELECT
                deporte.id_deporte,
                deporte.codigo,
                deporte.nombre,
                deporte.descripcion,
                deporte.cantidad_minima_jugadores,
                deporte.cantidad_maxima_jugadores,
                deporte.cantidad_titulares,
                deporte.tipo_marcador,
                deporte.permite_empate,
                deporte.puntos_victoria,
                deporte.puntos_empate,
                deporte.puntos_derrota,
                estado.codigo AS estado_codigo,
                deporte.fecha_registro
            FROM deporte_insertado deporte
            INNER JOIN catalogo.estado_deporte estado
                ON estado.id_estado_deporte =
                   deporte.id_estado_deporte
            """,
            (
                datos.estado_codigo,
                datos.codigo,
                datos.nombre,
                datos.descripcion,
                datos.cantidad_minima_jugadores,
                datos.cantidad_maxima_jugadores,
                datos.cantidad_titulares,
                datos.tipo_marcador,
                datos.permite_empate,
                datos.puntos_victoria,
                datos.puntos_empate,
                datos.puntos_derrota,
            ),
        )

        return await cursor.fetchone()

    async def actualizar(
        self,
        conexion: AsyncConnection,
        id_deporte: int,
        datos: DeporteCrear,
    ) -> FilaDeporte | None:
        cursor = await conexion.execute(
            """
            WITH estado_seleccionado AS (
                SELECT
                    id_estado_deporte
                FROM catalogo.estado_deporte
                WHERE codigo = %s
                  AND activo = TRUE
            ),
            deporte_actualizado AS (
                UPDATE competencia.deporte deporte
                SET
                    codigo = %s,
                    nombre = %s,
                    descripcion = %s,
                    cantidad_minima_jugadores = %s,
                    cantidad_maxima_jugadores = %s,
                    cantidad_titulares = %s,
                    tipo_marcador = %s,
                    permite_empate = %s,
                    puntos_victoria = %s,
                    puntos_empate = %s,
                    puntos_derrota = %s,
                    id_estado_deporte =
                        estado_seleccionado.id_estado_deporte
                FROM estado_seleccionado
                WHERE deporte.id_deporte = %s
                RETURNING deporte.*
            )
            SELECT
                deporte.id_deporte,
                deporte.codigo,
                deporte.nombre,
                deporte.descripcion,
                deporte.cantidad_minima_jugadores,
                deporte.cantidad_maxima_jugadores,
                deporte.cantidad_titulares,
                deporte.tipo_marcador,
                deporte.permite_empate,
                deporte.puntos_victoria,
                deporte.puntos_empate,
                deporte.puntos_derrota,
                estado.codigo AS estado_codigo,
                deporte.fecha_registro
            FROM deporte_actualizado deporte
            INNER JOIN catalogo.estado_deporte estado
                ON estado.id_estado_deporte =
                   deporte.id_estado_deporte
            """,
            (
                datos.estado_codigo,
                datos.codigo,
                datos.nombre,
                datos.descripcion,
                datos.cantidad_minima_jugadores,
                datos.cantidad_maxima_jugadores,
                datos.cantidad_titulares,
                datos.tipo_marcador,
                datos.permite_empate,
                datos.puntos_victoria,
                datos.puntos_empate,
                datos.puntos_derrota,
                id_deporte,
            ),
        )

        return await cursor.fetchone()

    async def desactivar(
        self,
        conexion: AsyncConnection,
        id_deporte: int,
    ) -> FilaDeporte | None:
        cursor = await conexion.execute(
            """
            WITH estado_inactivo AS (
                SELECT
                    id_estado_deporte
                FROM catalogo.estado_deporte
                WHERE codigo = 'INACTIVO'
                  AND activo = TRUE
            ),
            deporte_actualizado AS (
                UPDATE competencia.deporte deporte
                SET
                    id_estado_deporte =
                        estado_inactivo.id_estado_deporte
                FROM estado_inactivo
                WHERE deporte.id_deporte = %s
                RETURNING deporte.*
            )
            SELECT
                deporte.id_deporte,
                deporte.codigo,
                deporte.nombre,
                deporte.descripcion,
                deporte.cantidad_minima_jugadores,
                deporte.cantidad_maxima_jugadores,
                deporte.cantidad_titulares,
                deporte.tipo_marcador,
                deporte.permite_empate,
                deporte.puntos_victoria,
                deporte.puntos_empate,
                deporte.puntos_derrota,
                estado.codigo AS estado_codigo,
                deporte.fecha_registro
            FROM deporte_actualizado deporte
            INNER JOIN catalogo.estado_deporte estado
                ON estado.id_estado_deporte =
                   deporte.id_estado_deporte
            """,
            (id_deporte,),
        )

        return await cursor.fetchone()