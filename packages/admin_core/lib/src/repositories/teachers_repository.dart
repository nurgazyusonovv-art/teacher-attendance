import '../api.dart';
import '../models/teacher.dart';

/// Teacher administration, shared by both admin surfaces.
class TeachersRepository extends AdminApi {
  const TeachersRepository({required super.dio, super.basePath});

  /// Lists teachers in the caller's school.
  ///
  /// [limit] is the API's page size; the default matches the endpoint's own.
  Future<TeacherPage> list({
    String? search,
    bool? isActive,
    int skip = 0,
    int limit = 100,
  }) {
    return guard(() async {
      final query = <String, dynamic>{'skip': skip, 'limit': limit};
      if (search != null && search.isNotEmpty) query['search'] = search;
      if (isActive != null) query['is_active'] = isActive;

      final response = await dio.get(
        url('/teachers'),
        queryParameters: query,
      );
      return TeacherPage.fromJson(response.data as Map<String, dynamic>);
    }, 'Мугалимдердин тизмесин алуу ишке ашкан жок.');
  }

  Future<Teacher> getById(String teacherId) {
    return guard(() async {
      final response = await dio.get(
        url('/teachers/${Uri.encodeComponent(teacherId)}'),
      );
      return Teacher.fromJson(response.data as Map<String, dynamic>);
    }, 'Мугалимдин маалыматын алуу ишке ашкан жок.');
  }

  Future<Teacher> create({
    required String fullName,
    required String username,
    required String password,
    required String employeeCode,
    String? phoneNumber,
    String? subject,
  }) {
    return guard(() async {
      final response = await dio.post(
        url('/teachers'),
        data: {
          'full_name': fullName,
          'username': username,
          'password': password,
          'employee_code': employeeCode,
          if (phoneNumber != null && phoneNumber.isNotEmpty)
            'phone_number': phoneNumber,
          if (subject != null && subject.isNotEmpty) 'subject': subject,
        },
      );
      return Teacher.fromJson(response.data as Map<String, dynamic>);
    }, 'Мугалимди кошуу ишке ашкан жок.');
  }

  /// Updates only the fields that are passed.
  Future<Teacher> update({
    required String teacherId,
    String? fullName,
    String? employeeCode,
    String? phoneNumber,
    String? subject,
    String? password,
    bool? isActive,
  }) {
    return guard(() async {
      final data = <String, dynamic>{};
      if (fullName != null) data['full_name'] = fullName;
      if (employeeCode != null) data['employee_code'] = employeeCode;
      if (phoneNumber != null) data['phone_number'] = phoneNumber;
      if (subject != null) data['subject'] = subject;
      if (password != null) data['password'] = password;
      if (isActive != null) data['is_active'] = isActive;

      final response = await dio.patch(
        url('/teachers/${Uri.encodeComponent(teacherId)}'),
        data: data,
      );
      return Teacher.fromJson(response.data as Map<String, dynamic>);
    }, 'Мугалимдин маалыматын өзгөртүү ишке ашкан жок.');
  }

  Future<Teacher> setActive(String teacherId, bool isActive) =>
      update(teacherId: teacherId, isActive: isActive);

  /// Removes a teacher.
  ///
  /// A hard delete destroys attendance history, so the API refuses one for a
  /// teacher who has records unless [confirmation] carries its exact phrase.
  Future<void> remove(
    String teacherId, {
    bool hardDelete = false,
    String? confirmation,
  }) {
    return guard(() async {
      await dio.delete(
        url('/teachers/${Uri.encodeComponent(teacherId)}'),
        queryParameters: {
          'hard_delete': hardDelete,
          'confirmation': ?confirmation,
        },
      );
    }, 'Мугалимди өчүрүү ишке ашкан жок.');
  }
}

/// The phrase the API requires before a delete may destroy attendance history.
const String hardDeleteConfirmation = 'DELETE ATTENDANCE HISTORY';
