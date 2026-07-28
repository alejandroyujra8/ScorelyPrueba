import re

from collections.abc import Mapping
from datetime import date, datetime, time
from decimal import Decimal
from time import perf_counter
from typing import Any
from uuid import UUID

from psycopg import (
    AsyncConnection,
    Error as PsycopgError,
)

from app.schemas.sql_lab import (
    SqlLabEjecutarRespuesta,
    SqlLabResultadoConjunto,
)


MAXIMO_FILAS_POR_RESULTADO = 500
MAXIMO_RESULTADOS_POR_SCRIPT = 25
TIEMPO_MAXIMO_MILISEGUNDOS = 8_000
TIEMPO_MAXIMO_BLOQUEO_MILISEGUNDOS = 1_500

NOMBRE_SAVEPOINT = "scorely_laboratorio_sql"


class SqlLabValidacionError(Exception):
    """Error provocado por una instrucción no permitida."""


class SqlLabEjecucionError(Exception):
    """Error ocurrido durante la ejecución de PostgreSQL."""

    def __init__(
        self,
        mensaje: str,
        codigo_sql: str | None = None,
    ) -> None:
        super().__init__(mensaje)

        self.mensaje = mensaje
        self.codigo_sql = codigo_sql


PATRONES_BLOQUEADOS: tuple[
    tuple[str, str],
    ...,
] = (
    (
        r"\bCREATE\s+DATABASE\b",
        "No se permite crear bases de datos",
    ),
    (
        r"\bALTER\s+DATABASE\b",
        "No se permite modificar bases de datos",
    ),
    (
        r"\bDROP\s+DATABASE\b",
        "No se permite eliminar bases de datos",
    ),
    (
        r"\bCREATE\s+(ROLE|USER)\b",
        "No se permite crear usuarios o roles",
    ),
    (
        r"\bALTER\s+(ROLE|USER)\b",
        "No se permite modificar usuarios o roles",
    ),
    (
        r"\bDROP\s+(ROLE|USER)\b",
        "No se permite eliminar usuarios o roles",
    ),
    (
        r"\bALTER\s+SYSTEM\b",
        "No se permite modificar la configuración del servidor",
    ),
    (
        r"\bCREATE\s+TABLESPACE\b",
        "No se permite crear tablespaces",
    ),
    (
        r"\bALTER\s+TABLESPACE\b",
        "No se permite modificar tablespaces",
    ),
    (
        r"\bDROP\s+TABLESPACE\b",
        "No se permite eliminar tablespaces",
    ),
    (
        r"\bCREATE\s+EXTENSION\b",
        "No se permite instalar extensiones",
    ),
    (
        r"\bALTER\s+EXTENSION\b",
        "No se permite modificar extensiones",
    ),
    (
        r"\bDROP\s+EXTENSION\b",
        "No se permite eliminar extensiones",
    ),
    (
        r"\bCREATE\s+SUBSCRIPTION\b",
        "No se permite crear suscripciones",
    ),
    (
        r"\bALTER\s+SUBSCRIPTION\b",
        "No se permite modificar suscripciones",
    ),
    (
        r"\bDROP\s+SUBSCRIPTION\b",
        "No se permite eliminar suscripciones",
    ),
    (
        r"\bCREATE\s+PUBLICATION\b",
        "No se permite crear publicaciones",
    ),
    (
        r"\bALTER\s+PUBLICATION\b",
        "No se permite modificar publicaciones",
    ),
    (
        r"\bDROP\s+PUBLICATION\b",
        "No se permite eliminar publicaciones",
    ),
    (
        r"\bCREATE\s+SERVER\b",
        "No se permite crear servidores externos",
    ),
    (
        r"\bCREATE\s+USER\s+MAPPING\b",
        "No se permite crear mapeos de usuarios",
    ),
    (
        r"\bCOMMIT\b",
        "No se permite confirmar la transacción manualmente",
    ),
    (
        r"(?:^|;)\s*END\s*(?:;|$)",
        "No se permite finalizar la transacción manualmente",
    ),
    (
        r"\b(BEGIN|START\s+TRANSACTION)\b",
        "No se permite iniciar transacciones manualmente",
    ),
    (
        r"\bABORT\b",
        "No se permite revertir la transacción manualmente",
    ),
    (
        r"\b(GRANT|REVOKE)\b",
        "No se permite modificar privilegios desde el laboratorio",
    ),
    (
        r"\bROLLBACK\b",
        "No se permite revertir la transacción manualmente",
    ),
    (
        r"\bSAVEPOINT\b",
        "No se permite crear puntos de guardado manualmente",
    ),
    (
        r"\bRELEASE\s+SAVEPOINT\b",
        "No se permite liberar puntos de guardado manualmente",
    ),
    (
        r"\bPREPARE\s+TRANSACTION\b",
        "No se permiten transacciones preparadas",
    ),
    (
        r"\bSET\s+(LOCAL\s+|SESSION\s+)?ROLE\b",
        "No se permite cambiar el rol de PostgreSQL",
    ),
    (
        r"\bSET\s+SESSION\s+AUTHORIZATION\b",
        "No se permite cambiar la autorización de sesión",
    ),
    (
        r"\bSET\s+(LOCAL\s+|SESSION\s+)?"
        r"(STATEMENT_TIMEOUT|LOCK_TIMEOUT|"
        r"IDLE_IN_TRANSACTION_SESSION_TIMEOUT)\b",
        "No se permite modificar los límites de ejecución",
    ),
    (
        r"\bRESET\b",
        "No se permite reiniciar configuraciones de PostgreSQL",
    ),
    (
        r"\bSET_CONFIG\s*\(",
        "No se permite modificar configuraciones internas",
    ),
    (
        r"\bCOPY\b",
        "La instrucción COPY no está disponible en el laboratorio",
    ),
    (
        r"\\COPY\b",
        "El comando de psql \\copy no está permitido",
    ),
    (
        r"\bVACUUM\b",
        "La instrucción VACUUM no está permitida",
    ),
    (
        r"\bCHECKPOINT\b",
        "La instrucción CHECKPOINT no está permitida",
    ),
    (
        r"\bDISCARD\b",
        "La instrucción DISCARD no está permitida",
    ),
    (
        r"\bLOAD\b",
        "La instrucción LOAD no está permitida",
    ),
    (
        r"\bLOCK\s+TABLE\b",
        "No se permite bloquear tablas manualmente",
    ),
    (
        r"\bPG_READ_FILE\s*\(",
        "No se permite acceder a archivos del servidor",
    ),
    (
        r"\bPG_READ_BINARY_FILE\s*\(",
        "No se permite acceder a archivos del servidor",
    ),
    (
        r"\bPG_WRITE_FILE\s*\(",
        "No se permite escribir archivos del servidor",
    ),
    (
        r"\bPG_LS_DIR\s*\(",
        "No se permite explorar archivos del servidor",
    ),
    (
        r"\bLO_IMPORT\s*\(",
        "No se permite importar archivos del servidor",
    ),
    (
        r"\bLO_EXPORT\s*\(",
        "No se permite exportar archivos del servidor",
    ),
    (
        r"\bPG_TERMINATE_BACKEND\s*\(",
        "No se permite finalizar conexiones",
    ),
    (
        r"\bPG_CANCEL_BACKEND\s*\(",
        "No se permite cancelar conexiones",
    ),
    (
        r"\bPG_RELOAD_CONF\s*\(",
        "No se permite recargar la configuración del servidor",
    ),
    (
        r"\bNEXTVAL\s*\(",
        "No se permite avanzar secuencias desde el laboratorio",
    ),
    (
        r"\bSETVAL\s*\(",
        "No se permite modificar secuencias desde el laboratorio",
    ),
    (
        r"\bPG_(TRY_)?ADVISORY_(XACT_)?LOCK\s*\(",
        "No se permiten bloqueos consultivos manuales",
    ),
    (
        r"\b(LISTEN|UNLISTEN|NOTIFY)\b",
        "No se permiten notificaciones persistentes de sesión",
    ),
)


