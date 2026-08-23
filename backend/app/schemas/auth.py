from typing import Optional
from pydantic import BaseModel, EmailStr
from app.models.enums import UserRole


class LoginRequest(BaseModel):
    username_or_email: str
    password: str


class RefreshTokenRequest(BaseModel):
    refresh_token: str


class UserInfo(BaseModel):
    id: str
    email: EmailStr
    username: str
    full_name: str
    role: UserRole
    is_active: bool
    is_demo: bool
    school_id: Optional[str] = None
    teacher_id: Optional[str] = None

    class Config:
        from_attributes = True
