import '../api.dart';
import '../models/schedule.dart';

/// Work schedules: the school's weekly default and per-teacher overrides.
class SchedulesRepository extends AdminApi {
  const SchedulesRepository({required super.dio, super.basePath});

  /// The week for a teacher, or the school's default when [teacherId] is null.
  Future<List<WorkSchedule>> week({String? teacherId}) {
    return guard(() async {
      final response = await dio.get(
        url('/schedules'),
        queryParameters: {'teacher_id': ?teacherId},
      );
      final body = response.data;
      final rows = body is Map
          ? (body['schedules'] as List<dynamic>? ?? const [])
          : (body as List<dynamic>? ?? const []);
      return rows
          .map((s) => WorkSchedule.fromJson(s as Map<String, dynamic>))
          .toList();
    }, 'Иш графигин жүктөө ишке ашкан жок.');
  }

  /// Creates the weekday's schedule, or replaces it when one exists.
  Future<WorkSchedule> save({
    required int dayOfWeek,
    String? startTime,
    String? endTime,
    int graceMinutes = 0,
    bool isDayOff = false,
    String? teacherId,
  }) {
    return guard(() async {
      final response = await dio.post(
        url('/schedules'),
        data: {
          'day_of_week': dayOfWeek,
          'start_time': startTime,
          'end_time': endTime,
          'grace_minutes': graceMinutes,
          'is_day_off': isDayOff,
          'teacher_id': teacherId,
        },
      );
      return WorkSchedule.fromJson(response.data as Map<String, dynamic>);
    }, 'Иш графигин сактоо ишке ашкан жок.');
  }

  /// Updates only the fields that are passed.
  Future<WorkSchedule> update({
    required String scheduleId,
    String? startTime,
    String? endTime,
    int? graceMinutes,
    bool? isDayOff,
  }) {
    return guard(() async {
      final response = await dio.patch(
        url('/schedules/${Uri.encodeComponent(scheduleId)}'),
        data: {
          'start_time': ?startTime,
          'end_time': ?endTime,
          'grace_minutes': ?graceMinutes,
          'is_day_off': ?isDayOff,
        },
      );
      return WorkSchedule.fromJson(response.data as Map<String, dynamic>);
    }, 'Иш графигин өзгөртүү ишке ашкан жок.');
  }

  Future<void> remove(String scheduleId) {
    return guard(() async {
      await dio.delete(url('/schedules/${Uri.encodeComponent(scheduleId)}'));
    }, 'Иш графигин өчүрүү ишке ашкан жок.');
  }
}
