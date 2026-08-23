import 'dart:io';
import 'package:flutter/foundation.dart';

class AppConstants {
  static String? _customBaseUrl;

  static String get defaultBaseUrl {
    if (_customBaseUrl != null && _customBaseUrl!.trim().isNotEmpty) {
      return _customBaseUrl!.trim();
    }
    if (kIsWeb) {
      return 'http://127.0.0.1:8000/api/v1';
    }
    if (Platform.isIOS) {
      // iOS Simulator routes directly through localhost loopback
      return 'http://127.0.0.1:8000/api/v1';
    }
    if (Platform.isAndroid) {
      // Android Real Device / Local Wi-Fi
      return 'http://10.18.114.217:8000/api/v1';
    }
    return 'http://127.0.0.1:8000/api/v1';
  }

  static set defaultBaseUrl(String url) {
    _customBaseUrl = url;
  }

  static const int connectTimeoutSeconds = 15;
  static const int receiveTimeoutSeconds = 15;

  // Storage Keys
  static const String keyAccessToken = 'teacher_access_token';
  static const String keyRefreshToken = 'teacher_refresh_token';
  static const String keyUserData = 'teacher_user_data';
  static const String keyBaseUrl = 'teacher_custom_base_url';

  // App Strings
  static const String appName = 'Мугалим Каттоо';
  static const String appTimezone = 'Asia/Bishkek';
}
