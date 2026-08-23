from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from app.db.session import get_db
from app.api.deps import get_current_user
from app.models.user import User
from app.schemas.auth import LoginRequest, RefreshTokenRequest, UserInfo
from app.schemas.common import StandardResponse, TokenResponse
from app.services.auth_service import AuthService

router = APIRouter()


class LoginResponseData(TokenResponse):
    user: UserInfo


@router.post("/login", response_model=StandardResponse[LoginResponseData])
async def login(
    login_data: LoginRequest,
    db: AsyncSession = Depends(get_db),
):
    """
    Authenticates user and returns JWT access and refresh tokens along with profile data.
    """
    tokens, user_info = await AuthService.authenticate_user(db, login_data)
    response_data = LoginResponseData(
        access_token=tokens.access_token,
        refresh_token=tokens.refresh_token,
        token_type=tokens.token_type,
        expires_in=tokens.expires_in,
        user=user_info,
    )
    return StandardResponse(
        success=True,
        message="Ийгиликтүү кирдиңиз",
        data=response_data,
    )


@router.post("/refresh", response_model=StandardResponse[TokenResponse])
async def refresh_token(
    refresh_data: RefreshTokenRequest,
    db: AsyncSession = Depends(get_db),
):
    """
    Refreshes expired access token using a valid refresh token.
    """
    tokens = await AuthService.refresh_tokens(db, refresh_data.refresh_token)
    return StandardResponse(
        success=True,
        message="Токен ийгиликтүү жаңыланды",
        data=tokens,
    )


@router.get("/me", response_model=StandardResponse[UserInfo])
async def get_me(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    """
    Returns profile information of the currently authenticated user.
    """
    user_info = await AuthService.get_current_user_info(db, current_user)
    return StandardResponse(
        success=True,
        message="Колдонуучунун маалыматы",
        data=user_info,
    )


@router.post("/logout", response_model=StandardResponse[dict])
async def logout(
    current_user: User = Depends(get_current_user),
):
    """
    Logs out the user and informs the client to clear stored credentials.
    """
    return StandardResponse(
        success=True,
        message="Ийгиликтүү чыктыңыз",
        data={"user_id": current_user.id},
    )
