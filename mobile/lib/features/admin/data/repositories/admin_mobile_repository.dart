import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage_service.dart';

class TeacherItemModel {
  final String id;
  final String userId;
  final String schoolId;
  final String fullName;
  final String email;
  final String username;
  final String? phone;
  final String? subject;
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
    this.subject,
    required this.employeeCode,
    required this.isActive,
  });

  factory TeacherItemModel.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;
    return TeacherItemModel(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? user?['id'] as String? ?? '',
      schoolId: json['school_id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? user?['full_name'] as String? ?? 'Мугалим',
      email: json['email'] as String? ?? user?['email'] as String? ?? '',
      username: json['username'] as String? ?? user?['username'] as String? ?? '',
      phone: json['phone_number'] as String? ?? json['phone'] as String?,
      subject: json['subject'] as String?,
      employeeCode: json['employee_code'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  TeacherItemModel copyWith({
    String? id,
    String? userId,
    String? schoolId,
    String? fullName,
    String? email,
    String? username,
    String? phone,
    String? subject,
    String? employeeCode,
    bool? isActive,
  }) {
    return TeacherItemModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      schoolId: schoolId ?? this.schoolId,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      username: username ?? this.username,
      phone: phone ?? this.phone,
      subject: subject ?? this.subject,
      employeeCode: employeeCode ?? this.employeeCode,
      isActive: isActive ?? this.isActive,
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

class LessonDelayModel {
  final String id;
  final String teacherId;
  final String schoolId;
  final String date;
  final int lessonNumber;
  final int delayMinutes;
  final String? reason;
  final String? teacherName;
  final String createdAt;

  LessonDelayModel({
    required this.id,
    required this.teacherId,
    required this.schoolId,
    required this.date,
    required this.lessonNumber,
    required this.delayMinutes,
    this.reason,
    this.teacherName,
    required this.createdAt,
  });

  factory LessonDelayModel.fromJson(Map<String, dynamic> json) {
    return LessonDelayModel(
      id: json['id'] as String? ?? '',
      teacherId: json['teacher_id'] as String? ?? '',
      schoolId: json['school_id'] as String? ?? '',
      date: json['date'] as String? ?? '',
      lessonNumber: json['lesson_number'] as int? ?? 1,
      delayMinutes: json['delay_minutes'] as int? ?? 0,
      reason: json['reason'] as String?,
      teacherName: json['teacher_name'] as String?,
      createdAt: json['created_at'] as String? ?? '',
    );
  }
}

class AdminMobileRepository {
  final ApiClient _apiClient;

  AdminMobileRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient(storageService: SecureStorageService());

  Dio get _dio => _apiClient.dio;

  // 1. Dashboard
  Future<Map<String, dynamic>?> getTodayDashboard({String? targetDate}) async {
    try {
      final response = await _dio.get(
        '/attendance/dashboard/today',
        queryParameters: targetDate != null ? {'target_date': targetDate} : null,
      );
      return response.data as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // 2. Teachers CRUD
  Future<List<TeacherItemModel>> getTeachers() async {
    try {
      final response = await _dio.get('/teachers');
      final raw = response.data;
      final List list = raw is Map ? (raw['items'] as List? ?? []) : (raw as List? ?? []);
      return list
          .map((i) => TeacherItemModel.fromJson(i as Map<String, dynamic>))
          .toList();
    } catch (_) {
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
      final response = await _dio.post(
        '/teachers',
        data: {
          'full_name': fullName,
          'username': username,
          'subject': subject,
          'password': password,
          'employee_code': employeeCode,
          'phone_number': phone,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return (true, null);
      }
      return (false, 'Ката: ${response.statusCode}');
    } on DioException catch (e) {
      final data = e.response?.data;
      String? msg;
      if (data is Map) {
        msg = data['message'] as String? ?? data['detail'] as String?;
      }
      return (false, msg ?? 'Серверге туташуу катасы. Логин же сессияны текшериңиз.');
    } catch (e) {
      return (false, e.toString());
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
      final data = <String, dynamic>{};
      if (fullName != null && fullName.isNotEmpty) data['full_name'] = fullName;
      if (subject != null) data['subject'] = subject;
      if (phone != null) data['phone_number'] = phone;
      if (employeeCode != null && employeeCode.isNotEmpty) data['employee_code'] = employeeCode;
      if (password != null && password.trim().isNotEmpty) data['password'] = password.trim();
      if (isActive != null) data['is_active'] = isActive;

      final response = await _dio.patch(
        '/teachers/$teacherId',
        data: data,
      );
      if (response.statusCode == 200) {
        return (true, null);
      }
      return (false, 'Ката: ${response.statusCode}');
    } on DioException catch (e) {
      final data = e.response?.data;
      String? msg;
      if (data is Map) {
        msg = data['message'] as String? ?? data['detail'] as String?;
      }
      return (false, msg ?? 'Мугалимдин маалыматын өзгөртүүдө ката кетти');
    } catch (e) {
      return (false, e.toString());
    }
  }

  Future<(bool, String?)> deleteTeacher(String teacherId, {bool hardDelete = true}) async {
    try {
      final response = await _dio.delete(
        '/teachers/$teacherId',
        queryParameters: {'hard_delete': hardDelete},
      );
      if (response.statusCode == 200) {
        return (true, null);
      }
      return (false, 'Ката: ${response.statusCode}');
    } on DioException catch (e) {
      final data = e.response?.data;
      String? msg;
      if (data is Map) {
        msg = data['message'] as String? ?? data['detail'] as String?;
      }
      return (false, msg ?? 'Мугалимди өчүрүүдө ката кетти');
    } catch (e) {
      return (false, e.toString());
    }
  }

  Future<bool> toggleTeacherActive(String teacherId, bool isActive) async {
    try {
      final response = await _dio.patch(
        '/teachers/$teacherId',
        data: {'is_active': isActive},
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // 3. Lesson Delays (Сабактардагы кечигүүлөр)
  Future<(bool, String?)> addLessonDelay({
    required String teacherId,
    required String date,
    required int lessonNumber,
    required int delayMinutes,
    String? reason,
  }) async {
    try {
      final response = await _dio.post(
        '/attendance/lesson-delays',
        data: {
          'teacher_id': teacherId,
          'date': date,
          'lesson_number': lessonNumber,
          'delay_minutes': delayMinutes,
          'reason': reason,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return (true, null);
      }
      return (false, 'Ката: ${response.statusCode}');
    } on DioException catch (e) {
      final data = e.response?.data;
      String? msg;
      if (data is Map) {
        msg = data['message'] as String? ?? data['detail'] as String?;
      }
      return (false, msg ?? 'Сабак кечигүүсүн кошууда ката кетти');
    } catch (e) {
      return (false, e.toString());
    }
  }

  Future<List<LessonDelayModel>> getLessonDelays({
    required String teacherId,
    String? date,
    int? year,
    int? month,
  }) async {
    try {
      final response = await _dio.get(
        '/attendance/lesson-delays',
        queryParameters: {
          'teacher_id': teacherId,
          if (date != null) 'target_date': date,
          if (year != null) 'year': year,
          if (month != null) 'month': month,
        },
      );
      final List list = response.data as List? ?? [];
      return list
          .map((i) => LessonDelayModel.fromJson(i as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> deleteLessonDelay(String delayId) async {
    try {
      final response = await _dio.delete('/attendance/lesson-delays/$delayId');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // 4. Schedules
  Future<List<WorkScheduleItemModel>> getWeeklySchedules() async {
    try {
      final response = await _dio.get('/schedules');
      final raw = response.data;
      final List list = raw is Map ? (raw['schedules'] as List? ?? []) : (raw is List ? raw : []);
      return list
          .map((i) => WorkScheduleItemModel.fromJson(i as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<(bool, String?)> updateSchedule(WorkScheduleItemModel schedule) async {
    try {
      final response = await _dio.post(
        '/schedules',
        data: {
          'day_of_week': schedule.dayOfWeek,
          'start_time': schedule.startTime ?? '08:00:00',
          'end_time': schedule.endTime ?? '17:00:00',
          'grace_minutes': schedule.graceMinutes,
          'is_day_off': schedule.isDayOff,
        },
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return (true, null);
      }
      return (false, 'Ката: ${response.statusCode}');
    } on DioException catch (e) {
      final data = e.response?.data;
      String? msg;
      if (data is Map) {
        msg = data['message'] as String? ?? data['detail'] as String?;
      }
      return (false, msg ?? 'Серверге туташуу катасы');
    } catch (e) {
      return (false, e.toString());
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
      final response = await _dio.post(
        '/attendance/manual-correction',
        data: {
          'teacher_id': teacherId,
          'target_date': targetDate,
          'status': status,
          'reason': reason,
          'check_in_time': checkInTime,
          'check_out_time': checkOutTime,
        },
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // 6. School QR & Settings
  Future<Map<String, dynamic>?> getSchoolQr() async {
    try {
      final response = await _dio.get('/qr/current');
      return response.data as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> rotateSchoolQr(String schoolId) async {
    try {
      final response = await _dio.post('/qr/$schoolId/rotate');
      return response.data as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> getSchoolSettings() async {
    try {
      final response = await _dio.get('/schools/current');
      return response.data as Map<String, dynamic>;
    } catch (_) {
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
      final data = <String, dynamic>{};
      if (name != null && name.isNotEmpty) data['name'] = name;
      if (latitude != null) data['latitude'] = latitude;
      if (longitude != null) data['longitude'] = longitude;
      if (radius != null) data['allowed_radius_meters'] = radius;
      if (maxAccuracy != null) data['max_accuracy_meters'] = maxAccuracy;
      if (telegramBotToken != null) data['telegram_bot_token'] = telegramBotToken;
      if (telegramChatId != null) data['telegram_chat_id'] = telegramChatId;
      if (telegramEnabled != null) data['telegram_enabled'] = telegramEnabled;
      if (telegramReportTime != null) data['telegram_report_time'] = telegramReportTime;

      final response = await _dio.patch(
        '/schools/$schoolId',
        data: data,
      );
      if (response.statusCode == 200) {
        return (true, null);
      }
      return (false, 'Ката: ${response.statusCode}');
    } on DioException catch (e) {
      final data = e.response?.data;
      String? msg;
      if (data is Map) {
        msg = data['message'] as String? ?? data['detail'] as String?;
      }
      return (false, msg ?? 'Мектептин жөндөөлөрүн өзгөртүүдө ката кетти');
    } catch (e) {
      return (false, e.toString());
    }
  }

  // 6.1 Telegram Reports
  Future<(bool, String, String?)> sendTelegramReport({
    String? targetDate,
    String? botToken,
    String? chatId,
  }) async {
    try {
      final response = await _dio.post(
        '/reports/telegram/send',
        data: {
          if (targetDate != null) 'target_date': targetDate,
          if (botToken != null && botToken.isNotEmpty) 'bot_token': botToken,
          if (chatId != null && chatId.isNotEmpty) 'chat_id': chatId,
        },
      );
      final data = response.data as Map<String, dynamic>;
      final msg = data['message'] as String? ?? 'Отчет Telegram\'га ийгиликтүү жөнөтүлдү!';
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
          if (schoolName != null) 'school_name': schoolName,
        },
      );
      final data = response.data as Map<String, dynamic>;
      final msg = data['message'] as String? ?? 'Тесттик билдирүү ийгиликтүү жөнөтүлдү!';
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
        queryParameters: {
          if (targetDate != null) 'target_date': targetDate,
        },
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
        queryParameters: {
          if (year != null) 'year': year,
          if (month != null) 'month': month,
        },
      );
      final list = response.data as List? ?? [];
      return list.map((e) => e as Map<String, dynamic>).toList();
    } catch (_) {
      return [];
    }
  }

  // 8. Teacher specific schedules
  Future<List<WorkScheduleItemModel>> getTeacherSchedules({required String teacherId}) async {
    try {
      final response = await _dio.get(
        '/schedules',
        queryParameters: {'teacher_id': teacherId},
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
