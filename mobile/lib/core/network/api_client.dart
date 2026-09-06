import 'package:dio/dio.dart';
import '../constants/app_constants.dart';
import '../storage/secure_storage_service.dart';

class ApiClient {
  late final Dio dio;
  final SecureStorageService storageService;
  final String baseUrl;
  Future<String?>? _refreshFuture;

  ApiClient({required this.storageService, String? baseUrl})
    : baseUrl = baseUrl ?? AppConstants.defaultBaseUrl {
    dio = Dio(
      BaseOptions(
        baseUrl: this.baseUrl,
        connectTimeout: const Duration(
          seconds: AppConstants.connectTimeoutSeconds,
        ),
        receiveTimeout: const Duration(
          seconds: AppConstants.receiveTimeoutSeconds,
        ),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await storageService.getAccessToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) async {
          if (error.response?.statusCode == 401 &&
              error.requestOptions.extra['authRetried'] != true &&
              !error.requestOptions.path.contains('/auth/login') &&
              !error.requestOptions.path.contains('/auth/refresh')) {
            final newAccessToken = await _refreshAccessToken();
            if (newAccessToken != null) {
              final reqOptions = error.requestOptions;
              reqOptions.extra['authRetried'] = true;
              reqOptions.headers['Authorization'] = 'Bearer $newAccessToken';
              try {
                final retryResponse = await dio.fetch(reqOptions);
                return handler.resolve(retryResponse);
              } on DioException {
                // Return the original 401; the caller decides how to navigate.
              }
            }
          }
          return handler.next(error);
        },
      ),
    );
  }

  Future<String?> _refreshAccessToken() async {
    final activeRefresh = _refreshFuture;
    if (activeRefresh != null) return activeRefresh;

    final refreshOperation = _performRefresh();
    _refreshFuture = refreshOperation;
    try {
      return await refreshOperation;
    } finally {
      _refreshFuture = null;
    }
  }

  Future<String?> _performRefresh() async {
    final refreshToken = await storageService.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return null;

    try {
      final refreshDio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          headers: {'Content-Type': 'application/json'},
        ),
      );
      final refreshResponse = await refreshDio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      if (refreshResponse.statusCode != 200) return null;

      final data = refreshResponse.data['data'] as Map<String, dynamic>;
      final newAccessToken = data['access_token'] as String;
      final newRefreshToken = data['refresh_token'] as String;
      await storageService.saveTokens(
        accessToken: newAccessToken,
        refreshToken: newRefreshToken,
      );
      return newAccessToken;
    } catch (_) {
      await storageService.clearAll();
      return null;
    }
  }
}
