import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:teacher_mobile/core/constants/app_constants.dart';

class TeacherProfileData {
  final String id;
  final String fullName;
  final String username;
  final String employeeCode;
  final String? phoneNumber;
  final String? subject;
  final bool isDemo;

  TeacherProfileData({
    required this.id,
    required this.fullName,
    required this.username,
    required this.employeeCode,
    this.phoneNumber,
    this.subject,
    required this.isDemo,
  });

  factory TeacherProfileData.fromJson(Map<String, dynamic> json) {
    return TeacherProfileData(
      id: json['id'] as String,
      fullName: json['full_name'] as String,
      username: json['username'] as String,
      employeeCode: json['employee_code'] as String,
      phoneNumber: json['phone_number'] as String?,
      subject: json['subject'] as String?,
      isDemo: json['is_demo'] as bool? ?? false,
    );
  }
}

class MobileScheduleItem {
  final int dayOfWeek;
  final String startTime;
  final String endTime;
  final int graceMinutes;
  final bool isDayOff;

  MobileScheduleItem({
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.graceMinutes,
    required this.isDayOff,
  });

  factory MobileScheduleItem.fromJson(Map<String, dynamic> json) {
    return MobileScheduleItem(
      dayOfWeek: json['day_of_week'] as int,
      startTime: json['start_time'] as String,
      endTime: json['end_time'] as String,
      graceMinutes: json['grace_minutes'] as int? ?? 5,
      isDayOff: json['is_day_off'] as bool? ?? false,
    );
  }
}

class ProfileRepository {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  ProfileRepository({
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

  Future<TeacherProfileData?> getMyProfile() async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.get(
        '${AppConstants.defaultBaseUrl}/teachers/me',
        options: options,
      );
      if (response.data == null) return null;
      return TeacherProfileData.fromJson(response.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<List<MobileScheduleItem>> getMySchedules() async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.get(
        '${AppConstants.defaultBaseUrl}/schedules',
        options: options,
      );
      final list = (response.data['schedules'] as List)
          .map((s) => MobileScheduleItem.fromJson(s as Map<String, dynamic>))
          .toList();
      return list;
    } catch (_) {
      return [];
    }
  }
}
