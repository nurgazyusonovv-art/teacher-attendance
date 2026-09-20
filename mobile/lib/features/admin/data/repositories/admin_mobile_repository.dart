import 'package:admin_core/admin_core.dart' as core;
import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage_service.dart';

/// The shared teacher model; this app's screens keep their original name.
typedef TeacherItemModel = core.Teacher;
typedef LessonDelayModel = core.LessonDelay;
typedef WorkScheduleItemModel = core.WorkSchedule;

class AdminMobileRepository {
  final ApiClient _apiClient;

  AdminMobileRepository({ApiClient? apiClient})
    : _apiClient =
          apiClient ?? ApiClient(storageService: SecureStorageService());

  Dio get _dio => _apiClient.dio;

  // 1. Dashboard
  Future<Map<String, dynamic>?> getTodayDashboard({String? targetDate}) async {
    try {
      final response = await _dio.get(
        '/attendance/dashboard/today',
        queryParameters: targetDate != null
            ? {'target_date': targetDate}
            : null,
      );
      final data = response.data as Map<String, dynamic>;
      for (final record in data['records'] as List? ?? []) {
        if (record['display_status'] != null) record['status'] = record['display_status'];
      }
      return data;
    } catch (_) {
      return null;
    }
  }

  // 2. Teachers CRUD
  core.TeachersRepository get _teachers => core.TeachersRepository(dio: _dio);

  Future<List<TeacherItemModel>> getTeachers() async {
    try {
      return (await _teachers.list()).items;
    } on core.AdminApiException {
      // The teachers tab shows an empty list rather than an error state.
      return [];
    }
  }

  Future<(bool, String?)> createTeacher({
    required String fullName,
    required String username,
    required String subject,
    required String password,
    required String employeeCode,
    String? phone,
  }) async {
    try {
      await _teachers.create(
        fullName: fullName,
        username: username,
        subject: subject,
        password: password,
        employeeCode: employeeCode,
        phoneNumber: phone,
      );
      return (true, null);
    } on core.AdminApiException catch (error) {
      return (false, error.message);
    }
  }

  Future<(bool, String?)> updateTeacher({
    required String teacherId,
    String? fullName,
    String? subject,
    String? phone,
    String? employeeCode,
    String? password,
    bool? isActive,
  }) async {
    try {
      await _teachers.update(
        teacherId: teacherId,
        fullName: fullName != null && fullName.isNotEmpty ? fullName : null,
        subject: subject,
        phoneNumber: phone,
        employeeCode: employeeCode != null && employeeCode.isNotEmpty
            ? employeeCode
            : null,
        password: password != null && password.trim().isNotEmpty
            ? password.trim()
            : null,
        isActive: isActive,
      );
      return (true, null);
    } on core.AdminApiException catch (error) {
      return (false, error.message);
    }
  }

  /// Removes a teacher.
  ///
  /// A hard delete destroys attendance history, so the API refuses one for a
  /// teacher who has records unless [confirmation] carries its exact phrase
  /// (`core.hardDeleteConfirmation`). Without it the refusal comes back as a
  /// message for the administrator to read.
  Future<(bool, String?)> deleteTeacher(
    String teacherId, {
    bool hardDelete = true,
    String? confirmation,
  }) async {
    try {
      await _teachers.remove(
        teacherId,
        hardDelete: hardDelete,
        confirmation: confirmation,
      );
      return (true, null);
    } on core.AdminApiException catch (error) {
      return (false, error.message);
    }
  }

  Future<bool> toggleTeacherActive(String teacherId, bool isActive) async {
    try {
      await _teachers.setActive(teacherId, isActive);
      return true;
    } on core.AdminApiException {
      return false;
    }
  }

  core.AttendanceRepository get _attendance =>
      core.AttendanceRepository(dio: _dio);

  Future<(bool, String?)> addLessonDelay({
    required String teacherId,
    required String date,
    required int lessonNumber,
    required int delayMinutes,
    String? reason,
  }) async {
    try {
      await _attendance.addLessonDelay(
        teacherId: teacherId,
        date: date,
        lessonNumber: lessonNumber,
        delayMinutes: delayMinutes,
        reason: reason,
      );
      return (true, null);
    } on core.AdminApiException catch (error) {
      return (false, error.message);
    }
  }

  Future<List<LessonDelayModel>> getLessonDelays({
    required String teacherId,
    String? date,
    int? year,
    int? month,
  }) async {
    try {
      return await _attendance.lessonDelays(
        teacherId: teacherId,
        targetDate: date,
        year: year,
        month: month,
      );
    } on core.AdminApiException {
      return [];
    }
  }

  Future<bool> deleteLessonDelay(String delayId) async {
    try {
      await _attendance.deleteLessonDelay(delayId);
      return true;
    } on core.AdminApiException {
      return false;
    }
  }

  // 4. Schedules
  core.SchedulesRepository get _schedules =>
      core.SchedulesRepository(dio: _dio);

  Future<List<WorkScheduleItemModel>> getWeeklySchedules() async {
    try {
      return await _schedules.week();
    } on core.AdminApiException {
      return [];
    }
  }

  Future<(bool, String?)> updateSchedule(WorkScheduleItemModel schedule) async {
    try {
      await _schedules.save(
        dayOfWeek: schedule.dayOfWeek,
        startTime: schedule.startTime ?? '08:00:00',
        endTime: schedule.endTime ?? '17:00:00',
        graceMinutes: schedule.graceMinutes,
        isDayOff: schedule.isDayOff,
      );
      return (true, null);
    } on core.AdminApiException catch (error) {
      return (false, error.message);
    }
  }

