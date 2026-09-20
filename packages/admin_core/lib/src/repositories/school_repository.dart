import '../api.dart';
import '../models/school.dart';

/// School settings and the attendance QR.
class SchoolRepository extends AdminApi {
  const SchoolRepository({required super.dio, super.basePath});

  /// The school the signed-in user belongs to.
  Future<SchoolSettings> current() {
    return guard(() async {
      final response = await dio.get(url('/schools/current'));
      return SchoolSettings.fromJson(response.data as Map<String, dynamic>);
    }, 'Мектептин жөндөөлөрүн жүктөө ишке ашкан жок.');
  }

  /// Updates only the fields that are passed.
  ///
  /// `is_review_demo` is deliberately absent: the API does not accept it, so
  /// no administrator can widen a school's geofence to the review tenant's.
  Future<SchoolSettings> update({
    required String schoolId,
    String? name,
    double? latitude,
    double? longitude,
    double? allowedRadiusMeters,
    double? maxAccuracyMeters,
    int? graceMinutes,
    String? timezone,
    String? attendanceStartDate,
    bool? deviceBindingEnabled,
    String? telegramBotToken,
    String? telegramChatId,
    bool? telegramEnabled,
    String? telegramReportTime,
  }) {
    return guard(() async {
      final response = await dio.patch(
        url('/schools/${Uri.encodeComponent(schoolId)}'),
        data: {
          'name': ?name,
          'latitude': ?latitude,
          'longitude': ?longitude,
          'allowed_radius_meters': ?allowedRadiusMeters,
          'max_accuracy_meters': ?maxAccuracyMeters,
          'grace_minutes': ?graceMinutes,
          'timezone': ?timezone,
          'attendance_start_date': ?attendanceStartDate,
          'device_binding_enabled': ?deviceBindingEnabled,
          'telegram_bot_token': ?telegramBotToken,
          'telegram_chat_id': ?telegramChatId,
          'telegram_enabled': ?telegramEnabled,
          'telegram_report_time': ?telegramReportTime,
        },
      );
      return SchoolSettings.fromJson(response.data as Map<String, dynamic>);
    }, 'Жөндөөлөрдү сактоо ишке ашкан жок.');
  }

  Future<QrPayload> qr() {
    return guard(() async {
      final response = await dio.get(url('/qr/current'));
      return QrPayload.fromJson(response.data as Map<String, dynamic>);
    }, 'QR-кодду жүктөө ишке ашкан жок.');
  }

  /// Issues a new QR token. The old code stops working immediately, so the
  /// printed sheet at the school door has to be replaced.
  Future<QrPayload> rotateQr(String schoolId) {
    return guard(() async {
      final response = await dio.post(
        url('/qr/${Uri.encodeComponent(schoolId)}/rotate'),
      );
      return QrPayload.fromJson(response.data as Map<String, dynamic>);
    }, 'QR-кодду жаңылоо ишке ашкан жок.');
  }

  /// Clears the school's attendance records. Accounts, schedules and the
  /// audit trail survive; the API demands an exact confirmation phrase.
  Future<int> resetAttendance({
    String confirmation = attendanceResetConfirmation,
  }) {
    return guard(() async {
      final response = await dio.post(
        url('/attendance/admin/reset'),
        data: {'confirmation': confirmation},
      );
      final body = response.data as Map<String, dynamic>;
      return body['deleted'] as int? ?? 0;
    }, 'Катышуу жазууларын тазалоо ишке ашкан жок.');
  }
}

/// The phrase the API requires before it clears attendance records.
const String attendanceResetConfirmation = 'RESET ATTENDANCE';
