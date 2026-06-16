from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


PROJECT_ROOT = Path(__file__).resolve().parents[3]


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=(PROJECT_ROOT / ".env", ".env"),
        env_file_encoding="utf-8",
        extra="ignore",
    )

    app_env: str = "local"
    cors_origins: list[str] = [
        "http://localhost:3000",
        "http://localhost:5173",
        "http://localhost:8080",
        "http://localhost:8000",
        "http://127.0.0.1:8000",
        "http://www.kcastle.net",
        "https://www.kcastle.net",
        "http://kcastle.net",
        "https://kcastle.net",
    ]
    ktms_db_host: str = "localhost"
    ktms_db_port: int = 5432
    ktms_db_name: str = "postgres"
    ktms_db_user: str = "postgres"
    ktms_db_password: str = ""
    ktms_db_schema: str = "ktms"
    ktms_default_tenant_code: str | None = None
    ktms_default_company_code: str | None = None


settings = Settings()
