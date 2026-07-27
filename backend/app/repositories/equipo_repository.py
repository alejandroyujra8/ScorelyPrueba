from typing import Any

from psycopg import AsyncConnection

from app.schemas.equipo import EquipoCrear


FilaEquipo = dict[str, Any]


class RepositorioEquipos:
    _columnas_consulta = """
        SELECT
            equipo.id_equipo,
            equipo.nombre,
            equipo.sigla,
            equipo.fecha_fundacion,
            equipo.descripcion,
            estado.codigo AS estado_codigo,
            equipo.creado_por
        FROM participantes.equipo equipo
        INNER JOIN catalogo.estado_equipo estado
            ON estado.id_estado_equipo =
               equipo.id_estado_equipo
    """

    async def listar(
        self,
        conexion: AsyncConnection,
        estado_codigo: str | None,
        busqueda: str | None,
        limite: int,
        desplazamiento: int,
    ) -> tuple[list[FilaEquipo], int]:
        patron_busqueda = (
            f"%{busqueda}%"
            if busqueda is not None
            else None
        )

        parametros_filtro = (
            estado_codigo,
            estado_codigo,
            patron_busqueda,
            patron_busqueda,
            patron_busqueda,
        )

        cursor_total = await conexion.execute(
            """
            SELECT COUNT(*) AS total
            FROM participantes.equipo equipo
            INNER JOIN catalogo.estado_equipo estado
                ON estado.id_estado_equipo =
                   equipo.id_estado_equipo
            WHERE (
                %s::text IS NULL
                OR estado.codigo = %s
            )
            AND (
                %s::text IS NULL
                OR equipo.nombre ILIKE %s
                OR equipo.sigla ILIKE %s
            )
            """,
            parametros_filtro,
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
            AND (
                %s::text IS NULL
                OR equipo.nombre ILIKE %s
                OR equipo.sigla ILIKE %s
            )
            ORDER BY
                equipo.nombre,
                equipo.id_equipo
            LIMIT %s
            OFFSET %s
            """
        )

        cursor = await conexion.execute(
            consulta,
            parametros_filtro
            + (
                limite,
                desplazamiento,
            ),
        )

        filas = await cursor.fetchall()

        return list(filas), total

    async def obtener_por_id(
        self,
        conexion: AsyncConnection,
        id_equipo: int,
    ) -> FilaEquipo | None:
        consulta = (
            self._columnas_consulta
            + """
            WHERE equipo.id_equipo = %s
            """
        )

        cursor = await conexion.execute(
            consulta,
            (id_equipo,),
        )

        return await cursor.fetchone()

    async def existe_usuario_activo(
        self,
        conexion: AsyncConnection,
        id_usuario: int,
    ) -> bool:
        cursor = await conexion.execute(
            """
            SELECT EXISTS (
                SELECT 1
                FROM seguridad.usuario usuario
                INNER JOIN catalogo.estado_usuario estado
                    ON estado.id_estado_usuario =
                       usuario.id_estado_usuario
                WHERE usuario.id_usuario = %s
                  AND estado.codigo = 'ACTIVO'
            ) AS existe
            """,
            (id_usuario,),
        )

        fila = await cursor.fetchone()

        return bool(
            fila["existe"]
            if fila is not None
            else False
        )

    async def crear(
        self,
        conexion: AsyncConnection,
        datos: EquipoCrear,
        creado_por: int,
    ) -> FilaEquipo | None:
        cursor = await conexion.execute(
            """
            WITH estado_seleccionado AS (
                SELECT
                    id_estado_equipo
                FROM catalogo.estado_equipo
                WHERE codigo = %s
                  AND activo = TRUE
            ),
            equipo_insertado AS (
                INSERT INTO participantes.equipo (
                    nombre,
                    sigla,
                    fecha_fundacion,
                    descripcion,
                    id_estado_equipo,
                    creado_por
                )
                SELECT
                    %s,
                    %s,
                    %s,
                    %s,
                    estado_seleccionado.id_estado_equipo,
                    %s
                FROM estado_seleccionado
                RETURNING *
            )
            SELECT
                equipo.id_equipo,
                equipo.nombre,
                equipo.sigla,
                equipo.fecha_fundacion,
                equipo.descripcion,
                estado.codigo AS estado_codigo,
                equipo.creado_por
            FROM equipo_insertado equipo
            INNER JOIN catalogo.estado_equipo estado
                ON estado.id_estado_equipo =
                   equipo.id_estado_equipo
            """,
            (
                datos.estado_codigo,
                datos.nombre,
                datos.sigla,
                datos.fecha_fundacion,
                datos.descripcion,
                creado_por,
            ),
        )

        return await cursor.fetchone()

    async def actualizar(
        self,
        conexion: AsyncConnection,
        id_equipo: int,
        datos: EquipoCrear,
    ) -> FilaEquipo | None:
        cursor = await conexion.execute(
            """
            WITH estado_seleccionado AS (
                SELECT
                    id_estado_equipo
                FROM catalogo.estado_equipo
                WHERE codigo = %s
                  AND activo = TRUE
            ),
            equipo_actualizado AS (
                UPDATE participantes.equipo equipo
                SET
                    nombre = %s,
                    sigla = %s,
                    fecha_fundacion = %s,
                    descripcion = %s,
                    id_estado_equipo =
                        estado_seleccionado.id_estado_equipo
                FROM estado_seleccionado
                WHERE equipo.id_equipo = %s
                RETURNING equipo.*
            )
            SELECT
                equipo.id_equipo,
                equipo.nombre,
                equipo.sigla,
                equipo.fecha_fundacion,
                equipo.descripcion,
                estado.codigo AS estado_codigo,
                equipo.creado_por
            FROM equipo_actualizado equipo
            INNER JOIN catalogo.estado_equipo estado
                ON estado.id_estado_equipo =
                   equipo.id_estado_equipo
            """,
            (
                datos.estado_codigo,
                datos.nombre,
                datos.sigla,
                datos.fecha_fundacion,
                datos.descripcion,
                id_equipo,
            ),
        )

        return await cursor.fetchone()

    async def desactivar(
        self,
        conexion: AsyncConnection,
        id_equipo: int,
    ) -> FilaEquipo | None:
        cursor = await conexion.execute(
            """
            WITH estado_inactivo AS (
                SELECT
                    id_estado_equipo
                FROM catalogo.estado_equipo
                WHERE codigo = 'INACTIVO'
                  AND activo = TRUE
            ),
            equipo_actualizado AS (
                UPDATE participantes.equipo equipo
                SET
                    id_estado_equipo =
                        estado_inactivo.id_estado_equipo
                FROM estado_inactivo
                WHERE equipo.id_equipo = %s
                RETURNING equipo.*
            )
            SELECT
                equipo.id_equipo,
                equipo.nombre,
                equipo.sigla,
                equipo.fecha_fundacion,
                equipo.descripcion,
                estado.codigo AS estado_codigo,
                equipo.creado_por
            FROM equipo_actualizado equipo
            INNER JOIN catalogo.estado_equipo estado
                ON estado.id_estado_equipo =
                   equipo.id_estado_equipo
            """,
            (id_equipo,),
        )

        return await cursor.fetchone()