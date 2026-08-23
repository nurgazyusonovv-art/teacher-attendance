import 'package:dio/dio.dart';
import '../constants/app_constants.dart';
import '../storage/secure_storage_service.dart';

class ApiClient {
  late final Dio dio;
  final SecureStorageService storageService;
  final String baseUrl;

  ApiClient({
    required this.storageService,
    String? baseUrl,
  }) : baseUrl = baseUrl ?? AppConstants.defaultBaseUrl {
    dio = Dio(
      BaseOptions(
        baseUrl: this.baseUrl,
        connectTimeout: const Duration(seconds: AppConstants.connectTimeoutSeconds),
        receiveTimeout: const Duration(seconds: AppConstants.receiveTimeoutSeconds),
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
          // Handle token expiry / 401 refresh logic in Phase 2
          return handler.next(error);
        },
      ),
    );
  }
}
