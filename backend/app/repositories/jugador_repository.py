from datetime import date
from typing import Any

from psycopg import AsyncConnection

from app.schemas.jugador import (
    JugadorCrear,
    MembresiaJugadorCrear,
)


FilaJugador = dict[str, Any]
FilaMembresia = dict[str, Any]


class RepositorioJugadores:
    _columnas_jugador = """
        SELECT
            jugador.id_usuario AS id_jugador,

            usuario.numero_documento,
            usuario.nombres,
            usuario.apellido_paterno,
            usuario.apellido_materno,

            jugador.alias_deportivo,
            jugador.observaciones,

            estado_perfil.codigo AS estado_codigo,

            membresia.id_jugador_equipo
                AS id_membresia_actual,

            equipo.id_equipo
                AS id_equipo_actual,

            equipo.nombre
                AS equipo_actual,

            equipo.sigla
                AS sigla_equipo_actual,

            membresia.numero_camiseta
                AS numero_camiseta_actual,

            membresia.posicion
                AS posicion_actual,

            membresia.es_delegado
                AS es_delegado_actual

        FROM participantes.jugador jugador

        INNER JOIN seguridad.usuario usuario
            ON usuario.id_usuario =
               jugador.id_usuario

        INNER JOIN catalogo.estado_perfil_deportivo
            estado_perfil
            ON estado_perfil.id_estado_perfil =
               jugador.id_estado_perfil

        LEFT JOIN participantes.jugador_equipo membresia
            ON membresia.id_jugador =
               jugador.id_usuario
           AND membresia.fecha_fin IS NULL

        LEFT JOIN participantes.equipo equipo
            ON equipo.id_equipo =
               membresia.id_equipo
    """

    _columnas_membresia = """
        SELECT
            membresia.id_jugador_equipo,
            membresia.id_jugador,

            equipo.id_equipo,
            equipo.nombre AS equipo,
            equipo.sigla AS sigla_equipo,

            membresia.fecha_inicio,
            membresia.fecha_fin,

            membresia.numero_camiseta,
            membresia.posicion,
            membresia.es_delegado,

            estado.codigo AS estado_codigo,

            membresia.registrado_por,
            membresia.observaciones

        FROM participantes.jugador_equipo membresia

        INNER JOIN participantes.equipo equipo
            ON equipo.id_equipo =
               membresia.id_equipo

        INNER JOIN catalogo.estado_membresia estado
            ON estado.id_estado_membresia =
               membresia.id_estado_membresia
    """

    async def listar(
        self,
        conexion: AsyncConnection,
        estado_codigo: str | None,
        id_equipo: int | None,
        busqueda: str | None,
        limite: int,
        desplazamiento: int,
    ) -> tuple[list[FilaJugador], int]:
        patron_busqueda = (
            f"%{busqueda}%"
            if busqueda is not None
            else None
        )

        parametros_filtro = (
            estado_codigo,
            estado_codigo,
            id_equipo,
            id_equipo,
            patron_busqueda,
            patron_busqueda,
            patron_busqueda,
            patron_busqueda,
            patron_busqueda,
        )

        cursor_total = await conexion.execute(
            """
            SELECT COUNT(*) AS total

            FROM participantes.jugador jugador

            INNER JOIN seguridad.usuario usuario
                ON usuario.id_usuario =
                   jugador.id_usuario

            INNER JOIN catalogo.estado_perfil_deportivo
                estado_perfil
                ON estado_perfil.id_estado_perfil =
                   jugador.id_estado_perfil

            LEFT JOIN participantes.jugador_equipo membresia
                ON membresia.id_jugador =
                   jugador.id_usuario
               AND membresia.fecha_fin IS NULL

            WHERE (
                %s::text IS NULL
                OR estado_perfil.codigo = %s
            )

            AND (
                %s::bigint IS NULL
                OR membresia.id_equipo = %s
            )

            AND (
                %s::text IS NULL
                OR usuario.numero_documento ILIKE %s
                OR usuario.nombres ILIKE %s
                OR usuario.apellido_paterno ILIKE %s
                OR COALESCE(
                    jugador.alias_deportivo,
                    ''
                ) ILIKE %s
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
            self._columnas_jugador
            + """
            WHERE (
                %s::text IS NULL
                OR estado_perfil.codigo = %s
            )

            AND (
                %s::bigint IS NULL
                OR membresia.id_equipo = %s
            )

            AND (
                %s::text IS NULL
                OR usuario.numero_documento ILIKE %s
                OR usuario.nombres ILIKE %s
                OR usuario.apellido_paterno ILIKE %s
                OR COALESCE(
                    jugador.alias_deportivo,
                    ''
                ) ILIKE %s
            )

            ORDER BY
                usuario.apellido_paterno,
                usuario.nombres,
                jugador.id_usuario

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
        id_jugador: int,
    ) -> FilaJugador | None:
        consulta = (
            self._columnas_jugador
            + """
            WHERE jugador.id_usuario = %s
            """
        )

        cursor = await conexion.execute(
            consulta,
            (id_jugador,),
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
        datos: JugadorCrear,
    ) -> FilaJugador | None:
        cursor = await conexion.execute(
            """
            WITH estado_seleccionado AS (
                SELECT id_estado_perfil
                FROM catalogo.estado_perfil_deportivo
                WHERE codigo = %s
                  AND activo = TRUE
            ),
            jugador_insertado AS (
                INSERT INTO participantes.jugador (
                    id_usuario,
                    alias_deportivo,
                    id_estado_perfil,
                    observaciones
                )
                SELECT
                    %s,
                    %s,
                    estado_seleccionado.id_estado_perfil,
                    %s
                FROM estado_seleccionado
                RETURNING *
            )
            SELECT
                jugador.id_usuario AS id_jugador,

                usuario.numero_documento,
                usuario.nombres,
                usuario.apellido_paterno,
                usuario.apellido_materno,

                jugador.alias_deportivo,
                jugador.observaciones,

                estado_perfil.codigo AS estado_codigo,

                NULL::BIGINT AS id_membresia_actual,
                NULL::BIGINT AS id_equipo_actual,
                NULL::VARCHAR AS equipo_actual,
                NULL::VARCHAR AS sigla_equipo_actual,
                NULL::SMALLINT AS numero_camiseta_actual,
                NULL::VARCHAR AS posicion_actual,
                NULL::BOOLEAN AS es_delegado_actual

            FROM jugador_insertado jugador

            INNER JOIN seguridad.usuario usuario
                ON usuario.id_usuario =
                   jugador.id_usuario

            INNER JOIN catalogo.estado_perfil_deportivo
                estado_perfil
                ON estado_perfil.id_estado_perfil =
                   jugador.id_estado_perfil
            """,
            (
                datos.estado_codigo,
                datos.id_usuario,
                datos.alias_deportivo,
                datos.observaciones,
            ),
        )

        return await cursor.fetchone()

    async def asignar_rol_jugador(
        self,
        conexion: AsyncConnection,
        id_jugador: int,
        asignado_por: int,
    ) -> None:
        await conexion.execute(
            """
            INSERT INTO seguridad.usuario_rol (
                id_usuario,
                id_rol,
                asignado_por
            )
            SELECT
                %s,
                rol.id_rol,
                %s

            FROM seguridad.rol rol

            WHERE rol.codigo = 'JUGADOR'

              AND NOT EXISTS (
                  SELECT 1
                  FROM seguridad.usuario_rol usuario_rol
                  WHERE usuario_rol.id_usuario = %s
                    AND usuario_rol.id_rol =
                        rol.id_rol
                    AND usuario_rol.activo = TRUE
                    AND usuario_rol.fecha_fin IS NULL
              )
            """,
            (
                id_jugador,
                asignado_por,
                id_jugador,
            ),
        )

    async def actualizar(
        self,
        conexion: AsyncConnection,
        datos: JugadorCrear,
    ) -> FilaJugador | None:
        cursor = await conexion.execute(
            """
            WITH estado_seleccionado AS (
                SELECT id_estado_perfil
                FROM catalogo.estado_perfil_deportivo
                WHERE codigo = %s
                  AND activo = TRUE
            ),
            jugador_actualizado AS (
                UPDATE participantes.jugador jugador
                SET
                    alias_deportivo = %s,
                    observaciones = %s,
                    id_estado_perfil =
                        estado_seleccionado.id_estado_perfil
                FROM estado_seleccionado
                WHERE jugador.id_usuario = %s
                RETURNING jugador.*
            )
            SELECT
                jugador.id_usuario AS id_jugador,

                usuario.numero_documento,
                usuario.nombres,
                usuario.apellido_paterno,
                usuario.apellido_materno,

                jugador.alias_deportivo,
                jugador.observaciones,

                estado_perfil.codigo AS estado_codigo,

                membresia.id_jugador_equipo
                    AS id_membresia_actual,

                equipo.id_equipo
                    AS id_equipo_actual,

                equipo.nombre
                    AS equipo_actual,

                equipo.sigla
                    AS sigla_equipo_actual,

                membresia.numero_camiseta
                    AS numero_camiseta_actual,

                membresia.posicion
                    AS posicion_actual,

                membresia.es_delegado
                    AS es_delegado_actual

            FROM jugador_actualizado jugador

            INNER JOIN seguridad.usuario usuario
                ON usuario.id_usuario =
                   jugador.id_usuario

            INNER JOIN catalogo.estado_perfil_deportivo
                estado_perfil
                ON estado_perfil.id_estado_perfil =
                   jugador.id_estado_perfil

            LEFT JOIN participantes.jugador_equipo membresia
                ON membresia.id_jugador =
                   jugador.id_usuario
               AND membresia.fecha_fin IS NULL

            LEFT JOIN participantes.equipo equipo
                ON equipo.id_equipo =
                   membresia.id_equipo
            """,
            (
                datos.estado_codigo,
                datos.alias_deportivo,
                datos.observaciones,
                datos.id_usuario,
            ),
        )

        return await cursor.fetchone()

    async def desactivar(
        self,
        conexion: AsyncConnection,
        id_jugador: int,
    ) -> FilaJugador | None:
        cursor = await conexion.execute(
            """
            WITH estado_inactivo AS (
                SELECT id_estado_perfil
                FROM catalogo.estado_perfil_deportivo
                WHERE codigo = 'INACTIVO'
                  AND activo = TRUE
            ),
            jugador_actualizado AS (
                UPDATE participantes.jugador jugador
                SET
                    id_estado_perfil =
                        estado_inactivo.id_estado_perfil
                FROM estado_inactivo
                WHERE jugador.id_usuario = %s
                RETURNING jugador.*
            )
            SELECT
                jugador.id_usuario AS id_jugador,

                usuario.numero_documento,
                usuario.nombres,
                usuario.apellido_paterno,
                usuario.apellido_materno,

                jugador.alias_deportivo,
                jugador.observaciones,

                estado_perfil.codigo AS estado_codigo,

                membresia.id_jugador_equipo
                    AS id_membresia_actual,

                equipo.id_equipo
                    AS id_equipo_actual,

                equipo.nombre
                    AS equipo_actual,

                equipo.sigla
                    AS sigla_equipo_actual,

                membresia.numero_camiseta
                    AS numero_camiseta_actual,

                membresia.posicion
                    AS posicion_actual,

                membresia.es_delegado
                    AS es_delegado_actual

            FROM jugador_actualizado jugador

            INNER JOIN seguridad.usuario usuario
                ON usuario.id_usuario =
                   jugador.id_usuario

            INNER JOIN catalogo.estado_perfil_deportivo
                estado_perfil
                ON estado_perfil.id_estado_perfil =
                   jugador.id_estado_perfil

            LEFT JOIN participantes.jugador_equipo membresia
                ON membresia.id_jugador =
                   jugador.id_usuario
               AND membresia.fecha_fin IS NULL

            LEFT JOIN participantes.equipo equipo
                ON equipo.id_equipo =
                   membresia.id_equipo
            """,
            (id_jugador,),
        )

        return await cursor.fetchone()

    async def listar_membresias(
        self,
        conexion: AsyncConnection,
        id_jugador: int,
    ) -> list[FilaMembresia]:
        consulta = (
            self._columnas_membresia
            + """
            WHERE membresia.id_jugador = %s

            ORDER BY
                membresia.fecha_inicio DESC,
                membresia.id_jugador_equipo DESC
            """
        )

        cursor = await conexion.execute(
            consulta,
            (id_jugador,),
        )

        filas = await cursor.fetchall()

        return list(filas)

    async def obtener_membresia_activa(
        self,
        conexion: AsyncConnection,
        id_jugador: int,
    ) -> FilaMembresia | None:
        consulta = (
            self._columnas_membresia
            + """
            WHERE membresia.id_jugador = %s
              AND membresia.fecha_fin IS NULL
            """
        )

        cursor = await conexion.execute(
            consulta,
            (id_jugador,),
        )

        return await cursor.fetchone()

    async def obtener_membresia_por_id(
        self,
        conexion: AsyncConnection,
        id_jugador: int,
        id_membresia: int,
    ) -> FilaMembresia | None:
        consulta = (
            self._columnas_membresia
            + """
            WHERE membresia.id_jugador = %s
              AND membresia.id_jugador_equipo = %s
            """
        )

        cursor = await conexion.execute(
            consulta,
            (
                id_jugador,
                id_membresia,
            ),
        )

        return await cursor.fetchone()

    async def existe_equipo_activo(
        self,
        conexion: AsyncConnection,
        id_equipo: int,
    ) -> bool:
        cursor = await conexion.execute(
            """
            SELECT EXISTS (
                SELECT 1
                FROM participantes.equipo equipo

                INNER JOIN catalogo.estado_equipo estado
                    ON estado.id_estado_equipo =
                       equipo.id_estado_equipo

                WHERE equipo.id_equipo = %s
                  AND estado.codigo = 'ACTIVO'
            ) AS existe
            """,
            (id_equipo,),
        )

        fila = await cursor.fetchone()

        return bool(
            fila["existe"]
            if fila is not None
            else False
        )

    async def crear_membresia(
        self,
        conexion: AsyncConnection,
        id_jugador: int,
        datos: MembresiaJugadorCrear,
        registrado_por: int,
    ) -> FilaMembresia | None:
        cursor = await conexion.execute(
            """
            WITH estado_activo AS (
                SELECT id_estado_membresia
                FROM catalogo.estado_membresia
                WHERE codigo = 'ACTIVA'
                  AND activo = TRUE
            ),
            membresia_insertada AS (
                INSERT INTO participantes.jugador_equipo (
                    id_jugador,
                    id_equipo,
                    fecha_inicio,
                    numero_camiseta,
                    posicion,
                    es_delegado,
                    id_estado_membresia,
                    registrado_por,
                    observaciones
                )
                SELECT
                    %s,
                    %s,
                    %s,
                    %s,
                    %s,
                    %s,
                    estado_activo.id_estado_membresia,
                    %s,
                    %s
                FROM estado_activo
                RETURNING *
            )
            SELECT
                membresia.id_jugador_equipo,
                membresia.id_jugador,

                equipo.id_equipo,
                equipo.nombre AS equipo,
                equipo.sigla AS sigla_equipo,

                membresia.fecha_inicio,
                membresia.fecha_fin,

                membresia.numero_camiseta,
                membresia.posicion,
                membresia.es_delegado,

                estado.codigo AS estado_codigo,

                membresia.registrado_por,
                membresia.observaciones

            FROM membresia_insertada membresia

            INNER JOIN participantes.equipo equipo
                ON equipo.id_equipo =
                   membresia.id_equipo

            INNER JOIN catalogo.estado_membresia estado
                ON estado.id_estado_membresia =
                   membresia.id_estado_membresia
            """,
            (
                id_jugador,
                datos.id_equipo,
                datos.fecha_inicio,
                datos.numero_camiseta,
                datos.posicion,
                datos.es_delegado,
                registrado_por,
                datos.observaciones,
            ),
        )

        return await cursor.fetchone()

    async def finalizar_membresia(
        self,
        conexion: AsyncConnection,
        id_jugador: int,
        id_membresia: int,
        fecha_fin: date,
        observaciones: str | None,
    ) -> FilaMembresia | None:
        cursor = await conexion.execute(
            """
            WITH estado_finalizado AS (
                SELECT id_estado_membresia
                FROM catalogo.estado_membresia
                WHERE codigo = 'FINALIZADA'
                  AND activo = TRUE
            ),
            membresia_actualizada AS (
                UPDATE participantes.jugador_equipo membresia
                SET
                    fecha_fin = %s,
                    id_estado_membresia =
                        estado_finalizado.id_estado_membresia,

                    observaciones = COALESCE(
                        %s,
                        membresia.observaciones
                    )

                FROM estado_finalizado

                WHERE membresia.id_jugador_equipo = %s
                  AND membresia.id_jugador = %s
                  AND membresia.fecha_fin IS NULL

                RETURNING membresia.*
            )
            SELECT
                membresia.id_jugador_equipo,
                membresia.id_jugador,

                equipo.id_equipo,
                equipo.nombre AS equipo,
                equipo.sigla AS sigla_equipo,

                membresia.fecha_inicio,
                membresia.fecha_fin,

                membresia.numero_camiseta,
                membresia.posicion,
                membresia.es_delegado,

                estado.codigo AS estado_codigo,

                membresia.registrado_por,
                membresia.observaciones

            FROM membresia_actualizada membresia

            INNER JOIN participantes.equipo equipo
                ON equipo.id_equipo =
                   membresia.id_equipo

            INNER JOIN catalogo.estado_membresia estado
                ON estado.id_estado_membresia =
                   membresia.id_estado_membresia
            """,
            (
                fecha_fin,
                observaciones,
                id_membresia,
                id_jugador,
            ),
        )

        return await cursor.fetchone()