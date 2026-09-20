import 'package:dio/dio.dart';

/// An error the API reported, carrying its machine-readable code.
///
/// The backend answers failures with `{success, code, message, details}`
/// (see AGENTS.md §10). Each surface used to re-interpret that body itself and
/// they disagreed on which statuses deserved which wording; the parsing lives
/// here now and the apps decide only how to present it.
class AdminApiException implements Exception {
  const AdminApiException({
    required this.message,
    this.code,
    this.statusCode,
    this.details,
  });

  /// A message already suitable for showing to an administrator.
  final String message;

  /// The API's error code, e.g. `VALIDATION_ERROR`, when it sent one.
  final String? code;
  final int? statusCode;
  final Map<String, dynamic>? details;

  /// Whether the session is the problem rather than the request.
  bool get isAuthFailure => statusCode == 401 || statusCode == 403;

  factory AdminApiException.from(DioException error, String fallback) {
    final response = error.response;
    final data = response?.data;
    if (data is Map) {
      final message = data['message'];
      return AdminApiException(
        message: message is String && message.isNotEmpty ? message : fallback,
        code: data['code'] as String?,
        statusCode: response?.statusCode,
        details: data['details'] is Map
            ? Map<String, dynamic>.from(data['details'] as Map)
            : null,
      );
    }
    return AdminApiException(
      message: fallback,
      statusCode: response?.statusCode,
    );
  }

  @override
  String toString() => message;
}

/// Base for the shared repositories.
///
/// Each app passes its own configured [Dio] — `mobile` the one with the
/// refresh interceptor, `web_admin` its singleton — so session handling is
/// not duplicated here. [basePath] preserves each app's existing URL shape:
/// the phone's client already carries `/api/v1` in its base URL, the browser's
/// prefixes it per request.
abstract class AdminApi {
  const AdminApi({required Dio dio, String basePath = ''})
    : _dio = dio,
      _basePath = basePath;

  final Dio _dio;
  final String _basePath;

  Dio get dio => _dio;

  String url(String path) => '$_basePath$path';

  /// Runs [request], turning a transport failure into [AdminApiException].
  Future<T> guard<T>(Future<T> Function() request, String fallback) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw AdminApiException.from(error, fallback);
    }
  }
}
