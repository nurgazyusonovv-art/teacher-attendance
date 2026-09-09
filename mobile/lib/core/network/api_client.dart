import 'package:dio/dio.dart';
import 'dart:async';
import '../constants/app_constants.dart';
import '../storage/secure_storage_service.dart';

class ApiClient {
  static final StreamController<void> _expired =
      StreamController<void>.broadcast();
  static Stream<void> get sessionExpired => _expired.stream;
  late final Dio dio;
  final SecureStorageService storageService;
  final String baseUrl;
  final Dio? refreshClient;
  static final Map<String, Future<String?>> _refreshes = {};

  ApiClient({required this.storageService, String? baseUrl, this.refreshClient})
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
          if (error.response?.statusCode == 401 &&
              !error.requestOptions.path.contains('/auth/login') &&
              !error.requestOptions.path.contains('/auth/refresh') &&
              await storageService.getRefreshToken() != null) {
            return handler.reject(
              DioException(
                requestOptions: error.requestOptions,
                type: DioExceptionType.connectionError,
                error:
                    'Сессияны жаңыртуу мүмкүн болгон жок. Байланышты текшериңиз.',
              ),
            );
          }
          return handler.next(error);
        },
      ),
    );
  }

  Future<String?> _refreshAccessToken() async {
    final token = await storageService.getRefreshToken();
    if (token == null || token.isEmpty) return null;
    final key = '$baseUrl:$token';
    final activeRefresh = _refreshes[key];
    if (activeRefresh != null) return activeRefresh;

    final refreshOperation = _performRefresh();
    _refreshes[key] = refreshOperation;
    try {
      return await refreshOperation;
    } finally {
      _refreshes.remove(key);
    }
  }

  Future<String?> _performRefresh() async {
    final refreshToken = await storageService.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return null;

    try {
      final refreshDio =
          refreshClient ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl,
              headers: {'Content-Type': 'application/json'},
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
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
    } on DioException catch (error) {
      if (error.response?.statusCode == 401 ||
          error.response?.statusCode == 403) {
        await storageService.clearAll();
        _expired.add(null);
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
