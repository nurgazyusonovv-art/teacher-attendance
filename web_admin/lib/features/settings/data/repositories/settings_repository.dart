import 'package:admin_core/admin_core.dart' as core;
import 'package:dio/dio.dart';
import 'package:teacher_admin/core/network/admin_api_client.dart';

/// Shared models; this app's screens keep their original names.
typedef SchoolSettingsData = core.SchoolSettings;
typedef QrPayloadData = core.QrPayload;

class SettingsRepository {
  SettingsRepository({Dio? dio})
    : _school = core.SchoolRepository(dio: dio ?? AdminApiClient.instance.dio);

  final core.SchoolRepository _school;

  Future<SchoolSettingsData?> getSchoolSettings() async {
    try {
      return await _school.current();
    } on core.AdminApiException {
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
    bool? deviceBindingEnabled,
  }) async {
    try {
      await _school.update(
        schoolId: schoolId,
        name: name,
        latitude: latitude,
        longitude: longitude,
        allowedRadiusMeters: allowedRadiusMeters,
        maxAccuracyMeters: maxAccuracyMeters,
        graceMinutes: graceMinutes,
        timezone: timezone,
        deviceBindingEnabled: deviceBindingEnabled,
      );
      return true;
    } on core.AdminApiException {
      return false;
    }
  }

  Future<QrPayloadData?> getSchoolQr() async {
    try {
      return await _school.qr();
    } on core.AdminApiException {
      return null;
    }
  }

  Future<QrPayloadData?> rotateSchoolQr(String schoolId) async {
    try {
      return await _school.rotateQr(schoolId);
    } on core.AdminApiException {
      return null;
    }
  }

  Future<int?> resetAttendance() async {
    try {
      return await _school.resetAttendance();
    } on core.AdminApiException {
      return null;
    }
  }
}
