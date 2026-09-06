from datetime import datetime, timedelta, timezone
import secrets
from typing import Optional, Tuple
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, or_
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import selectinload
from app.core.security import (
    verify_password,
    create_access_token,
    create_refresh_token,
    decode_token,
    hash_token_identifier,
)
from app.core.config import settings
from app.core.errors import AppException, ErrorCode
from app.models.user import User
from app.models.teacher import Teacher
from app.models.audit import AuditLog
from app.models.auth_security import AuthSession, LoginAttempt
from app.schemas.auth import LoginRequest, UserInfo
from app.schemas.common import TokenResponse


class AuthService:
    @staticmethod
    def _login_key(identifier: str) -> str:
        return hash_token_identifier(identifier.strip().lower())

    @classmethod
    async def _get_login_attempt(
        cls, db: AsyncSession, identifier: str, client_ip: str
    ) -> Optional[LoginAttempt]:
        result = await db.execute(
            select(LoginAttempt).where(
                LoginAttempt.identifier_hash == cls._login_key(identifier),
                LoginAttempt.ip_address == client_ip,
            )
        )
        return result.scalar_one_or_none()

    @classmethod
    async def _record_failed_login(
        cls,
        db: AsyncSession,
        identifier: str,
        client_ip: str,
        user: Optional[User] = None,
        retry_on_conflict: bool = True,
    ) -> None:
        attempt = await cls._get_login_attempt(db, identifier, client_ip)
        if attempt is None:
            attempt = LoginAttempt(
                identifier_hash=cls._login_key(identifier),
                ip_address=client_ip,
                failed_count=0,
            )
            db.add(attempt)
        attempt.failed_count += 1
        if attempt.failed_count >= settings.LOGIN_MAX_FAILED_ATTEMPTS:
            attempt.locked_until = datetime.now(timezone.utc) + timedelta(
                minutes=settings.LOGIN_LOCKOUT_MINUTES
            )
        db.add(
            AuditLog(
                school_id=(user.teacher_profile.school_id if user and user.teacher_profile else None),
                user_id=user.id if user else None,
                action="LOGIN_FAILED",
                entity_name="auth",
                entity_id=user.id if user else None,
                ip_address=client_ip,
            )
        )
        try:
            await db.commit()
        except IntegrityError:
            await db.rollback()
            if not retry_on_conflict:
                raise
            await cls._record_failed_login(
                db,
                identifier,
                client_ip,
                user,
                retry_on_conflict=False,
            )

    @classmethod
    async def authenticate_user(
        cls,
        db: AsyncSession,
        login_data: LoginRequest,
        client_ip: str = "unknown",
    ) -> Tuple[TokenResponse, UserInfo]:
        """
        Authenticates a user by username or email and returns access/refresh tokens along with user info.
        """
        attempt = await cls._get_login_attempt(
            db, login_data.username_or_email, client_ip
        )
        if attempt and attempt.locked_until:
            locked_until = attempt.locked_until
            if locked_until.tzinfo is None:
                locked_until = locked_until.replace(tzinfo=timezone.utc)
            if locked_until > datetime.now(timezone.utc):
                raise AppException(
                    code=ErrorCode.RATE_LIMITED,
                    message="Өтө көп туура эмес аракет. Бир аздан кийин кайра кириңиз.",
                    status_code=429,
                )

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
            await cls._record_failed_login(
                db, login_data.username_or_email, client_ip
            )
            raise AppException(
                code=ErrorCode.INVALID_CREDENTIALS,
                message="Колдонуучу аты же сырсөз туура эмес.",
                status_code=400,
            )

        if not verify_password(login_data.password, user.hashed_password):
            await cls._record_failed_login(
                db, login_data.username_or_email, client_ip, user
            )
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
        school_id: Optional[str] = user.school_id

        if user.teacher_profile:
            if not user.teacher_profile.is_active:
                raise AppException(
                    code=ErrorCode.TEACHER_INACTIVE,
                    message="Мугалимдик профилиңиз өчүрүлгөн.",
                    status_code=403,
                )
            teacher_id = user.teacher_profile.id
            school_id = user.teacher_profile.school_id

        if attempt:
            await db.delete(attempt)

        # Persist a server-controlled refresh session before issuing tokens.
        refresh_jti = secrets.token_urlsafe(32)
        auth_session = AuthSession(
            user_id=user.id,
            refresh_jti_hash=hash_token_identifier(refresh_jti),
            expires_at=datetime.now(timezone.utc)
            + timedelta(days=settings.REFRESH_TOKEN_EXPIRE_DAYS),
        )
        db.add(auth_session)
        await db.flush()

        # Generate tokens
        access_token = create_access_token(
            subject=user.id,
            role=user.role.value if hasattr(user.role, "value") else str(user.role),
            school_id=school_id,
            teacher_id=teacher_id,
            session_id=auth_session.id,
        )
        refresh_token = create_refresh_token(
            subject=user.id, session_id=auth_session.id, jti=refresh_jti
        )
        db.add(
            AuditLog(
                school_id=school_id,
                user_id=user.id,
                action="LOGIN_SUCCEEDED",
                entity_name="auth",
                entity_id=auth_session.id,
                ip_address=client_ip,
            )
        )
        await db.commit()

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
            session_id = payload.get("sid")
            refresh_jti = payload.get("jti")
            if not user_id or token_type != "refresh" or not session_id or not refresh_jti:
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

        session_result = await db.execute(
            select(AuthSession).where(
                AuthSession.id == session_id,
                AuthSession.user_id == user_id,
            ).with_for_update()
        )
        auth_session = session_result.scalar_one_or_none()
        if (
            auth_session is None
            or auth_session.revoked_at is not None
            or auth_session.refresh_jti_hash != hash_token_identifier(refresh_jti)
        ):
            if auth_session is not None and auth_session.revoked_at is None:
                auth_session.revoked_at = datetime.now(timezone.utc)
                await db.commit()
            raise AppException(
                code=ErrorCode.TOKEN_INVALID,
                message="Refresh token жараксыз же кайра колдонулган.",
                status_code=401,
            )

        expires_at = auth_session.expires_at
        if expires_at.tzinfo is None:
            expires_at = expires_at.replace(tzinfo=timezone.utc)
        if expires_at <= datetime.now(timezone.utc):
            auth_session.revoked_at = datetime.now(timezone.utc)
            await db.commit()
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
        school_id = (
            user.teacher_profile.school_id if user.teacher_profile else user.school_id
        )

        new_refresh_jti = secrets.token_urlsafe(32)
        auth_session.refresh_jti_hash = hash_token_identifier(new_refresh_jti)
        auth_session.expires_at = datetime.now(timezone.utc) + timedelta(
            days=settings.REFRESH_TOKEN_EXPIRE_DAYS
        )
        access_token = create_access_token(
            subject=user.id,
            role=user.role.value if hasattr(user.role, "value") else str(user.role),
            school_id=school_id,
            teacher_id=teacher_id,
            session_id=auth_session.id,
        )
        new_refresh_token = create_refresh_token(
            subject=user.id,
            session_id=auth_session.id,
            jti=new_refresh_jti,
        )
        await db.commit()

        return TokenResponse(
            access_token=access_token,
            refresh_token=new_refresh_token,
            token_type="bearer",
            expires_in=settings.ACCESS_TOKEN_EXPIRE_MINUTES * 60,
        )

    @staticmethod
    async def revoke_session(
        db: AsyncSession, user_id: str, session_id: Optional[str]
    ) -> None:
        if not session_id:
            return
        result = await db.execute(
            select(AuthSession).where(
                AuthSession.id == session_id,
                AuthSession.user_id == user_id,
                AuthSession.revoked_at.is_(None),
            )
        )
        auth_session = result.scalar_one_or_none()
        if auth_session:
            auth_session.revoked_at = datetime.now(timezone.utc)
            await db.commit()

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
        school_id = (
            loaded_user.teacher_profile.school_id
            if loaded_user.teacher_profile
            else loaded_user.school_id
        )

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
