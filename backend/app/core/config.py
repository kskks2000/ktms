from pathlib import Path

from pydantic import SecretStr
from pydantic_settings import BaseSettings, SettingsConfigDict


PROJECT_ROOT = Path(__file__).resolve().parents[3]


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=(PROJECT_ROOT / ".env", ".env"),
        env_file_encoding="utf-8",
        extra="ignore",
    )

    app_env: str = "local"
    ktms_cors_origins: str
    ktms_db_host: str
    ktms_db_port: int = 5432
    ktms_db_name: str
    ktms_db_user: str
    ktms_db_password: SecretStr
    ktms_db_schema: str = "ktms"
    ktms_default_tenant_code: str | None = None
    ktms_default_company_code: str | None = None

    @property
    def cors_origins(self) -> list[str]:
        return [
            origin.strip()
            for origin in self.ktms_cors_origins.split(",")
            if origin.strip()
        ]

    @property
    def db_password(self) -> str:
        return self.ktms_db_password.get_secret_value()


settings = Settings()
