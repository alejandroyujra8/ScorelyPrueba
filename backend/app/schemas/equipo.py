from datetime import date
from typing import Self

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    field_validator,
    model_validator,
)


class EquipoBase(BaseModel):
    nombre: str = Field(
        min_length=3,
        max_length=120,
        examples=["Titanes Universitarios"],
    )

    sigla: str = Field(
        min_length=2,
        max_length=15,
        pattern=r"^[A-Z0-9_]+$",
        examples=["TIT"],
    )

    fecha_fundacion: date

    descripcion: str | None = Field(
        default=None,
        max_length=500,
    )

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

    @field_validator(
        "sigla",
        mode="before",
    )
    @classmethod
    def normalizar_sigla(
        cls,
        valor: object,
    ) -> object:
        if isinstance(valor, str):
            return valor.strip().upper()

        return valor

    @model_validator(mode="after")
    def validar_fecha_fundacion(self) -> Self:
        if self.fecha_fundacion > date.today():
            raise ValueError(
                "La fecha de fundacion no puede estar "
                "en el futuro"
            )

        return self


class EquipoCrear(EquipoBase):
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


class EquipoActualizar(BaseModel):
    nombre: str | None = Field(
        default=None,
        min_length=3,
        max_length=120,
    )

    sigla: str | None = Field(
        default=None,
        min_length=2,
        max_length=15,
        pattern=r"^[A-Z0-9_]+$",
    )

    fecha_fundacion: date | None = None

    descripcion: str | None = Field(
        default=None,
        max_length=500,
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
        "sigla",
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
    def validar_actualizacion(self) -> Self:
        if not self.model_fields_set:
            raise ValueError(
                "Debe enviar al menos un campo para actualizar"
            )

        campos_no_nulos = {
            "nombre",
            "sigla",
            "fecha_fundacion",
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

        if (
            self.fecha_fundacion is not None
            and self.fecha_fundacion > date.today()
        ):
            raise ValueError(
                "La fecha de fundacion no puede estar "
                "en el futuro"
            )

        return self


class EquipoRespuesta(BaseModel):
    id_equipo: int
    nombre: str
    sigla: str | None
    fecha_fundacion: date | None
    descripcion: str | None
    estado_codigo: str
    creado_por: int | None


class ListaEquiposRespuesta(BaseModel):
    total: int
    limite: int
    desplazamiento: int
    resultados: list[EquipoRespuesta]