from fastapi import HTTPException, status
from psycopg import AsyncConnection
from psycopg.errors import (
    CheckViolation,
    UniqueViolation,
)

from app.repositories.deporte_repository import (
    RepositorioDeportes,
)
from app.schemas.deporte import (
    DeporteActualizar,
    DeporteCrear,
    DeporteRespuesta,
    ListaDeportesRespuesta,
)


class ServicioDeportes:
    def __init__(
        self,
        repositorio: RepositorioDeportes,
    ) -> None:
        self.repositorio = repositorio

    async def listar(
        self,
        conexion: AsyncConnection,
        estado_codigo: str | None,
        limite: int,
        desplazamiento: int,
    ) -> ListaDeportesRespuesta:
        estado_normalizado = (
            estado_codigo.strip().upper()
            if estado_codigo is not None
            else None
        )

        if estado_normalizado not in {
            None,
            "ACTIVO",
            "INACTIVO",
        }:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=(
                    "El estado debe ser ACTIVO o INACTIVO"
                ),
            )

        filas, total = await self.repositorio.listar(
            conexion=conexion,
            estado_codigo=estado_normalizado,
            limite=limite,
            desplazamiento=desplazamiento,
        )

        return ListaDeportesRespuesta(
            total=total,
            limite=limite,
            desplazamiento=desplazamiento,
            resultados=[
                DeporteRespuesta.model_validate(fila)
                for fila in filas
            ],
        )

    async def obtener_por_id(
        self,
        conexion: AsyncConnection,
        id_deporte: int,
    ) -> DeporteRespuesta:
        fila = await self.repositorio.obtener_por_id(
            conexion=conexion,
            id_deporte=id_deporte,
        )

        if fila is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="El deporte no existe",
            )

        return DeporteRespuesta.model_validate(fila)

    async def crear(
        self,
        conexion: AsyncConnection,
        datos: DeporteCrear,
    ) -> DeporteRespuesta:
        try:
            fila = await self.repositorio.crear(
                conexion=conexion,
                datos=datos,
            )

        except UniqueViolation as error:
            restriccion = error.diag.constraint_name

            if restriccion == "uq_deporte_codigo":
                detalle = (
                    "Ya existe un deporte con ese codigo"
                )
            elif (
                restriccion
                == "uq_deporte_nombre_minuscula"
            ):
                detalle = (
                    "Ya existe un deporte con ese nombre"
                )
            else:
                detalle = (
                    "El deporte contiene un valor duplicado"
                )

            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=detalle,
            ) from error

        except CheckViolation as error:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=(
                    "Los datos incumplen una restriccion "
                    "de PostgreSQL"
                ),
            ) from error

        if fila is None:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail="El estado del deporte no existe",
            )

        return DeporteRespuesta.model_validate(fila)

    async def actualizar(
        self,
        conexion: AsyncConnection,
        id_deporte: int,
        cambios: DeporteActualizar,
    ) -> DeporteRespuesta:
        deporte_actual = await self.obtener_por_id(
            conexion=conexion,
            id_deporte=id_deporte,
        )

        datos_completos = deporte_actual.model_dump(
            exclude={
                "id_deporte",
                "fecha_registro",
            }
        )

        datos_recibidos = cambios.model_dump(
            exclude_unset=True,
        )

        datos_completos.update(datos_recibidos)

        datos_validados = DeporteCrear.model_validate(
            datos_completos
        )

        try:
            fila = await self.repositorio.actualizar(
                conexion=conexion,
                id_deporte=id_deporte,
                datos=datos_validados,
            )

        except UniqueViolation as error:
            restriccion = error.diag.constraint_name

            if restriccion == "uq_deporte_codigo":
                detalle = (
                    "Ya existe otro deporte con ese codigo"
                )
            elif (
                restriccion
                == "uq_deporte_nombre_minuscula"
            ):
                detalle = (
                    "Ya existe otro deporte con ese nombre"
                )
            else:
                detalle = (
                    "La actualizacion contiene "
                    "un valor duplicado"
                )

            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=detalle,
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
                detail="El estado del deporte no existe",
            )

        return DeporteRespuesta.model_validate(fila)

    async def desactivar(
        self,
        conexion: AsyncConnection,
        id_deporte: int,
    ) -> DeporteRespuesta:
        deporte_actual = await self.obtener_por_id(
            conexion=conexion,
            id_deporte=id_deporte,
        )

        if deporte_actual.estado_codigo == "INACTIVO":
            return deporte_actual

        fila = await self.repositorio.desactivar(
            conexion=conexion,
            id_deporte=id_deporte,
        )

        if fila is None:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=(
                    "No se encontro el estado INACTIVO "
                    "en PostgreSQL"
                ),
            )

        return DeporteRespuesta.model_validate(fila)