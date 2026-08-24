from typing import List, Union
from pydantic import AnyHttpUrl, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    PROJECT_NAME: str = "Teacher Attendance API"
    API_V1_STR: str = "/api/v1"
    ENVIRONMENT: str = "development"
    DEBUG: bool = True

    # Security
    SECRET_KEY: str = "development-secret-key-change-in-production-min-32-chars-long"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 60 * 24 * 30  # 30 days for mobile longevity
    REFRESH_TOKEN_EXPIRE_DAYS: int = 60

    # School & Attendance defaults
    TIMEZONE: str = "Asia/Bishkek"
    DEFAULT_ALLOWED_RADIUS_METERS: float = 80.0
    DEFAULT_MAX_GPS_ACCURACY_METERS: float = 50.0

    # Database
    DATABASE_URL: str = "sqlite+aiosqlite:///./teacher_attendance.db"
    SYNC_DATABASE_URL: str = "sqlite:///./teacher_attendance.db"

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

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=True,
        extra="ignore"
    )


settings = Settings()
