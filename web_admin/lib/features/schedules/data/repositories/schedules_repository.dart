import 'package:admin_core/admin_core.dart' as core;
import 'package:dio/dio.dart';
import 'package:teacher_admin/core/network/admin_api_client.dart';

/// The shared schedule model; this app's screens keep their original name.
typedef ScheduleItem = core.WorkSchedule;

class SchedulesRepository {
  SchedulesRepository({Dio? dio})
    : _schedules = core.SchedulesRepository(
        dio: dio ?? AdminApiClient.instance.dio,
      );

  final core.SchedulesRepository _schedules;

  Future<List<ScheduleItem>> getWeeklySchedules({String? teacherId}) async {
    try {
      return await _schedules.week(teacherId: teacherId);
    } on core.AdminApiException {
      return [];
    }
  }

  Future<bool> createOrUpdateSchedule({
    required int dayOfWeek,
    required String startTime,
    required String endTime,
    int graceMinutes = 5,
    bool isDayOff = false,
    String? teacherId,
  }) async {
    try {
      await _schedules.save(
        dayOfWeek: dayOfWeek,
        startTime: startTime,
        endTime: endTime,
        graceMinutes: graceMinutes,
        isDayOff: isDayOff,
        teacherId: teacherId,
      );
      return true;
    } on core.AdminApiException {
      return false;
    }
  }

  Future<bool> updateSchedule({
    required String scheduleId,
    String? startTime,
    String? endTime,
    int? graceMinutes,
    bool? isDayOff,
  }) async {
    try {
      await _schedules.update(
        scheduleId: scheduleId,
        startTime: startTime,
        endTime: endTime,
        graceMinutes: graceMinutes,
        isDayOff: isDayOff,
      );
      return true;
    } on core.AdminApiException {
      return false;
    }
  }
}
