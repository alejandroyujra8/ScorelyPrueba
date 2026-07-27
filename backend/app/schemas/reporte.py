from decimal import Decimal
from typing import Any

from pydantic import BaseModel


class DashboardRespuesta(BaseModel):
    total_usuarios: int
    total_equipos: int
    total_jugadores: int
    total_torneos: int
    torneos_en_curso: int
    total_partidos: int
    partidos_finalizados: int
    total_recaudado: Decimal
    premios_entregados: int


class ReporteObjetoRespuesta(BaseModel):
    datos: dict[str, Any]


class ReporteListaRespuesta(BaseModel):
    total: int
    datos: list[dict[str, Any]]