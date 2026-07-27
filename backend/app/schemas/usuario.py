from datetime import date, datetime
from typing import Self

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    field_validator,
    model_validator,
)


ROLES_SISTEMA = {
    "ADMINISTRADOR",
    "ORGANIZADOR",
    "ARBITRO",
    "JUGADOR",
    "CONSULTA",
}


class UsuarioCrear(BaseModel):
    tipo_documento_codigo: str = Field(
        default="CI",
        min_length=2,
        max_length=30,
        pattern=r"^[A-Z0-9_]+$",
    )
    numero_documento: str = Field(min_length=4, max_length=30)
    nombres: str = Field(min_length=2, max_length=100)
    apellido_paterno: str | None = Field(default=None, max_length=80)
    apellido_materno: str | None = Field(default=None, max_length=80)
    fecha_nacimiento: date
    sexo: str | None = Field(default=None, pattern=r"^[MFON]$")
    correo: str = Field(
        min_length=6,
        max_length=150,
        pattern=r"(?i)^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$",
    )
    telefono: str | None = Field(
        default=None,
        max_length=20,
        pattern=r"^\+?[0-9]{7,15}$",
    )
    direccion: str | None = Field(default=None, max_length=200)
    zona: str | None = Field(default=None, max_length=100)
    contrasenia: str = Field(min_length=8, max_length=128)
    estado_codigo: str = Field(
        default="ACTIVO",
        min_length=2,
        max_length=30,
        pattern=r"^[A-Z0-9_]+$",
    )
    roles: list[str] = Field(default_factory=list, max_length=5)

    model_config = ConfigDict(extra="forbid")

    @field_validator(
        "tipo_documento_codigo",
        "estado_codigo",
        "sexo",
        mode="before",
    )
    @classmethod
    def convertir_a_mayusculas(cls, valor: object) -> object:
        if isinstance(valor, str):
            texto = valor.strip().upper()
            return texto or None
        return valor

    @field_validator("roles", mode="before")
    @classmethod
    def normalizar_roles(cls, valor: object) -> object:
        if not isinstance(valor, list):
            return valor
        return sorted(
            {
                str(rol).strip().upper()
                for rol in valor
                if str(rol).strip()
            }
        )

    @field_validator(
        "numero_documento",
        "nombres",
        "apellido_paterno",
        "apellido_materno",
        "correo",
        "telefono",
        "direccion",
        "zona",
        mode="before",
    )
    @classmethod
    def limpiar_textos(cls, valor: object) -> object:
        if isinstance(valor, str):
            texto = valor.strip()
            return texto or None
        return valor

    @model_validator(mode="after")
    def validar_usuario(self) -> Self:
        if self.fecha_nacimiento < date(1900, 1, 1):
            raise ValueError("La fecha de nacimiento no puede ser anterior a 1900")
        if self.fecha_nacimiento > date.today():
            raise ValueError("La fecha de nacimiento no puede estar en el futuro")

        roles_invalidos = set(self.roles) - ROLES_SISTEMA
        if roles_invalidos:
            raise ValueError(
                "Los roles no son válidos: "
                + ", ".join(sorted(roles_invalidos))
            )

        if self.estado_codigo == "ACTIVO" and not self.roles:
            raise ValueError("Un usuario activo debe tener al menos un rol")

        return self


class UsuarioActualizar(BaseModel):
    tipo_documento_codigo: str | None = Field(
        default=None,
        min_length=2,
        max_length=30,
        pattern=r"^[A-Z0-9_]+$",
    )
    numero_documento: str | None = Field(default=None, min_length=4, max_length=30)
    nombres: str | None = Field(default=None, min_length=2, max_length=100)
    apellido_paterno: str | None = Field(default=None, max_length=80)
    apellido_materno: str | None = Field(default=None, max_length=80)
    fecha_nacimiento: date | None = None
    sexo: str | None = Field(default=None, pattern=r"^[MFON]$")
    correo: str | None = Field(
        default=None,
        min_length=6,
        max_length=150,
        pattern=r"(?i)^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$",
    )
    telefono: str | None = Field(
        default=None,
        max_length=20,
        pattern=r"^\+?[0-9]{7,15}$",
    )
    direccion: str | None = Field(default=None, max_length=200)
    zona: str | None = Field(default=None, max_length=100)
    estado_codigo: str | None = Field(
        default=None,
        min_length=2,
        max_length=30,
        pattern=r"^[A-Z0-9_]+$",
    )
    roles: list[str] | None = Field(default=None, max_length=5)

    model_config = ConfigDict(extra="forbid")

    @field_validator(
        "tipo_documento_codigo",
        "estado_codigo",
        "sexo",
        mode="before",
    )
    @classmethod
    def convertir_a_mayusculas(cls, valor: object) -> object:
        if isinstance(valor, str):
            texto = valor.strip().upper()
            return texto or None
        return valor

    @field_validator("roles", mode="before")
    @classmethod
    def normalizar_roles(cls, valor: object) -> object:
        if valor is None or not isinstance(valor, list):
            return valor
        return sorted(
            {
                str(rol).strip().upper()
                for rol in valor
                if str(rol).strip()
            }
        )

    @field_validator(
        "numero_documento",
        "nombres",
        "apellido_paterno",
        "apellido_materno",
        "correo",
        "telefono",
        "direccion",
        "zona",
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
            "tipo_documento_codigo",
            "numero_documento",
            "nombres",
            "fecha_nacimiento",
            "correo",
            "estado_codigo",
        }
        for campo in campos_no_nulos:
            if campo in self.model_fields_set and getattr(self, campo) is None:
                raise ValueError(f"El campo {campo} no puede ser nulo")

        if self.fecha_nacimiento is not None:
            if self.fecha_nacimiento < date(1900, 1, 1):
                raise ValueError("La fecha de nacimiento no puede ser anterior a 1900")
            if self.fecha_nacimiento > date.today():
                raise ValueError("La fecha de nacimiento no puede estar en el futuro")

        if self.roles is not None:
            roles_invalidos = set(self.roles) - ROLES_SISTEMA
            if roles_invalidos:
                raise ValueError(
                    "Los roles no son válidos: "
                    + ", ".join(sorted(roles_invalidos))
                )

        return self


class UsuarioContraseniaActualizar(BaseModel):
    contrasenia: str = Field(min_length=8, max_length=128)

    model_config = ConfigDict(extra="forbid")


class UsuarioRespuesta(BaseModel):
    id_usuario: int
    tipo_documento_codigo: str
    numero_documento: str
    nombres: str
    apellido_paterno: str | None
    apellido_materno: str | None
    fecha_nacimiento: date
    sexo: str | None
    correo: str
    telefono: str | None
    direccion: str | None
    zona: str | None
    estado_codigo: str
    intentos_fallidos: int
    ultimo_acceso: datetime | None
    fecha_registro: datetime
    fecha_actualizacion: datetime
    roles: list[str]


class ListaUsuariosRespuesta(BaseModel):
    total: int
    limite: int
    desplazamiento: int
    resultados: list[UsuarioRespuesta]
