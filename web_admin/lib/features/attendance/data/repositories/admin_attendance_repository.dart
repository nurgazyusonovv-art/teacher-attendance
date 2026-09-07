import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:teacher_admin/core/constants/app_constants.dart';
import 'package:teacher_admin/core/network/admin_api_client.dart';

class AdminDailyAttendanceItem {
  final String id;
  final String teacherId;
  final String schoolId;
  final String date;
  final String? checkInTime;
  final String? checkOutTime;
  final String status;
  final int lateMinutes;
  final int lessonLateMinutes;
  final int workedMinutes;
  final bool isManuallyCorrected;
  final String? correctionReason;
  final String? teacherName;
  final String? employeeCode;

  AdminDailyAttendanceItem({
    required this.id,
    required this.teacherId,
    required this.schoolId,
    required this.date,
    this.checkInTime,
    this.checkOutTime,
    required this.status,
    required this.lateMinutes,
    this.lessonLateMinutes = 0,
    required this.workedMinutes,
    required this.isManuallyCorrected,
    this.correctionReason,
    this.teacherName,
    this.employeeCode,
  });

  factory AdminDailyAttendanceItem.fromJson(Map<String, dynamic> json) {
    return AdminDailyAttendanceItem(
      id: json['id'] as String,
      teacherId: json['teacher_id'] as String,
      schoolId: json['school_id'] as String,
      date: json['date'] as String,
      checkInTime: json['check_in_time'] as String?,
      checkOutTime: json['check_out_time'] as String?,
      status: json['status'] as String? ?? 'ON_TIME',
      lateMinutes: json['late_minutes'] as int? ?? 0,
      lessonLateMinutes: json['lesson_late_minutes'] as int? ?? 0,
      workedMinutes: json['worked_minutes'] as int? ?? 0,
      isManuallyCorrected: json['is_manually_corrected'] as bool? ?? false,
      correctionReason: json['correction_reason'] as String?,
      teacherName: json['teacher_name'] as String?,
      employeeCode: json['employee_code'] as String?,
    );
  }
}

class AdminDashboardData {
  final int totalTeachers;
  final int checkedInCount;
  final int onTimeCount;
  final int lateCount;
  final int notCheckedInCount;
  final String date;
  final List<AdminDailyAttendanceItem> records;

  AdminDashboardData({
    required this.totalTeachers,
    required this.checkedInCount,
    required this.onTimeCount,
    required this.lateCount,
    required this.notCheckedInCount,
    required this.date,
    required this.records,
  });

  factory AdminDashboardData.fromJson(Map<String, dynamic> json) {
    return AdminDashboardData(
      totalTeachers: json['total_teachers'] as int? ?? 0,
      checkedInCount: json['checked_in_count'] as int? ?? 0,
      onTimeCount: json['on_time_count'] as int? ?? 0,
      lateCount: json['late_count'] as int? ?? 0,
      notCheckedInCount: json['not_checked_in_count'] as int? ?? 0,
      date: json['date'] as String? ?? '',
      records: (json['records'] as List? ?? [])
          .map(
            (r) => AdminDailyAttendanceItem.fromJson(r as Map<String, dynamic>),
          )
          .toList(),
    );
  }
}

class AdminAttendanceRepository {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  AdminAttendanceRepository({Dio? dio, FlutterSecureStorage? storage})
    : _dio = dio ?? AdminApiClient.instance.dio,
      _storage = storage ?? const FlutterSecureStorage();

  Future<Options> _getAuthOptions() async {
    final token = await _storage.read(key: AppConstants.keyAccessToken);
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  Future<AdminDashboardData?> getTodayDashboard({String? targetDate}) async {
    try {
      final options = await _getAuthOptions();
      final queryParams = <String, dynamic>{};
      if (targetDate != null) queryParams['target_date'] = targetDate;

      final response = await _dio.get(
        '${AppConstants.apiBaseUrl}/attendance/dashboard/today',
        queryParameters: queryParams,
        options: options,
      );
      return AdminDashboardData.fromJson(response.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Reads every teacher page, including inactive teachers, without hiding
  /// partial failures as an empty or complete report.
  Future<List<AdminDailyAttendanceItem>> getReportHistory() async {
    final options = await _getAuthOptions();
    final teachers = <Map<String, dynamic>>[];
    var skip = 0;
    while (true) {
      final response = await _dio.get(
        '${AppConstants.apiBaseUrl}/teachers',
        queryParameters: {'skip': skip, 'limit': 100},
        options: options,
      );
      final page = (response.data['items'] as List)
          .cast<Map<String, dynamic>>();
      teachers.addAll(page);
      skip += page.length;
      if (skip >= (response.data['total'] as int)) break;
      if (page.isEmpty) throw StateError('Incomplete teacher list');
    }
    final records = <AdminDailyAttendanceItem>[];
    // Bound concurrency so a large school cannot overwhelm the API.
    for (var offset = 0; offset < teachers.length; offset += 4) {
      final batch = teachers.skip(offset).take(4);
      final results = await Future.wait(
        batch.map((teacher) async {
          final response = await _dio.get(
            '${AppConstants.apiBaseUrl}/attendance/teacher/${teacher['id']}/history',
            options: options,
          );
          return (response.data as List).map((raw) {
            final json = Map<String, dynamic>.from(raw as Map);
            json['teacher_name'] = teacher['full_name'];
            json['employee_code'] = teacher['employee_code'];
            return AdminDailyAttendanceItem.fromJson(json);
          }).toList();
        }),
      );
      records.addAll(results.expand((items) => items));
    }
    records.sort((a, b) => b.date.compareTo(a.date));
    return records;
  }

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
        '${AppConstants.apiBaseUrl}/attendance/manual-correction',
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
}
