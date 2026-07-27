from fastapi import HTTPException, status
from psycopg import AsyncConnection
from psycopg.errors import (
    CheckViolation,
    ForeignKeyViolation,
    RaiseException,
    UniqueViolation,
)

from app.core.database import (
    establecer_usuario_aplicacion,
)
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
)


class ServicioJugadores:
    def __init__(
        self,
        repositorio: RepositorioJugadores,
    ) -> None:
        self.repositorio = repositorio

    @staticmethod
    def obtener_detalle_postgresql(
        error: Exception,
        mensaje_defecto: str,
    ) -> str:
        diagnostico = getattr(
            error,
            "diag",
            None,
        )

        mensaje = getattr(
            diagnostico,
            "message_primary",
            None,
        )

        if isinstance(mensaje, str) and mensaje.strip():
            return mensaje

        return mensaje_defecto

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

    async def listar(
        self,
        conexion: AsyncConnection,
        estado_codigo: str | None,
        id_equipo: int | None,
        busqueda: str | None,
        limite: int,
        desplazamiento: int,
    ) -> ListaJugadoresRespuesta:
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
            id_equipo=id_equipo,
            busqueda=busqueda_normalizada,
            limite=limite,
            desplazamiento=desplazamiento,
        )

        return ListaJugadoresRespuesta(
            total=total,
            limite=limite,
            desplazamiento=desplazamiento,
            resultados=[
                JugadorRespuesta.model_validate(fila)
                for fila in filas
            ],
        )

    async def obtener_por_id(
        self,
        conexion: AsyncConnection,
        id_jugador: int,
    ) -> JugadorRespuesta:
        fila = await self.repositorio.obtener_por_id(
            conexion=conexion,
            id_jugador=id_jugador,
        )

        if fila is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="El jugador no existe",
            )

        return JugadorRespuesta.model_validate(fila)

    async def crear(
        self,
        conexion: AsyncConnection,
        datos: JugadorCrear,
        id_usuario_responsable: int,
    ) -> JugadorRespuesta:
        await self.validar_usuario_responsable(
            conexion=conexion,
            id_usuario=id_usuario_responsable,
        )

        usuario_existe = (
            await self.repositorio.existe_usuario_activo(
                conexion=conexion,
                id_usuario=datos.id_usuario,
            )
        )

        if not usuario_existe:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=(
                    "El usuario del jugador no existe "
                    "o se encuentra inactivo"
                ),
            )

        jugador_existente = (
            await self.repositorio.obtener_por_id(
                conexion=conexion,
                id_jugador=datos.id_usuario,
            )
        )

        if jugador_existente is not None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=(
                    "El usuario ya tiene un perfil de jugador"
                ),
            )

        await establecer_usuario_aplicacion(
            conexion=conexion,
            id_usuario=id_usuario_responsable,
        )

        try:
            fila = await self.repositorio.crear(
                conexion=conexion,
                datos=datos,
            )

            await self.repositorio.asignar_rol_jugador(
                conexion=conexion,
                id_jugador=datos.id_usuario,
                asignado_por=id_usuario_responsable,
            )

        except UniqueViolation as error:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=(
                    "El usuario ya tiene un perfil de jugador"
                ),
            ) from error

        except ForeignKeyViolation as error:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=(
                    "El usuario o el estado seleccionado "
                    "no existe"
                ),
            ) from error

        except CheckViolation as error:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=self.obtener_detalle_postgresql(
                    error,
                    "Los datos incumplen una restriccion",
                ),
            ) from error

        if fila is None:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=(
                    "El estado del perfil no existe"
                ),
            )

        return JugadorRespuesta.model_validate(fila)

    async def actualizar(
        self,
        conexion: AsyncConnection,
        id_jugador: int,
        cambios: JugadorActualizar,
        id_usuario_responsable: int,
    ) -> JugadorRespuesta:
        await self.validar_usuario_responsable(
            conexion=conexion,
            id_usuario=id_usuario_responsable,
        )

        jugador_actual = await self.obtener_por_id(
            conexion=conexion,
            id_jugador=id_jugador,
        )

        datos_completos = {
            "id_usuario": id_jugador,
            "alias_deportivo": (
                jugador_actual.alias_deportivo
            ),
            "observaciones": (
                jugador_actual.observaciones
            ),
            "estado_codigo": (
                jugador_actual.estado_codigo
            ),
        }

        datos_completos.update(
            cambios.model_dump(
                exclude_unset=True,
            )
        )

        datos_validados = JugadorCrear.model_validate(
            datos_completos
        )

        await establecer_usuario_aplicacion(
            conexion=conexion,
            id_usuario=id_usuario_responsable,
        )

        try:
            fila = await self.repositorio.actualizar(
                conexion=conexion,
                datos=datos_validados,
            )

        except CheckViolation as error:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=self.obtener_detalle_postgresql(
                    error,
                    "La actualizacion incumple una restriccion",
                ),
            ) from error

        if fila is None:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=(
                    "El estado del perfil no existe"
                ),
            )

        return JugadorRespuesta.model_validate(fila)

    async def desactivar(
        self,
        conexion: AsyncConnection,
        id_jugador: int,
        id_usuario_responsable: int,
    ) -> JugadorRespuesta:
        await self.validar_usuario_responsable(
            conexion=conexion,
            id_usuario=id_usuario_responsable,
        )

        jugador_actual = await self.obtener_por_id(
            conexion=conexion,
            id_jugador=id_jugador,
        )

        if jugador_actual.estado_codigo == "INACTIVO":
            return jugador_actual

        membresia_actual = (
            await self.repositorio.obtener_membresia_activa(
                conexion=conexion,
                id_jugador=id_jugador,
            )
        )

        if membresia_actual is not None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=(
                    "Debe finalizar la membresia activa "
                    "antes de desactivar al jugador"
                ),
            )

        await establecer_usuario_aplicacion(
            conexion=conexion,
            id_usuario=id_usuario_responsable,
        )

        fila = await self.repositorio.desactivar(
            conexion=conexion,
            id_jugador=id_jugador,
        )

        if fila is None:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=(
                    "No se encontro el estado INACTIVO"
                ),
            )

        return JugadorRespuesta.model_validate(fila)

    async def listar_membresias(
        self,
        conexion: AsyncConnection,
        id_jugador: int,
    ) -> list[MembresiaJugadorRespuesta]:
        await self.obtener_por_id(
            conexion=conexion,
            id_jugador=id_jugador,
        )

        filas = await self.repositorio.listar_membresias(
            conexion=conexion,
            id_jugador=id_jugador,
        )

        return [
            MembresiaJugadorRespuesta.model_validate(fila)
            for fila in filas
        ]

    async def crear_membresia(
        self,
        conexion: AsyncConnection,
        id_jugador: int,
        datos: MembresiaJugadorCrear,
        id_usuario_responsable: int,
    ) -> MembresiaJugadorRespuesta:
        await self.validar_usuario_responsable(
            conexion=conexion,
            id_usuario=id_usuario_responsable,
        )

        jugador = await self.obtener_por_id(
            conexion=conexion,
            id_jugador=id_jugador,
        )

        if jugador.estado_codigo != "ACTIVO":
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=(
                    "El jugador se encuentra inactivo"
                ),
            )

        equipo_existe = (
            await self.repositorio.existe_equipo_activo(
                conexion=conexion,
                id_equipo=datos.id_equipo,
            )
        )

        if not equipo_existe:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=(
                    "El equipo no existe o se encuentra inactivo"
                ),
            )

        membresia_actual = (
            await self.repositorio.obtener_membresia_activa(
                conexion=conexion,
                id_jugador=id_jugador,
            )
        )

        if membresia_actual is not None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=(
                    "El jugador ya tiene una membresia activa. "
                    "Utilice el endpoint de transferencia."
                ),
            )

        await establecer_usuario_aplicacion(
            conexion=conexion,
            id_usuario=id_usuario_responsable,
        )

        try:
            fila = await self.repositorio.crear_membresia(
                conexion=conexion,
                id_jugador=id_jugador,
                datos=datos,
                registrado_por=id_usuario_responsable,
            )

        except UniqueViolation as error:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=self.obtener_detalle_postgresql(
                    error,
                    "La membresia contiene un valor duplicado",
                ),
            ) from error

        except (
            CheckViolation,
            ForeignKeyViolation,
            RaiseException,
        ) as error:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=self.obtener_detalle_postgresql(
                    error,
                    "La membresia fue rechazada por PostgreSQL",
                ),
            ) from error

        if fila is None:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=(
                    "No se pudo registrar la membresia"
                ),
            )

        return MembresiaJugadorRespuesta.model_validate(fila)

    async def transferir(
        self,
        conexion: AsyncConnection,
        id_jugador: int,
        datos: TransferenciaJugadorCrear,
        id_usuario_responsable: int,
    ) -> TransferenciaJugadorRespuesta:
        await self.validar_usuario_responsable(
            conexion=conexion,
            id_usuario=id_usuario_responsable,
        )

        jugador = await self.obtener_por_id(
            conexion=conexion,
            id_jugador=id_jugador,
        )

        if jugador.estado_codigo != "ACTIVO":
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=(
                    "El jugador se encuentra inactivo"
                ),
            )

        equipo_existe = (
            await self.repositorio.existe_equipo_activo(
                conexion=conexion,
                id_equipo=datos.id_equipo_destino,
            )
        )

        if not equipo_existe:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=(
                    "El equipo destino no existe "
                    "o se encuentra inactivo"
                ),
            )

        membresia_actual = (
            await self.repositorio.obtener_membresia_activa(
                conexion=conexion,
                id_jugador=id_jugador,
            )
        )

        if membresia_actual is None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=(
                    "El jugador no tiene una membresia activa"
                ),
            )

        membresia_actual_validada = (
            MembresiaJugadorRespuesta.model_validate(
                membresia_actual
            )
        )

        if (
            membresia_actual_validada.id_equipo
            == datos.id_equipo_destino
        ):
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=(
                    "El jugador ya pertenece al equipo destino"
                ),
            )

        if (
            datos.fecha_transferencia
            <= membresia_actual_validada.fecha_inicio
        ):
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=(
                    "La fecha de transferencia debe ser posterior "
                    "a la fecha de inicio de la membresia actual"
                ),
            )

        await establecer_usuario_aplicacion(
            conexion=conexion,
            id_usuario=id_usuario_responsable,
        )

        try:
            fila_anterior = (
                await self.repositorio.finalizar_membresia(
                    conexion=conexion,
                    id_jugador=id_jugador,
                    id_membresia=(
                        membresia_actual_validada
                        .id_jugador_equipo
                    ),
                    fecha_fin=datos.fecha_transferencia,
                    observaciones=(
                        "Membresia finalizada por transferencia"
                    ),
                )
            )

            nueva_membresia = MembresiaJugadorCrear(
                id_equipo=datos.id_equipo_destino,
                fecha_inicio=datos.fecha_transferencia,
                numero_camiseta=datos.numero_camiseta,
                posicion=datos.posicion,
                es_delegado=datos.es_delegado,
                observaciones=datos.observaciones,
            )

            fila_nueva = (
                await self.repositorio.crear_membresia(
                    conexion=conexion,
                    id_jugador=id_jugador,
                    datos=nueva_membresia,
                    registrado_por=id_usuario_responsable,
                )
            )

        except UniqueViolation as error:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=self.obtener_detalle_postgresql(
                    error,
                    "La transferencia produce un valor duplicado",
                ),
            ) from error

        except (
            CheckViolation,
            ForeignKeyViolation,
            RaiseException,
        ) as error:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=self.obtener_detalle_postgresql(
                    error,
                    "La transferencia fue rechazada por PostgreSQL",
                ),
            ) from error

        if fila_anterior is None or fila_nueva is None:
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail=(
                    "No se pudo completar la transferencia"
                ),
            )

        return TransferenciaJugadorRespuesta(
            membresia_anterior=(
                MembresiaJugadorRespuesta.model_validate(
                    fila_anterior
                )
            ),
            membresia_nueva=(
                MembresiaJugadorRespuesta.model_validate(
                    fila_nueva
                )
            ),
        )

    async def finalizar_membresia(
        self,
        conexion: AsyncConnection,
        id_jugador: int,
        id_membresia: int,
        datos: MembresiaJugadorFinalizar,
        id_usuario_responsable: int,
    ) -> MembresiaJugadorRespuesta:
        await self.validar_usuario_responsable(
            conexion=conexion,
            id_usuario=id_usuario_responsable,
        )

        await self.obtener_por_id(
            conexion=conexion,
            id_jugador=id_jugador,
        )

        membresia = (
            await self.repositorio.obtener_membresia_por_id(
                conexion=conexion,
                id_jugador=id_jugador,
                id_membresia=id_membresia,
            )
        )

        if membresia is None:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="La membresia no existe",
            )

        membresia_validada = (
            MembresiaJugadorRespuesta.model_validate(
                membresia
            )
        )

        if membresia_validada.fecha_fin is not None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=(
                    "La membresia ya se encuentra finalizada"
                ),
            )

        if datos.fecha_fin < membresia_validada.fecha_inicio:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=(
                    "La fecha final no puede ser anterior "
                    "a la fecha inicial"
                ),
            )

        await establecer_usuario_aplicacion(
            conexion=conexion,
            id_usuario=id_usuario_responsable,
        )

        try:
            fila = await self.repositorio.finalizar_membresia(
                conexion=conexion,
                id_jugador=id_jugador,
                id_membresia=id_membresia,
                fecha_fin=datos.fecha_fin,
                observaciones=datos.observaciones,
            )

        except (
            CheckViolation,
            ForeignKeyViolation,
            RaiseException,
        ) as error:
            raise HTTPException(
                status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                detail=self.obtener_detalle_postgresql(
                    error,
                    "La finalizacion fue rechazada por PostgreSQL",
                ),
            ) from error

        if fila is None:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=(
                    "La membresia no pudo ser finalizada"
                ),
            )

        return MembresiaJugadorRespuesta.model_validate(fila)