from typing import Any, Literal

from pydantic import (
    BaseModel,
    Field,
    field_validator,
)


class SqlLabEjecutarSolicitud(BaseModel):
    script: str = Field(
        min_length=1,
        max_length=50_000,
        description=(
            "Script SQL que se ejecutará dentro de una "
            "transacción simulada."
        ),
    )

    @field_validator("script")
    @classmethod
    def validar_script_no_vacio(
        cls,
        valor: str,
    ) -> str:
        script_limpio = valor.strip()

        if not script_limpio:
            raise ValueError(
                "El script SQL no puede estar vacío"
            )

        if "\x00" in script_limpio:
            raise ValueError(
                "El script contiene caracteres no permitidos"
            )

        return script_limpio


class SqlLabResultadoConjunto(BaseModel):
    indice: int
    comando: str

    columnas: list[str] = Field(
        default_factory=list
    )

    filas: list[dict[str, Any]] = Field(
        default_factory=list
    )

    cantidad_filas: int = 0
    filas_truncadas: bool = False

    mensaje: str | None = None


class SqlLabEjecutarRespuesta(BaseModel):
    exito: bool = True

    modo: Literal[
        "SIMULACION_ROLLBACK"
    ] = "SIMULACION_ROLLBACK"

    tiempo_ms: float

    resultados: list[
        SqlLabResultadoConjunto
    ] = Field(
        default_factory=list
    )

    mensajes: list[str] = Field(
        default_factory=list
    )


class SqlLabTriggerRespuesta(BaseModel):
    esquema: str
    tabla: str
    nombre: str
    habilitado: str
    funcion_esquema: str
    funcion_nombre: str
    definicion: str
    sql_inspeccion: str


class SqlLabCursorRespuesta(BaseModel):
    esquema: str
    rutina: str
    tipo_rutina: str
    argumentos: str
    cursores: list[str] = Field(default_factory=list)
    definicion: str
    sql_inspeccion: str


class SqlLabObjetosRespuesta(BaseModel):
    triggers: list[SqlLabTriggerRespuesta] = Field(default_factory=list)
    cursores: list[SqlLabCursorRespuesta] = Field(default_factory=list)
