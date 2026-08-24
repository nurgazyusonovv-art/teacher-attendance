import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage_service.dart';

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
  final ApiClient _apiClient;

  ProfileRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient(storageService: SecureStorageService());

  Dio get _dio => _apiClient.dio;

  Future<TeacherProfileData?> getMyProfile() async {
    try {
      final response = await _dio.get('/teachers/me');
      if (response.data == null) return null;
      return TeacherProfileData.fromJson(response.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<List<MobileScheduleItem>> getMySchedules() async {
    try {
      final response = await _dio.get('/schedules');
      final list = (response.data['schedules'] as List)
          .map((s) => MobileScheduleItem.fromJson(s as Map<String, dynamic>))
          .toList();
      return list;
    } catch (_) {
      return [];
    }
  }
}
