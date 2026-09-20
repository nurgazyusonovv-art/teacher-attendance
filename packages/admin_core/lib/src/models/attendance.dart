/// A delay for a single lesson, recorded by an administrator.
class LessonDelay {
  const LessonDelay({
    required this.id,
    required this.teacherId,
    required this.schoolId,
    required this.date,
    required this.lessonNumber,
    required this.delayMinutes,
    this.reason,
    this.teacherName,
    this.createdAt,
  });

  final String id;
  final String teacherId;
  final String schoolId;
  final String date;
  final int lessonNumber;
  final int delayMinutes;
  final String? reason;
  final String? teacherName;
  final String? createdAt;

  factory LessonDelay.fromJson(Map<String, dynamic> json) {
    return LessonDelay(
      id: json['id'] as String,
      teacherId: json['teacher_id'] as String? ?? '',
      schoolId: json['school_id'] as String? ?? '',
      date: json['date'] as String? ?? '',
      lessonNumber: json['lesson_number'] as int? ?? 0,
      delayMinutes: json['delay_minutes'] as int? ?? 0,
      reason: json['reason'] as String?,
      teacherName: json['teacher_name'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }
}


/// One teacher's attendance for one day, as `DailyAttendanceRead` returns it.
///
/// Times arrive already localized to the school's timezone — the API converts
/// them, because the TIMESTAMPTZ columns read back as UTC — so the wall clock
/// in the string is the one to show.
class DailyAttendance {
  const DailyAttendance({
    required this.id,
    required this.teacherId,
    required this.schoolId,
    required this.date,
    required this.status,
    this.checkInTime,
    this.checkOutTime,
    this.lateMinutes = 0,
    this.lessonLateMinutes = 0,
    this.totalLateMinutes = 0,
    this.workedMinutes = 0,
    this.isManuallyCorrected = false,
    this.correctionReason,
    this.teacherName,
    this.employeeCode,
    this.phoneNumber,
    this.subject,
    this.lessonDelays = const [],
  });

  final String id;
  final String teacherId;
  final String schoolId;

  /// `YYYY-MM-DD` in the school's timezone.
  final String date;

  /// What to show. The API's `display_status` already accounts for the
  /// schedule and the time of day, so it is preferred over the stored
  /// `status`, which is only what was recorded.
  final String status;

  final String? checkInTime;
  final String? checkOutTime;
  final int lateMinutes;
  final int lessonLateMinutes;
  final int totalLateMinutes;
  final int workedMinutes;
  final bool isManuallyCorrected;
  final String? correctionReason;
  final String? teacherName;
  final String? employeeCode;
  final String? phoneNumber;
  final String? subject;

  /// Per-lesson delays recorded for this day, if the endpoint includes them.
  final List<LessonDelay> lessonDelays;

  bool get hasCheckedIn => checkInTime != null;
  bool get hasCheckedOut => checkOutTime != null;

  factory DailyAttendance.fromJson(Map<String, dynamic> json) {
    final late = json['late_minutes'] as int? ?? 0;
    final lessonLate = json['lesson_late_minutes'] as int? ?? 0;
    return DailyAttendance(
      id: json['id'] as String,
      teacherId: json['teacher_id'] as String? ?? '',
      schoolId: json['school_id'] as String? ?? '',
      date: json['date'] as String? ?? '',
      status:
          json['display_status'] as String? ??
          json['status'] as String? ??
          'UNKNOWN',
      checkInTime: json['check_in_time'] as String?,
      checkOutTime: json['check_out_time'] as String?,
      lateMinutes: late,
      lessonLateMinutes: lessonLate,
      totalLateMinutes: json['total_late_minutes'] as int? ?? late + lessonLate,
      workedMinutes: json['worked_minutes'] as int? ?? 0,
      isManuallyCorrected: json['is_manually_corrected'] as bool? ?? false,
      correctionReason: json['correction_reason'] as String?,
      teacherName: json['teacher_name'] as String?,
      employeeCode: json['employee_code'] as String?,
      phoneNumber: json['phone_number'] as String?,
      subject: json['subject'] as String?,
      lessonDelays: (json['lesson_delays'] as List<dynamic>? ?? const [])
          .map((d) => LessonDelay.fromJson(d as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// The admin dashboard for one day, as `AdminDashboardSummary` returns it.
class AttendanceDashboard {
  const AttendanceDashboard({
    required this.date,
    required this.totalTeachers,
    required this.checkedInCount,
    required this.onTimeCount,
    required this.lateCount,
    required this.notCheckedInCount,
    required this.records,
  });

  final String date;
  final int totalTeachers;
  final int checkedInCount;
  final int onTimeCount;
  final int lateCount;
  final int notCheckedInCount;
  final List<DailyAttendance> records;

  factory AttendanceDashboard.fromJson(Map<String, dynamic> json) {
    return AttendanceDashboard(
      date: json['date'] as String? ?? '',
      totalTeachers: json['total_teachers'] as int? ?? 0,
      checkedInCount: json['checked_in_count'] as int? ?? 0,
      onTimeCount: json['on_time_count'] as int? ?? 0,
      lateCount: json['late_count'] as int? ?? 0,
      notCheckedInCount: json['not_checked_in_count'] as int? ?? 0,
      records: (json['records'] as List<dynamic>? ?? const [])
          .map((r) => DailyAttendance.fromJson(r as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// A page of attendance rows, as `/attendance/history` returns it.
class AttendancePage {
  const AttendancePage({required this.items, required this.total});

  final List<DailyAttendance> items;
  final int total;

  factory AttendancePage.fromJson(Map<String, dynamic> json) {
    final rows = json['items'] as List<dynamic>? ?? const [];
    return AttendancePage(
      items: rows
          .map((r) => DailyAttendance.fromJson(r as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int? ?? rows.length,
    );
  }
}
