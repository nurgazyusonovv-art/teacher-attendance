import datetime as _dt
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field


class LessonDelayCreate(BaseModel):
    teacher_id: str = Field(..., description="Мугалимдин IDси")
    date: _dt.date = Field(..., description="Сабак өтүлгөн күн")
    lesson_number: int = Field(..., ge=1, le=12, description="Сабактын тартип номери (1..12)")
    delay_minutes: int = Field(..., ge=1, le=120, description="Кечиккен убактысы (мүнөт)")
    reason: Optional[str] = Field(None, max_length=255, description="Кечигүүнүн себеби")


class LessonDelayRead(BaseModel):
    id: str
    teacher_id: str
    school_id: str
    date: _dt.date
    lesson_number: int
    delay_minutes: int
    reason: Optional[str] = None
    recorded_by_user_id: Optional[str] = None
    teacher_name: Optional[str] = None
    created_at: _dt.datetime

    model_config = ConfigDict(from_attributes=True)


class LessonDelayListResponse(BaseModel):
    items: List[LessonDelayRead]
    total: int
    total_delay_minutes: int
