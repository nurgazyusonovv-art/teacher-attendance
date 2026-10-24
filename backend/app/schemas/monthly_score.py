from datetime import date, datetime
from typing import Literal

from pydantic import BaseModel


class ScoreDay(BaseModel):
    date: date
    points: int = 0
    possible_points: int = 0
    arrival_points: int = 0
    departure_points: int = 0
    late: bool = False
    early_departure: bool = False
    absent: bool = False
    missing_checkout: bool = False
    pending: bool = False
    exclusion: str | None = None


class MonthlyScore(BaseModel):
    year: int
    month: int
    as_of: datetime
    rule_version: str = 'monthly-5-plus-5-v1'
    schedule_basis: Literal['current_schedule'] = 'current_schedule'
    points: int
    possible_points: int
    on_time_arrivals: int
    on_time_departures: int
    late_days: int
    early_departure_days: int
    absent_days: int
    missing_checkout_days: int
    excused_days: int
    unscored_days: int
    provisional: bool
    days: list[ScoreDay]
