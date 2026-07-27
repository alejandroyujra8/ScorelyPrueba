from datetime import date
from typing import Self

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    field_validator,
    model_validator,
)


class JugadorCrear(BaseModel):
    id_usuario: int = Field(
        ge=1,
    )

    alias_deportivo: str | None = Field(
        default=None,
        max_length=80,
    )

    observaciones: str | None = Field(
        default=None,
        max_length=500,
    )

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

    @field_validator(
        "alias_deportivo",
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

            if texto == "":
                return None

            return texto

        return valor


class JugadorActualizar(BaseModel):
    alias_deportivo: str | None = Field(
        default=None,
        max_length=80,
    )

    observaciones: str | None = Field(
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

    @field_validator(
        "alias_deportivo",
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

        if (
            "estado_codigo" in self.model_fields_set
            and self.estado_codigo is None
        ):
            raise ValueError(
                "El campo estado_codigo no puede ser nulo"
            )

        return self


class JugadorRespuesta(BaseModel):
    id_jugador: int

    numero_documento: str
    nombres: str
    apellido_paterno: str | None
    apellido_materno: str | None

    alias_deportivo: str | None
    observaciones: str | None
    estado_codigo: str

    id_membresia_actual: int | None
    id_equipo_actual: int | None
    equipo_actual: str | None
    sigla_equipo_actual: str | None

    numero_camiseta_actual: int | None
    posicion_actual: str | None
    es_delegado_actual: bool | None


class ListaJugadoresRespuesta(BaseModel):
    total: int
    limite: int
    desplazamiento: int
    resultados: list[JugadorRespuesta]


class UsuarioJugadorOpcionRespuesta(BaseModel):
    id_usuario: int
    numero_documento: str
    nombre_completo: str
    correo: str


class MembresiaJugadorCrear(BaseModel):
    id_equipo: int = Field(
        ge=1,
    )

    fecha_inicio: date

    numero_camiseta: int | None = Field(
        default=None,
        ge=0,
        le=999,
    )

    posicion: str | None = Field(
        default=None,
        max_length=80,
    )

    es_delegado: bool = False

    observaciones: str | None = Field(
        default=None,
        max_length=500,
    )

    model_config = ConfigDict(
        extra="forbid",
    )

    @field_validator(
        "posicion",
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

            if texto == "":
                return None

            return texto

        return valor

    @model_validator(mode="after")
    def validar_fecha_inicio(self) -> Self:
        if self.fecha_inicio > date.today():
            raise ValueError(
                "La fecha de inicio no puede estar en el futuro"
            )

        return self


class TransferenciaJugadorCrear(BaseModel):
    id_equipo_destino: int = Field(
        ge=1,
    )

    fecha_transferencia: date

    numero_camiseta: int | None = Field(
        default=None,
        ge=0,
        le=999,
    )

    posicion: str | None = Field(
        default=None,
        max_length=80,
    )

    es_delegado: bool = False

    observaciones: str | None = Field(
        default=None,
        max_length=500,
    )

    model_config = ConfigDict(
        extra="forbid",
    )

    @field_validator(
        "posicion",
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

            if texto == "":
                return None

            return texto

        return valor

    @model_validator(mode="after")
    def validar_fecha_transferencia(self) -> Self:
        if self.fecha_transferencia > date.today():
            raise ValueError(
                "La fecha de transferencia no puede estar "
                "en el futuro"
            )

        return self


class MembresiaJugadorFinalizar(BaseModel):
    fecha_fin: date

    observaciones: str | None = Field(
        default=None,
        max_length=500,
    )

    model_config = ConfigDict(
        extra="forbid",
    )

    @field_validator(
        "observaciones",
        mode="before",
    )
    @classmethod
    def limpiar_observaciones(
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
    def validar_fecha_fin(self) -> Self:
        if self.fecha_fin > date.today():
            raise ValueError(
                "La fecha de finalizacion no puede estar "
                "en el futuro"
            )

        return self


class MembresiaJugadorRespuesta(BaseModel):
    id_jugador_equipo: int
    id_jugador: int

    id_equipo: int
    equipo: str
    sigla_equipo: str | None

    fecha_inicio: date
    fecha_fin: date | None

    numero_camiseta: int | None
    posicion: str | None
    es_delegado: bool

    estado_codigo: str
    registrado_por: int | None

    observaciones: str | None


class TransferenciaJugadorRespuesta(BaseModel):
    membresia_anterior: MembresiaJugadorRespuesta
    membresia_nueva: MembresiaJugadorRespuesta