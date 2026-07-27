from typing import Annotated

from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
    status,
)

from psycopg import AsyncConnection

from app.api.dependencies.auth import (
    requerir_roles,
)

from app.core.database import (
    establecer_usuario_aplicacion,
    obtener_conexion,
)

from app.schemas.auth import (
    UsuarioAutenticadoRespuesta,
)

from app.schemas.sql_lab import (
    SqlLabEjecutarRespuesta,
    SqlLabEjecutarSolicitud,
    SqlLabObjetosRespuesta,
)

from app.services.sql_lab_service import (
    SqlLabEjecucionError,
    SqlLabValidacionError,
    ejecutar_script_sql_simulado,
    obtener_objetos_sql,
)


router = APIRouter(
    prefix="/api/sql-lab",
    tags=["Laboratorio SQL"],
)


@router.post(
    "/ejecutar",
    response_model=SqlLabEjecutarRespuesta,
    summary="Ejecutar SQL con rollback automático",
)
async def ejecutar_sql_laboratorio(
    solicitud: SqlLabEjecutarSolicitud,

    conexion: Annotated[
        AsyncConnection,
        Depends(obtener_conexion),
    ],

    usuario: Annotated[
        UsuarioAutenticadoRespuesta,
        Depends(
            requerir_roles(
                "ADMINISTRADOR",
            )
        ),
    ],
) -> SqlLabEjecutarRespuesta:
    await establecer_usuario_aplicacion(
        conexion,
        usuario.id_usuario,
    )

    try:
        return await ejecutar_script_sql_simulado(
            conexion=conexion,
            script=solicitud.script,
        )

    except SqlLabValidacionError as error:
        raise HTTPException(
            status_code=(
                status.HTTP_400_BAD_REQUEST
            ),
            detail=str(error),
        ) from error

    except SqlLabEjecucionError as error:
        mensaje = error.mensaje

        if error.codigo_sql:
            mensaje = (
                f"{mensaje} "
                f"[SQLSTATE: {error.codigo_sql}]"
            )

        raise HTTPException(
            status_code=(
                status.HTTP_400_BAD_REQUEST
            ),
            detail=mensaje,
        ) from error


@router.get(
    "/objetos",
    response_model=SqlLabObjetosRespuesta,
    summary="Listar triggers y rutinas con cursores",
)
async def listar_objetos_laboratorio(
    conexion: Annotated[
        AsyncConnection,
        Depends(obtener_conexion),
    ],
    usuario: Annotated[
        UsuarioAutenticadoRespuesta,
        Depends(requerir_roles("ADMINISTRADOR")),
    ],
) -> SqlLabObjetosRespuesta:
    del usuario
    datos = await obtener_objetos_sql(conexion)
    return SqlLabObjetosRespuesta.model_validate(datos)
