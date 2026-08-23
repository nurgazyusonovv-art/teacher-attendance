from datetime import datetime, date, time
from zoneinfo import ZoneInfo
from app.core.config import settings


def get_school_timezone(tz_name: str | None = None) -> ZoneInfo:
    """Returns the ZoneInfo for the given timezone name or the default school timezone."""
    return ZoneInfo(tz_name or settings.TIMEZONE)


def current_time_in_school_timezone(tz_name: str | None = None) -> datetime:
    """
    Returns the current server datetime localized to the school timezone.
    CRITICAL RULE (AGENTS.md #5): Never trust client-provided timestamps.
    Always evaluate attendance using the server's authoritative timezone.
    """
    tz = get_school_timezone(tz_name)
    return datetime.now(tz)


def get_today_date_in_school_timezone(tz_name: str | None = None) -> date:
    """Returns today's date in the school's timezone."""
    return current_time_in_school_timezone(tz_name).date()


def to_school_timezone(dt: datetime, tz_name: str | None = None) -> datetime:
    """Converts a naive or aware datetime to the school timezone."""
    tz = get_school_timezone(tz_name)
    if dt.tzinfo is None:
        return dt.replace(tzinfo=tz)
    return dt.astimezone(tz)