def quitar_comentarios_sql(
    script: str,
) -> str:
    sin_comentarios_bloque = re.sub(
        r"/\*.*?\*/",
        " ",
        script,
        flags=re.DOTALL,
    )

    return re.sub(
        r"--[^\n]*",
        " ",
        sin_comentarios_bloque,
    )


def quitar_cadenas_simples(
    script: str,
) -> str:
    return re.sub(
        r"'(?:''|[^'])*'",
        "''",
        script,
        flags=re.DOTALL,
    )


def validar_script_sql(
    script: str,
) -> None:
    script_inspeccion = quitar_comentarios_sql(
        script
    )

    script_inspeccion = quitar_cadenas_simples(
        script_inspeccion
    )

    script_inspeccion = (
        script_inspeccion.upper()
    )

    for patron, mensaje in PATRONES_BLOQUEADOS:
        if re.search(
            patron,
            script_inspeccion,
            flags=re.IGNORECASE | re.DOTALL,
        ):
            raise SqlLabValidacionError(
                mensaje
            )


def normalizar_valor(
    valor: Any,
) -> Any:
    if valor is None:
        return None

    if isinstance(
        valor,
        (
            str,
            int,
            float,
            bool,
        ),
    ):
        return valor

    if isinstance(
        valor,
        Decimal,
    ):
        return str(valor)

    if isinstance(
        valor,
        (
            date,
            datetime,
            time,
        ),
    ):
        return valor.isoformat()

    if isinstance(
        valor,
        UUID,
    ):
        return str(valor)

    if isinstance(
        valor,
        memoryview,
    ):
        return valor.tobytes().hex()

    if isinstance(
        valor,
        bytes,
    ):
        return valor.hex()

    if isinstance(
        valor,
        Mapping,
    ):
        return {
            str(clave): normalizar_valor(
                contenido
            )
            for clave, contenido in valor.items()
        }

    if isinstance(
        valor,
        (
            list,
            tuple,
            set,
        ),
    ):
        return [
            normalizar_valor(elemento)
            for elemento in valor
        ]

    return str(valor)


