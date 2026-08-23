import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:teacher_admin/core/constants/app_constants.dart';

class ScheduleItem {
  final String id;
  final String? schoolId;
  final String? teacherId;
  final int dayOfWeek;
  final String startTime;
  final String endTime;
  final int graceMinutes;
  final bool isDayOff;

  ScheduleItem({
    required this.id,
    this.schoolId,
    this.teacherId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.graceMinutes,
    required this.isDayOff,
  });

  factory ScheduleItem.fromJson(Map<String, dynamic> json) {
    return ScheduleItem(
      id: json['id'] as String,
      schoolId: json['school_id'] as String?,
      teacherId: json['teacher_id'] as String?,
      dayOfWeek: json['day_of_week'] as int,
      startTime: json['start_time'] as String,
      endTime: json['end_time'] as String,
      graceMinutes: json['grace_minutes'] as int? ?? 5,
      isDayOff: json['is_day_off'] as bool? ?? false,
    );
  }
}

class SchedulesRepository {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  SchedulesRepository({
    Dio? dio,
    FlutterSecureStorage? storage,
  })  : _dio = dio ?? Dio(),
        _storage = storage ?? const FlutterSecureStorage();

  Future<Options> _getAuthOptions() async {
    final token = await _storage.read(key: AppConstants.keyAccessToken);
    return Options(
      headers: {
        'Authorization': 'Bearer $token',
      },
    );
  }

  Future<List<ScheduleItem>> getWeeklySchedules({String? teacherId}) async {
    try {
      final options = await _getAuthOptions();
      final queryParams = <String, dynamic>{};
      if (teacherId != null) queryParams['teacher_id'] = teacherId;

      final response = await _dio.get(
        '${AppConstants.apiBaseUrl}/schedules',
        queryParameters: queryParams,
        options: options,
      );

      final schedules = (response.data['schedules'] as List)
          .map((s) => ScheduleItem.fromJson(s as Map<String, dynamic>))
          .toList();
      return schedules;
    } catch (_) {
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
      final options = await _getAuthOptions();
      final response = await _dio.post(
        '${AppConstants.apiBaseUrl}/schedules',
        data: {
          'day_of_week': dayOfWeek,
          'start_time': startTime,
          'end_time': endTime,
          'grace_minutes': graceMinutes,
          'is_day_off': isDayOff,
          'teacher_id': teacherId,
        },
        options: options,
      );
      return response.statusCode == 200;
    } catch (_) {
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
      final options = await _getAuthOptions();
      final data = <String, dynamic>{};
      if (startTime != null) data['start_time'] = startTime;
      if (endTime != null) data['end_time'] = endTime;
      if (graceMinutes != null) data['grace_minutes'] = graceMinutes;
      if (isDayOff != null) data['is_day_off'] = isDayOff;

      final response = await _dio.patch(
        '${AppConstants.apiBaseUrl}/schedules/$scheduleId',
        data: data,
        options: options,
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
