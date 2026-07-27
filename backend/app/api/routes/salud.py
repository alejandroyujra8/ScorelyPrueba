from typing import Annotated, Any

from fastapi import APIRouter, Depends, HTTPException, status
from psycopg import AsyncConnection

from app.core.database import obtener_conexion
from app.schemas.salud import (
    RespuestaSalud,
    RespuestaSaludBaseDatos,
)


router = APIRouter(
    prefix="/api/salud",
    tags=["Salud"],
)


@router.get(
    "",
    response_model=RespuestaSalud,
    status_code=status.HTTP_200_OK,
)
async def verificar_salud() -> RespuestaSalud:
    return RespuestaSalud(
        estado="activo",
        servicio="backend-fastapi",
    )


@router.get(
    "/base-datos",
    response_model=RespuestaSaludBaseDatos,
    status_code=status.HTTP_200_OK,
)
async def verificar_salud_base_datos(
    conexion: Annotated[
        AsyncConnection,
        Depends(obtener_conexion),
    ],
) -> RespuestaSaludBaseDatos:
    cursor = await conexion.execute(
        """
        SELECT
            CURRENT_DATABASE() AS base_datos,
            CURRENT_USER AS usuario_postgresql,
            CURRENT_SETTING(
                'server_version'
            ) AS version_postgresql,
            CURRENT_TIMESTAMP AS fecha_hora
        """
    )

    fila: dict[str, Any] | None = await cursor.fetchone()

    if fila is None:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="PostgreSQL no devolvio informacion",
        )

    return RespuestaSaludBaseDatos(
        estado="activo",
        servicio="postgresql",
        base_datos=str(fila["base_datos"]),
        usuario_postgresql=str(
            fila["usuario_postgresql"]
        ),
        version_postgresql=str(
            fila["version_postgresql"]
        ),
        fecha_hora=fila["fecha_hora"],
    )