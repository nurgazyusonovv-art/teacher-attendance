from datetime import datetime, timezone
from zoneinfo import ZoneInfo
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
