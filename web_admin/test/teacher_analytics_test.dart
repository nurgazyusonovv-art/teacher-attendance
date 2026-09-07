import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_admin/features/teachers/domain/teacher_analytics.dart';
import 'package:teacher_admin/features/attendance/data/repositories/admin_attendance_repository.dart';

AdminDailyAttendanceItem row(
  String date,
  String status, {
  bool checked = false,
  int lesson = 0,
}) => AdminDailyAttendanceItem(
  id: date,
  teacherId: 't',
  schoolId: 's',
  date: date,
  status: status,
  checkInTime: checked ? '${date}T08:00:00+06:00' : null,
  lateMinutes: 0,
  lessonLateMinutes: lesson,
  workedMinutes: checked ? 60 : 0,
  isManuallyCorrected: false,
);

void main() {
  final history = [
    row('2026-09-07', 'ON_TIME', checked: true),
    row('2026-09-01', 'ON_TIME', checked: true, lesson: 10),
    row('2026-08-31', 'ABSENT'),
    row('2026-08-09', 'EXCUSED'),
    row('2026-08-08', 'DAY_OFF'),
    row('2026-09-08', 'ON_TIME', checked: true),
  ];
  test('Inclusive server-date windows exclude future dates', () {
    expect(TeacherAnalytics(history, '2026-09-07', 1).records.length, 1);
    expect(TeacherAnalytics(history, '2026-09-07', 7).records.length, 2);
    expect(TeacherAnalytics(history, '2026-09-07', 30).records.length, 4);
    expect(TeacherAnalytics(history, '2026-09-07', 0).records.length, 5);
  });
  test(
    'Cards and charts reconcile, lesson delay counts and absent is explicit',
    () {
      final stats = TeacherAnalytics(history, '2026-09-07', 0);
      expect(stats.checkedIn, 2);
      expect(stats.onTime, 1);
      expect(stats.late, 1);
      expect(stats.absent, 1);
      expect(stats.lateMinutes, 10);
      expect(stats.workedMinutes, 120);
      expect(stats.monthlyLate['2026-09'], 10);
      expect(
        stats.statuses.values.reduce((a, b) => a + b),
        stats.records.length,
      );
    },
  );
  test('Empty history does not fabricate attendance', () {
    final stats = TeacherAnalytics([], '2026-09-07', 30);
    expect(stats.checkedIn, 0);
    expect(stats.absent, 0);
    expect(stats.monthlyLate, isEmpty);
  });
}
