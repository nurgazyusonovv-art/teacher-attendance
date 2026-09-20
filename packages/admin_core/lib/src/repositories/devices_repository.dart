import '../api.dart';
import '../models/device.dart';

/// Device binding administration (PROJECT.md §10).
///
/// Enforcement is per school and off by default, so approving devices only
/// matters once `device_binding_enabled` is on. Approving is still worth doing
/// beforehand: it lets a school build the approved set before switching
/// enforcement on, rather than locking everyone out at once.
class DevicesRepository extends AdminApi {
  const DevicesRepository({required super.dio, super.basePath});

  /// The school's devices, newest first, optionally narrowed to one status.
  Future<List<TeacherDevice>> list({
    DeviceStatus? status,
    String? teacherId,
  }) {
    return guard(() async {
      final query = <String, dynamic>{};
      if (status != null) query['status'] = status.wireName;
      if (teacherId != null) query['teacher_id'] = teacherId;

      final response = await dio.get(
        url('/devices'),
        queryParameters: query.isEmpty ? null : query,
      );
      final rows = response.data as List<dynamic>? ?? const [];
      return rows
          .map((row) => TeacherDevice.fromJson(row as Map<String, dynamic>))
          .toList();
    }, 'Түзмөктөрдү жүктөө ишке ашкан жок.');
  }

  /// Approves a device. The teacher's previous one is revoked server-side, so
  /// a teacher always has at most one approved device.
  ///
  /// The endpoint answers with the device alone, without its owner's name —
  /// reload the list when the screen shows one.
  Future<TeacherDevice> approve(String deviceRowId) {
    return guard(() async {
      final response = await dio.post(url('/devices/$deviceRowId/approve'));
      return TeacherDevice.fromJson(response.data as Map<String, dynamic>);
    }, 'Түзмөктү ырастоо ишке ашкан жок.');
  }

  Future<TeacherDevice> revoke(String deviceRowId) {
    return guard(() async {
      final response = await dio.post(url('/devices/$deviceRowId/revoke'));
      return TeacherDevice.fromJson(response.data as Map<String, dynamic>);
    }, 'Түзмөктү жокко чыгаруу ишке ашкан жок.');
  }
}
