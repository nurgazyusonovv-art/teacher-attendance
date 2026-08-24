from datetime import date
from app.schemas.lesson_delay import LessonDelayCreate, LessonDelayRead
import pytest


def test_lesson_delay_schema_validation():
    payload = LessonDelayCreate(
        teacher_id="teacher-uuid-1",
        date=date(2026, 8, 24),
        lesson_number=3,
        delay_minutes=15,
        reason="Жол тыгыны",
    )
    assert payload.lesson_number == 3
    assert payload.delay_minutes == 15
    assert payload.reason == "Жол тыгыны"


def test_lesson_delay_minutes_bounds():
    # lesson_number should be between 1 and 12
    with pytest.raises(Exception):
        LessonDelayCreate(
            teacher_id="teacher-uuid-1",
            date=date(2026, 8, 24),
            lesson_number=0,
            delay_minutes=10,
        )

    # delay_minutes should be positive
    with pytest.raises(Exception):
        LessonDelayCreate(
            teacher_id="teacher-uuid-1",
            date=date(2026, 8, 24),
            lesson_number=2,
            delay_minutes=-5,
        )
