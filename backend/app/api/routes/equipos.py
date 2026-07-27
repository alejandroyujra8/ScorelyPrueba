from typing import Annotated

from fastapi import (
    APIRouter,
    Depends,
    Path,
    Query,
    status,
)
from psycopg import AsyncConnection

from app.core.database import obtener_conexion
from app.repositories.equipo_repository import (
    RepositorioEquipos,
)
from app.schemas.equipo import (
    EquipoActualizar,
    EquipoCrear,
    EquipoRespuesta,
    ListaEquiposRespuesta,
)
from app.services.equipo_service import (
    ServicioEquipos,
)
from app.api.dependencies.auth import (
    requerir_roles_id,
)


router = APIRouter(
    prefix="/api/equipos",
    tags=["Equipos"],
)


repositorio_equipos = RepositorioEquipos()

servicio_equipos = ServicioEquipos(
    repositorio=repositorio_equipos,
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
    response_model=ListaEquiposRespuesta,
    status_code=status.HTTP_200_OK,
    summary="Listar equipos",
)
async def listar_equipos(
    conexion: ConexionPostgresql,
    estado: Annotated[
        str | None,
        Query(
            min_length=2,
            max_length=30,
        ),
    ] = None,
    busqueda: Annotated[
        str | None,
        Query(
            min_length=1,
            max_length=100,
            description=(
                "Busca por nombre o sigla"
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
) -> ListaEquiposRespuesta:
    return await servicio_equipos.listar(
        conexion=conexion,
        estado_codigo=estado,
        busqueda=busqueda,
        limite=limite,
        desplazamiento=desplazamiento,
    )


@router.get(
    "/{id_equipo}",
    response_model=EquipoRespuesta,
    status_code=status.HTTP_200_OK,
    summary="Obtener un equipo",
)
async def obtener_equipo(
    conexion: ConexionPostgresql,
    id_equipo: Annotated[
        int,
        Path(ge=1),
    ],
) -> EquipoRespuesta:
    return await servicio_equipos.obtener_por_id(
        conexion=conexion,
        id_equipo=id_equipo,
    )


@router.post(
    "",
    response_model=EquipoRespuesta,
    status_code=status.HTTP_201_CREATED,
    summary="Crear un equipo",
)
async def crear_equipo(
    datos: EquipoCrear,
    conexion: ConexionPostgresql,
    id_usuario: UsuarioResponsable,
) -> EquipoRespuesta:
    return await servicio_equipos.crear(
        conexion=conexion,
        datos=datos,
        id_usuario=id_usuario,
    )


@router.patch(
    "/{id_equipo}",
    response_model=EquipoRespuesta,
    status_code=status.HTTP_200_OK,
    summary="Actualizar parcialmente un equipo",
)
async def actualizar_equipo(
    datos: EquipoActualizar,
    conexion: ConexionPostgresql,
    id_usuario: UsuarioResponsable,
    id_equipo: Annotated[
        int,
        Path(ge=1),
    ],
) -> EquipoRespuesta:
    return await servicio_equipos.actualizar(
        conexion=conexion,
        id_equipo=id_equipo,
        cambios=datos,
        id_usuario=id_usuario,
    )


@router.delete(
    "/{id_equipo}",
    response_model=EquipoRespuesta,
    status_code=status.HTTP_200_OK,
    summary="Desactivar un equipo",
)
async def desactivar_equipo(
    conexion: ConexionPostgresql,
    id_usuario: UsuarioResponsable,
    id_equipo: Annotated[
        int,
        Path(ge=1),
    ],
) -> EquipoRespuesta:
    return await servicio_equipos.desactivar(
        conexion=conexion,
        id_equipo=id_equipo,
        id_usuario=id_usuario,
    )