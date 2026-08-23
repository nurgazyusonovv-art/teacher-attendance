from datetime import date
import pytest
from sqlalchemy import select
from app.models.enums import AttendanceStatus
from app.models.school import School
from app.services.absence_service import AbsenceService


@pytest.mark.asyncio
async def test_absence_processing_service(db_session):
    school_res = await db_session.execute(select(School).limit(1))
    school = school_res.scalar_one()

    # Process absences for Monday (work day)
    work_monday = date(2026, 8, 24)
    absent_records = await AbsenceService.process_daily_absences(
        db=db_session,
        school_id=school.id,
        target_date=work_monday,
    )
    assert isinstance(absent_records, list)
    for rec in absent_records:
        assert rec.status == AttendanceStatus.ABSENT
        assert rec.check_in_time is None
