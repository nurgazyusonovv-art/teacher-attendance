from datetime import date
import pytest
from httpx import AsyncClient
from sqlalchemy import select
from app.models.school import School
from app.services.telegram_service import TelegramService


@pytest.mark.asyncio
async def test_generate_daily_attendance_report(db_session):
    res = await db_session.execute(select(School).limit(1))
    school = res.scalar_one()

    report_text, fetched_school = await TelegramService.generate_daily_attendance_report(
        db_session, school.id, target_date=date(2026, 8, 26)
    )

    assert fetched_school.id == school.id
    assert school.name in report_text
    assert "Мугалимдердин катышуусу боюнча күндөлүк отчет" in report_text
    assert "Бардык мугалимдер:" in report_text
    assert "Келгендер:" in report_text


@pytest.mark.asyncio
async def test_preview_report_endpoint(
    async_client: AsyncClient, admin_auth_headers: dict
):
    response = await async_client.get(
        "/api/v1/reports/telegram/preview",
        params={"target_date": "2026-08-26"},
        headers=admin_auth_headers,
    )
    assert response.status_code == 200
    data = response.json()
    assert "report_text" in data
    assert "№1 Орто Мектеп" in data["report_text"]


@pytest.mark.asyncio
async def test_check_and_send_scheduled_reports(db_session, monkeypatch):
    res = await db_session.execute(select(School).limit(1))
    school = res.scalar_one()

    # Enable telegram
    school.telegram_enabled = True
    school.telegram_bot_token = "mock-bot-token"
    school.telegram_chat_id = "mock-chat-id"
    school.telegram_report_time = None  # defaults to 17:30
    school.last_telegram_report_sent_date = None
    await db_session.commit()

    # Mock send_message to return success
    async def mock_send_message(*args, **kwargs):
        return True, None

    monkeypatch.setattr(TelegramService, "send_message", mock_send_message)

    sent = await TelegramService.check_and_send_scheduled_reports(db_session)
    assert sent >= 1

    # Second run on same day should skip (no duplicate)
    sent_again = await TelegramService.check_and_send_scheduled_reports(db_session)
    assert sent_again == 0
