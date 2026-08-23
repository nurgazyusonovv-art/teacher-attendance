from datetime import datetime
from typing import List, Optional
from pydantic import BaseModel, ConfigDict, Field


class TeacherCreate(BaseModel):
    full_name: str = Field(..., min_length=2, max_length=255, description="Аты-жөнү")
    username: str = Field(..., min_length=3, max_length=100, description="Логин")
    password: str = Field(..., min_length=6, description="Сырсөз")
    employee_code: str = Field(..., min_length=2, max_length=50, description="Табель/кызматкер номери")
    phone_number: Optional[str] = Field(None, max_length=50, description="Телефон номери")
    subject: Optional[str] = Field(None, max_length=100, description="Окуткан предмети")
    school_id: Optional[str] = Field(None, description="Мектептин IDси")


class TeacherUpdate(BaseModel):
    full_name: Optional[str] = Field(None, min_length=2, max_length=255)
    employee_code: Optional[str] = Field(None, min_length=2, max_length=50)
    phone_number: Optional[str] = Field(None, max_length=50)
    subject: Optional[str] = Field(None, max_length=100)
    password: Optional[str] = Field(None, min_length=6)
    is_active: Optional[bool] = None


class TeacherRead(BaseModel):
    id: str
    user_id: str
    school_id: str
    employee_code: str
    phone_number: Optional[str]
    subject: Optional[str]
    full_name: str
    username: str
    is_active: bool
    is_demo: bool
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class TeacherListResponse(BaseModel):
    items: List[TeacherRead]
    total: int
