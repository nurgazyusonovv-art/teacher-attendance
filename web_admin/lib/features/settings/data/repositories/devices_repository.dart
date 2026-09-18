import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:teacher_admin/core/constants/app_constants.dart';
import 'package:teacher_admin/core/network/admin_api_client.dart';

/// A teacher's registered device and where it sits in the approval flow.
class TeacherDeviceData {
  const TeacherDeviceData({
    required this.id,
    required this.deviceId,
    required this.platform,
    required this.status,
    required this.teacherName,
    this.username,
    this.lastSeenAt,
  });

  final String id;
  final String deviceId;
  final String platform;
  final String status;
  final String teacherName;
  final String? username;
  final DateTime? lastSeenAt;

  bool get isPending => status == 'PENDING';
  bool get isApproved => status == 'APPROVED';

  factory TeacherDeviceData.fromJson(Map<String, dynamic> json) {
    final lastSeen = json['last_seen_at'] as String?;
    return TeacherDeviceData(
      id: json['id'] as String,
      deviceId: json['device_id'] as String,
      platform: json['platform'] as String? ?? '',
      status: json['status'] as String? ?? 'PENDING',
      teacherName: json['teacher_name'] as String? ?? 'Белгисиз',
      username: json['username'] as String?,
      lastSeenAt: lastSeen == null ? null : DateTime.tryParse(lastSeen),
    );
  }
}

class DevicesRepository {
  DevicesRepository({Dio? dio, FlutterSecureStorage? storage})
    : _dio = dio ?? AdminApiClient.instance.dio,
      _storage = storage ?? const FlutterSecureStorage();

  final Dio _dio;
  final FlutterSecureStorage _storage;

  Future<Options> _getAuthOptions() async {
    final token = await _storage.read(key: AppConstants.keyAccessToken);
    return Options(headers: {'Authorization': 'Bearer $token'});
  }

  /// Returns the school's devices, optionally narrowed to one status.
  Future<List<TeacherDeviceData>> listDevices({String? status}) async {
    final response = await _dio.get(
      '${AppConstants.apiBaseUrl}/devices',
      queryParameters: status == null ? null : {'status': status},
      options: await _getAuthOptions(),
    );
    final rows = response.data as List<dynamic>;
    return rows
        .map((row) => TeacherDeviceData.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Approves a device. The teacher's previous device is revoked server-side.
  Future<void> approve(String id) async {
    await _dio.post(
      '${AppConstants.apiBaseUrl}/devices/$id/approve',
      options: await _getAuthOptions(),
    );
  }

  Future<void> revoke(String id) async {
    await _dio.post(
      '${AppConstants.apiBaseUrl}/devices/$id/revoke',
      options: await _getAuthOptions(),
    );
  }
}
