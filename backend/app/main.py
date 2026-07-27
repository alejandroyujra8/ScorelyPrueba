from collections.abc import AsyncIterator
from contextlib import asynccontextmanager
from uuid import uuid4

from fastapi import (
    Depends,
    FastAPI,
    Request,
    Response,
)

from fastapi.middleware.cors import (
    CORSMiddleware,
)

from app.api.dependencies.auth import (
    obtener_usuario_actual,
)

from app.api.routes.auth import (
    router as router_auth,
)

from app.api.routes.catalogos import (
    router as router_catalogos,
)

from app.api.routes.deportes import (
    router as router_deportes,
)

from app.api.routes.equipos import (
    router as router_equipos,
)

from app.api.routes.inscripciones import (
    router as router_inscripciones,
)

from app.api.routes.jugadores import (
    router as router_jugadores,
)

from app.api.routes.partidos import (
    router as router_partidos,
)

from app.api.routes.reportes import (
    router as router_reportes,
)

from app.api.routes.salud import (
    router as router_salud,
)

from app.api.routes.sql_lab import (
    router as router_sql_lab,
)

from app.api.routes.torneos import (
    router as router_torneos,
)

from app.api.routes.usuarios import (
    router as router_usuarios,
)

from app.core.config import (
    obtener_configuracion,
)

from app.core.database import (
    abrir_pool_postgresql,
    cerrar_pool_postgresql,
)


configuracion = obtener_configuracion()


@asynccontextmanager
async def lifespan(
    app: FastAPI,
) -> AsyncIterator[None]:
    del app

    await abrir_pool_postgresql()

    try:
        yield
    finally:
        await cerrar_pool_postgresql()


app = FastAPI(
    title=configuracion.app_name,
    description=(
        "API para la gestion de usuarios, equipos, "
        "torneos, partidos, pagos y reportes."
    ),
    version="1.0.0",
    lifespan=lifespan,
)


app.add_middleware(
    CORSMiddleware,
    allow_origins=(
        configuracion.lista_frontend_origins
    ),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.middleware("http")
async def agregar_identificador_solicitud(
    request: Request,
    call_next,
) -> Response:
    request_id = (
        request.headers.get(
            "X-Request-ID"
        )
        or str(uuid4())
    )

    request.state.request_id = request_id

    respuesta: Response = (
        await call_next(request)
    )

    respuesta.headers[
        "X-Request-ID"
    ] = request_id

    return respuesta


@app.get("/")
async def inicio() -> dict[str, str]:
    return {
        "mensaje": (
            "API del sistema de torneos "
            "funcionando correctamente"
        )
    }


app.include_router(
    router_salud
)

app.include_router(
    router_auth
)

app.include_router(
    router_sql_lab
)


dependencias_autenticadas = [
    Depends(
        obtener_usuario_actual
    )
]


app.include_router(
    router_usuarios,
    dependencies=(
        dependencias_autenticadas
    ),
)

app.include_router(
    router_catalogos,
    dependencies=(
        dependencias_autenticadas
    ),
)

app.include_router(
    router_deportes,
    dependencies=(
        dependencias_autenticadas
    ),
)

app.include_router(
    router_equipos,
    dependencies=(
        dependencias_autenticadas
    ),
)

app.include_router(
    router_jugadores,
    dependencies=(
        dependencias_autenticadas
    ),
)

app.include_router(
    router_torneos,
    dependencies=(
        dependencias_autenticadas
    ),
)

app.include_router(
    router_inscripciones,
    dependencies=(
        dependencias_autenticadas
    ),
)

app.include_router(
    router_partidos,
    dependencies=(
        dependencias_autenticadas
    ),
)

app.include_router(
    router_reportes,
    dependencies=(
        dependencias_autenticadas
    ),
)