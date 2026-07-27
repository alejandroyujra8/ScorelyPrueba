from typing import Annotated

from fastapi import (
    APIRouter,
    Depends,
    HTTPException,
    Path,
    status,
)
from psycopg import AsyncConnection, sql

from app.core.database import obtener_conexion
from app.schemas.catalogo import CatalogoRespuesta


router = APIRouter(
    prefix="/api/catalogos",
    tags=["Catalogos"],
)


ConexionPostgresql = Annotated[
    AsyncConnection,
    Depends(obtener_conexion),
]


CATALOGOS_PERMITIDOS: dict[
    str,
    tuple[str, str, str],
] = {
    "estados-torneo": (
        "catalogo",
        "estado_torneo",
        "id_estado_torneo",
    ),
    "formatos-torneo": (
        "catalogo",
        "formato_torneo",
        "id_formato_torneo",
    ),
    "estados-inscripcion": (
        "catalogo",
        "estado_inscripcion",
        "id_estado_inscripcion",
    ),
    "metodos-pago": (
        "catalogo",
        "metodo_pago",
        "id_metodo_pago",
    ),
    "estados-pago": (
        "catalogo",
        "estado_pago",
        "id_estado_pago",
    ),
    "estados-partido": (
        "catalogo",
        "estado_partido",
        "id_estado_partido",
    ),
    "tipos-fase": (
        "catalogo",
        "tipo_fase",
        "id_tipo_fase",
    ),
    "estados-fase": (
        "catalogo",
        "estado_fase",
        "id_estado_fase",
    ),
    "estados-jornada": (
        "catalogo",
        "estado_jornada",
        "id_estado_jornada",
    ),
    "roles-torneo": (
        "catalogo",
        "rol_torneo",
        "id_rol_torneo",
    ),
    "tipos-premio": (
        "catalogo",
        "tipo_premio",
        "id_tipo_premio",
    ),
    "tipos-arbitro-partido": (
        "catalogo",
        "tipo_arbitro_partido",
        "id_tipo_arbitro_partido",
    ),
    "estados-equipo": (
        "catalogo",
        "estado_equipo",
        "id_estado_equipo",
    ),
    "estados-deporte": (
        "catalogo",
        "estado_deporte",
        "id_estado_deporte",
    ),
    "tipos-documento": (
        "catalogo",
        "tipo_documento",
        "id_tipo_documento",
    ),
    "estados-usuario": (
        "catalogo",
        "estado_usuario",
        "id_estado_usuario",
    ),
    "estados-perfil": (
        "catalogo",
        "estado_perfil_deportivo",
        "id_estado_perfil",
    ),
    "roles-sistema": (
        "seguridad",
        "rol",
        "id_rol",
    ),
}


@router.get(
    "/{nombre_catalogo}",
    response_model=list[CatalogoRespuesta],
    status_code=status.HTTP_200_OK,
    summary="Consultar un catalogo",
)
async def consultar_catalogo(
    conexion: ConexionPostgresql,
    nombre_catalogo: Annotated[
        str,
        Path(
            min_length=2,
            max_length=60,
        ),
    ],
) -> list[CatalogoRespuesta]:
    configuracion = CATALOGOS_PERMITIDOS.get(
        nombre_catalogo
    )

    if configuracion is None:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="El catalogo solicitado no existe",
        )

    esquema, tabla, columna_id = configuracion

    consulta = sql.SQL(
        """
        SELECT
            {columna_id} AS id,
            codigo,
            nombre
        FROM {esquema}.{tabla}
        WHERE activo = TRUE
        ORDER BY nombre
        """
    ).format(
        columna_id=sql.Identifier(columna_id),
        esquema=sql.Identifier(esquema),
        tabla=sql.Identifier(tabla),
    )

    cursor = await conexion.execute(consulta)

    filas = await cursor.fetchall()

    return [
        CatalogoRespuesta.model_validate(fila)
        for fila in filas
    ]