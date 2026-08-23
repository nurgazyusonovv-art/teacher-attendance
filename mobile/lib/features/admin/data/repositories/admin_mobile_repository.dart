import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../../../core/constants/app_constants.dart';

class TeacherItemModel {
  final String id;
  final String userId;
  final String schoolId;
  final String fullName;
  final String email;
  final String username;
  final String? phone;
  final String employeeCode;
  final bool isActive;

  TeacherItemModel({
    required this.id,
    required this.userId,
    required this.schoolId,
    required this.fullName,
    required this.email,
    required this.username,
    this.phone,
    required this.employeeCode,
    required this.isActive,
  });

  factory TeacherItemModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    return TeacherItemModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      schoolId: json['school_id'] as String,
      fullName: user?['full_name'] as String? ?? json['full_name'] as String? ?? 'Мугалим',
      email: user?['email'] as String? ?? json['email'] as String? ?? '',
      username: user?['username'] as String? ?? json['username'] as String? ?? '',
      phone: json['phone'] as String?,
      employeeCode: json['employee_code'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class WorkScheduleItemModel {
  final String? id;
  final int dayOfWeek;
  final String? startTime;
  final String? endTime;
  final int graceMinutes;
  final bool isDayOff;

  WorkScheduleItemModel({
    this.id,
    required this.dayOfWeek,
    this.startTime,
    this.endTime,
    required this.graceMinutes,
    required this.isDayOff,
  });

  factory WorkScheduleItemModel.fromJson(Map<String, dynamic> json) {
    return WorkScheduleItemModel(
      id: json['id'] as String?,
      dayOfWeek: json['day_of_week'] as int,
      startTime: json['start_time'] as String?,
      endTime: json['end_time'] as String?,
      graceMinutes: json['grace_minutes'] as int? ?? 15,
      isDayOff: json['is_day_off'] as bool? ?? false,
    );
  }
}

class AdminMobileRepository {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  AdminMobileRepository({
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

  // 1. Dashboard
  Future<Map<String, dynamic>?> getTodayDashboard() async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.get(
        '${AppConstants.defaultBaseUrl}/attendance/dashboard/today',
        options: options,
      );
      return response.data as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // 2. Teachers CRUD
  Future<List<TeacherItemModel>> getTeachers() async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.get(
        '${AppConstants.defaultBaseUrl}/teachers',
        options: options,
      );
      final raw = response.data;
      final List list = raw is Map ? (raw['items'] as List? ?? []) : (raw as List? ?? []);
      return list
          .map((i) => TeacherItemModel.fromJson(i as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> createTeacher({
    required String fullName,
    required String username,
    required String email,
    required String password,
    required String employeeCode,
    String? phone,
  }) async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.post(
        '${AppConstants.defaultBaseUrl}/teachers',
        data: {
          'full_name': fullName,
          'username': username,
          'email': email,
          'password': password,
          'employee_code': employeeCode,
          'phone': phone,
        },
        options: options,
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  Future<bool> toggleTeacherActive(String teacherId, bool isActive) async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.patch(
        '${AppConstants.defaultBaseUrl}/teachers/$teacherId',
        data: {'is_active': isActive},
        options: options,
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // 3. Schedules
  Future<List<WorkScheduleItemModel>> getWeeklySchedules() async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.get(
        '${AppConstants.defaultBaseUrl}/schedules',
        options: options,
      );
      final raw = response.data;
      final List list = raw is List ? raw : (raw is Map ? (raw['items'] as List? ?? []) : []);
      return list
          .map((i) => WorkScheduleItemModel.fromJson(i as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> updateSchedule(WorkScheduleItemModel schedule) async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.post(
        '${AppConstants.defaultBaseUrl}/schedules/',
        data: {
          'day_of_week': schedule.dayOfWeek,
          'start_time': schedule.startTime,
          'end_time': schedule.endTime,
          'grace_minutes': schedule.graceMinutes,
          'is_day_off': schedule.isDayOff,
        },
        options: options,
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // 4. Manual attendance correction
  Future<bool> manualCorrection({
    required String teacherId,
    required String targetDate,
    required String status,
    required String reason,
    String? checkInTime,
    String? checkOutTime,
  }) async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.post(
        '${AppConstants.defaultBaseUrl}/attendance/manual-correction',
        data: {
          'teacher_id': teacherId,
          'target_date': targetDate,
          'status': status,
          'reason': reason,
          'check_in_time': checkInTime,
          'check_out_time': checkOutTime,
        },
        options: options,
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // 5. School QR & Settings
  Future<Map<String, dynamic>?> getSchoolQr() async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.get(
        '${AppConstants.defaultBaseUrl}/qr/current',
        options: options,
      );
      return response.data as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // 6. Teacher specific history
  Future<List<Map<String, dynamic>>> getTeacherHistory({
    required String teacherId,
    int? year,
    int? month,
  }) async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.get(
        '${AppConstants.defaultBaseUrl}/attendance/teacher/$teacherId/history',
        queryParameters: {
          'year': ?year,
          'month': ?month,
        },
        options: options,
      );
      final list = response.data as List? ?? [];
      return list.map((e) => e as Map<String, dynamic>).toList();
    } catch (_) {
      return [];
    }
  }

  // 7. Teacher specific schedules
  Future<List<WorkScheduleItemModel>> getTeacherSchedules({required String teacherId}) async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.get(
        '${AppConstants.defaultBaseUrl}/schedules',
        queryParameters: {'teacher_id': teacherId},
        options: options,
      );
      final raw = response.data;
      final List list = raw is Map ? (raw['schedules'] as List? ?? []) : (raw is List ? raw : []);
      return list
          .map((i) => WorkScheduleItemModel.fromJson(i as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> saveTeacherSchedule({
    required String teacherId,
    required WorkScheduleItemModel schedule,
  }) async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.post(
        '${AppConstants.defaultBaseUrl}/schedules',
        data: {
          'teacher_id': teacherId,
          'day_of_week': schedule.dayOfWeek,
          'start_time': schedule.startTime,
          'end_time': schedule.endTime,
          'grace_minutes': schedule.graceMinutes,
          'is_day_off': schedule.isDayOff,
        },
        options: options,
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteTeacherSchedule(String scheduleId) async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.delete(
        '${AppConstants.defaultBaseUrl}/schedules/$scheduleId',
        options: options,
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