def normalizar_fila(
    fila: Any,
    columnas: list[str],
) -> dict[str, Any]:
    if isinstance(
        fila,
        Mapping,
    ):
        return {
            str(clave): normalizar_valor(
                valor
            )
            for clave, valor in fila.items()
        }

    return {
        columna: normalizar_valor(
            valor
        )
        for columna, valor in zip(
            columnas,
            fila,
            strict=False,
        )
    }


def obtener_mensaje_error_postgresql(
    error: PsycopgError,
) -> str:
    mensaje_principal = getattr(
        error.diag,
        "message_primary",
        None,
    )

    detalle = getattr(
        error.diag,
        "message_detail",
        None,
    )

    sugerencia = getattr(
        error.diag,
        "message_hint",
        None,
    )

    partes = [
        parte
        for parte in (
            mensaje_principal,
            detalle,
            sugerencia,
        )
        if parte
    ]

    if partes:
        return " ".join(partes)

    return str(error)


async def revertir_laboratorio(
    conexion: AsyncConnection,
) -> None:
    await conexion.execute(
        f"ROLLBACK TO SAVEPOINT {NOMBRE_SAVEPOINT}"
    )

    await conexion.execute(
        f"RELEASE SAVEPOINT {NOMBRE_SAVEPOINT}"
    )


