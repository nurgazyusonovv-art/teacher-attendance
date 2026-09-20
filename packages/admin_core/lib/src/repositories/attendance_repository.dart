import '../api.dart';
import '../models/attendance.dart';

/// Attendance administration: the daily dashboard, reports, manual
/// corrections and per-lesson delays.
class AttendanceRepository extends AdminApi {
  const AttendanceRepository({required super.dio, super.basePath});

  /// The dashboard for one day, defaulting to the school's today.
  Future<AttendanceDashboard> dashboard({String? targetDate}) {
    return guard(() async {
      final response = await dio.get(
        url('/attendance/dashboard/today'),
        queryParameters: targetDate == null
            ? null
            : {'target_date': targetDate},
      );
      return AttendanceDashboard.fromJson(response.data as Map<String, dynamic>);
    }, 'Дашбордду жүктөө ишке ашкан жок.');
  }

  /// One page of the school's history.
  Future<AttendancePage> history({
    String? startDate,
    String? endDate,
    String? teacherId,
    int skip = 0,
    int limit = 500,
  }) {
    return guard(() async {
      final response = await dio.get(
        url('/attendance/history'),
        queryParameters: {
          'skip': skip,
          'limit': limit,
          'start_date': ?startDate,
          'end_date': ?endDate,
          'teacher_id': ?teacherId,
        },
      );
      return AttendancePage.fromJson(response.data as Map<String, dynamic>);
    }, 'Катышуу тарыхын жүктөө ишке ашкан жок.');
  }

  /// Every row for a period, following the pages.
  ///
  /// Reports used to fetch the teacher list and then one history request per
  /// teacher, so the cost grew with the size of the school. A page that comes
  /// back empty while rows remain is an error rather than a short report —
  /// silently returning fewer rows would understate absences.
  Future<List<DailyAttendance>> allHistory({
    String? startDate,
    String? endDate,
    String? teacherId,
    int pageSize = 1000,
  }) async {
    final records = <DailyAttendance>[];
    var skip = 0;

    while (true) {
      final page = await history(
        startDate: startDate,
        endDate: endDate,
        teacherId: teacherId,
        skip: skip,
        limit: pageSize,
      );
      records.addAll(page.items);
      skip += page.items.length;
      if (skip >= page.total) break;
      if (page.items.isEmpty) {
        throw const AdminApiException(
          message: 'Катышуу тарыхы толук жүктөлгөн жок. Кайра аракет кылыңыз.',
        );
      }
    }

    records.sort((a, b) => b.date.compareTo(a.date));
    return records;
  }

  /// One teacher's own history.
  Future<List<DailyAttendance>> teacherHistory(
    String teacherId, {
    int? year,
    int? month,
  }) {
    return guard(() async {
      final response = await dio.get(
        url('/attendance/teacher/${Uri.encodeComponent(teacherId)}/history'),
        queryParameters: {'year': ?year, 'month': ?month},
      );
      return (response.data as List<dynamic>)
          .map((r) => DailyAttendance.fromJson(r as Map<String, dynamic>))
          .toList();
    }, 'Мугалимдин тарыхын жүктөө ишке ашкан жок.');
  }

  /// Corrects a recorded day. The API audits every correction.
  Future<DailyAttendance> manualCorrection({
    required String teacherId,
    required String targetDate,
    required String status,
    required String reason,
    String? checkInTime,
    String? checkOutTime,
  }) {
    return guard(() async {
      final response = await dio.post(
        url('/attendance/manual-correction'),
        data: {
          'teacher_id': teacherId,
          'target_date': targetDate,
          'status': status,
          'reason': reason,
          'check_in_time': checkInTime,
          'check_out_time': checkOutTime,
        },
      );
      return DailyAttendance.fromJson(response.data as Map<String, dynamic>);
    }, 'Катышууну оңдоо ишке ашкан жок.');
  }

  Future<List<LessonDelay>> lessonDelays({
    String? teacherId,
    String? targetDate,
    int? year,
    int? month,
  }) {
    return guard(() async {
      final response = await dio.get(
        url('/attendance/lesson-delays'),
        queryParameters: {
          'teacher_id': ?teacherId,
          'target_date': ?targetDate,
          'year': ?year,
          'month': ?month,
        },
      );
      return (response.data as List<dynamic>)
          .map((r) => LessonDelay.fromJson(r as Map<String, dynamic>))
          .toList();
    }, 'Сабак кечигүүлөрүн жүктөө ишке ашкан жок.');
  }

  Future<LessonDelay> addLessonDelay({
    required String teacherId,
    required String date,
    required int lessonNumber,
    required int delayMinutes,
    String? reason,
  }) {
    return guard(() async {
      final response = await dio.post(
        url('/attendance/lesson-delays'),
        data: {
          'teacher_id': teacherId,
          'date': date,
          'lesson_number': lessonNumber,
          'delay_minutes': delayMinutes,
          'reason': reason,
        },
      );
      return LessonDelay.fromJson(response.data as Map<String, dynamic>);
    }, 'Сабак кечигүүсүн кошуу ишке ашкан жок.');
  }

  Future<void> deleteLessonDelay(String delayId) {
    return guard(() async {
      await dio.delete(
        url('/attendance/lesson-delays/${Uri.encodeComponent(delayId)}'),
      );
    }, 'Сабак кечигүүсүн өчүрүү ишке ашкан жок.');
  }
}
