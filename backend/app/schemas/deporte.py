from datetime import datetime
from typing import Self

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    field_validator,
    model_validator,
)


class DeporteBase(BaseModel):
    codigo: str = Field(
        min_length=2,
        max_length=40,
        pattern=r"^[A-Z0-9_]+$",
        examples=["FUTBOL"],
    )

    nombre: str = Field(
        min_length=3,
        max_length=100,
        examples=["Futbol"],
    )

    descripcion: str | None = Field(
        default=None,
        max_length=500,
    )

    cantidad_minima_jugadores: int = Field(
        ge=1,
        le=100,
    )

    cantidad_maxima_jugadores: int = Field(
        ge=1,
        le=100,
    )

    cantidad_titulares: int = Field(
        ge=1,
        le=100,
    )

    tipo_marcador: str = Field(
        min_length=2,
        max_length=30,
        pattern=r"^[A-Z0-9_]+$",
        examples=["GOL"],
    )

    permite_empate: bool = False

    puntos_victoria: int = Field(
        default=3,
        ge=0,
        le=100,
    )

    puntos_empate: int = Field(
        default=1,
        ge=0,
        le=100,
    )

    puntos_derrota: int = Field(
        default=0,
        ge=0,
        le=100,
    )

    @field_validator(
        "codigo",
        "tipo_marcador",
        mode="before",
    )
    @classmethod
    def convertir_a_mayusculas(
        cls,
        valor: object,
    ) -> object:
        if isinstance(valor, str):
            return valor.strip().upper()

        return valor

    @field_validator(
        "nombre",
        "descripcion",
        mode="before",
    )
    @classmethod
    def limpiar_textos(
        cls,
        valor: object,
    ) -> object:
        if isinstance(valor, str):
            texto = valor.strip()

            if texto == "":
                return None

            return texto

        return valor

    @model_validator(mode="after")
    def validar_cantidades(self) -> Self:
        if (
            self.cantidad_maxima_jugadores
            < self.cantidad_minima_jugadores
        ):
            raise ValueError(
                "La cantidad maxima no puede ser menor "
                "que la cantidad minima"
            )

        if (
            self.cantidad_titulares
            < self.cantidad_minima_jugadores
        ):
            raise ValueError(
                "La cantidad de titulares no puede ser menor "
                "que la cantidad minima de jugadores"
            )

        if (
            self.cantidad_titulares
            > self.cantidad_maxima_jugadores
        ):
            raise ValueError(
                "La cantidad de titulares no puede superar "
                "la cantidad maxima de jugadores"
            )

        return self


class DeporteCrear(DeporteBase):
    estado_codigo: str = Field(
        default="ACTIVO",
        min_length=2,
        max_length=30,
        pattern=r"^[A-Z0-9_]+$",
    )

    model_config = ConfigDict(
        extra="forbid",
    )

    @field_validator(
        "estado_codigo",
        mode="before",
    )
    @classmethod
    def normalizar_estado(
        cls,
        valor: object,
    ) -> object:
        if isinstance(valor, str):
            return valor.strip().upper()

        return valor


class DeporteActualizar(BaseModel):
    codigo: str | None = Field(
        default=None,
        min_length=2,
        max_length=40,
        pattern=r"^[A-Z0-9_]+$",
    )

    nombre: str | None = Field(
        default=None,
        min_length=3,
        max_length=100,
    )

    descripcion: str | None = Field(
        default=None,
        max_length=500,
    )

    cantidad_minima_jugadores: int | None = Field(
        default=None,
        ge=1,
        le=100,
    )

    cantidad_maxima_jugadores: int | None = Field(
        default=None,
        ge=1,
        le=100,
    )

    cantidad_titulares: int | None = Field(
        default=None,
        ge=1,
        le=100,
    )

    tipo_marcador: str | None = Field(
        default=None,
        min_length=2,
        max_length=30,
        pattern=r"^[A-Z0-9_]+$",
    )

    permite_empate: bool | None = None

    puntos_victoria: int | None = Field(
        default=None,
        ge=0,
        le=100,
    )

    puntos_empate: int | None = Field(
        default=None,
        ge=0,
        le=100,
    )

    puntos_derrota: int | None = Field(
        default=None,
        ge=0,
        le=100,
    )

    estado_codigo: str | None = Field(
        default=None,
        min_length=2,
        max_length=30,
        pattern=r"^[A-Z0-9_]+$",
    )

    model_config = ConfigDict(
        extra="forbid",
    )

    @field_validator(
        "codigo",
        "tipo_marcador",
        "estado_codigo",
        mode="before",
    )
    @classmethod
    def convertir_a_mayusculas(
        cls,
        valor: object,
    ) -> object:
        if isinstance(valor, str):
            return valor.strip().upper()

        return valor

    @field_validator(
        "nombre",
        "descripcion",
        mode="before",
    )
    @classmethod
    def limpiar_textos(
        cls,
        valor: object,
    ) -> object:
        if isinstance(valor, str):
            texto = valor.strip()

            if texto == "":
                return None

            return texto

        return valor

    @model_validator(mode="after")
    def validar_campos_enviados(self) -> Self:
        if not self.model_fields_set:
            raise ValueError(
                "Debe enviar al menos un campo para actualizar"
            )

        campos_no_nulos = {
            "codigo",
            "nombre",
            "cantidad_minima_jugadores",
            "cantidad_maxima_jugadores",
            "cantidad_titulares",
            "tipo_marcador",
            "permite_empate",
            "puntos_victoria",
            "puntos_empate",
            "puntos_derrota",
            "estado_codigo",
        }

        for campo in campos_no_nulos:
            if (
                campo in self.model_fields_set
                and getattr(self, campo) is None
            ):
                raise ValueError(
                    f"El campo {campo} no puede ser nulo"
                )

        return self


class DeporteRespuesta(BaseModel):
    id_deporte: int
    codigo: str
    nombre: str
    descripcion: str | None

    cantidad_minima_jugadores: int
    cantidad_maxima_jugadores: int
    cantidad_titulares: int

    tipo_marcador: str
    permite_empate: bool

    puntos_victoria: int
    puntos_empate: int
    puntos_derrota: int

    estado_codigo: str
    fecha_registro: datetime


class ListaDeportesRespuesta(BaseModel):
    total: int
    limite: int
    desplazamiento: int
    resultados: list[DeporteRespuesta]