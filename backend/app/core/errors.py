from enum import Enum
from typing import Any, Dict, Optional
from fastapi import HTTPException, status
from pydantic import BaseModel


class ErrorCode(str, Enum):
    # Location & Geofence errors
    LOCATION_OUTSIDE_SCHOOL = "LOCATION_OUTSIDE_SCHOOL"
    LOCATION_ACCURACY_TOO_LOW = "LOCATION_ACCURACY_TOO_LOW"
    LOCATION_REQUIRED = "LOCATION_REQUIRED"

    # QR & Credential errors
    QR_INVALID = "QR_INVALID"
    QR_EXPIRED = "QR_EXPIRED"
    QR_DISABLED = "QR_DISABLED"
    QR_WRONG_SCHOOL = "QR_WRONG_SCHOOL"

    # Attendance business logic errors
    ALREADY_CHECKED_IN = "ALREADY_CHECKED_IN"
    ALREADY_CHECKED_OUT = "ALREADY_CHECKED_OUT"
    NO_CHECK_IN_FOUND = "NO_CHECK_IN_FOUND"
    NO_SCHEDULE = "NO_SCHEDULE"
    DAY_OFF = "DAY_OFF"

    # Auth & Permissions
    UNAUTHORIZED = "UNAUTHORIZED"
    PERMISSION_DENIED = "PERMISSION_DENIED"
    USER_NOT_FOUND = "USER_NOT_FOUND"
    USER_INACTIVE = "USER_INACTIVE"
    TEACHER_NOT_FOUND = "TEACHER_NOT_FOUND"
    TEACHER_INACTIVE = "TEACHER_INACTIVE"
    INVALID_CREDENTIALS = "INVALID_CREDENTIALS"
    TOKEN_EXPIRED = "TOKEN_EXPIRED"
    TOKEN_INVALID = "TOKEN_INVALID"

    # General
    NOT_FOUND = "NOT_FOUND"
    VALIDATION_ERROR = "VALIDATION_ERROR"
    INTERNAL_SERVER_ERROR = "INTERNAL_SERVER_ERROR"


class ErrorResponse(BaseModel):
    code: ErrorCode
    message: str
    details: Optional[Dict[str, Any]] = None


class AppException(HTTPException):
    def __init__(
        self,
        code: ErrorCode,
        message: str,
        status_code: int = status.HTTP_400_BAD_REQUEST,
        details: Optional[Dict[str, Any]] = None,
        headers: Optional[Dict[str, str]] = None,
    ):
        super().__init__(status_code=status_code, detail=message, headers=headers)
        self.code = code
        self.message = message
        self.details = details or {}
