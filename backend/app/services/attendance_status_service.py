class AttendanceStatusService:
    @staticmethod
    def resolve(record, schedule, target_date, server_now):
        if record:
            return record.status.value
        if schedule is None:
            return 'NO_SCHEDULE'
        if schedule.is_day_off:
            return 'DAY_OFF'
        if target_date < server_now.date() or (
            target_date == server_now.date()
            and server_now.time().replace(tzinfo=None) >= schedule.end_time
        ):
            return 'ABSENT'
        return 'PENDING'