async def ejecutar_script_sql_simulado(
    conexion: AsyncConnection,
    script: str,
) -> SqlLabEjecutarRespuesta:
    validar_script_sql(script)

    inicio = perf_counter()

    await conexion.execute(
        f"SAVEPOINT {NOMBRE_SAVEPOINT}"
    )

    try:
        await conexion.execute(
            """
            SELECT set_config(
                'statement_timeout',
                %s,
                TRUE
            )
            """,
            (
                f"{TIEMPO_MAXIMO_MILISEGUNDOS}ms",
            ),
        )

        await conexion.execute(
            """
            SELECT set_config(
                'lock_timeout',
                %s,
                TRUE
            )
            """,
            (
                f"{TIEMPO_MAXIMO_BLOQUEO_MILISEGUNDOS}ms",
            ),
        )

        resultados: list[
            SqlLabResultadoConjunto
        ] = []

        async with conexion.cursor() as cursor:
            await cursor.execute(
                script,
                prepare=False,
            )

            indice = 1

            while True:
                mensaje_estado = (
                    cursor.statusmessage
                    or "Comando ejecutado"
                )

                columnas: list[str] = []
                filas: list[
                    dict[str, Any]
                ] = []

                filas_truncadas = False

                if cursor.description is not None:
                    columnas = [
                        columna.name
                        for columna
                        in cursor.description
                    ]

                    filas_obtenidas = (
                        await cursor.fetchmany(
                            MAXIMO_FILAS_POR_RESULTADO
                            + 1
                        )
                    )

                    if (
                        len(filas_obtenidas)
                        > MAXIMO_FILAS_POR_RESULTADO
                    ):
                        filas_truncadas = True

                        filas_obtenidas = (
                            filas_obtenidas[
                                :MAXIMO_FILAS_POR_RESULTADO
                            ]
                        )

                    filas = [
                        normalizar_fila(
                            fila,
                            columnas,
                        )
                        for fila in filas_obtenidas
                    ]

                comando = (
                    mensaje_estado.split(
                        " ",
                        maxsplit=1,
                    )[0]
                    if mensaje_estado
                    else "SQL"
                )

                if indice > MAXIMO_RESULTADOS_POR_SCRIPT:
                    raise SqlLabValidacionError(
                        f"El script no puede generar más de {MAXIMO_RESULTADOS_POR_SCRIPT} resultados"
                    )

                resultados.append(
                    SqlLabResultadoConjunto(
                        indice=indice,
                        comando=comando,
                        columnas=columnas,
                        filas=filas,
                        cantidad_filas=len(
                            filas
                        ),
                        filas_truncadas=(
                            filas_truncadas
                        ),
                        mensaje=mensaje_estado,
                    )
                )

                indice += 1

                siguiente_resultado = (
                    cursor.nextset()
                )

                if not siguiente_resultado:
                    break

        await revertir_laboratorio(
            conexion
        )

        tiempo_ms = (
            perf_counter() - inicio
        ) * 1000

        return SqlLabEjecutarRespuesta(
            tiempo_ms=round(
                tiempo_ms,
                2,
            ),
            resultados=resultados,
            mensajes=[
                (
                    "La ejecución terminó correctamente."
                ),
                (
                    "Todos los cambios fueron revertidos "
                    "automáticamente mediante ROLLBACK."
                ),
            ],
        )

    except PsycopgError as error:
        await revertir_laboratorio(
            conexion
        )

        raise SqlLabEjecucionError(
            mensaje=(
                obtener_mensaje_error_postgresql(
                    error
                )
            ),
            codigo_sql=error.sqlstate,
        ) from error

    except Exception:
        await revertir_laboratorio(
            conexion
        )

        raise


