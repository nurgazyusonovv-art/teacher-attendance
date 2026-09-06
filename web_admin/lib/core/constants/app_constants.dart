import 'package:flutter/foundation.dart';

class AppConstants {
  static const String _configuredApiUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String get apiBaseUrl => _configuredApiUrl.isNotEmpty
      ? _configuredApiUrl
      : (kIsWeb ? '/api/v1' : 'http://127.0.0.1:8000/api/v1');
  static String get defaultBaseUrl => apiBaseUrl;
  static const String appName = 'Teacher Attendance Admin';
  static const String keyAccessToken = 'admin_access_token';
  static const String keyRefreshToken = 'admin_refresh_token';
}
