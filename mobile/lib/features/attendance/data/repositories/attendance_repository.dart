import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../admin/data/repositories/admin_mobile_repository.dart';

class DailyAttendanceModel {
  final String id;
  final String date;
  final String? checkInTime;
  final String? checkOutTime;
  final String status;
  final int lateMinutes;
  final int workedMinutes;
  final bool isManuallyCorrected;
  final String? correctionReason;
  final List<LessonDelayModel> lessonDelays;
  final int lessonLateMinutes;
  final int totalLateMinutes;

  DailyAttendanceModel({
    required this.id,
    required this.date,
    this.checkInTime,
    this.checkOutTime,
    required this.status,
    required this.lateMinutes,
    required this.workedMinutes,
    required this.isManuallyCorrected,
    this.correctionReason,
    this.lessonDelays = const [],
    this.lessonLateMinutes = 0,
    this.totalLateMinutes = 0,
  });

  factory DailyAttendanceModel.fromJson(Map<String, dynamic> json) {
    final rawDelays = json['lesson_delays'] as List? ?? [];
    final delays = rawDelays
        .map((e) => LessonDelayModel.fromJson(e as Map<String, dynamic>))
        .toList();
    final lateMins = json['late_minutes'] as int? ?? 0;
    final lessonLateMins = json['lesson_late_minutes'] as int? ?? delays.fold<int>(0, (sum, d) => sum + d.delayMinutes);
    final totalLateMins = json['total_late_minutes'] as int? ?? (lateMins + lessonLateMins);

    return DailyAttendanceModel(
      id: json['id'] as String,
      date: json['date'] as String,
      checkInTime: json['check_in_time'] as String?,
      checkOutTime: json['check_out_time'] as String?,
      status: json['status'] as String? ?? 'ON_TIME',
      lateMinutes: lateMins,
      workedMinutes: json['worked_minutes'] as int? ?? 0,
      isManuallyCorrected: json['is_manually_corrected'] as bool? ?? false,
      correctionReason: json['correction_reason'] as String?,
      lessonDelays: delays,
      lessonLateMinutes: lessonLateMins,
      totalLateMinutes: totalLateMins,
    );
  }
}

class TodayStatusModel {
  final String date;
  final bool hasCheckedIn;
  final bool hasCheckedOut;
  final String? checkInTime;
  final String? checkOutTime;
  final String? status;
  final int lateMinutes;
  final int workedMinutes;
  final String? scheduledStart;
  final String? scheduledEnd;
  final bool isDayOff;
  final List<LessonDelayModel> lessonDelays;
  final int lessonLateMinutes;
  final int totalLateMinutes;

  TodayStatusModel({
    required this.date,
    required this.hasCheckedIn,
    required this.hasCheckedOut,
    this.checkInTime,
    this.checkOutTime,
    this.status,
    required this.lateMinutes,
    required this.workedMinutes,
    this.scheduledStart,
    this.scheduledEnd,
    required this.isDayOff,
    this.lessonDelays = const [],
    this.lessonLateMinutes = 0,
    this.totalLateMinutes = 0,
  });

  factory TodayStatusModel.fromJson(Map<String, dynamic> json) {
    final rawDelays = json['lesson_delays'] as List? ?? [];
    final delays = rawDelays
        .map((e) => LessonDelayModel.fromJson(e as Map<String, dynamic>))
        .toList();
    final lateMins = json['late_minutes'] as int? ?? 0;
    final lessonLateMins = json['lesson_late_minutes'] as int? ?? delays.fold<int>(0, (sum, d) => sum + d.delayMinutes);
    final totalLateMins = json['total_late_minutes'] as int? ?? (lateMins + lessonLateMins);

    return TodayStatusModel(
      date: json['date'] as String,
      hasCheckedIn: json['has_checked_in'] as bool? ?? false,
      hasCheckedOut: json['has_checked_out'] as bool? ?? false,
      checkInTime: json['check_in_time'] as String?,
      checkOutTime: json['check_out_time'] as String?,
      status: json['status'] as String?,
      lateMinutes: lateMins,
      workedMinutes: json['worked_minutes'] as int? ?? 0,
      scheduledStart: json['scheduled_start'] as String?,
      scheduledEnd: json['scheduled_end'] as String?,
      isDayOff: json['is_day_off'] as bool? ?? false,
      lessonDelays: delays,
      lessonLateMinutes: lessonLateMins,
      totalLateMinutes: totalLateMins,
    );
  }
}

class AttendanceRepository {
  final ApiClient _apiClient;

  AttendanceRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient(storageService: SecureStorageService());

  Dio get _dio => _apiClient.dio;

  Future<DailyAttendanceModel> checkIn({
    required String schoolId,
    required String qrToken,
    required double latitude,
    required double longitude,
    required double accuracy,
    String? deviceInfo,
  }) async {
    try {
      final response = await _dio.post(
        '/attendance/check-in',
        data: {
          'school_id': schoolId,
          'qr_token': qrToken,
          'latitude': latitude,
          'longitude': longitude,
          'accuracy': accuracy,
          'device_info': deviceInfo,
        },
      );
      return DailyAttendanceModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map<String, dynamic> && data['message'] != null) {
        throw Exception(data['message'] as String);
      }
      throw Exception('Келүү каттоосу ишке ашкан жок. Тармак же GPS сигналын текшериңиз.');
    }
  }

  Future<DailyAttendanceModel> checkOut({
    required String schoolId,
    required String qrToken,
    required double latitude,
    required double longitude,
    required double accuracy,
    String? deviceInfo,
  }) async {
    try {
      final response = await _dio.post(
        '/attendance/check-out',
        data: {
          'school_id': schoolId,
          'qr_token': qrToken,
          'latitude': latitude,
          'longitude': longitude,
          'accuracy': accuracy,
          'device_info': deviceInfo,
        },
      );
      return DailyAttendanceModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map<String, dynamic> && data['message'] != null) {
        throw Exception(data['message'] as String);
      }
      throw Exception('Кетүү каттоосу ишке ашкан жок. Тармак же GPS сигналын текшериңиз.');
    }
  }

  Future<TodayStatusModel?> getTodayStatus() async {
    try {
      final response = await _dio.get('/attendance/today');
      return TodayStatusModel.fromJson(response.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<List<DailyAttendanceModel>> getMyHistory({int? year, int? month}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (year != null) queryParams['year'] = year;
      if (month != null) queryParams['month'] = month;

      final response = await _dio.get(
        '/attendance/my-history',
        queryParameters: queryParams,
      );
      final list = (response.data as List)
          .map((i) => DailyAttendanceModel.fromJson(i as Map<String, dynamic>))
          .toList();
      return list;
    } catch (_) {
      return [];
    }
  }
}
