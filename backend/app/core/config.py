from typing import List, Union
from pydantic import field_validator, model_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    PROJECT_NAME: str = "Teacher Attendance API"
    API_V1_STR: str = "/api/v1"
    ENVIRONMENT: str = "development"
    DEBUG: bool = True

    # Security
    SECRET_KEY: str = "development-only-insecure-secret-key"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30
    LOGIN_MAX_FAILED_ATTEMPTS: int = 5
    LOGIN_LOCKOUT_MINUTES: int = 15
    ATTENDANCE_RATE_LIMIT_PER_MINUTE: int = 10

    # School & Attendance defaults
    TIMEZONE: str = "Asia/Bishkek"
    DEFAULT_ALLOWED_RADIUS_METERS: float = 80.0
    DEFAULT_MAX_GPS_ACCURACY_METERS: float = 50.0

    # Database
    DATABASE_URL: str = "sqlite+aiosqlite:///./teacher_attendance.db"
    SYNC_DATABASE_URL: str = "sqlite:///./teacher_attendance.db"
    DB_SSL_REQUIRE: bool = False

    # CORS
    CORS_ORIGINS: List[str] = ["*"]

    @field_validator("CORS_ORIGINS", mode="before")
    @classmethod
    def assemble_cors_origins(cls, v: Union[str, List[str]]) -> List[str]:
        if isinstance(v, str) and not v.startswith("["):
            return [i.strip() for i in v.split(",")]
        elif isinstance(v, (list, str)):
            return v
        raise ValueError(v)

    @model_validator(mode="after")
    def reject_unsafe_production_configuration(self) -> "Settings":
        """Fail closed instead of silently starting production with dev defaults."""
        if self.ENVIRONMENT.lower() != "production":
            return self

        if self.DEBUG:
            raise ValueError("DEBUG must be disabled in production")
        if self.SECRET_KEY == "development-only-insecure-secret-key" or len(self.SECRET_KEY) < 32:
            raise ValueError("A unique SECRET_KEY of at least 32 characters is required in production")
        if self.DATABASE_URL.startswith("sqlite") or self.SYNC_DATABASE_URL.startswith("sqlite"):
            raise ValueError("PostgreSQL DATABASE_URL and SYNC_DATABASE_URL are required in production")
        if "*" in self.CORS_ORIGINS:
            raise ValueError("Wildcard CORS_ORIGINS is not allowed in production")
        return self

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True,
        extra="ignore"
    )


settings = Settings()
