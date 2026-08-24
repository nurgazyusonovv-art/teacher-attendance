class AppConstants {
  static String? _customBaseUrl;

  static const String productionApiUrl = 'https://teacher-attendance-api-hfh2.onrender.com/api/v1';

  static String get defaultBaseUrl {
    if (_customBaseUrl != null && _customBaseUrl!.trim().isNotEmpty) {
      return _customBaseUrl!.trim();
    }
    // Production Cloud API URL (Render.com + Supabase)
    return productionApiUrl;
  }

  static set defaultBaseUrl(String url) {
    _customBaseUrl = url;
  }

  static const int connectTimeoutSeconds = 30;
  static const int receiveTimeoutSeconds = 30;

  // Storage Keys
  static const String keyAccessToken = 'teacher_access_token';
  static const String keyRefreshToken = 'teacher_refresh_token';
  static const String keyUserData = 'teacher_user_data';
  static const String keyBaseUrl = 'teacher_custom_base_url';

  // App Strings
  static const String appName = 'Мугалим Каттоо';
  static const String appTimezone = 'Asia/Bishkek';
}
