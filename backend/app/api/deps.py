from typing import Optional
from fastapi import Depends, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
import jwt
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from app.db.session import get_db
from app.core.security import decode_token
from app.core.errors import AppException, ErrorCode
from app.models.user import User
from app.models.teacher import Teacher
from app.models.enums import UserRole
from app.models.auth_security import AuthSession
from app.models.school import School
from datetime import datetime, timezone

security_bearer = HTTPBearer(auto_error=False)


async def get_user_school_id(db: AsyncSession, user: User) -> str:
    """Resolve the single school an ordinary user/admin may access."""
    if user.teacher_profile and user.teacher_profile.school_id:
        return user.teacher_profile.school_id
    if user.school_id:
        return user.school_id
    if user.role != UserRole.SUPER_ADMIN:
        raise AppException(
            code=ErrorCode.PERMISSION_DENIED,
            message="Администратор мектепке байланыштырылган эмес.",
            status_code=403,
        )
    result = await db.execute(
        select(School.id)
        .where(School.is_active.is_(True))
        .order_by(School.created_at.asc())
        .limit(1)
    )
    school_id = result.scalar_one_or_none()
    if not school_id:
        raise AppException(
            code=ErrorCode.NOT_FOUND,
            message="Активдүү мектеп табылган жок.",
            status_code=404,
        )
    return school_id


async def ensure_school_access(
    db: AsyncSession, user: User, school_id: str
) -> None:
    if user.role == UserRole.SUPER_ADMIN:
        return
    allowed_school_id = await get_user_school_id(db, user)
    if allowed_school_id != school_id:
        raise AppException(
            code=ErrorCode.PERMISSION_DENIED,
            message="Башка мектептин маалыматына уруксат жок.",
            status_code=403,
        )


async def ensure_teacher_access(
    db: AsyncSession, user: User, teacher_id: str
) -> Teacher:
    result = await db.execute(select(Teacher).where(Teacher.id == teacher_id))
    teacher = result.scalar_one_or_none()
    if not teacher:
        raise AppException(
            code=ErrorCode.TEACHER_NOT_FOUND,
            message="Мугалим табылган жок.",
            status_code=404,
        )
    await ensure_school_access(db, user, teacher.school_id)
    return teacher


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
        session_id = payload.get("sid")
        if not user_id or token_type != "access" or not session_id:
            raise AppException(
                code=ErrorCode.TOKEN_INVALID,
                message="Сессиянын мөөнөтү жараксыз. Кайра кириңиз.",
                status_code=status.HTTP_401_UNAUTHORIZED,
            )
    except jwt.ExpiredSignatureError:
        raise AppException(
            code=ErrorCode.TOKEN_EXPIRED,
            message="Сессиянын мөөнөтү бүттү. Кайра кириңиз.",
            status_code=status.HTTP_401_UNAUTHORIZED,
        )
    except jwt.PyJWTError:
        raise AppException(
            code=ErrorCode.TOKEN_INVALID,
            message="Сессия жараксыз. Кайра кириңиз.",
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

    session_result = await db.execute(
        select(AuthSession).where(
            AuthSession.id == session_id,
            AuthSession.user_id == user.id,
            AuthSession.revoked_at.is_(None),
        )
    )
    auth_session = session_result.scalar_one_or_none()
    if auth_session is None:
        raise AppException(
            code=ErrorCode.TOKEN_INVALID,
            message="Сессия жараксыз. Кайра кириңиз.",
            status_code=status.HTTP_401_UNAUTHORIZED,
        )
    expires_at = auth_session.expires_at
    if expires_at.tzinfo is None:
        expires_at = expires_at.replace(tzinfo=timezone.utc)
    if expires_at <= datetime.now(timezone.utc):
        raise AppException(
            code=ErrorCode.TOKEN_EXPIRED,
            message="Сессиянын мөөнөтү бүттү. Кайра кириңиз.",
            status_code=status.HTTP_401_UNAUTHORIZED,
        )

    setattr(user, "_auth_session_id", session_id)

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
