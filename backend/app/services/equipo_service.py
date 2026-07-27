from fastapi import HTTPException, status
from psycopg import AsyncConnection
from psycopg.errors import (
    CheckViolation,
    ForeignKeyViolation,
    UniqueViolation,
)

from app.core.database import (
    establecer_usuario_aplicacion,
)
from app.repositories.equipo_repository import (
    RepositorioEquipos,
)
from app.schemas.equipo import (
    EquipoActualizar,
    EquipoCrear,
    EquipoRespuesta,
    ListaEquiposRespuesta,
)


class ServicioEquipos:
    def __init__(
        self,
        repositorio: RepositorioEquipos,
    ) -> None:
        self.repositorio = repositorio

    async def listar(
        self,
        conexion: AsyncConnection,
        estado_codigo: str | None,
        busqueda: str | None,
        limite: int,
        desplazamiento: int,
    ) -> ListaEquiposRespuesta:
        estado_normalizado = (
            estado_codigo.strip().upper()
            if estado_codigo is not None
            else None
        )

        busqueda_normalizada = (
            busqueda.strip()
            if busqueda is not None
            else None
        )

        if busqueda_normalizada == "":
            busqueda_normalizada = None

        if estado_normalizado not in {
            None,
            "ACTIVO",
            "INACTIVO",
            "SUSPENDIDO",
        }:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=(
                    "El estado debe ser ACTIVO, INACTIVO o SUSPENDIDO"
                ),
            )

        filas, total = await self.repositorio.listar(
            conexion=conexion,
            estado_codigo=estado_normalizado,
            busqueda=busqueda_normalizada,
            limite=limite,
            desplazamiento=desplazamiento,
        )

        return ListaEquiposRespuesta(
            total=total,
            limite=limite,
            desplazamiento=desplazamiento,
            resultados=[
                EquipoRespuesta.model_validate(fila)
                for fila in filas
            ],
        )

    async def obtener_por_id(
        self,
        conexion: AsyncConnection,
        id_equipo: int,
    ) -> EquipoRespuesta:
        fila = await self.repositorio.obtener_por_id(
            conexion=conexion,
            id_equipo=id_equipo,
        )

        if fila is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="El equipo no existe",
            )

        return EquipoRespuesta.model_validate(fila)

    async def validar_usuario_responsable(
        self,
        conexion: AsyncConnection,
        id_usuario: int,
    ) -> None:
        existe = await self.repositorio.existe_usuario_activo(
            conexion=conexion,
            id_usuario=id_usuario,
        )

        if not existe:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=(
                    "El usuario responsable no existe "
                    "o se encuentra inactivo"
                ),
            )

    async def crear(
        self,
        conexion: AsyncConnection,
        datos: EquipoCrear,
        id_usuario: int,
    ) -> EquipoRespuesta:
        await self.validar_usuario_responsable(
            conexion=conexion,
            id_usuario=id_usuario,
        )

        await establecer_usuario_aplicacion(
            conexion=conexion,
            id_usuario=id_usuario,
        )

        try:
            fila = await self.repositorio.crear(
                conexion=conexion,
                datos=datos,
                creado_por=id_usuario,
            )

        except UniqueViolation as error:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=(
                    "Ya existe un equipo con ese nombre "
                    "o con esa sigla"
                ),
            ) from error

        except ForeignKeyViolation as error:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=(
                    "El usuario responsable o el estado "
                    "seleccionado no existe"
                ),
            ) from error

        except CheckViolation as error:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=(
                    "Los datos del equipo incumplen una "
                    "restriccion de PostgreSQL"
                ),
            ) from error

        if fila is None:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="El estado del equipo no existe",
            )

        return EquipoRespuesta.model_validate(fila)

    async def actualizar(
        self,
        conexion: AsyncConnection,
        id_equipo: int,
        cambios: EquipoActualizar,
        id_usuario: int,
    ) -> EquipoRespuesta:
        await self.validar_usuario_responsable(
            conexion=conexion,
            id_usuario=id_usuario,
        )

        equipo_actual = await self.obtener_por_id(
            conexion=conexion,
            id_equipo=id_equipo,
        )

        datos_completos = equipo_actual.model_dump(
            exclude={
                "id_equipo",
                "creado_por",
            }
        )

        datos_recibidos = cambios.model_dump(
            exclude_unset=True,
        )

        datos_completos.update(datos_recibidos)

        datos_validados = EquipoCrear.model_validate(
            datos_completos
        )

        await establecer_usuario_aplicacion(
            conexion=conexion,
            id_usuario=id_usuario,
        )

        try:
            fila = await self.repositorio.actualizar(
                conexion=conexion,
                id_equipo=id_equipo,
                datos=datos_validados,
            )

        except UniqueViolation as error:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=(
                    "Ya existe otro equipo con ese nombre "
                    "o con esa sigla"
                ),
            ) from error

        except CheckViolation as error:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=(
                    "La actualizacion incumple una "
                    "restriccion de PostgreSQL"
                ),
            ) from error

        if fila is None:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="El estado del equipo no existe",
            )

        return EquipoRespuesta.model_validate(fila)

    async def desactivar(
        self,
        conexion: AsyncConnection,
        id_equipo: int,
        id_usuario: int,
    ) -> EquipoRespuesta:
        await self.validar_usuario_responsable(
            conexion=conexion,
            id_usuario=id_usuario,
        )

        equipo_actual = await self.obtener_por_id(
            conexion=conexion,
            id_equipo=id_equipo,
        )

        if equipo_actual.estado_codigo == "INACTIVO":
            return equipo_actual

        await establecer_usuario_aplicacion(
            conexion=conexion,
            id_usuario=id_usuario,
        )

        fila = await self.repositorio.desactivar(
            conexion=conexion,
            id_equipo=id_equipo,
        )

        if fila is None:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=(
                    "No se encontro el estado INACTIVO "
                    "en PostgreSQL"
                ),
            )

        return EquipoRespuesta.model_validate(fila)