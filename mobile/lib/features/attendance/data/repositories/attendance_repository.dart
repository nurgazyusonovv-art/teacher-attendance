import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:teacher_mobile/core/constants/app_constants.dart';

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
  });

  factory DailyAttendanceModel.fromJson(Map<String, dynamic> json) {
    return DailyAttendanceModel(
      id: json['id'] as String,
      date: json['date'] as String,
      checkInTime: json['check_in_time'] as String?,
      checkOutTime: json['check_out_time'] as String?,
      status: json['status'] as String? ?? 'ON_TIME',
      lateMinutes: json['late_minutes'] as int? ?? 0,
      workedMinutes: json['worked_minutes'] as int? ?? 0,
      isManuallyCorrected: json['is_manually_corrected'] as bool? ?? false,
      correctionReason: json['correction_reason'] as String?,
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
  });

  factory TodayStatusModel.fromJson(Map<String, dynamic> json) {
    return TodayStatusModel(
      date: json['date'] as String,
      hasCheckedIn: json['has_checked_in'] as bool? ?? false,
      hasCheckedOut: json['has_checked_out'] as bool? ?? false,
      checkInTime: json['check_in_time'] as String?,
      checkOutTime: json['check_out_time'] as String?,
      status: json['status'] as String?,
      lateMinutes: json['late_minutes'] as int? ?? 0,
      workedMinutes: json['worked_minutes'] as int? ?? 0,
      scheduledStart: json['scheduled_start'] as String?,
      scheduledEnd: json['scheduled_end'] as String?,
      isDayOff: json['is_day_off'] as bool? ?? false,
    );
  }
}

class AttendanceRepository {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  AttendanceRepository({
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

  Future<DailyAttendanceModel> checkIn({
    required String schoolId,
    required String qrToken,
    required double latitude,
    required double longitude,
    required double accuracy,
    String? deviceInfo,
  }) async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.post(
        '${AppConstants.defaultBaseUrl}/attendance/check-in',
        data: {
          'school_id': schoolId,
          'qr_token': qrToken,
          'latitude': latitude,
          'longitude': longitude,
          'accuracy': accuracy,
          'device_info': deviceInfo,
        },
        options: options,
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
      final options = await _getAuthOptions();
      final response = await _dio.post(
        '${AppConstants.defaultBaseUrl}/attendance/check-out',
        data: {
          'school_id': schoolId,
          'qr_token': qrToken,
          'latitude': latitude,
          'longitude': longitude,
          'accuracy': accuracy,
          'device_info': deviceInfo,
        },
        options: options,
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
      final options = await _getAuthOptions();
      final response = await _dio.get(
        '${AppConstants.defaultBaseUrl}/attendance/today',
        options: options,
      );
      return TodayStatusModel.fromJson(response.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<List<DailyAttendanceModel>> getMyHistory({int? year, int? month}) async {
    try {
      final options = await _getAuthOptions();
      final queryParams = <String, dynamic>{};
      if (year != null) queryParams['year'] = year;
      if (month != null) queryParams['month'] = month;

      final response = await _dio.get(
        '${AppConstants.defaultBaseUrl}/attendance/my-history',
        queryParameters: queryParams,
        options: options,
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