  // 5. Manual attendance correction
  Future<bool> manualCorrection({
    required String teacherId,
    required String targetDate,
    required String status,
    required String reason,
    String? checkInTime,
    String? checkOutTime,
  }) async {
    try {
      await _attendance.manualCorrection(
        teacherId: teacherId,
        targetDate: targetDate,
        status: status,
        reason: reason,
        checkInTime: checkInTime,
        checkOutTime: checkOutTime,
      );
      return true;
    } on core.AdminApiException {
      return false;
    }
  }

  // 6. School QR & Settings
  core.SchoolRepository get _school => core.SchoolRepository(dio: _dio);

  Future<core.QrPayload?> getSchoolQr() async {
    try {
      return await _school.qr();
    } on core.AdminApiException {
      return null;
    }
  }

  Future<core.QrPayload?> rotateSchoolQr(String schoolId) async {
    try {
      return await _school.rotateQr(schoolId);
    } on core.AdminApiException {
      return null;
    }
  }

  Future<core.SchoolSettings?> getSchoolSettings() async {
    try {
      return await _school.current();
    } on core.AdminApiException {
      return null;
    }
  }

  Future<(bool, String?)> updateSchoolSettings({
    required String schoolId,
    String? name,
    double? latitude,
    double? longitude,
    double? radius,
    double? maxAccuracy,
    String? telegramBotToken,
    String? telegramChatId,
    bool? telegramEnabled,
    String? telegramReportTime,
  }) async {
    try {
      await _school.update(
        schoolId: schoolId,
        name: name != null && name.isNotEmpty ? name : null,
        latitude: latitude,
        longitude: longitude,
        allowedRadiusMeters: radius,
        maxAccuracyMeters: maxAccuracy,
        telegramBotToken: telegramBotToken,
        telegramChatId: telegramChatId,
        telegramEnabled: telegramEnabled,
        telegramReportTime: telegramReportTime,
      );
      return (true, null);
    } on core.AdminApiException catch (error) {
      return (false, error.message);
    }
  }

  Future<(bool, String, String?)> sendTelegramReport({
    String? targetDate,
    String? botToken,
    String? chatId,
  }) async {
    try {
      final response = await _dio.post(
        '/reports/telegram/send',
        data: {
          'target_date': ?targetDate,
          if (botToken != null && botToken.isNotEmpty) 'bot_token': botToken,
          if (chatId != null && chatId.isNotEmpty) 'chat_id': chatId,
        },
      );
      final data = response.data as Map<String, dynamic>;
      final msg =
          data['message'] as String? ??
          'Отчет Telegram\'га ийгиликтүү жөнөтүлдү!';
      final text = data['report_text'] as String?;
      return (true, msg, text);
    } on DioException catch (e) {
      final data = e.response?.data;
      String? msg;
      if (data is Map) {
        msg = data['message'] as String? ?? data['detail'] as String?;
      }
      return (false, msg ?? 'Telegram\'га жөнөтүүдө ката кетти', null);
    } catch (e) {
      return (false, e.toString(), null);
    }
  }

  Future<(bool, String)> testTelegramConnection({
    required String botToken,
    required String chatId,
    String? schoolName,
  }) async {
    try {
      final response = await _dio.post(
        '/reports/telegram/test',
        data: {
          'bot_token': botToken,
          'chat_id': chatId,
          'school_name': ?schoolName,
        },
      );
      final data = response.data as Map<String, dynamic>;
      final msg =
          data['message'] as String? ??
          'Тесттик билдирүү ийгиликтүү жөнөтүлдү!';
      return (true, msg);
    } on DioException catch (e) {
      final data = e.response?.data;
      String? msg;
      if (data is Map) {
        msg = data['message'] as String? ?? data['detail'] as String?;
      }
      return (false, msg ?? 'Telegram ботко туташууда ката кетти');
    } catch (e) {
      return (false, e.toString());
    }
  }

  Future<String?> previewTelegramReport({String? targetDate}) async {
    try {
      final response = await _dio.get(
        '/reports/telegram/preview',
        queryParameters: {'target_date': ?targetDate},
      );
      final data = response.data as Map<String, dynamic>;
      return data['report_text'] as String?;
    } catch (_) {
      return null;
    }
  }

  // 7. Teacher specific history
  Future<List<Map<String, dynamic>>> getTeacherHistory({
    required String teacherId,
    int? year,
    int? month,
  }) async {
    try {
      final response = await _dio.get(
        '/attendance/teacher/$teacherId/history',
        queryParameters: {'year': ?year, 'month': ?month},
      );
      final list = response.data as List? ?? [];
      return list.map((e) => e as Map<String, dynamic>).toList();
    } catch (_) {
      return [];
    }
  }

  // 8. Teacher specific schedules
  Future<List<WorkScheduleItemModel>> getTeacherSchedules({
    required String teacherId,
  }) async {
    try {
      final response = await _dio.get(
        '/schedules',
        queryParameters: {'teacher_id': teacherId},
      );
      final raw = response.data;
      final List list = raw is Map
          ? (raw['schedules'] as List? ?? [])
          : (raw is List ? raw : []);
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
      final response = await _dio.post(
        '/schedules',
        data: {
          'teacher_id': teacherId,
          'day_of_week': schedule.dayOfWeek,
          'start_time': schedule.startTime,
          'end_time': schedule.endTime,
          'grace_minutes': schedule.graceMinutes,
          'is_day_off': schedule.isDayOff,
        },
      );
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  Future<bool> deleteTeacherSchedule(String scheduleId) async {
    try {
      final response = await _dio.delete('/schedules/$scheduleId');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
