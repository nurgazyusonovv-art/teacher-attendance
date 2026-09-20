/// A school's settings, as `SchoolRead` returns them.
///
/// The Telegram bot token is deliberately absent: the API never serializes it
/// back, so there is nothing here to leak into a log or a screen.
class SchoolSettings {
  const SchoolSettings({
    required this.id,
    required this.name,
    required this.code,
    required this.latitude,
    required this.longitude,
    required this.allowedRadiusMeters,
    required this.maxAccuracyMeters,
    this.defaultStartTime,
    this.defaultEndTime,
    this.graceMinutes = 0,
    this.timezone = 'Asia/Bishkek',
    this.attendanceStartDate,
    this.deviceBindingEnabled = false,
    this.isReviewDemo = false,
    this.telegramChatId,
    this.telegramEnabled = false,
    this.telegramReportTime,
    this.isActive = true,
  });

  final String id;
  final String name;
  final String code;
  final double latitude;
  final double longitude;
  final double allowedRadiusMeters;
  final double maxAccuracyMeters;
  final String? defaultStartTime;
  final String? defaultEndTime;
  final int graceMinutes;
  final String timezone;

  /// First day this school is accounted for; absences are never inferred
  /// before it.
  final String? attendanceStartDate;

  /// When on, a scan must come from the teacher's approved device.
  final bool deviceBindingEnabled;

  /// The isolated App Review tenant. Its geofence is deliberately worldwide,
  /// which is why it may only ever hold demo accounts.
  final bool isReviewDemo;

  final String? telegramChatId;
  final bool telegramEnabled;
  final String? telegramReportTime;
  final bool isActive;

  factory SchoolSettings.fromJson(Map<String, dynamic> json) {
    double number(String key, double fallback) {
      final value = json[key];
      return value is num ? value.toDouble() : fallback;
    }

    return SchoolSettings(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      latitude: number('latitude', 0),
      longitude: number('longitude', 0),
      allowedRadiusMeters: number('allowed_radius_meters', 0),
      maxAccuracyMeters: number('max_accuracy_meters', 0),
      defaultStartTime: json['default_start_time'] as String?,
      defaultEndTime: json['default_end_time'] as String?,
      graceMinutes: json['grace_minutes'] as int? ?? 0,
      timezone: json['timezone'] as String? ?? 'Asia/Bishkek',
      attendanceStartDate: json['attendance_start_date'] as String?,
      deviceBindingEnabled: json['device_binding_enabled'] as bool? ?? false,
      isReviewDemo: json['is_review_demo'] as bool? ?? false,
      telegramChatId: json['telegram_chat_id'] as String?,
      telegramEnabled: json['telegram_enabled'] as bool? ?? false,
      telegramReportTime: json['telegram_report_time'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

/// The school's QR payload, as `QrPayloadResponse` returns it.
class QrPayload {
  const QrPayload({
    required this.schoolId,
    required this.schoolName,
    required this.qrToken,
    required this.qrPayload,
    this.createdAt,
  });

  final String schoolId;
  final String schoolName;
  final String qrToken;

  /// The exact JSON string to render into the QR image.
  final String qrPayload;

  final String? createdAt;

  factory QrPayload.fromJson(Map<String, dynamic> json) {
    return QrPayload(
      schoolId: json['school_id'] as String? ?? '',
      schoolName: json['school_name'] as String? ?? '',
      qrToken: json['qr_token'] as String? ?? '',
      qrPayload: json['qr_payload'] as String? ?? '',
      createdAt: json['created_at'] as String?,
    );
  }
}
