import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_admin/features/attendance/data/repositories/admin_attendance_repository.dart';
import 'package:teacher_admin/features/attendance/presentation/widgets/attendance_details.dart';

AdminDailyAttendanceItem record(
  String status, {
  bool checked = false,
  int lessonLate = 0,
}) => AdminDailyAttendanceItem(
  id: '1',
  teacherId: 't',
  schoolId: 's',
  date: '2026-09-07',
  status: status,
  lateMinutes: 0,
  lessonLateMinutes: lessonLate,
  workedMinutes: 0,
  isManuallyCorrected: false,
  teacherName: 'Мугалим',
  checkInTime: checked ? '2026-09-07T08:00:00+06:00' : null,
);

void main() {
  test('Dashboard categories use server status, lesson delays remain separate', () {
    final onTime = record('ON_TIME', checked: true);
    final lessonLate = record('ON_TIME', checked: true, lessonLate: 10);
    expect(matchesGroup(onTime, AttendanceGroup.onTime), isTrue);
    expect(matchesGroup(lessonLate, AttendanceGroup.onTime), isTrue);
    expect(matchesGroup(lessonLate, AttendanceGroup.late), isFalse);
    for (final status in ['EXCUSED', 'PENDING', 'NO_SCHEDULE']) {
      expect(matchesGroup(record(status), AttendanceGroup.absent), isFalse);
    }
    expect(matchesGroup(onTime, AttendanceGroup.checkedIn), isTrue);
    expect(matchesGroup(record('DAY_OFF'), AttendanceGroup.absent), isFalse);
    expect(matchesGroup(record('ABSENT'), AttendanceGroup.absent), isTrue);
    expect(matchesGroup(record('DAY_OFF'), AttendanceGroup.all), isTrue);
  });
  test('School wall time is retained and missing times stay empty', () {
    expect(attendanceTime('2026-09-07T08:15:00+06:00'), '08:15');
    expect(attendanceTime(null), '—');
  });
  testWidgets('Details show date and teacher, including empty state', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AttendanceDetails(records: [record('ON_TIME', checked: true)]),
        ),
      ),
    );
    expect(find.text('2026-09-07'), findsOneWidget);
    expect(find.text('08:00'), findsOneWidget);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AttendanceDetails(records: [])),
      ),
    );
    expect(find.text('Тандалган чыпка боюнча маалымат жок'), findsOneWidget);
  });
}
