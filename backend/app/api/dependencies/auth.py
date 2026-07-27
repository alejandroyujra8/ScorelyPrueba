from collections.abc import Callable
from typing import Annotated

from fastapi import (
    Depends,
    HTTPException,
    status,
)
from fastapi.security import (
    HTTPAuthorizationCredentials,
    HTTPBearer,
)
from psycopg import AsyncConnection

from app.core.database import obtener_conexion
from app.core.security import (
    TokenInvalidoError,
    decodificar_token_acceso,
)
from app.schemas.auth import (
    UsuarioAutenticadoRespuesta,
)


portador_jwt = HTTPBearer(
    bearerFormat="JWT",
    auto_error=False,
)


async def obtener_usuario_actual(
    credenciales: Annotated[
        HTTPAuthorizationCredentials | None,
        Depends(portador_jwt),
    ],
    conexion: Annotated[
        AsyncConnection,
        Depends(obtener_conexion),
    ],
) -> UsuarioAutenticadoRespuesta:
    excepcion_credenciales = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail=(
            "No se proporciono un token valido"
        ),
        headers={
            "WWW-Authenticate": "Bearer"
        },
    )

    if credenciales is None:
        raise excepcion_credenciales

    if credenciales.scheme.lower() != "bearer":
        raise excepcion_credenciales

    try:
        id_usuario = decodificar_token_acceso(
            credenciales.credentials
        )
    except TokenInvalidoError as error:
        raise excepcion_credenciales from error

    cursor = await conexion.execute(
        """
        SELECT
            usuario.id_usuario,
            usuario.numero_documento,

            usuario.nombres,
            usuario.apellido_paterno,
            usuario.apellido_materno,

            usuario.correo,

            estado.codigo AS estado_codigo,

            COALESCE(
                ARRAY_AGG(
                    DISTINCT rol.codigo
                    ORDER BY rol.codigo
                ) FILTER (
                    WHERE usuario_rol.activo = TRUE
                      AND rol.activo = TRUE
                      AND usuario_rol.fecha_inicio <= CURRENT_DATE
                      AND (
                          usuario_rol.fecha_fin IS NULL
                          OR usuario_rol.fecha_fin
                             >= CURRENT_DATE
                      )
                ),
                ARRAY[]::VARCHAR[]
            ) AS roles

        FROM seguridad.usuario usuario

        INNER JOIN catalogo.estado_usuario estado
            ON estado.id_estado_usuario =
               usuario.id_estado_usuario

        LEFT JOIN seguridad.usuario_rol usuario_rol
            ON usuario_rol.id_usuario =
               usuario.id_usuario

        LEFT JOIN seguridad.rol rol
            ON rol.id_rol =
               usuario_rol.id_rol

        WHERE usuario.id_usuario = %s
          AND estado.codigo = 'ACTIVO'

        GROUP BY
            usuario.id_usuario,
            usuario.numero_documento,
            usuario.nombres,
            usuario.apellido_paterno,
            usuario.apellido_materno,
            usuario.correo,
            estado.codigo
        """,
        (id_usuario,),
    )

    fila = await cursor.fetchone()

    if fila is None:
        raise excepcion_credenciales

    return UsuarioAutenticadoRespuesta.model_validate(
        fila
    )


def requerir_roles(
    *roles_permitidos: str,
) -> Callable[..., UsuarioAutenticadoRespuesta]:
    roles_normalizados = {
        rol.strip().upper()
        for rol in roles_permitidos
    }

    async def dependencia(
        usuario: Annotated[
            UsuarioAutenticadoRespuesta,
            Depends(obtener_usuario_actual),
        ],
    ) -> UsuarioAutenticadoRespuesta:
        roles_usuario = set(usuario.roles)

        if "ADMINISTRADOR" in roles_usuario:
            return usuario

        if not roles_usuario.intersection(
            roles_normalizados
        ):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=(
                    "No tiene permisos para realizar "
                    "esta operacion"
                ),
            )

        return usuario

    return dependencia


def requerir_roles_id(
    *roles_permitidos: str,
) -> Callable[..., int]:
    dependencia_roles = requerir_roles(
        *roles_permitidos
    )

    async def dependencia(
        usuario: Annotated[
            UsuarioAutenticadoRespuesta,
            Depends(dependencia_roles),
        ],
    ) -> int:
        return usuario.id_usuario

    return dependencia