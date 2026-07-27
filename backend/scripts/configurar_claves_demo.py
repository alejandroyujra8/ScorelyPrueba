from psycopg import connect

from app.core.config import obtener_configuracion
from app.core.security import (
    generar_hash_contrasenia,
)


DOCUMENTOS_DEMO = [
    "7000001",
    "7000002",
    "7000003",
    "7100001",
    "7100002",
    "7100003",
    "7100004",
    "7100005",
    "7200001",
    "7200002",
    "7200003",
    "7200004",
    "7200005",
]


def main() -> None:
    configuracion = obtener_configuracion()

    cantidad_actualizada = 0

    with connect(
        configuracion.db_conninfo
    ) as conexion:
        for numero_documento in DOCUMENTOS_DEMO:
            nuevo_hash = generar_hash_contrasenia(
                "Demo123*"
            )

            cursor = conexion.execute(
                """
                UPDATE seguridad.usuario
                SET contrasenia_hash = %s
                WHERE numero_documento = %s
                """,
                (
                    nuevo_hash,
                    numero_documento,
                ),
            )

            cantidad_actualizada += (
                cursor.rowcount or 0
            )

    print(
        "Usuarios demo actualizados:",
        cantidad_actualizada,
    )

    print(
        "Contrasenia temporal: Demo123*"
    )


if __name__ == "__main__":
    main()