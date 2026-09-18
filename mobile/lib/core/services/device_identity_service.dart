import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../constants/app_constants.dart';
import '../storage/secure_storage_service.dart';

/// Stable per-install identifier used for device binding (PROJECT.md §10).
///
/// Generated once and kept in secure storage, so it survives app restarts but
/// not a reinstall — a reinstall registers as a new device and waits for an
/// administrator, which is exactly the intent.
class DeviceIdentityService {
  DeviceIdentityService({SecureStorageService? storageService})
    : _storage = storageService ?? SecureStorageService();

  final SecureStorageService _storage;
  String? _cached;

  static final Random _random = Random.secure();

  /// Platform value the API expects (`IOS`, `ANDROID`, `WEB`).
  static String get platform {
    if (kIsWeb) return 'WEB';
    if (Platform.isIOS || Platform.isMacOS) return 'IOS';
    return 'ANDROID';
  }

  /// Returns the stored identifier, creating it on first call.
  Future<String> getDeviceId() async {
    final cached = _cached;
    if (cached != null) return cached;

    final stored = await _storage.readValue(AppConstants.keyDeviceId);
    if (stored != null && stored.trim().length >= 3) {
      _cached = stored.trim();
      return _cached!;
    }

    final generated = _generateId();
    await _storage.writeValue(AppConstants.keyDeviceId, generated);
    _cached = generated;
    return generated;
  }

  /// Reads the identifier without creating one. Used where a missing id should
  /// simply mean "not registered yet" rather than silently minting a device.
  Future<String?> peekDeviceId() async {
    final cached = _cached;
    if (cached != null) return cached;
    final stored = await _storage.readValue(AppConstants.keyDeviceId);
    if (stored == null || stored.trim().length < 3) return null;
    _cached = stored.trim();
    return _cached;
  }

  @visibleForTesting
  void clearCache() => _cached = null;

  String _generateId() {
    final bytes = List<int>.generate(24, (_) => _random.nextInt(256));
    final token = base64Url.encode(bytes).replaceAll('=', '');
    return '${platform.toLowerCase()}-$token';
  }
}
