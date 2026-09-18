import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_mobile/features/attendance/presentation/screens/home_screen.dart';

void main() {
  test('Completed attendance never asks to scan again', () {
    expect(
      attendanceGuidance('ON_TIME', true),
      contains('кайра каттоонун кереги жок'),
    );
  });
  test('Approved leave and day off explain why scanning is unavailable', () {
    expect(attendanceGuidance('EXCUSED', false), contains('бекитилген'));
    expect(attendanceGuidance('DAY_OFF', false), contains('дем алыш'));
  });
  test('Missing schedule and unknown status provide a next step', () {
    expect(
      attendanceGuidance('NO_SCHEDULE', false),
      contains('администраторго'),
    );
    expect(attendanceGuidance('UNKNOWN', false), contains('ылдый тартыңыз'));
  });
  test('Arrival and departure have distinct instructions', () {
    expect(attendanceGuidance('PENDING', false), contains('келүүнү'));
    expect(attendanceGuidance('LATE', false), contains('кетүүнү'));
  });
}
