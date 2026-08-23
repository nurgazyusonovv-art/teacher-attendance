from datetime import datetime, time
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field


class ScheduleBase(BaseModel):
    school_id: Optional[str] = None
    teacher_id: Optional[str] = None
    day_of_week: int = Field(..., ge=0, le=6, description="0=Дүйшөмбү, 6=Жекшемби")
    start_time: time = Field(..., description="Келүү убактысы (мис: 08:00)")
    end_time: time = Field(..., description="Кетүү убактысы (мис: 17:00)")
    grace_minutes: int = Field(5, ge=0, le=60, description="Кечигүүгө жеңилдик мүнөтү")
    is_day_off: bool = Field(False, description="Дем алыш күнбү")


class ScheduleCreate(ScheduleBase):
    pass


class ScheduleUpdate(BaseModel):
    day_of_week: Optional[int] = Field(None, ge=0, le=6)
    start_time: Optional[time] = None
    end_time: Optional[time] = None
    grace_minutes: Optional[int] = Field(None, ge=0, le=60)
    is_day_off: Optional[bool] = None


class ScheduleRead(ScheduleBase):
    id: str
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


class WeeklyScheduleResponse(BaseModel):
    school_id: str
    teacher_id: Optional[str] = None
    schedules: List[ScheduleRead]
