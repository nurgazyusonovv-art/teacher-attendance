import calendar
from datetime import date, datetime, timedelta

from app.core.errors import AppException, ErrorCode
from app.core.timezone import current_time_in_school_timezone, to_school_timezone
from app.repositories.monthly_score_repository import MonthlyScoreRepository
from app.schemas.monthly_score import MonthlyScore, ScoreDay


class MonthlyScoreService:
    @staticmethod
    async def get(db, teacher, school, year=None, month=None):
        now = current_time_in_school_timezone(school.timezone)
        if (year is None) != (month is None):
            raise AppException(code=ErrorCode.VALIDATION_ERROR,
                               message='Жыл менен айды чогуу көрсөтүңүз.', status_code=422)
        year, month = year or now.year, month or now.month
        if (year, month) > (now.year, now.month):
            raise AppException(code=ErrorCode.VALIDATION_ERROR,
                               message='Келечектеги ай үчүн балл жок.', status_code=422)
        start = date(year, month, 1)
        end = min(date(year, month, calendar.monthrange(year, month)[1]), now.date())
        records, schedules, approved = await MonthlyScoreRepository(db).load(teacher, start, end)
        return MonthlyScoreService.calculate(teacher, school, now, year, month,
                                             records, schedules, approved)

    @staticmethod
    def calculate(teacher, school, now, year, month, records, schedules, approved):
        """Read-only, repeatable monthly score; no points are added on page refresh.

        Historical schedules are not versioned in this app. Expose that this is
        a recalculated report using current schedules, not a frozen payroll ledger.
        Arrival uses the recorded server status (including its grace period).
        """
        start = date(year, month, 1)
        end = min(date(year, month, calendar.monthrange(year, month)[1]), now.date())
        epoch = school.attendance_start_date
        if epoch is None:
            epoch = to_school_timezone(school.created_at, school.timezone).date()
        start = max(start, epoch, to_school_timezone(teacher.created_at, school.timezone).date())
        by_day = {row.date: row for row in records}
        days = []
        day = start
        while day <= end:
            row = by_day.get(day)
            schedule = schedules.for_teacher(teacher.id, day)
            status = getattr(row, 'status', None)
            status = getattr(status, 'value', status)
            item = ScoreDay(date=day)
            if day in approved or status == 'EXCUSED':
                item.exclusion = 'EXCUSED'
            elif status == 'DAY_OFF' or (schedule and schedule.is_day_off):
                item.exclusion = 'DAY_OFF'
            elif schedule is None:
                item.exclusion = 'NO_SCHEDULE'
            else:
                finish = datetime.combine(day, schedule.end_time, tzinfo=now.tzinfo)
                item.pending = now < finish
                item.possible_points = 10
                arrived = row is not None and row.check_in_time is not None
                departed = arrived and row.check_out_time is not None
                if arrived and status == 'ON_TIME' and row.late_minutes == 0:
                    item.arrival_points = 5
                item.late = arrived and (status == 'LATE' or row.late_minutes > 0)
                if departed:
                    departure = to_school_timezone(row.check_out_time, school.timezone)
                    arrival = to_school_timezone(row.check_in_time, school.timezone)
                    if departure >= arrival:
                        item.early_departure = departure < finish
                        item.departure_points = 0 if item.early_departure else 5
                item.absent = not arrived and not item.pending
                item.missing_checkout = arrived and not departed and not item.pending
                item.points = item.arrival_points + item.departure_points
            days.append(item)
            day += timedelta(days=1)
        return MonthlyScore(
            year=year, month=month, as_of=now,
            points=sum(d.points for d in days),
            possible_points=sum(d.possible_points for d in days),
            on_time_arrivals=sum(d.arrival_points == 5 for d in days),
            on_time_departures=sum(d.departure_points == 5 for d in days),
            late_days=sum(d.late for d in days),
            early_departure_days=sum(d.early_departure for d in days),
            absent_days=sum(d.absent for d in days),
            missing_checkout_days=sum(d.missing_checkout for d in days),
            excused_days=sum(d.exclusion == 'EXCUSED' for d in days),
            unscored_days=sum(d.exclusion == 'NO_SCHEDULE' for d in days),
            provisional=(year, month) == (now.year, now.month), days=days,
        )
