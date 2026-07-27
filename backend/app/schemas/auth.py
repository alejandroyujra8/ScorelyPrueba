from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    field_validator,
)


class LoginEntrada(BaseModel):
    identificador: str = Field(
        min_length=3,
        max_length=150,
        description=(
            "Correo electronico o numero de documento"
        ),
    )

    contrasenia: str = Field(
        min_length=6,
        max_length=128,
    )

    model_config = ConfigDict(
        extra="forbid",
    )

    @field_validator(
        "identificador",
        mode="before",
    )
    @classmethod
    def limpiar_identificador(
        cls,
        valor: object,
    ) -> object:
        if isinstance(valor, str):
            return valor.strip()

        return valor


class UsuarioAutenticadoRespuesta(BaseModel):
    id_usuario: int

    numero_documento: str

    nombres: str
    apellido_paterno: str | None
    apellido_materno: str | None

    correo: str

    estado_codigo: str

    roles: list[str]


class TokenRespuesta(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int

    usuario: UsuarioAutenticadoRespuesta