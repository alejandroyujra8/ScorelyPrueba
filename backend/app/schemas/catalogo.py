from pydantic import BaseModel


class CatalogoRespuesta(BaseModel):
    id: int
    codigo: str
    nombre: str