from datetime import datetime

from pydantic import BaseModel


class RespuestaSalud(BaseModel):
    estado: str
    servicio: str


class RespuestaSaludBaseDatos(BaseModel):
    estado: str
    servicio: str

    base_datos: str
    usuario_postgresql: str
    version_postgresql: str
    fecha_hora: datetime