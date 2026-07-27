from typing import Annotated

from fastapi import (
    APIRouter,
    Depends,
    Path,
    Query,
    status,
)
from psycopg import AsyncConnection

from app.repositories.deporte_repository import (
    RepositorioDeportes,
)
from app.schemas.deporte import (
    DeporteActualizar,
    DeporteCrear,
    DeporteRespuesta,
    ListaDeportesRespuesta,
)
from app.services.deporte_service import (
    ServicioDeportes,
)
from app.api.dependencies.auth import (
    requerir_roles_id,
)
from app.core.database import (
    establecer_usuario_aplicacion,
    obtener_conexion,
)


router = APIRouter(
    prefix="/api/deportes",
    tags=["Deportes"],
)


repositorio_deportes = RepositorioDeportes()

servicio_deportes = ServicioDeportes(
    repositorio=repositorio_deportes,
)


ConexionPostgresql = Annotated[
    AsyncConnection,
    Depends(obtener_conexion),
]
UsuarioResponsable = Annotated[
    int,
    Depends(
        requerir_roles_id(
            "ADMINISTRADOR",
            "ORGANIZADOR",
        )
    ),
]

@router.get(
    "",
    response_model=ListaDeportesRespuesta,
    status_code=status.HTTP_200_OK,
    summary="Listar deportes",
)
async def listar_deportes(
    conexion: ConexionPostgresql,
    estado: Annotated[
        str | None,
        Query(
            min_length=2,
            max_length=30,
            description=(
                "Permite filtrar por ACTIVO o INACTIVO"
            ),
        ),
    ] = None,
    limite: Annotated[
        int,
        Query(
            ge=1,
            le=100,
        ),
    ] = 20,
    desplazamiento: Annotated[
        int,
        Query(
            ge=0,
        ),
    ] = 0,
) -> ListaDeportesRespuesta:
    return await servicio_deportes.listar(
        conexion=conexion,
        estado_codigo=estado,
        limite=limite,
        desplazamiento=desplazamiento,
    )


@router.get(
    "/{id_deporte}",
    response_model=DeporteRespuesta,
    status_code=status.HTTP_200_OK,
    summary="Obtener un deporte",
)
async def obtener_deporte(
    conexion: ConexionPostgresql,
    id_deporte: Annotated[
        int,
        Path(
            ge=1,
        ),
    ],
) -> DeporteRespuesta:
    return await servicio_deportes.obtener_por_id(
        conexion=conexion,
        id_deporte=id_deporte,
    )


@router.post(
    "",
    response_model=DeporteRespuesta,
    status_code=status.HTTP_201_CREATED,
    summary="Crear un deporte",
)
async def crear_deporte(
    datos: DeporteCrear,
    conexion: ConexionPostgresql,
    id_usuario: UsuarioResponsable,
) -> DeporteRespuesta:
    await establecer_usuario_aplicacion(
        conexion=conexion,
        id_usuario=id_usuario,
    )

    return await servicio_deportes.crear(
        conexion=conexion,
        datos=datos,
    )


@router.patch(
    "/{id_deporte}",
    response_model=DeporteRespuesta,
    status_code=status.HTTP_200_OK,
    summary="Actualizar parcialmente un deporte",
)
async def actualizar_deporte(
    datos: DeporteActualizar,
    conexion: ConexionPostgresql,
    id_usuario: UsuarioResponsable,
    id_deporte: Annotated[
        int,
        Path(ge=1),
    ],
) -> DeporteRespuesta:
    await establecer_usuario_aplicacion(
        conexion=conexion,
        id_usuario=id_usuario,
    )

    return await servicio_deportes.actualizar(
        conexion=conexion,
        id_deporte=id_deporte,
        cambios=datos,
    )


@router.delete(
    "/{id_deporte}",
    response_model=DeporteRespuesta,
    status_code=status.HTTP_200_OK,
    summary="Desactivar un deporte",
)
async def desactivar_deporte(
    conexion: ConexionPostgresql,
    id_usuario: UsuarioResponsable,
    id_deporte: Annotated[
        int,
        Path(ge=1),
    ],
) -> DeporteRespuesta:
    await establecer_usuario_aplicacion(
        conexion=conexion,
        id_usuario=id_usuario,
    )

    return await servicio_deportes.desactivar(
        conexion=conexion,
        id_deporte=id_deporte,
    )