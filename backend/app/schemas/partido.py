from datetime import datetime
from decimal import Decimal
from typing import Any, Self

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    field_validator,
    model_validator,
)


class PartidoCrear(BaseModel):
    id_jornada: int = Field(ge=1)
    id_lugar: int = Field(ge=1)

    codigo: str = Field(
        min_length=3,
        max_length=50,
        pattern=r"^[A-Z0-9_-]+$",
    )

    numero_partido: int = Field(
        ge=1,
        le=10000,
    )

    fecha_hora_inicio: datetime
    fecha_hora_fin: datetime

    id_inscripcion_local: int = Field(ge=1)
    id_inscripcion_visitante: int = Field(ge=1)

    id_grupo_torneo: int | None = Field(
        default=None,
        ge=1,
    )

    nombre_ronda: str | None = Field(
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
        "codigo",
        mode="before",
    )
    @classmethod
    def normalizar_codigo(
        cls,
        valor: object,
    ) -> object:
        if isinstance(valor, str):
            return valor.strip().upper()

        return valor

    @field_validator(
        "nombre_ronda",
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

    @model_validator(mode="after")
    def validar_partido(self) -> Self:
        if self.fecha_hora_fin <= self.fecha_hora_inicio:
            raise ValueError(
                "La fecha final debe ser posterior "
                "a la fecha inicial"
            )

        if (
            self.id_inscripcion_local
            == self.id_inscripcion_visitante
        ):
            raise ValueError(
                "Un equipo no puede jugar contra si mismo"
            )

        return self


class PartidoRespuesta(BaseModel):
    id_partido: int
    codigo: str
    numero_partido: int
    nombre_ronda: str | None

    id_torneo: int
    torneo: str

    fase: str
    numero_jornada: int
    jornada: str

    grupo: str | None

    lugar: str | None
    direccion_lugar: str | None

    fecha_hora_inicio: datetime
    fecha_hora_fin: datetime

    estado_partido: str
    arbitro_actual_asignado: bool = False

    id_inscripcion_local: int | None
    equipo_local: str | None
    marcador_local: int | None
    desempate_local: int | None
    resultado_local: str | None

    id_inscripcion_visitante: int | None
    equipo_visitante: str | None
    marcador_visitante: int | None
    desempate_visitante: int | None
    resultado_visitante: str | None

    observaciones: str | None


class ListaPartidosRespuesta(BaseModel):
    total: int
    resultados: list[PartidoRespuesta]


class ArbitroAsignar(BaseModel):
    id_arbitro: int = Field(ge=1)

    tipo_arbitro: str = Field(
        default="PRINCIPAL",
        min_length=2,
        max_length=40,
        pattern=r"^[A-Z0-9_]+$",
    )

    observaciones: str | None = Field(
        default=None,
        max_length=500,
    )

    model_config = ConfigDict(
        extra="forbid",
    )

    @field_validator(
        "tipo_arbitro",
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


class ParticipacionJugadorCrear(BaseModel):
    id_jugador_inscripcion: int = Field(ge=1)

    convocado: bool = True
    asistio: bool = True
    titular: bool = False

    minutos_jugados: int = Field(
        default=0,
        ge=0,
        le=1000,
    )

    puntos_anotados: int = Field(
        default=0,
        ge=0,
    )

    faltas: int = Field(
        default=0,
        ge=0,
        le=100,
    )

    amonestaciones: int = Field(
        default=0,
        ge=0,
        le=100,
    )

    expulsado: bool = False
    lesionado: bool = False

    calificacion: Decimal | None = Field(
        default=None,
        ge=0,
        le=10,
    )

    estadisticas: dict[str, Any] = Field(
        default_factory=dict,
    )

    observaciones: str | None = Field(
        default=None,
        max_length=500,
    )

    model_config = ConfigDict(
        extra="forbid",
    )

    @model_validator(mode="after")
    def validar_participacion(self) -> Self:
        if self.titular and not self.asistio:
            raise ValueError(
                "Un jugador titular debe haber asistido"
            )

        if self.asistio and not self.convocado:
            raise ValueError(
                "Un jugador que asistio debe estar convocado"
            )

        if not self.asistio and self.minutos_jugados > 0:
            raise ValueError(
                "Un jugador ausente no puede tener "
                "minutos jugados"
            )

        return self


class ParticipacionJugadorRespuesta(BaseModel):
    id_jugador_partido: int

    id_torneo: int
    torneo: str

    id_partido: int
    partido: str

    id_equipo: int
    equipo: str

    id_jugador: int
    numero_documento: str
    nombres: str
    apellido_paterno: str | None
    apellido_materno: str | None

    convocado: bool
    asistio: bool
    titular: bool

    minutos_jugados: int
    puntos_anotados: int
    faltas: int
    amonestaciones: int

    expulsado: bool
    lesionado: bool

    calificacion: Decimal | None
    estadisticas: dict[str, Any] | None

    fecha_actualizacion: datetime


class PartidoFinalizar(BaseModel):
    marcador_local: int = Field(ge=0)
    marcador_visitante: int = Field(ge=0)

    desempate_local: int | None = Field(
        default=None,
        ge=0,
    )

    desempate_visitante: int | None = Field(
        default=None,
        ge=0,
    )

    observaciones: str | None = Field(
        default=None,
        max_length=500,
    )

    model_config = ConfigDict(
        extra="forbid",
    )

    @model_validator(mode="after")
    def validar_desempate(self) -> Self:
        uno_es_nulo = (
            self.desempate_local is None
            or self.desempate_visitante is None
        )

        ambos_son_nulos = (
            self.desempate_local is None
            and self.desempate_visitante is None
        )

        if uno_es_nulo and not ambos_son_nulos:
            raise ValueError(
                "Debe enviar los dos marcadores de desempate"
            )

        return self


class LugarOpcionRespuesta(BaseModel):
    id_lugar: int
    nombre: str
    direccion: str
    zona: str | None
    ciudad: str
    capacidad: int | None
    tipo_superficie: str | None


class ArbitroOpcionRespuesta(BaseModel):
    id_arbitro: int
    numero_licencia: str | None
    nombre_completo: str
    nivel: str | None


class OperacionPartidoRespuesta(BaseModel):
    mensaje: str
    id_partido: int