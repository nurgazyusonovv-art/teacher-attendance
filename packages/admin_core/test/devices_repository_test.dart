import 'package:admin_core/admin_core.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

import 'support/fake_dio.dart';

const _deviceJson = {
  'id': 'd-1',
  'user_id': 'u-1',
  'device_id': 'android-Zq8Vx2bT7nKpLm4RsW9y',
  'platform': 'ANDROID',
  'status': 'PENDING',
  'is_active': false,
  'teacher_name': 'Асанов Үсөн',
  'username': 'asanov',
  'last_seen_at': '2026-09-18T14:57:43+06:00',
  'created_at': '2026-09-18T14:50:00+06:00',
};

void main() {
  group('DeviceStatus', () {
    test('maps the API values', () {
      expect(DeviceStatus.parse('PENDING'), DeviceStatus.pending);
      expect(DeviceStatus.parse('APPROVED'), DeviceStatus.approved);
      expect(DeviceStatus.parse('REVOKED'), DeviceStatus.revoked);
    });

    test('an unknown value is treated as pending, never as approved', () {
      // Defaulting the other way would let a status the client does not
      // understand read as permission to record attendance.
      expect(DeviceStatus.parse(null), DeviceStatus.pending);
      expect(DeviceStatus.parse('SOMETHING_NEW'), DeviceStatus.pending);
    });

    test('round-trips through the wire name', () {
      for (final status in DeviceStatus.values) {
        expect(DeviceStatus.parse(status.wireName), status);
        expect(status.label, isNotEmpty);
      }
    });
  });

  group('TeacherDevice', () {
    test('maps the admin listing shape', () {
      final device = TeacherDevice.fromJson(
        Map<String, dynamic>.from(_deviceJson),
      );
      expect(device.id, 'd-1');
      expect(device.platform, 'ANDROID');
      expect(device.status, DeviceStatus.pending);
      expect(device.isPending, isTrue);
      expect(device.isApproved, isFalse);
      expect(device.teacherName, 'Асанов Үсөн');
      expect(device.lastSeenAt?.year, 2026);
    });

    test('names an owner even when the endpoint omits one', () {
      // approve/revoke answer with the device alone.
      final device = TeacherDevice.fromJson({'id': 'd-1', 'status': 'APPROVED'});
      expect(device.teacherName, 'Белгисиз');
      expect(device.isApproved, isTrue);
    });

    test('shortens a long identifier for a phone screen', () {
      final device = TeacherDevice.fromJson(
        Map<String, dynamic>.from(_deviceJson),
      );
      expect(device.shortDeviceId.length, lessThan(device.deviceId.length));
      expect(device.shortDeviceId, endsWith('…'));

      final short = TeacherDevice.fromJson({'id': 'd', 'device_id': 'abc-123'});
      expect(short.shortDeviceId, 'abc-123', reason: 'short ids are left whole');
    });
  });

  group('DevicesRepository', () {
    test('lists without a filter when none is asked for', () async {
      final captured = <RequestOptions>[];
      final repo = DevicesRepository(
        dio: dioReturning([_deviceJson], capture: captured),
      );
      final devices = await repo.list();
      expect(devices.single.teacherName, 'Асанов Үсөн');
      expect(captured.single.queryParameters, isEmpty);
    });

    test('a status filter is sent in the API\'s own spelling', () async {
      final captured = <RequestOptions>[];
      final repo = DevicesRepository(
        dio: dioReturning(<Object>[], capture: captured),
      );
      await repo.list(status: DeviceStatus.pending, teacherId: 't-1');
      expect(captured.single.queryParameters['status'], 'PENDING');
      expect(captured.single.queryParameters['teacher_id'], 't-1');
    });

    test('approve and revoke hit the right routes', () async {
      final captured = <RequestOptions>[];
      final repo = DevicesRepository(
        dio: dioReturning(_deviceJson, capture: captured),
        basePath: '/api/v1',
      );
      await repo.approve('d-1');
      expect(captured.single.method, 'POST');
      expect(captured.single.path, '/api/v1/devices/d-1/approve');

      captured.clear();
      await repo.revoke('d-1');
      expect(captured.single.path, '/api/v1/devices/d-1/revoke');
    });

    test('an empty listing is not an error', () async {
      final repo = DevicesRepository(dio: dioReturning(<Object>[]));
      expect(await repo.list(), isEmpty);
    });

    test('a failure carries the API message', () async {
      final repo = DevicesRepository(
        dio: dioReturning({
          'code': 'PERMISSION_DENIED',
          'message': 'Башка мектептин маалыматына уруксат жок.',
        }, status: 403),
      );
      await expectLater(
        repo.approve('d-1'),
        throwsA(
          isA<AdminApiException>()
              .having((e) => e.code, 'code', 'PERMISSION_DENIED')
              .having((e) => e.isAuthFailure, 'isAuthFailure', isTrue),
        ),
      );
    });
  });
}
