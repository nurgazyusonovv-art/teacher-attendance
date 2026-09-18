import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_mobile/core/constants/app_constants.dart';
import 'package:teacher_mobile/core/services/device_identity_service.dart';
import 'package:teacher_mobile/core/storage/secure_storage_service.dart';

/// Minimal in-memory stand-in; the plugin is unavailable in unit tests.
class _FakeStorage implements SecureStorageService {
  final Map<String, String> values = {};

  @override
  Future<void> writeValue(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<String?> readValue(String key) async => values[key];

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('device id is generated once and reused across instances', () async {
    final storage = _FakeStorage();

    final first = await DeviceIdentityService(storageService: storage).getDeviceId();
    expect(first.length, greaterThanOrEqualTo(3));
    expect(storage.values[AppConstants.keyDeviceId], first);

    // A fresh instance reading the same storage must not mint a new device;
    // that would send the teacher back to the approval queue on every launch.
    final second = await DeviceIdentityService(storageService: storage).getDeviceId();
    expect(second, first);
  });

  test('peek does not create an identifier', () async {
    final storage = _FakeStorage();
    final service = DeviceIdentityService(storageService: storage);

    expect(await service.peekDeviceId(), isNull);
    expect(storage.values, isEmpty);

    final created = await service.getDeviceId();
    service.clearCache();
    expect(await service.peekDeviceId(), created);
  });

  test('a too-short stored value is replaced', () async {
    final storage = _FakeStorage();
    storage.values[AppConstants.keyDeviceId] = 'ab';

    final generated = await DeviceIdentityService(
      storageService: storage,
    ).getDeviceId();
    expect(generated, isNot('ab'));
    expect(generated.length, greaterThan(10));
  });

  test('platform is one of the values the API accepts', () {
    expect(
      DeviceIdentityService.platform,
      anyOf('IOS', 'ANDROID', 'WEB'),
    );
  });
}
