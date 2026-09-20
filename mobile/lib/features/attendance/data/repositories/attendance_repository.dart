import 'package:dio/dio.dart';
import 'dart:convert';
import '../../../../core/errors/error_messages.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/device_identity_service.dart';
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
    final lessonLateMins =
        json['lesson_late_minutes'] as int? ??
        delays.fold<int>(0, (sum, d) => sum + d.delayMinutes);
    final totalLateMins =
        json['total_late_minutes'] as int? ?? (lateMins + lessonLateMins);

    return DailyAttendanceModel(
      id: json['id'] as String,
      date: json['date'] as String,
      checkInTime: json['check_in_time'] as String?,
      checkOutTime: json['check_out_time'] as String?,
      status:
          json['display_status'] as String? ??
          json['status'] as String? ??
          'UNKNOWN',
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
  final String? schoolName;
  final String? displayStatus;
  final String date;

  /// The school's offset from UTC, as reported by the server. Used to decide
  /// whether a cached status still belongs to the school's current day.
  final int utcOffsetMinutes;

  /// The school's clock when the server answered.
  ///
  /// The home screen ticks forward from this rather than reading the device
  /// clock: a phone minutes behind would tell a teacher they are on time
  /// while the server records them late.
  final String? serverTime;
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
    this.schoolName,
    this.displayStatus,
    required this.date,
    this.utcOffsetMinutes = 0,
    this.serverTime,
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
    final lessonLateMins =
        json['lesson_late_minutes'] as int? ??
        delays.fold<int>(0, (sum, d) => sum + d.delayMinutes);
    final totalLateMins =
        json['total_late_minutes'] as int? ?? (lateMins + lessonLateMins);

    return TodayStatusModel(
      schoolName: json['school_name'] as String?,
      displayStatus: json['display_status'] as String?,
      date: json['date'] as String,
      utcOffsetMinutes: json['utc_offset_minutes'] as int? ?? 0,
      serverTime: json['server_time'] as String?,
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

  Map<String, dynamic> toJson() => {
    'school_name': schoolName,
    'display_status': displayStatus,
    'date': date,
    'utc_offset_minutes': utcOffsetMinutes,
    'server_time': serverTime,
    'has_checked_in': hasCheckedIn,
    'has_checked_out': hasCheckedOut,
    'check_in_time': checkInTime,
    'check_out_time': checkOutTime,
    'status': status,
    'late_minutes': lateMinutes,
    'worked_minutes': workedMinutes,
    'scheduled_start': scheduledStart,
    'scheduled_end': scheduledEnd,
    'is_day_off': isDayOff,
    'lesson_late_minutes': lessonLateMinutes,
    'total_late_minutes': totalLateMinutes,
    'lesson_delays': const [],
  };
}

class AttendanceRepository {
  final ApiClient _apiClient;

  AttendanceRepository({ApiClient? apiClient})
    : _apiClient =
          apiClient ?? ApiClient(storageService: SecureStorageService());

  Dio get _dio => _apiClient.dio;

  final DeviceIdentityService _deviceIdentity = DeviceIdentityService();

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
          // Device binding (PROJECT.md §10); ignored by schools that have
          // not enabled it.
          'device_id': await _deviceIdentity.getDeviceId(),
        },
      );
      return DailyAttendanceModel.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        throw Exception(
          ErrorMessages.getKyrgyzMessage(
            data['code'] as String?,
            data['message'] as String?,
          ),
        );
      }
      throw Exception(
        'Келүү каттоосу ишке ашкан жок. Тармак же GPS сигналын текшериңиз.',
      );
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
          // Device binding (PROJECT.md §10); ignored by schools that have
          // not enabled it.
          'device_id': await _deviceIdentity.getDeviceId(),
        },
      );
      return DailyAttendanceModel.fromJson(
        response.data as Map<String, dynamic>,
      );
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        throw Exception(
          ErrorMessages.getKyrgyzMessage(
            data['code'] as String?,
            data['message'] as String?,
          ),
        );
      }
      throw Exception(
        'Кетүү каттоосу ишке ашкан жок. Тармак же GPS сигналын текшериңиз.',
      );
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

  Future<TodayStatusModel?> getCachedTodayStatus() async {
    try {
      final raw = await _apiClient.storageService.readValue(
        AppConstants.keyTodayAttendanceCache,
      );
      if (raw == null) return null;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final user = await _apiClient.storageService.getUserData();
      if (user == null ||
          data['owner'] != user ||
          data['api'] != _apiClient.baseUrl) {
        return null;
      }
      final cache = data['today_attendance'];
      if (cache is! Map<String, dynamic>) return null;
      final model = TodayStatusModel.fromJson(cache);
      // Expire against the school's own day. This used to assume UTC+6, which
      // is wrong for any school on another timezone; the offset now comes from
      // the server response that produced this cache entry.
      final schoolNow = DateTime.now().toUtc().add(
        Duration(minutes: model.utcOffsetMinutes),
      );
      final today = schoolNow.toIso8601String().substring(0, 10);
      return model.date == today ? model : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> cacheTodayStatus(TodayStatusModel model) async {
    try {
      final user = await _apiClient.storageService.getUserData();
      if (user == null) return;
      await _apiClient.storageService.writeValue(
        AppConstants.keyTodayAttendanceCache,
        jsonEncode({
          'owner': user,
          'api': _apiClient.baseUrl,
          'today_attendance': model.toJson(),
        }),
      );
    } catch (_) {
      // Cache failures must not hide a successful server response.
    }
  }

  Future<List<DailyAttendanceModel>> getMyHistory({
    int? year,
    int? month,
  }) async {
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
      throw Exception('Тарых жүктөлгөн жок. Байланышты текшериңиз.');
    }
  }
}
