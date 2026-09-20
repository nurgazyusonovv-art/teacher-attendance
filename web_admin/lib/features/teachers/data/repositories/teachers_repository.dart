import 'package:admin_core/admin_core.dart' as core;
import 'package:dio/dio.dart';
import 'package:teacher_admin/features/attendance/data/repositories/admin_attendance_repository.dart';
import 'package:teacher_admin/core/constants/app_constants.dart';
import 'package:teacher_admin/core/network/admin_api_client.dart';

/// The shared teacher model; this app's screens keep their original name.
typedef TeacherItem = core.Teacher;

class TeachersRepository {
  TeachersRepository({Dio? dio})
    : _dio = dio ?? AdminApiClient.instance.dio,
      _teachers = core.TeachersRepository(
        dio: dio ?? AdminApiClient.instance.dio,
        basePath: AppConstants.apiBaseUrl,
      );

  final Dio _dio;
  final core.TeachersRepository _teachers;

  Future<List<TeacherItem>> getTeachers({String? search, bool? isActive}) async {
    try {
      final page = await _teachers.list(search: search, isActive: isActive);
      return page.items;
    } on core.AdminApiException {
      // Screens here render an empty table rather than an error state.
      return [];
    }
  }

  Future<TeacherItem> getTeacher(String id) => _teachers.getById(id);

  Future<List<AdminDailyAttendanceItem>> getHistory(String id) async {
    final response = await _dio.get(
      '${AppConstants.apiBaseUrl}/attendance/teacher/${Uri.encodeComponent(id)}/history',
    );
    return (response.data as List)
        .map((r) => AdminDailyAttendanceItem.fromJson(r as Map<String, dynamic>))
        .toList();
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
      await _teachers.create(
        fullName: fullName,
        username: username,
        password: password,
        employeeCode: employeeCode,
        phoneNumber: phoneNumber,
        subject: subject,
      );
      return true;
    } on core.AdminApiException catch (error) {
      if (error.statusCode == 422) {
        throw Exception(
          'Маалыматтарды текшериңиз: аты-жөнү кеминде 2, логин 3, сырсөз 8, табель номери 2 белгиден турушу керек.',
        );
      }
      if (error.isAuthFailure) {
        throw Exception('Админ сессиясын текшериңиз. Аккаунтка кайра кириңиз.');
      }
      // Only a rejection the API meant for a person is shown verbatim; a 500
      // carries an internal message that would mean nothing to an administrator.
      if (error.statusCode == 400 || error.statusCode == 409) {
        throw Exception(error.message);
      }
      throw Exception(
        'Мугалимди кошуу ырасталган жок. Тизмени текшерип, кайра аракет кылыңыз.',
      );
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
      await _teachers.update(
        teacherId: teacherId,
        fullName: fullName,
        employeeCode: employeeCode,
        phoneNumber: phoneNumber,
        subject: subject,
        isActive: isActive,
      );
      return true;
    } on core.AdminApiException {
      return false;
    }
  }

  Future<bool> toggleActive(String teacherId, bool currentlyActive) =>
      updateTeacher(teacherId: teacherId, isActive: !currentlyActive);
}
