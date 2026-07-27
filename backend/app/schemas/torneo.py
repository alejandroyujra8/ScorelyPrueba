from datetime import date, datetime
from decimal import Decimal
from typing import Self

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    field_validator,
    model_validator,
)


class TorneoCrear(BaseModel):
    id_deporte: int = Field(ge=1)

    formato_codigo: str = Field(
        min_length=2,
        max_length=40,
        pattern=r"^[A-Z0-9_]+$",
    )

    codigo: str = Field(
        min_length=3,
        max_length=40,
        pattern=r"^[A-Z0-9_-]+$",
    )

    nombre: str = Field(
        min_length=4,
        max_length=150,
    )

    edicion: str | None = Field(
        default=None,
        max_length=50,
    )

    categoria: str = Field(
        min_length=2,
        max_length=100,
    )

    rama: str = Field(
        min_length=5,
        max_length=20,
        pattern=r"^(MASCULINO|FEMENINO|MIXTO|ABIERTO)$",
    )

    fecha_inicio_inscripcion: date
    fecha_fin_inscripcion: date
    fecha_inicio_torneo: date
    fecha_fin_torneo: date

    cantidad_maxima_equipos: int = Field(
        ge=2,
        le=128,
    )

    cantidad_minima_jugadores: int = Field(
        ge=1,
        le=100,
    )

    cantidad_maxima_jugadores: int = Field(
        ge=1,
        le=100,
    )

    costo_inscripcion: Decimal = Field(
        default=Decimal("0"),
        ge=0,
    )

    moneda: str = Field(
        default="BOB",
        min_length=3,
        max_length=3,
        pattern=r"^[A-Z]{3}$",
    )

    permite_empate: bool = False

    descripcion: str | None = Field(
        default=None,
        max_length=500,
    )

    model_config = ConfigDict(
        extra="forbid",
    )

    @field_validator(
        "formato_codigo",
        "codigo",
        "rama",
        "moneda",
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
        "edicion",
        "categoria",
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
            return texto or None

        return valor

    @model_validator(mode="after")
    def validar_fechas_y_cantidades(self) -> Self:
        if (
            self.fecha_fin_inscripcion
            < self.fecha_inicio_inscripcion
        ):
            raise ValueError(
                "La fecha final de inscripcion no puede ser "
                "anterior a la fecha inicial"
            )

        if (
            self.fecha_inicio_torneo
            < self.fecha_fin_inscripcion
        ):
            raise ValueError(
                "El torneo no puede comenzar antes del cierre "
                "de inscripciones"
            )

        if (
            self.fecha_fin_torneo
            < self.fecha_inicio_torneo
        ):
            raise ValueError(
                "La fecha final del torneo no puede ser "
                "anterior a la fecha inicial"
            )

        if (
            self.cantidad_maxima_jugadores
            < self.cantidad_minima_jugadores
        ):
            raise ValueError(
                "La cantidad maxima de jugadores no puede ser "
                "menor que la cantidad minima"
            )

        if (
            self.formato_codigo == "PARTIDO_UNICO"
            and self.cantidad_maxima_equipos != 2
        ):
            raise ValueError(
                "Un torneo de partido unico debe permitir "
                "exactamente 2 equipos"
            )

        return self


class TorneoActualizar(BaseModel):
    id_deporte: int | None = Field(default=None, ge=1)
    formato_codigo: str | None = Field(
        default=None,
        min_length=2,
        max_length=40,
        pattern=r"^[A-Z0-9_]+$",
    )
    codigo: str | None = Field(
        default=None,
        min_length=3,
        max_length=40,
        pattern=r"^[A-Z0-9_-]+$",
    )
    nombre: str | None = Field(default=None, min_length=4, max_length=150)
    edicion: str | None = Field(default=None, max_length=50)
    categoria: str | None = Field(default=None, min_length=2, max_length=100)
    rama: str | None = Field(
        default=None,
        min_length=5,
        max_length=20,
        pattern=r"^(MASCULINO|FEMENINO|MIXTO|ABIERTO)$",
    )
    fecha_inicio_inscripcion: date | None = None
    fecha_fin_inscripcion: date | None = None
    fecha_inicio_torneo: date | None = None
    fecha_fin_torneo: date | None = None
    cantidad_maxima_equipos: int | None = Field(default=None, ge=2, le=128)
    cantidad_minima_jugadores: int | None = Field(default=None, ge=1, le=100)
    cantidad_maxima_jugadores: int | None = Field(default=None, ge=1, le=100)
    costo_inscripcion: Decimal | None = Field(default=None, ge=0)
    moneda: str | None = Field(
        default=None,
        min_length=3,
        max_length=3,
        pattern=r"^[A-Z]{3}$",
    )
    permite_empate: bool | None = None
    descripcion: str | None = Field(default=None, max_length=500)

    model_config = ConfigDict(extra="forbid")

    @field_validator(
        "formato_codigo",
        "codigo",
        "rama",
        "moneda",
        mode="before",
    )
    @classmethod
    def convertir_a_mayusculas(cls, valor: object) -> object:
        if isinstance(valor, str):
            texto = valor.strip().upper()
            return texto or None
        return valor

    @field_validator(
        "nombre",
        "edicion",
        "categoria",
        "descripcion",
        mode="before",
    )
    @classmethod
    def limpiar_textos(cls, valor: object) -> object:
        if isinstance(valor, str):
            texto = valor.strip()
            return texto or None
        return valor

    @model_validator(mode="after")
    def validar_actualizacion(self) -> Self:
        if not self.model_fields_set:
            raise ValueError("Debe enviar al menos un campo para actualizar")

        campos_no_nulos = {
            "id_deporte",
            "formato_codigo",
            "codigo",
            "nombre",
            "categoria",
            "rama",
            "fecha_inicio_inscripcion",
            "fecha_fin_inscripcion",
            "fecha_inicio_torneo",
            "fecha_fin_torneo",
            "cantidad_maxima_equipos",
            "cantidad_minima_jugadores",
            "cantidad_maxima_jugadores",
            "costo_inscripcion",
            "moneda",
            "permite_empate",
        }
        for campo in campos_no_nulos:
            if campo in self.model_fields_set and getattr(self, campo) is None:
                raise ValueError(f"El campo {campo} no puede ser nulo")
        return self


class TorneoEstadoActualizar(BaseModel):
    estado_codigo: str = Field(
        min_length=2,
        max_length=40,
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


class TorneoRespuesta(BaseModel):
    id_torneo: int
    id_deporte: int
    formato_codigo: str
    codigo: str
    nombre: str

    edicion: str | None
    categoria: str
    rama: str

    deporte: str
    formato: str
    estado_torneo: str

    fecha_inicio_inscripcion: date
    fecha_fin_inscripcion: date
    fecha_inicio_torneo: date
    fecha_fin_torneo: date

    cantidad_maxima_equipos: int
    cantidad_minima_jugadores: int
    cantidad_maxima_jugadores: int

    costo_inscripcion: Decimal
    moneda: str
    permite_empate: bool
    descripcion: str | None

    total_inscripciones: int
    inscripciones_habilitadas: int
    total_fases: int
    total_partidos: int
    partidos_finalizados: int

    total_recaudado: Decimal


class ListaTorneosRespuesta(BaseModel):
    total: int
    resultados: list[TorneoRespuesta]


class FaseCrear(BaseModel):
    tipo_fase_codigo: str = Field(
        min_length=2,
        max_length=40,
        pattern=r"^[A-Z0-9_]+$",
    )

    nombre: str = Field(
        min_length=2,
        max_length=120,
    )

    numero_orden: int = Field(
        ge=1,
        le=100,
    )

    cantidad_clasificados: int | None = Field(
        default=None,
        ge=1,
        le=128,
    )

    fecha_inicio: date
    fecha_fin: date

    descripcion: str | None = Field(
        default=None,
        max_length=500,
    )

    model_config = ConfigDict(
        extra="forbid",
    )

    @field_validator(
        "tipo_fase_codigo",
        mode="before",
    )
    @classmethod
    def normalizar_tipo(
        cls,
        valor: object,
    ) -> object:
        if isinstance(valor, str):
            return valor.strip().upper()

        return valor

    @model_validator(mode="after")
    def validar_fechas(self) -> Self:
        if self.fecha_fin < self.fecha_inicio:
            raise ValueError(
                "La fecha final de la fase no puede ser "
                "anterior a la fecha inicial"
            )

        return self


class FaseRespuesta(BaseModel):
    id_fase_torneo: int
    id_torneo: int
    tipo_fase: str
    estado_fase: str
    nombre: str
    numero_orden: int
    cantidad_clasificados: int | None
    fecha_inicio: date
    fecha_fin: date
    descripcion: str | None


class JornadaCrear(BaseModel):
    numero_jornada: int = Field(
        ge=1,
        le=1000,
    )

    nombre: str = Field(
        min_length=2,
        max_length=120,
    )

    fecha_inicio: datetime
    fecha_fin: datetime

    observaciones: str | None = Field(
        default=None,
        max_length=500,
    )

    model_config = ConfigDict(
        extra="forbid",
    )

    @model_validator(mode="after")
    def validar_fechas(self) -> Self:
        if self.fecha_fin <= self.fecha_inicio:
            raise ValueError(
                "La fecha final debe ser posterior "
                "a la fecha inicial"
            )

        return self


class JornadaRespuesta(BaseModel):
    id_jornada: int
    id_fase_torneo: int
    estado_jornada: str
    numero_jornada: int
    nombre: str
    fecha_inicio: datetime
    fecha_fin: datetime
    observaciones: str | None


class EstructuraTorneoRespuesta(BaseModel):
    fases: list[FaseRespuesta]
    jornadas: list[JornadaRespuesta]