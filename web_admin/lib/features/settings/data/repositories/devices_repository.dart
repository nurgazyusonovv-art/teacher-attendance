import 'package:admin_core/admin_core.dart' as core;
import 'package:dio/dio.dart';
import 'package:teacher_admin/core/network/admin_api_client.dart';

/// The shared device model; this app's screens keep their original name.
typedef TeacherDeviceData = core.TeacherDevice;

class DevicesRepository {
  DevicesRepository({Dio? dio})
    : _devices = core.DevicesRepository(
        dio: dio ?? AdminApiClient.instance.dio,
      );

  final core.DevicesRepository _devices;

  /// Returns the school's devices, optionally narrowed to one status.
  Future<List<TeacherDeviceData>> listDevices({String? status}) {
    return _devices.list(
      status: status == null ? null : core.DeviceStatus.parse(status),
    );
  }

  /// Approves a device. The teacher's previous device is revoked server-side.
  Future<void> approve(String id) => _devices.approve(id);

  Future<void> revoke(String id) => _devices.revoke(id);
}
