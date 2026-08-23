import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:teacher_admin/core/constants/app_constants.dart';

class TeacherItem {
  final String id;
  final String userId;
  final String employeeCode;
  final String? phoneNumber;
  final String? subject;
  final String fullName;
  final String username;
  final bool isActive;
  final bool isDemo;

  TeacherItem({
    required this.id,
    required this.userId,
    required this.employeeCode,
    this.phoneNumber,
    this.subject,
    required this.fullName,
    required this.username,
    required this.isActive,
    required this.isDemo,
  });

  factory TeacherItem.fromJson(Map<String, dynamic> json) {
    return TeacherItem(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      employeeCode: json['employee_code'] as String,
      phoneNumber: json['phone_number'] as String?,
      subject: json['subject'] as String?,
      fullName: json['full_name'] as String,
      username: json['username'] as String,
      isActive: json['is_active'] as bool? ?? true,
      isDemo: json['is_demo'] as bool? ?? false,
    );
  }
}

class TeachersRepository {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  TeachersRepository({
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

  Future<List<TeacherItem>> getTeachers({String? search, bool? isActive}) async {
    try {
      final options = await _getAuthOptions();
      final queryParams = <String, dynamic>{};
      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (isActive != null) queryParams['is_active'] = isActive;

      final response = await _dio.get(
        '${AppConstants.apiBaseUrl}/teachers',
        queryParameters: queryParams,
        options: options,
      );

      final items = (response.data['items'] as List)
          .map((i) => TeacherItem.fromJson(i as Map<String, dynamic>))
          .toList();
      return items;
    } catch (_) {
      return [];
    }
  }

  Future<bool> createTeacher({
    required String fullName,
    required String username,
    required String password,
    required String employeeCode,
    String? phoneNumber,
    String? subject,
  }) async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.post(
        '${AppConstants.apiBaseUrl}/teachers',
        data: {
          'full_name': fullName,
          'username': username,
          'password': password,
          'employee_code': employeeCode,
          'phone_number': phoneNumber,
          'subject': subject,
        },
        options: options,
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> updateTeacher({
    required String teacherId,
    String? fullName,
    String? employeeCode,
    String? phoneNumber,
    String? subject,
    bool? isActive,
  }) async {
    try {
      final options = await _getAuthOptions();
      final data = <String, dynamic>{};
      if (fullName != null) data['full_name'] = fullName;
      if (employeeCode != null) data['employee_code'] = employeeCode;
      if (phoneNumber != null) data['phone_number'] = phoneNumber;
      if (subject != null) data['subject'] = subject;
      if (isActive != null) data['is_active'] = isActive;

      final response = await _dio.patch(
        '${AppConstants.apiBaseUrl}/teachers/$teacherId',
        data: data,
        options: options,
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> toggleActive(String teacherId, bool currentlyActive) async {
    return updateTeacher(teacherId: teacherId, isActive: !currentlyActive);
  }
}
