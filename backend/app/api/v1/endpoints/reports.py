from datetime import date
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.deps import get_current_active_admin
from app.db.session import get_db
from app.models.user import User
from app.services.school_service import SchoolService
from app.services.telegram_service import TelegramService

router = APIRouter()


class SendTelegramReportRequest(BaseModel):
    target_date: Optional[date] = Field(None, description="Отчет алынуучу дата (дефолт: бүгүн)")
    school_id: Optional[str] = Field(None, description="Мектептин IDси")
    bot_token: Optional[str] = Field(None, description="Өзгөчө Bot Token (кааласаңыз)")
    chat_id: Optional[str] = Field(None, description="Өзгөчө Chat ID (кааласаңыз)")


class TestTelegramRequest(BaseModel):
    bot_token: str = Field(..., description="Telegram Bot Token")
    chat_id: str = Field(..., description="Telegram Chat/Channel/Group ID")
    school_name: Optional[str] = Field("№1 Орто Мектеп", description="Мектептин аталышы")


class TelegramReportResponse(BaseModel):
    success: bool
    message: str
    report_text: Optional[str] = None


@router.post("/telegram/send", response_model=TelegramReportResponse, summary="Күндөлүк катышуу отчетун Telegram'га жөнөтүү")
async def send_telegram_report(
    payload: SendTelegramReportRequest,
    db: AsyncSession = Depends(get_db),
    admin_user: User = Depends(get_current_active_admin),
):
    school_id = payload.school_id
    if not school_id:
        school = await SchoolService.get_first_active_school(db)
        school_id = school.id

    success, message, report_text = await TelegramService.send_daily_report(
        db=db,
        school_id=school_id,
        target_date=payload.target_date,
        override_bot_token=payload.bot_token,
        override_chat_id=payload.chat_id,
    )

    if not success:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=message,
        )

    return TelegramReportResponse(
        success=True,
        message=message,
        report_text=report_text,
    )


@router.post("/telegram/test", response_model=TelegramReportResponse, summary="Telegram Бот байланышын текшерүү (Тест билдирүү)")
async def test_telegram_connection(
    payload: TestTelegramRequest,
    db: AsyncSession = Depends(get_db),
    admin_user: User = Depends(get_current_active_admin),
):
    school_name = payload.school_name
    if not school_name:
        school = await SchoolService.get_first_active_school(db)
        school_name = school.name

    success, err = await TelegramService.test_telegram_connection(
        bot_token=payload.bot_token,
        chat_id=payload.chat_id,
        school_name=school_name,
    )

    if not success:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=err or "Telegram ботко туташууда ката кетти",
        )

    return TelegramReportResponse(
        success=True,
        message="Тесттик билдирүү Telegram чатка/каналга ийгиликтүү жөнөтүлдү! ✅",
    )


@router.get("/telegram/preview", summary="Telegram отчеттун текстин алдын ала көрүү")
async def preview_telegram_report(
    target_date: Optional[date] = Query(None, description="Дата"),
    school_id: Optional[str] = Query(None, description="Мектеп ID"),
    db: AsyncSession = Depends(get_db),
    admin_user: User = Depends(get_current_active_admin),
):
    target_school_id = school_id
    if not target_school_id:
        school = await SchoolService.get_first_active_school(db)
        target_school_id = school.id

    report_text, school = await TelegramService.generate_daily_attendance_report(
        db, target_school_id, target_date
    )
    return {
        "school_id": target_school_id,
        "school_name": school.name,
        "target_date": target_date or date.today(),
        "report_text": report_text,
    }
