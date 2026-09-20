/// One weekday of a work schedule, as `ScheduleRead` returns it.
///
/// A schedule with no `teacherId` is the school's default for that weekday; a
/// row carrying one overrides the default for that teacher.
class WorkSchedule {
  const WorkSchedule({
    required this.dayOfWeek,
    this.id,
    this.schoolId,
    this.teacherId,
    this.startTime,
    this.endTime,
    this.graceMinutes = 0,
    this.isDayOff = false,
  });

  final String? id;
  final String? schoolId;
  final String? teacherId;

  /// 0 = Monday … 6 = Sunday, matching the API.
  final int dayOfWeek;

  /// `HH:mm:ss` in the school's timezone; null on a day off.
  final String? startTime;
  final String? endTime;

  /// Minutes of lateness still counted as on time.
  ///
  /// Defaults to 0, matching the column. The two apps used to default it to
  /// 15 and 5 respectively, so the same response could be read as a different
  /// policy depending on which one you opened. The API always sends the
  /// field, so this fallback should never decide anything.
  final int graceMinutes;

  final bool isDayOff;

  /// True for the school-wide default rather than a teacher's override.
  bool get isSchoolDefault => teacherId == null;

  factory WorkSchedule.fromJson(Map<String, dynamic> json) {
    return WorkSchedule(
      id: json['id'] as String?,
      schoolId: json['school_id'] as String?,
      teacherId: json['teacher_id'] as String?,
      dayOfWeek: json['day_of_week'] as int? ?? 0,
      startTime: json['start_time'] as String?,
      endTime: json['end_time'] as String?,
      graceMinutes: json['grace_minutes'] as int? ?? 0,
      isDayOff: json['is_day_off'] as bool? ?? false,
    );
  }

  WorkSchedule copyWith({
    String? id,
    String? teacherId,
    int? dayOfWeek,
    String? startTime,
    String? endTime,
    int? graceMinutes,
    bool? isDayOff,
  }) {
    return WorkSchedule(
      id: id ?? this.id,
      schoolId: schoolId,
      teacherId: teacherId ?? this.teacherId,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      graceMinutes: graceMinutes ?? this.graceMinutes,
      isDayOff: isDayOff ?? this.isDayOff,
    );
  }
}

/// Day names in Kyrgyz, indexed the way the API indexes weekdays.
const List<String> weekdayNames = [
  'Дүйшөмбү',
  'Шейшемби',
  'Шаршемби',
  'Бейшемби',
  'Жума',
  'Ишемби',
  'Жекшемби',
];

/// The weekday's name, or an empty string for an index the API never sends.
String weekdayName(int dayOfWeek) =>
    dayOfWeek >= 0 && dayOfWeek < weekdayNames.length
    ? weekdayNames[dayOfWeek]
    : '';
