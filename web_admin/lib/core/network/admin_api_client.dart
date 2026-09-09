import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:teacher_admin/core/constants/app_constants.dart';

class AdminApiClient {
  AdminApiClient._();

  static final AdminApiClient instance = AdminApiClient._().._initialize();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  late final Dio dio;
  Future<String?>? _refreshFuture;

  void _initialize() {
    dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.defaultBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: const {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final isAuthRequest =
              options.path.contains('/auth/login') ||
              options.path.contains('/auth/refresh');
          if (!isAuthRequest) {
            final token = await _storage.read(key: AppConstants.keyAccessToken);
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          final request = error.requestOptions;
          final canRefresh =
              error.response?.statusCode == 401 &&
              request.extra['authRetried'] != true &&
              !request.path.contains('/auth/login') &&
              !request.path.contains('/auth/refresh');
          if (canRefresh) {
            final accessToken = await _refreshAccessToken();
            if (accessToken != null) {
              request.extra['authRetried'] = true;
              request.headers['Authorization'] = 'Bearer $accessToken';
              try {
                return handler.resolve(await dio.fetch(request));
              } on DioException {
                // Return the original 401; the caller decides how to navigate.
              }
            }
          }
          handler.next(error);
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
    final refreshToken = await _storage.read(key: AppConstants.keyRefreshToken);
    if (refreshToken == null || refreshToken.isEmpty) return null;

    try {
      final refreshClient = Dio(
        BaseOptions(
          baseUrl: AppConstants.defaultBaseUrl,
          headers: const {'Content-Type': 'application/json'},
        ),
      );
      final response = await refreshClient.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      final data = response.data['data'] as Map<String, dynamic>;
      final accessToken = data['access_token'] as String;
      final rotatedRefreshToken = data['refresh_token'] as String;
      await _storage.write(
        key: AppConstants.keyAccessToken,
        value: accessToken,
      );
      await _storage.write(
        key: AppConstants.keyRefreshToken,
        value: rotatedRefreshToken,
      );
      return accessToken;
    } on DioException catch (error) {
      if (error.response?.statusCode == 401 || error.response?.statusCode == 403) {
        await _storage.deleteAll();
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
