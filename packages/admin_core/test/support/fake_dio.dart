import 'dart:convert';

import 'package:dio/dio.dart';

/// Answers requests from a canned body instead of the network.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.respond);

  final ResponseBody Function(RequestOptions options) respond;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async => respond(options);

  @override
  void close({bool force = false}) {}
}

/// A [Dio] that answers every request with [body].
///
/// Pass [capture] to inspect what the repository actually sent — the route it
/// built, the query it attached, the payload it serialized.
Dio dioReturning(
  Object body, {
  int status = 200,
  List<RequestOptions>? capture,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
  dio.httpClientAdapter = _FakeAdapter(
    (options) => ResponseBody.fromString(
      body is String ? body : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    ),
  );
  if (capture != null) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          capture.add(options);
          handler.next(options);
        },
      ),
    );
  }
  return dio;
}
