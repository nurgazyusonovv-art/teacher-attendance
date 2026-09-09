from datetime import date, datetime
from typing import Literal
from pydantic import BaseModel, ConfigDict, Field


class LeaveCreate(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True, extra='forbid')
    target_date: date
    reason: str = Field(min_length=5, max_length=500)


class LeaveDecision(BaseModel):
    model_config = ConfigDict(str_strip_whitespace=True, extra='forbid')
    status: Literal['APPROVED', 'REJECTED']
    reason: str = Field(min_length=5, max_length=500)


class LeaveRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: str
    teacher_id: str
    teacher_name: str | None = None
    target_date: date
    reason: str
    status: Literal['PENDING', 'APPROVED', 'REJECTED']
    decision_reason: str | None = None
    reviewed_at: datetime | None = None
    created_at: datetime
