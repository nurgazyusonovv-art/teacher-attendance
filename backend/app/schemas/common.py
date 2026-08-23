from typing import Generic, Optional, TypeVar, Any, Dict
from pydantic import BaseModel
from app.core.errors import ErrorCode

T = TypeVar("T")


class StandardResponse(BaseModel, Generic[T]):
    success: bool = True
    data: Optional[T] = None
    message: Optional[str] = None


class ErrorResponseSchema(BaseModel):
    success: bool = False
    code: ErrorCode
    message: str
    details: Optional[Dict[str, Any]] = None


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int


class TokenPayload(BaseModel):
    sub: str
    type: str
    role: str
    school_id: Optional[str] = None
    teacher_id: Optional[str] = None
    exp: int
