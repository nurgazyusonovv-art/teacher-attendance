import pytest

from datetime import datetime, timezone
from app.core.timezone import (
    get_school_timezone,
    current_time_in_school_timezone,
    to_school_timezone,
    get_today_date_in_school_timezone,
)


def test_school_timezone_defaults_to_bishkek():
    tz = get_school_timezone()
    assert tz.key == "Asia/Bishkek"


def test_current_time_has_bishkek_timezone():
    now_tz = current_time_in_school_timezone()
    assert now_tz.tzinfo is not None
    # Bishkek is UTC+6
    assert now_tz.utcoffset().total_seconds() == 6 * 3600


def test_to_school_timezone_conversion():
    utc_time = datetime(2026, 9, 1, 2, 0, 0, tzinfo=timezone.utc)
    bishkek_time = to_school_timezone(utc_time)
    assert bishkek_time.hour == 8  # 02:00 UTC + 6 hours = 08:00 Bishkek
    assert bishkek_time.day == 1


def test_today_date_in_school_timezone():
    today = get_today_date_in_school_timezone()
    assert today == current_time_in_school_timezone().date()


@pytest.mark.asyncio
async def test_today_status_reports_the_school_utc_offset(
    async_client, teacher_auth_headers
):
    """The client needs the school's offset so it stops assuming UTC+6."""
    response = await async_client.get(
        "/api/v1/attendance/today", headers=teacher_auth_headers
    )
    assert response.status_code == 200
    assert response.json()["utc_offset_minutes"] == 6 * 60
