import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:teacher_admin/core/constants/app_constants.dart';

class SchoolSettingsData {
  final String id;
  final String name;
  final String code;
  final double latitude;
  final double longitude;
  final double allowedRadiusMeters;
  final double maxAccuracyMeters;
  final int graceMinutes;
  final String timezone;
  final bool isActive;

  SchoolSettingsData({
    required this.id,
    required this.name,
    required this.code,
    required this.latitude,
    required this.longitude,
    required this.allowedRadiusMeters,
    required this.maxAccuracyMeters,
    required this.graceMinutes,
    required this.timezone,
    required this.isActive,
  });

  factory SchoolSettingsData.fromJson(Map<String, dynamic> json) {
    return SchoolSettingsData(
      id: json['id'] as String,
      name: json['name'] as String,
      code: json['code'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      allowedRadiusMeters: (json['allowed_radius_meters'] as num).toDouble(),
      maxAccuracyMeters: (json['max_accuracy_meters'] as num).toDouble(),
      graceMinutes: json['grace_minutes'] as int? ?? 5,
      timezone: json['timezone'] as String? ?? 'Asia/Bishkek',
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

class QrPayloadData {
  final String schoolId;
  final String schoolName;
  final String qrToken;
  final String qrPayload;

  QrPayloadData({
    required this.schoolId,
    required this.schoolName,
    required this.qrToken,
    required this.qrPayload,
  });

  factory QrPayloadData.fromJson(Map<String, dynamic> json) {
    return QrPayloadData(
      schoolId: json['school_id'] as String,
      schoolName: json['school_name'] as String,
      qrToken: json['qr_token'] as String,
      qrPayload: json['qr_payload'] as String,
    );
  }
}

class SettingsRepository {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  SettingsRepository({
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

  Future<SchoolSettingsData?> getSchoolSettings() async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.get(
        '${AppConstants.apiBaseUrl}/schools/current',
        options: options,
      );
      return SchoolSettingsData.fromJson(response.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<bool> updateSchoolSettings({
    required String schoolId,
    String? name,
    double? latitude,
    double? longitude,
    double? allowedRadiusMeters,
    double? maxAccuracyMeters,
    int? graceMinutes,
    String? timezone,
  }) async {
    try {
      final options = await _getAuthOptions();
      final data = <String, dynamic>{};
      if (name != null) data['name'] = name;
      if (latitude != null) data['latitude'] = latitude;
      if (longitude != null) data['longitude'] = longitude;
      if (allowedRadiusMeters != null) data['allowed_radius_meters'] = allowedRadiusMeters;
      if (maxAccuracyMeters != null) data['max_accuracy_meters'] = maxAccuracyMeters;
      if (graceMinutes != null) data['grace_minutes'] = graceMinutes;
      if (timezone != null) data['timezone'] = timezone;

      final response = await _dio.patch(
        '${AppConstants.apiBaseUrl}/schools/$schoolId',
        data: data,
        options: options,
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<QrPayloadData?> getSchoolQr() async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.get(
        '${AppConstants.apiBaseUrl}/qr/current',
        options: options,
      );
      return QrPayloadData.fromJson(response.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<QrPayloadData?> rotateSchoolQr(String schoolId) async {
    try {
      final options = await _getAuthOptions();
      final response = await _dio.post(
        '${AppConstants.apiBaseUrl}/qr/$schoolId/rotate',
        options: options,
      );
      return QrPayloadData.fromJson(response.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }
}
