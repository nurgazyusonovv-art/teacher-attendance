import 'dart:convert';

import 'package:admin_core/admin_core.dart' as core;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_mobile/core/theme/app_theme.dart';
import 'package:teacher_mobile/features/admin/presentation/screens/admin_devices_screen.dart';

/// Answers every request with a canned body.
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

/// One decision per request, so a test never depends on the order in which
/// the status and the body happen to be evaluated.
typedef _Reply = (int status, Object body);

Dio _dio({
  required _Reply Function(RequestOptions options) reply,
  List<RequestOptions>? capture,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
  dio.httpClientAdapter = _FakeAdapter((options) {
    capture?.add(options);
    final (status, body) = reply(options);
    return ResponseBody.fromString(
      body is String ? body : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  });
  return dio;
}

Map<String, dynamic> _device({
  String id = 'd-1',
  String status = 'PENDING',
  String teacher = 'Асанов Үсөн',
}) => {
  'id': id,
  'device_id': 'android-Zq8Vx2bT7nKpLm4RsW9y',
  'platform': 'ANDROID',
  'status': status,
  'teacher_name': teacher,
  'username': 'asanov',
};

Widget _wrap(core.DevicesRepository repository) => MaterialApp(
  theme: AppTheme.lightTheme,
  home: AdminDevicesScreen(repository: repository),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('a pending device can be approved from the phone', (
    tester,
  ) async {
    final calls = <RequestOptions>[];
    var approved = false;
    final repo = core.DevicesRepository(
      dio: _dio(
        capture: calls,
        reply: (options) {
          if (options.path.endsWith('/approve')) {
            approved = true;
            return (200, _device(status: 'APPROVED'));
          }
          return (200, [_device(status: approved ? 'APPROVED' : 'PENDING')]);
        },
      ),
    );

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('Асанов Үсөн'), findsOneWidget);
    expect(find.text('Күтүүдө'), findsOneWidget);

    await tester.tap(find.text('Ырастоо'));
    await tester.pumpAndSettle();

    expect(
      calls.any((c) => c.path.endsWith('/devices/d-1/approve')),
      isTrue,
      reason: 'approving must reach the API',
    );
    // The list is reloaded, so the row reflects the new state.
    expect(find.text('Ырасталган'), findsOneWidget);
    expect(find.text('Ырастоо'), findsNothing);
  });

  testWidgets('revoking asks first and does nothing when declined', (
    tester,
  ) async {
    final calls = <RequestOptions>[];
    final repo = core.DevicesRepository(
      dio: _dio(
        capture: calls,
        reply: (_) => (200, [_device(status: 'APPROVED')]),
      ),
    );

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Жокко чыгаруу'));
    await tester.pumpAndSettle();
    expect(find.textContaining('каттай албай калат'), findsOneWidget);

    await tester.tap(find.text('Жок'));
    await tester.pumpAndSettle();

    expect(
      calls.any((c) => c.path.contains('/revoke')),
      isFalse,
      reason: 'declining the dialog must not call the API',
    );
  });

  testWidgets('an empty school explains what to expect', (tester) async {
    final repo = core.DevicesRepository(dio: _dio(reply: (_) => (200, <Object>[])));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.textContaining('катталган түзмөк жок'), findsOneWidget);
  });

  testWidgets('a failure is shown with a way to retry', (tester) async {
    var attempts = 0;
    final repo = core.DevicesRepository(
      dio: _dio(
        reply: (_) => attempts++ == 0
            ? (500, {'message': 'Сервер жеткиликсиз.'})
            : (200, [_device()]),
      ),
    );

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.text('Сервер жеткиликсиз.'), findsOneWidget);
    expect(find.text('Кайра аракет'), findsOneWidget);

    await tester.tap(find.text('Кайра аракет'));
    await tester.pumpAndSettle();

    expect(find.text('Асанов Үсөн'), findsOneWidget);
  });

  testWidgets('pending devices are listed before the rest', (tester) async {
    final repo = core.DevicesRepository(
      dio: _dio(
        reply: (_) => (200, [
          _device(id: 'd-old', status: 'APPROVED', teacher: 'Эски Түзмөк'),
          _device(id: 'd-new', status: 'PENDING', teacher: 'Жаңы Түзмөк'),
        ]),
      ),
    );

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    final pendingHeader = tester.getTopLeft(
      find.textContaining('Ырастоону күтүүдө'),
    );
    final othersHeader = tester.getTopLeft(find.text('Башка түзмөктөр'));
    expect(
      pendingHeader.dy,
      lessThan(othersHeader.dy),
      reason: 'what needs the administrator comes first',
    );
  });

  testWidgets('renders on a small screen without overflow', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = core.DevicesRepository(
      dio: _dio(
        reply: (_) => (200, [_device(), _device(id: 'd-2', status: 'APPROVED')]),
      ),
    );

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    expect(find.byType(AdminDevicesScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
