import 'package:admin_core/admin_core.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

import 'support/fake_dio.dart';

const _attendanceJson = {
  'id': 'a-1',
  'teacher_id': 't-1',
  'school_id': 's-1',
  'date': '2026-09-18',
  'status': 'LATE',
  'display_status': 'LATE',
  'check_in_time': '2026-09-18T14:57:43+06:00',
  'check_out_time': '2026-09-18T18:05:00+06:00',
  'late_minutes': 7,
  'lesson_late_minutes': 3,
  'worked_minutes': 188,
  'is_manually_corrected': false,
  'teacher_name': 'Асанов Үсөн',
};

void main() {
  group('DailyAttendance', () {
    test('prefers display_status over the stored status', () {
      // display_status accounts for the schedule and the time of day; status
      // is only what was recorded, so a day with no scan yet reads PENDING.
      final row = DailyAttendance.fromJson({
        ..._attendanceJson,
        'status': 'ABSENT',
        'display_status': 'PENDING',
      });
      expect(row.status, 'PENDING');
    });

    test('falls back to the stored status when no display one is sent', () {
      final json = Map<String, dynamic>.from(_attendanceJson)
        ..remove('display_status');
      expect(DailyAttendance.fromJson(json).status, 'LATE');
    });

    test('derives the total lateness when the API omits it', () {
      final row = DailyAttendance.fromJson(
        Map<String, dynamic>.from(_attendanceJson),
      );
      expect(row.totalLateMinutes, 10, reason: '7 morning + 3 lesson minutes');
    });

    test('keeps the total the API sends', () {
      final row = DailyAttendance.fromJson({
        ..._attendanceJson,
        'total_late_minutes': 42,
      });
      expect(row.totalLateMinutes, 42);
    });

    test('reports whether the day was scanned', () {
      final row = DailyAttendance.fromJson(
        Map<String, dynamic>.from(_attendanceJson),
      );
      expect(row.hasCheckedIn, isTrue);
      expect(row.hasCheckedOut, isTrue);

      final empty = DailyAttendance.fromJson({'id': 'a-2'});
      expect(empty.hasCheckedIn, isFalse);
      expect(empty.hasCheckedOut, isFalse);
    });
  });

  group('AttendanceRepository', () {
    test('the dashboard reads its counters', () async {
      final repo = AttendanceRepository(
        dio: dioReturning({
          'date': '2026-09-18',
          'total_teachers': 12,
          'checked_in_count': 9,
          'on_time_count': 7,
          'late_count': 2,
          'not_checked_in_count': 3,
          'records': [_attendanceJson],
        }),
      );
      final dashboard = await repo.dashboard(targetDate: '2026-09-18');
      expect(dashboard.totalTeachers, 12);
      expect(dashboard.notCheckedInCount, 3);
      expect(dashboard.records.single.teacherName, 'Асанов Үсөн');
    });

    test('allHistory follows every page', () async {
      var call = 0;
      final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
      dio.httpClientAdapter = pagingAdapter(() {
        call++;
        return call == 1
            ? {
                'items': [
                  {..._attendanceJson, 'id': 'a-1', 'date': '2026-09-17'},
                ],
                'total': 2,
              }
            : {
                'items': [
                  {..._attendanceJson, 'id': 'a-2', 'date': '2026-09-18'},
                ],
                'total': 2,
              };
      });

      final rows = await AttendanceRepository(dio: dio).allHistory(pageSize: 1);
      expect(rows, hasLength(2));
      expect(call, 2);
      expect(rows.first.date, '2026-09-18', reason: 'newest first');
    });

    test('a short page that leaves rows behind is an error', () async {
      // Returning fewer rows silently would understate absences.
      final repo = AttendanceRepository(
        dio: dioReturning({'items': <Object>[], 'total': 5}),
      );
      await expectLater(
        repo.allHistory(),
        throwsA(
          isA<AdminApiException>().having(
            (e) => e.message,
            'message',
            contains('толук жүктөлгөн жок'),
          ),
        ),
      );
    });

    test('a correction carries its reason', () async {
      final captured = <RequestOptions>[];
      final repo = AttendanceRepository(
        dio: dioReturning(_attendanceJson, capture: captured),
      );
      await repo.manualCorrection(
        teacherId: 't-1',
        targetDate: '2026-09-18',
        status: 'EXCUSED',
        reason: 'Оорудан',
      );
      final data = captured.single.data as Map;
      expect(data['status'], 'EXCUSED');
      expect(data['reason'], 'Оорудан');
    });
  });

  group('WorkSchedule', () {
    test('a row without a teacher is the school default', () {
      final row = WorkSchedule.fromJson({
        'id': 's-1',
        'day_of_week': 2,
        'start_time': '08:00:00',
        'end_time': '17:00:00',
        'grace_minutes': 5,
      });
      expect(row.isSchoolDefault, isTrue);
      expect(weekdayName(row.dayOfWeek), 'Шаршемби');
    });

    test('a teacher override is not the default', () {
      final row = WorkSchedule.fromJson({
        'id': 's-2',
        'teacher_id': 't-1',
        'day_of_week': 0,
      });
      expect(row.isSchoolDefault, isFalse);
    });

    test('grace defaults to the column value, not either app\'s guess', () {
      // The apps used to default this to 15 and 5, so the same response read
      // as a different policy depending on which one you opened.
      expect(WorkSchedule.fromJson({'day_of_week': 0}).graceMinutes, 0);
    });

    test('an out-of-range weekday has no name rather than a wrong one', () {
      expect(weekdayName(9), isEmpty);
      expect(weekdayName(-1), isEmpty);
    });
  });

  group('SchoolSettings', () {
    test('maps the settings a screen shows', () {
      final school = SchoolSettings.fromJson({
        'id': 's-1',
        'name': 'Мектеп',
        'code': 'SCH-001',
        'latitude': 42.87,
        'longitude': 74.6,
        'allowed_radius_meters': 50,
        'max_accuracy_meters': 50,
        'grace_minutes': 5,
        'timezone': 'Asia/Bishkek',
        'device_binding_enabled': true,
        'is_review_demo': false,
        'attendance_start_date': '2026-09-07',
      });
      expect(school.allowedRadiusMeters, 50.0);
      expect(school.deviceBindingEnabled, isTrue);
      expect(school.attendanceStartDate, '2026-09-07');
    });

    test('never exposes a bot token, because the API never sends one', () {
      final json = SchoolSettings.fromJson({
        'id': 's-1',
        'telegram_bot_token': 'should-not-be-read',
      });
      expect(
        json.toString(),
        isNot(contains('should-not-be-read')),
        reason: 'the model has no field for it',
      );
    });
  });

  group('LeavesRepository', () {
    test('a teacher reads their own requests', () async {
      final captured = <RequestOptions>[];
      final repo = LeavesRepository(
        dio: dioReturning([
          {
            'id': 'l-1',
            'target_date': '2026-09-20',
            'reason': 'Үй-бүлөлүк жагдай',
            'status': 'PENDING',
          },
        ], capture: captured),
      );
      final rows = await repo.list();
      expect(captured.single.path, '/leaves/mine');
      expect(rows.single.isPending, isTrue);
      expect(rows.single.status.label, 'Каралууда');
    });

    test('an administrator reads the school queue', () async {
      final captured = <RequestOptions>[];
      final repo = LeavesRepository(
        dio: dioReturning(<Object>[], capture: captured),
      );
      await repo.list(admin: true);
      expect(captured.single.path, '/leaves/admin');
    });

    test('a decision is sent in the API\'s own spelling', () async {
      final captured = <RequestOptions>[];
      final repo = LeavesRepository(dio: dioReturning('', capture: captured));
      await repo.decide(
        requestId: 'l-1',
        status: LeaveStatus.approved,
        reason: 'Макул',
      );
      expect(captured.single.path, '/leaves/admin/l-1/decision');
      expect((captured.single.data as Map)['status'], 'APPROVED');
    });

    test('an unknown status is pending, never approved', () {
      expect(LeaveStatus.parse('SOMETHING'), LeaveStatus.pending);
      expect(LeaveStatus.parse(null), LeaveStatus.pending);
    });
  });

  group('SchoolRepository', () {
    test('an update sends only what it was given', () async {
      final captured = <RequestOptions>[];
      final repo = SchoolRepository(
        dio: dioReturning({'id': 's-1'}, capture: captured),
      );
      await repo.update(schoolId: 's-1', deviceBindingEnabled: true);
      expect(captured.single.data, {'device_binding_enabled': true});
    });

    test('a reset carries the exact confirmation the API demands', () async {
      final captured = <RequestOptions>[];
      final repo = SchoolRepository(
        dio: dioReturning({'deleted': 12}, capture: captured),
      );
      expect(await repo.resetAttendance(), 12);
      expect(
        (captured.single.data as Map)['confirmation'],
        'RESET ATTENDANCE',
      );
    });
  });
}
