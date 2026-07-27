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
from app.repositories.jugador_repository import (
    RepositorioJugadores,
)
from app.schemas.jugador import (
    JugadorActualizar,
    JugadorCrear,
    JugadorRespuesta,
    ListaJugadoresRespuesta,
    MembresiaJugadorCrear,
    MembresiaJugadorFinalizar,
    MembresiaJugadorRespuesta,
    TransferenciaJugadorCrear,
    TransferenciaJugadorRespuesta,
    UsuarioJugadorOpcionRespuesta,
)
from app.services.jugador_service import (
    ServicioJugadores,
)
from app.api.dependencies.auth import (
    requerir_roles_id,
)

router = APIRouter(
    prefix="/api/jugadores",
    tags=["Jugadores"],
)


repositorio_jugadores = RepositorioJugadores()

servicio_jugadores = ServicioJugadores(
    repositorio=repositorio_jugadores,
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
    response_model=ListaJugadoresRespuesta,
    status_code=status.HTTP_200_OK,
    summary="Listar jugadores",
)
async def listar_jugadores(
    conexion: ConexionPostgresql,
    estado: Annotated[
        str | None,
        Query(
            min_length=2,
            max_length=30,
        ),
    ] = None,
    id_equipo: Annotated[
        int | None,
        Query(ge=1),
    ] = None,
    busqueda: Annotated[
        str | None,
        Query(
            min_length=1,
            max_length=100,
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
        Query(ge=0),
    ] = 0,
) -> ListaJugadoresRespuesta:
    return await servicio_jugadores.listar(
        conexion=conexion,
        estado_codigo=estado,
        id_equipo=id_equipo,
        busqueda=busqueda,
        limite=limite,
        desplazamiento=desplazamiento,
    )




@router.get(
    "/opciones/usuarios",
    response_model=list[UsuarioJugadorOpcionRespuesta],
    status_code=status.HTTP_200_OK,
    summary="Listar usuarios disponibles para perfil de jugador",
)
async def listar_usuarios_disponibles_jugador(
    conexion: ConexionPostgresql,
    _: UsuarioResponsable,
) -> list[UsuarioJugadorOpcionRespuesta]:
    cursor = await conexion.execute(
        """
        SELECT
            usuario.id_usuario,
            usuario.numero_documento,
            CONCAT_WS(
                ' ',
                usuario.nombres,
                usuario.apellido_paterno,
                usuario.apellido_materno
            ) AS nombre_completo,
            usuario.correo
        FROM seguridad.usuario usuario
        INNER JOIN catalogo.estado_usuario estado
            ON estado.id_estado_usuario = usuario.id_estado_usuario
        LEFT JOIN participantes.jugador jugador
            ON jugador.id_usuario = usuario.id_usuario
        WHERE estado.codigo = 'ACTIVO'
          AND jugador.id_usuario IS NULL
        ORDER BY
            usuario.apellido_paterno NULLS LAST,
            usuario.nombres,
            usuario.id_usuario
        """
    )
    return [
        UsuarioJugadorOpcionRespuesta.model_validate(fila)
        for fila in await cursor.fetchall()
    ]


@router.get(
    "/{id_jugador}",
    response_model=JugadorRespuesta,
    status_code=status.HTTP_200_OK,
    summary="Obtener un jugador",
)
async def obtener_jugador(
    conexion: ConexionPostgresql,
    id_jugador: Annotated[
        int,
        Path(ge=1),
    ],
) -> JugadorRespuesta:
    return await servicio_jugadores.obtener_por_id(
        conexion=conexion,
        id_jugador=id_jugador,
    )


@router.post(
    "",
    response_model=JugadorRespuesta,
    status_code=status.HTTP_201_CREATED,
    summary="Crear perfil de jugador",
)
async def crear_jugador(
    datos: JugadorCrear,
    conexion: ConexionPostgresql,
    id_usuario_responsable: UsuarioResponsable,
) -> JugadorRespuesta:
    return await servicio_jugadores.crear(
        conexion=conexion,
        datos=datos,
        id_usuario_responsable=id_usuario_responsable,
    )


@router.patch(
    "/{id_jugador}",
    response_model=JugadorRespuesta,
    status_code=status.HTTP_200_OK,
    summary="Actualizar perfil de jugador",
)
async def actualizar_jugador(
    datos: JugadorActualizar,
    conexion: ConexionPostgresql,
    id_usuario_responsable: UsuarioResponsable,
    id_jugador: Annotated[
        int,
        Path(ge=1),
    ],
) -> JugadorRespuesta:
    return await servicio_jugadores.actualizar(
        conexion=conexion,
        id_jugador=id_jugador,
        cambios=datos,
        id_usuario_responsable=id_usuario_responsable,
    )


@router.delete(
    "/{id_jugador}",
    response_model=JugadorRespuesta,
    status_code=status.HTTP_200_OK,
    summary="Desactivar jugador",
)
async def desactivar_jugador(
    conexion: ConexionPostgresql,
    id_usuario_responsable: UsuarioResponsable,
    id_jugador: Annotated[
        int,
        Path(ge=1),
    ],
) -> JugadorRespuesta:
    return await servicio_jugadores.desactivar(
        conexion=conexion,
        id_jugador=id_jugador,
        id_usuario_responsable=id_usuario_responsable,
    )


@router.get(
    "/{id_jugador}/membresias",
    response_model=list[MembresiaJugadorRespuesta],
    status_code=status.HTTP_200_OK,
    summary="Listar historial de membresias",
)
async def listar_membresias_jugador(
    conexion: ConexionPostgresql,
    id_jugador: Annotated[
        int,
        Path(ge=1),
    ],
) -> list[MembresiaJugadorRespuesta]:
    return await servicio_jugadores.listar_membresias(
        conexion=conexion,
        id_jugador=id_jugador,
    )


@router.post(
    "/{id_jugador}/membresias",
    response_model=MembresiaJugadorRespuesta,
    status_code=status.HTTP_201_CREATED,
    summary="Registrar membresia inicial",
)
async def crear_membresia_jugador(
    datos: MembresiaJugadorCrear,
    conexion: ConexionPostgresql,
    id_usuario_responsable: UsuarioResponsable,
    id_jugador: Annotated[
        int,
        Path(ge=1),
    ],
) -> MembresiaJugadorRespuesta:
    return await servicio_jugadores.crear_membresia(
        conexion=conexion,
        id_jugador=id_jugador,
        datos=datos,
        id_usuario_responsable=id_usuario_responsable,
    )


@router.post(
    "/{id_jugador}/transferencias",
    response_model=TransferenciaJugadorRespuesta,
    status_code=status.HTTP_201_CREATED,
    summary="Transferir jugador a otro equipo",
)
async def transferir_jugador(
    datos: TransferenciaJugadorCrear,
    conexion: ConexionPostgresql,
    id_usuario_responsable: UsuarioResponsable,
    id_jugador: Annotated[
        int,
        Path(ge=1),
    ],
) -> TransferenciaJugadorRespuesta:
    return await servicio_jugadores.transferir(
        conexion=conexion,
        id_jugador=id_jugador,
        datos=datos,
        id_usuario_responsable=id_usuario_responsable,
    )


@router.patch(
    "/{id_jugador}/membresias/{id_membresia}/finalizar",
    response_model=MembresiaJugadorRespuesta,
    status_code=status.HTTP_200_OK,
    summary="Finalizar membresia activa",
)
async def finalizar_membresia_jugador(
    datos: MembresiaJugadorFinalizar,
    conexion: ConexionPostgresql,
    id_usuario_responsable: UsuarioResponsable,
    id_jugador: Annotated[
        int,
        Path(ge=1),
    ],
    id_membresia: Annotated[
        int,
        Path(ge=1),
    ],
) -> MembresiaJugadorRespuesta:
    return await servicio_jugadores.finalizar_membresia(
        conexion=conexion,
        id_jugador=id_jugador,
        id_membresia=id_membresia,
        datos=datos,
        id_usuario_responsable=id_usuario_responsable,
    )