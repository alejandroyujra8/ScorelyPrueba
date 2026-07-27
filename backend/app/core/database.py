from collections.abc import AsyncGenerator

from fastapi import Request
from psycopg import AsyncConnection
from psycopg.rows import dict_row
from psycopg_pool import AsyncConnectionPool

from app.core.config import obtener_configuracion


configuracion = obtener_configuracion()


pool_postgresql = AsyncConnectionPool(
    conninfo=configuracion.db_conninfo,
    min_size=configuracion.db_pool_min_size,
    max_size=configuracion.db_pool_max_size,
    timeout=configuracion.db_pool_timeout,
    open=False,
    name="pool_sistema_torneos",
    kwargs={
        "autocommit": False,
        "row_factory": dict_row,
    },
)


async def abrir_pool_postgresql() -> None:
    """
    Abre el pool al iniciar FastAPI.

    wait() comprueba que el pool pueda crear sus conexiones
    iniciales antes de aceptar solicitudes HTTP.
    """
    await pool_postgresql.open()
    await pool_postgresql.wait()


async def cerrar_pool_postgresql() -> None:
    """
    Cierra todas las conexiones al detener FastAPI.
    """
    await pool_postgresql.close()


async def obtener_conexion(
    request: Request,
) -> AsyncGenerator[AsyncConnection, None]:
    """
    Entrega una conexion PostgreSQL a una operacion de FastAPI.

    La conexion se obtiene del pool. Cuando termina la solicitud:

    - se confirma la transaccion si no hubo errores;
    - se revierte la transaccion si ocurrio una excepcion;
    - se devuelve la conexion al pool.
    """
    async with pool_postgresql.connection() as conexion:
        request_id = getattr(
            request.state,
            "request_id",
            "",
        )

        ip_cliente = (
            request.client.host
            if request.client is not None
            else ""
        )

        await conexion.execute(
            """
            SELECT SET_CONFIG(
                'app.request_id',
                %s,
                TRUE
            )
            """,
            (request_id,),
        )

        await conexion.execute(
            """
            SELECT SET_CONFIG(
                'app.ip_cliente',
                %s,
                TRUE
            )
            """,
            (ip_cliente,),
        )

        yield conexion


async def establecer_usuario_aplicacion(
    conexion: AsyncConnection,
    id_usuario: int,
) -> None:
    """
    Establece el usuario de aplicacion dentro de la
    transaccion PostgreSQL actual.

    Este valor es utilizado por los triggers de auditoria.
    """
    await conexion.execute(
        """
        SELECT SET_CONFIG(
            'app.usuario_id',
            %s,
            TRUE
        )
        """,
        (str(id_usuario),),
    )