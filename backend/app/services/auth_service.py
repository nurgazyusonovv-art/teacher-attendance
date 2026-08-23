from datetime import datetime, timezone
from typing import Optional, Tuple
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, or_
from sqlalchemy.orm import selectinload
from app.core.security import (
    verify_password,
    get_password_hash,
    create_access_token,
    create_refresh_token,
    decode_token,
)
from app.core.config import settings
from app.core.errors import AppException, ErrorCode
from app.models.user import User
from app.models.teacher import Teacher
from app.models.school import School
from app.schemas.auth import LoginRequest, UserInfo
from app.schemas.common import TokenResponse


class AuthService:
    @classmethod
    async def authenticate_user(
        cls,
        db: AsyncSession,
        login_data: LoginRequest,
    ) -> Tuple[TokenResponse, UserInfo]:
        """
        Authenticates a user by username or email and returns access/refresh tokens along with user info.
        """
        # Find user by username or email
        stmt = (
            select(User)
            .options(
                selectinload(User.teacher_profile).selectinload(Teacher.school)
            )
            .where(
                or_(
                    User.username == login_data.username_or_email.strip(),
                    User.email == login_data.username_or_email.strip().lower(),
                )
            )
        )
        result = await db.execute(stmt)
        user = result.scalar_one_or_none()

        if not user:
            raise AppException(
                code=ErrorCode.INVALID_CREDENTIALS,
                message="Колдонуучу аты же сырсөз туура эмес.",
                status_code=400,
            )

        if not verify_password(login_data.password, user.hashed_password):
            raise AppException(
                code=ErrorCode.INVALID_CREDENTIALS,
                message="Колдонуучу аты же сырсөз туура эмес.",
                status_code=400,
            )

        if not user.is_active:
            raise AppException(
                code=ErrorCode.USER_INACTIVE,
                message="Сиздин аккаунтуңуз активдүү эмес. Администраторго кайрылыңыз.",
                status_code=403,
            )

        # If user is a teacher, verify teacher profile is active
        teacher_id: Optional[str] = None
        school_id: Optional[str] = None

        if user.teacher_profile:
            if not user.teacher_profile.is_active:
                raise AppException(
                    code=ErrorCode.TEACHER_INACTIVE,
                    message="Мугалимдик профилиңиз өчүрүлгөн.",
                    status_code=403,
                )
            teacher_id = user.teacher_profile.id
            school_id = user.teacher_profile.school_id

        # Generate tokens
        access_token = create_access_token(
            subject=user.id,
            role=user.role.value if hasattr(user.role, "value") else str(user.role),
            school_id=school_id,
            teacher_id=teacher_id,
        )
        refresh_token = create_refresh_token(subject=user.id)

        token_response = TokenResponse(
            access_token=access_token,
            refresh_token=refresh_token,
            token_type="bearer",
            expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
        )

        user_info = UserInfo(
            id=user.id,
            email=user.email,
            username=user.username,
            full_name=user.full_name,
            role=user.role,
            is_active=user.is_active,
            is_demo=user.is_demo,
            school_id=school_id,
            teacher_id=teacher_id,
        )

        return token_response, user_info

    @classmethod
    async def refresh_tokens(
        cls,
        db: AsyncSession,
        refresh_token: str,
    ) -> TokenResponse:
        """
        Validates refresh token and issues a new access token and fresh refresh token.
        """
        try:
            payload = decode_token(refresh_token)
            user_id = payload.get("sub")
            token_type = payload.get("type")
            if not user_id or token_type != "refresh":
                raise AppException(
                    code=ErrorCode.TOKEN_INVALID,
                    message="Жараксыз refresh token.",
                    status_code=401,
                )
        except Exception:
            raise AppException(
                code=ErrorCode.TOKEN_EXPIRED,
                message="Сессиянын мөөнөтү бүттү. Кайра кириңиз.",
                status_code=401,
            )

        stmt = (
            select(User)
            .options(selectinload(User.teacher_profile))
            .where(User.id == user_id)
        )
        result = await db.execute(stmt)
        user = result.scalar_one_or_none()

        if not user or not user.is_active:
            raise AppException(
                code=ErrorCode.USER_INACTIVE,
                message="Колдонуучу активдүү эмес.",
                status_code=403,
            )

        teacher_id = user.teacher_profile.id if user.teacher_profile else None
        school_id = user.teacher_profile.school_id if user.teacher_profile else None

        access_token = create_access_token(
            subject=user.id,
            role=user.role.value if hasattr(user.role, "value") else str(user.role),
            school_id=school_id,
            teacher_id=teacher_id,
        )
        new_refresh_token = create_refresh_token(subject=user.id)

        return TokenResponse(
            access_token=access_token,
            refresh_token=new_refresh_token,
            token_type="bearer",
            expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
        )

    @classmethod
    async def get_current_user_info(
        cls,
        db: AsyncSession,
        user: User,
    ) -> UserInfo:
        """
        Loads detailed profile information for the current user.
        """
        stmt = (
            select(User)
            .options(selectinload(User.teacher_profile))
            .where(User.id == user.id)
        )
        result = await db.execute(stmt)
        loaded_user = result.scalar_one()

        teacher_id = loaded_user.teacher_profile.id if loaded_user.teacher_profile else None
        school_id = loaded_user.teacher_profile.school_id if loaded_user.teacher_profile else None

        return UserInfo(
            id=loaded_user.id,
            email=loaded_user.email,
            username=loaded_user.username,
            full_name=loaded_user.full_name,
            role=loaded_user.role,
            is_active=loaded_user.is_active,
            is_demo=loaded_user.is_demo,
            school_id=school_id,
            teacher_id=teacher_id,
        )
