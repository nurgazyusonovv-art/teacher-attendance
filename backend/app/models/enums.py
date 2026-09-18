from enum import Enum


class UserRole(str, Enum):
    ADMIN = "ADMIN"
    TEACHER = "TEACHER"
    SUPER_ADMIN = "SUPER_ADMIN"


class AttendanceEventType(str, Enum):
    CHECK_IN = "CHECK_IN"
    CHECK_OUT = "CHECK_OUT"


class AttendanceStatus(str, Enum):
    ON_TIME = "ON_TIME"
    LATE = "LATE"
    ABSENT = "ABSENT"
    EXCUSED = "EXCUSED"
    DAY_OFF = "DAY_OFF"


class DevicePlatform(str, Enum):
    IOS = "IOS"
    ANDROID = "ANDROID"
    WEB = "WEB"


class DeviceStatus(str, Enum):
    """Lifecycle of a teacher's registered device.

    A teacher's first device is trusted on registration; every later one waits
    for an administrator so a stolen password alone cannot register a scanner.
    """

    PENDING = "PENDING"
    APPROVED = "APPROVED"
    REVOKED = "REVOKED"
