from datetime import datetime
from decimal import Decimal

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    field_validator,
)


class InscripcionCrear(BaseModel):
    id_torneo: int = Field(ge=1)
    id_equipo: int = Field(ge=1)

    observaciones: str | None = Field(
        default=None,
        max_length=500,
    )

    model_config = ConfigDict(
        extra="forbid",
    )


class InscripcionRespuesta(BaseModel):
    id_inscripcion: int

    id_torneo: int
    codigo_torneo: str
    torneo: str

    id_equipo: int
    equipo: str
    sigla: str | None

    estado_inscripcion: str

    monto_requerido: Decimal
    moneda: str
    total_pagado: Decimal
    saldo_pendiente: Decimal

    jugadores_nomina: int
    jugadores_habilitados: int

    fecha_inscripcion: datetime
    fecha_actualizacion: datetime


class ListaInscripcionesRespuesta(BaseModel):
    total: int
    resultados: list[InscripcionRespuesta]


class JugadorNominaCrear(BaseModel):
    id_jugador: int = Field(ge=1)

    numero_camiseta: int | None = Field(
        default=None,
        ge=0,
        le=999,
    )

    es_delegado: bool = False
    es_capitan: bool = False

    observaciones: str | None = Field(
        default=None,
        max_length=500,
    )

    model_config = ConfigDict(
        extra="forbid",
    )


class JugadorNominaRespuesta(BaseModel):
    id_jugador_inscripcion: int
    id_inscripcion: int
    id_jugador: int

    numero_documento: str
    nombres: str
    apellido_paterno: str | None
    apellido_materno: str | None

    numero_camiseta: int | None
    es_delegado: bool
    es_capitan: bool

    estado_codigo: str
    fecha_baja: datetime | None
    observaciones: str | None


class PagoCrear(BaseModel):
    metodo_codigo: str = Field(
        min_length=2,
        max_length=40,
        pattern=r"^[A-Z0-9_]+$",
    )

    estado_codigo: str = Field(
        default="PENDIENTE",
        min_length=2,
        max_length=40,
        pattern=r"^[A-Z0-9_]+$",
    )

    monto: Decimal = Field(
        gt=0,
        decimal_places=2,
    )

    referencia: str | None = Field(
        default=None,
        max_length=100,
    )

    observaciones: str | None = Field(
        default=None,
        max_length=500,
    )

    model_config = ConfigDict(
        extra="forbid",
    )

    @field_validator(
        "metodo_codigo",
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
        "referencia",
        "observaciones",
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


class PagoRespuesta(BaseModel):
    id_pago: int
    id_inscripcion: int

    id_torneo: int
    torneo: str

    id_equipo: int
    equipo: str

    metodo_pago: str
    estado_pago: str

    monto: Decimal
    moneda: str
    referencia: str | None

    fecha_pago: datetime
    fecha_verificacion: datetime | None

    id_usuario_registro: int
    registrado_por: str

    id_usuario_verificacion: int | None
    verificado_por: str | None

    observaciones: str | None