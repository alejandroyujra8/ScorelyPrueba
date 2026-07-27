from functools import lru_cache
from pathlib import Path

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict
from psycopg.conninfo import make_conninfo


BASE_DIR = Path(__file__).resolve().parents[2]


class Configuracion(BaseSettings):
    app_name: str = Field(
        default="Sistema de Gestion de Torneos"
    )
    app_env: str = Field(default="development")
    app_host: str = Field(default="127.0.0.1")
    app_port: int = Field(default=8000)
    frontend_origins: str = Field(
        default=(
            "http://localhost:5173,"
            "http://127.0.0.1:5173"
        )
    )
    jwt_secret: str
    jwt_algorithm: str = Field(default="HS256")

    jwt_expire_minutes: int = Field(
        default=120,
        ge=5,
        le=1440,
    )
    db_host: str = Field(default="localhost")
    db_port: int = Field(default=5432)
    db_name: str = Field(default="sistema_torneos_db")
    db_user: str = Field(default="postgres")
    db_password: str

    db_pool_min_size: int = Field(default=1, ge=1)
    db_pool_max_size: int = Field(default=10, ge=1)
    db_pool_timeout: float = Field(default=10, gt=0)

    model_config = SettingsConfigDict(
        env_file=BASE_DIR / ".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    @property
    def lista_frontend_origins(self) -> list[str]:
        return [
            origen.strip()
            for origen in self.frontend_origins.split(",")
            if origen.strip()
        ]

    @property
    def db_conninfo(self) -> str:
        """
        Construye una cadena de conexion segura para Psycopg.

        make_conninfo se encarga de escapar correctamente valores
        como contrasenias que tengan espacios o caracteres especiales.
        """
        return make_conninfo(
            host=self.db_host,
            port=self.db_port,
            dbname=self.db_name,
            user=self.db_user,
            password=self.db_password,
            application_name="backend_torneos_fastapi",
        )


@lru_cache
def obtener_configuracion() -> Configuracion:
    """
    Devuelve una unica instancia de la configuracion durante
    la ejecucion de la aplicacion.
    """
    return Configuracion()