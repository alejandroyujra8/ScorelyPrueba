from datetime import datetime, timedelta, timezone
from typing import Any

import jwt
from jwt.exceptions import InvalidTokenError
from pwdlib import PasswordHash

from app.core.config import obtener_configuracion


configuracion = obtener_configuracion()

administrador_contrasenias = PasswordHash.recommended()


class TokenInvalidoError(Exception):
    pass


def generar_hash_contrasenia(
    contrasenia: str,
) -> str:
    """
    Genera un hash Argon2 para almacenar la contrasenia.
    """
    return administrador_contrasenias.hash(
        contrasenia
    )


def verificar_contrasenia(
    contrasenia_plana: str,
    contrasenia_hash: str,
) -> bool:
    """
    Comprueba la contrasenia sin exponer el hash.

    Si el hash almacenado es antiguo o invalido, devuelve False.
    """
    try:
        return administrador_contrasenias.verify(
            contrasenia_plana,
            contrasenia_hash,
        )
    except Exception:
        return False


def crear_token_acceso(
    id_usuario: int,
) -> str:
    ahora = datetime.now(timezone.utc)

    fecha_expiracion = ahora + timedelta(
        minutes=configuracion.jwt_expire_minutes
    )

    contenido: dict[str, Any] = {
        "sub": str(id_usuario),
        "type": "access",
        "iat": ahora,
        "exp": fecha_expiracion,
    }

    return jwt.encode(
        contenido,
        configuracion.jwt_secret,
        algorithm=configuracion.jwt_algorithm,
    )


def decodificar_token_acceso(
    token: str,
) -> int:
    try:
        contenido = jwt.decode(
            token,
            configuracion.jwt_secret,
            algorithms=[
                configuracion.jwt_algorithm
            ],
            options={
                "require": [
                    "sub",
                    "type",
                    "iat",
                    "exp",
                ]
            },
        )

        if contenido.get("type") != "access":
            raise TokenInvalidoError(
                "El token no es de acceso"
            )

        id_usuario = int(contenido["sub"])

        if id_usuario <= 0:
            raise TokenInvalidoError(
                "El identificador del token es invalido"
            )

        return id_usuario

    except (
        InvalidTokenError,
        KeyError,
        TypeError,
        ValueError,
    ) as error:
        raise TokenInvalidoError(
            "El token es invalido o ha expirado"
        ) from error