async def obtener_objetos_sql(
    conexion: AsyncConnection,
) -> dict[str, list[dict[str, Any]]]:
    """Devuelve triggers y rutinas con cursores de los esquemas del proyecto."""
    cursor = await conexion.execute(
        """
        SELECT
            esquema.nspname AS esquema,
            tabla.relname AS tabla,
            trigger.tgname AS nombre,
            CASE trigger.tgenabled
                WHEN 'O' THEN 'HABILITADO'
                WHEN 'D' THEN 'DESHABILITADO'
                WHEN 'R' THEN 'REPLICA'
                WHEN 'A' THEN 'SIEMPRE'
                ELSE trigger.tgenabled::text
            END AS habilitado,
            esquema_funcion.nspname AS funcion_esquema,
            funcion.proname AS funcion_nombre,
            PG_GET_TRIGGERDEF(trigger.oid, TRUE) AS definicion
        FROM pg_trigger trigger
        INNER JOIN pg_class tabla
            ON tabla.oid = trigger.tgrelid
        INNER JOIN pg_namespace esquema
            ON esquema.oid = tabla.relnamespace
        INNER JOIN pg_proc funcion
            ON funcion.oid = trigger.tgfoid
        INNER JOIN pg_namespace esquema_funcion
            ON esquema_funcion.oid = funcion.pronamespace
        WHERE trigger.tgisinternal = FALSE
          AND esquema.nspname IN (
              'auditoria',
              'catalogo',
              'competencia',
              'finanzas',
              'participantes',
              'reportes',
              'seguridad'
          )
        ORDER BY esquema.nspname, tabla.relname, trigger.tgname
        """
    )
    filas_triggers = await cursor.fetchall()

    triggers: list[dict[str, Any]] = []
    for fila in filas_triggers:
        esquema = str(fila["esquema"])
        tabla = str(fila["tabla"])
        nombre = str(fila["nombre"])
        triggers.append(
            {
                **dict(fila),
                "sql_inspeccion": (
                    "SELECT\n"
                    "    n.nspname AS esquema,\n"
                    "    c.relname AS tabla,\n"
                    "    t.tgname AS trigger,\n"
                    "    pg_get_triggerdef(t.oid, TRUE) AS definicion,\n"
                    "    pg_get_functiondef(p.oid) AS funcion_trigger\n"
                    "FROM pg_trigger t\n"
                    "INNER JOIN pg_class c ON c.oid = t.tgrelid\n"
                    "INNER JOIN pg_namespace n ON n.oid = c.relnamespace\n"
                    "INNER JOIN pg_proc p ON p.oid = t.tgfoid\n"
                    f"WHERE n.nspname = '{esquema}'\n"
                    f"  AND c.relname = '{tabla}'\n"
                    f"  AND t.tgname = '{nombre}';"
                ),
            }
        )

    cursor = await conexion.execute(
        """
        SELECT
            esquema.nspname AS esquema,
            rutina.proname AS rutina,
            CASE rutina.prokind
                WHEN 'p' THEN 'PROCEDIMIENTO'
                ELSE 'FUNCION'
            END AS tipo_rutina,
            PG_GET_FUNCTION_IDENTITY_ARGUMENTS(rutina.oid) AS argumentos,
            PG_GET_FUNCTIONDEF(rutina.oid) AS definicion
        FROM pg_proc rutina
        INNER JOIN pg_namespace esquema
            ON esquema.oid = rutina.pronamespace
        WHERE rutina.prokind IN ('f', 'p')
          AND esquema.nspname IN (
              'auditoria',
              'catalogo',
              'competencia',
              'finanzas',
              'participantes',
              'reportes',
              'seguridad'
          )
          AND PG_GET_FUNCTIONDEF(rutina.oid) ~* '\\mCURSOR\\M'
        ORDER BY esquema.nspname, rutina.proname
        """
    )
    filas_cursores = await cursor.fetchall()

    cursores: list[dict[str, Any]] = []
    for fila in filas_cursores:
        definicion = str(fila["definicion"])
        nombres = sorted(
            set(
                re.findall(
                    r"\b([A-Za-z_][A-Za-z0-9_]*)\s+CURSOR\s+FOR\b",
                    definicion,
                    flags=re.IGNORECASE,
                )
            )
        )
        esquema = str(fila["esquema"])
        rutina = str(fila["rutina"])
        cursores.append(
            {
                **dict(fila),
                "cursores": nombres,
                "sql_inspeccion": (
                    "SELECT\n"
                    "    n.nspname AS esquema,\n"
                    "    p.proname AS rutina,\n"
                    "    pg_get_function_identity_arguments(p.oid) AS argumentos,\n"
                    "    pg_get_functiondef(p.oid) AS definicion\n"
                    "FROM pg_proc p\n"
                    "INNER JOIN pg_namespace n ON n.oid = p.pronamespace\n"
                    f"WHERE n.nspname = '{esquema}'\n"
                    f"  AND p.proname = '{rutina}';"
                ),
            }
        )

    return {
        "triggers": triggers,
        "cursores": cursores,
    }
