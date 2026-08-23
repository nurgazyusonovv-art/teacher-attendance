from typing import AsyncGenerator, Optional
from fastapi import Depends, Header, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import jwt
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from app.db.session import get_db
from app.core.config import settings
from app.core.security import decode_token
from app.core.errors import AppException, ErrorCode
from app.models.user import User
from app.models.teacher import Teacher
from app.models.enums import UserRole

security_bearer = HTTPBearer(auto_error=False)


async def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security_bearer),
    db: AsyncSession = Depends(get_db),
) -> User:
    """Extracts and validates current User from Authorization Bearer token."""
    if not credentials or not credentials.credentials:
        raise AppException(
            code=ErrorCode.UNAUTHORIZED,
            message="Authentication credentials required",
            status_code=status.HTTP_401_UNAUTHORIZED,
            headers={"WWW-Authenticate": "Bearer"},
        )

    try:
        payload = decode_token(credentials.credentials)
        user_id = payload.get("sub")
        token_type = payload.get("type")
        if not user_id or token_type != "access":
            raise AppException(
                code=ErrorCode.TOKEN_INVALID,
                message="Invalid access token",
                status_code=status.HTTP_401_UNAUTHORIZED,
            )
    except jwt.ExpiredSignatureError:
        raise AppException(
            code=ErrorCode.TOKEN_EXPIRED,
            message="Token has expired. Please refresh your session.",
            status_code=status.HTTP_401_UNAUTHORIZED,
        )
    except jwt.PyJWTError:
        raise AppException(
            code=ErrorCode.TOKEN_INVALID,
            message="Could not validate credentials",
            status_code=status.HTTP_401_UNAUTHORIZED,
        )

    from sqlalchemy.orm import selectinload

    stmt = select(User).options(selectinload(User.teacher_profile)).where(User.id == user_id)
    result = await db.execute(stmt)
    user = result.scalar_one_or_none()

    if not user:
        raise AppException(
            code=ErrorCode.USER_NOT_FOUND,
            message="User account not found",
            status_code=status.HTTP_404_NOT_FOUND,
        )

    if not user.is_active:
        raise AppException(
            code=ErrorCode.USER_INACTIVE,
            message="User account is deactivated. Contact administrator.",
            status_code=status.HTTP_403_FORBIDDEN,
        )

    return user


async def get_current_active_admin(
    current_user: User = Depends(get_current_user),
) -> User:
    """Ensures current user has ADMIN or SUPER_ADMIN role."""
    if current_user.role not in [UserRole.ADMIN, UserRole.SUPER_ADMIN]:
        raise AppException(
            code=ErrorCode.PERMISSION_DENIED,
            message="Administrator privileges required for this action.",
            status_code=status.HTTP_403_FORBIDDEN,
        )
    return current_user


async def get_current_active_teacher(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
) -> Teacher:
    """Ensures current user is an active Teacher and returns the Teacher profile."""
    if current_user.role != UserRole.TEACHER:
        raise AppException(
            code=ErrorCode.PERMISSION_DENIED,
            message="Teacher profile required.",
            status_code=status.HTTP_403_FORBIDDEN,
        )

    stmt = select(Teacher).options(selectinload(Teacher.user)).where(Teacher.user_id == current_user.id)
    result = await db.execute(stmt)
    teacher = result.scalar_one_or_none()

    if not teacher or not teacher.is_active:
        raise AppException(
            code=ErrorCode.TEACHER_INACTIVE,
            message="Teacher profile is not active.",
            status_code=status.HTTP_403_FORBIDDEN,
        )

    return teacher
