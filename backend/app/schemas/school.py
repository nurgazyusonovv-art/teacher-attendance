from datetime import datetime, date, time
from typing import Optional
from pydantic import BaseModel, ConfigDict, Field


class SchoolBase(BaseModel):
    name: str = Field(..., min_length=2, max_length=255, description="Мектептин аталышы")
    code: str = Field(..., min_length=2, max_length=50, description="Мектептин уникалдуу коду")
    latitude: float = Field(..., ge=-90.0, le=90.0, description="GPS кеңдик")
    longitude: float = Field(..., ge=-180.0, le=180.0, description="GPS узундук")
    allowed_radius_meters: float = Field(80.0, ge=10.0, le=1000.0, description="Уруксат берилген GPS радиусу (метр)")
    max_accuracy_meters: float = Field(50.0, ge=5.0, le=200.0, description="Максималдуу жол берилген GPS тактыгы")
    default_start_time: time = Field(time(8, 0), description="Жалпы жумуш башталуу убактысы")
    default_end_time: time = Field(time(17, 0), description="Жалпы жумуш аяктоо убактысы")
    grace_minutes: int = Field(5, ge=0, le=60, description="Кечигүүгө берилген жеңилдик убактысы (мүнөт)")
    timezone: str = Field("Asia/Bishkek", description="Мектептин убакыт алкагы")
    telegram_bot_token: Optional[str] = Field(None, description="Telegram Bot Token")
    telegram_chat_id: Optional[str] = Field(None, description="Telegram Chat/Channel ID")
    telegram_enabled: bool = Field(False, description="Telegram отчет жөнөтүү активдүүлүгү")
    telegram_report_time: Optional[time] = Field(time(17, 30), description="Автоматтык отчет убактысы")
    is_active: bool = True


class SchoolCreate(SchoolBase):
    pass


class SchoolUpdate(BaseModel):
    name: Optional[str] = Field(None, min_length=2, max_length=255)
    latitude: Optional[float] = Field(None, ge=-90.0, le=90.0)
    longitude: Optional[float] = Field(None, ge=-180.0, le=180.0)
    allowed_radius_meters: Optional[float] = Field(None, ge=10.0, le=1000.0)
    max_accuracy_meters: Optional[float] = Field(None, ge=5.0, le=200.0)
    default_start_time: Optional[time] = None
    default_end_time: Optional[time] = None
    grace_minutes: Optional[int] = Field(None, ge=0, le=60)
    timezone: Optional[str] = None
    telegram_bot_token: Optional[str] = None
    telegram_chat_id: Optional[str] = None
    telegram_enabled: Optional[bool] = None
    telegram_report_time: Optional[time] = None
    is_active: Optional[bool] = None


class SchoolRead(SchoolBase):
    id: str
    last_telegram_report_sent_date: Optional[date] = None
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)
