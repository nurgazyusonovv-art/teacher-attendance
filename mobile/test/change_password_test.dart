import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_mobile/core/network/api_client.dart';
import 'package:teacher_mobile/core/storage/secure_storage_service.dart';
import 'package:teacher_mobile/core/theme/app_theme.dart';
import 'package:teacher_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:teacher_mobile/features/profile/presentation/widgets/change_password_sheet.dart';

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.respond);

  final (int, Object) Function(RequestOptions options) respond;
  final List<RequestOptions> calls = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(options);
    final (status, body) = respond(options);
    return ResponseBody.fromString(
      body is String ? body : jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

AuthRepository _repository(_FakeAdapter adapter) {
  final storage = SecureStorageService();
  final client = ApiClient(storageService: storage);
  client.dio.httpClientAdapter = adapter;
  return AuthRepository(apiClient: client, storageService: storage);
}

Future<void> _open(WidgetTester tester, AuthRepository repository) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () =>
                ChangePasswordSheet.show(context, repository: repository),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

Future<void> _fill(
  WidgetTester tester, {
  required String current,
  required String next,
  String? confirm,
}) async {
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), current);
  await tester.enterText(fields.at(1), next);
  await tester.enterText(fields.at(2), confirm ?? next);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  testWidgets('a valid change reaches the API and reports success', (
    tester,
  ) async {
    final adapter = _FakeAdapter((_) => (200, {'success': true}));
    await _open(tester, _repository(adapter));

    await _fill(tester, current: 'old-password', next: 'brand-new-pass');
    await tester.tap(find.text('Сактоо'));
    await tester.pumpAndSettle();

    final call = adapter.calls.single;
    expect(call.path, contains('/auth/change-password'));
    expect((call.data as Map)['current_password'], 'old-password');
    expect((call.data as Map)['new_password'], 'brand-new-pass');
    expect(find.textContaining('Башка түзмөктөрдөн чыгарылдыңыз'), findsOneWidget);
  });

  testWidgets('a short password is refused before any request', (tester) async {
    final adapter = _FakeAdapter((_) => (200, {'success': true}));
    await _open(tester, _repository(adapter));

    await _fill(tester, current: 'old-password', next: 'short');
    await tester.tap(find.text('Сактоо'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Кеминде 8 белги'), findsOneWidget);
    expect(adapter.calls, isEmpty, reason: 'nothing should be sent');
  });

  testWidgets('reusing the current password is refused', (tester) async {
    final adapter = _FakeAdapter((_) => (200, {'success': true}));
    await _open(tester, _repository(adapter));

    await _fill(tester, current: 'same-password', next: 'same-password');
    await tester.tap(find.text('Сактоо'));
    await tester.pumpAndSettle();

    expect(find.textContaining('айырмаланышы керек'), findsOneWidget);
    expect(adapter.calls, isEmpty);
  });

  testWidgets('a mistyped confirmation is refused', (tester) async {
    final adapter = _FakeAdapter((_) => (200, {'success': true}));
    await _open(tester, _repository(adapter));

    await _fill(
      tester,
      current: 'old-password',
      next: 'brand-new-pass',
      confirm: 'brand-new-pas',
    );
    await tester.tap(find.text('Сактоо'));
    await tester.pumpAndSettle();

    expect(find.text('Сырсөздөр дал келбейт'), findsOneWidget);
    expect(adapter.calls, isEmpty);
  });

  testWidgets('a wrong current password shows the API message', (tester) async {
    final adapter = _FakeAdapter(
      (_) => (
        400,
        {
          'code': 'INVALID_CREDENTIALS',
          'message': 'Учурдагы сырсөз туура эмес.',
        },
      ),
    );
    await _open(tester, _repository(adapter));

    await _fill(tester, current: 'wrong-password', next: 'brand-new-pass');
    await tester.tap(find.text('Сактоо'));
    await tester.pumpAndSettle();

    // The sheet stays open so the teacher can correct the entry.
    expect(find.text('Сырсөздү өзгөртүү'), findsOneWidget);
    expect(find.textContaining('туура эмес'), findsOneWidget);
  });

  testWidgets('renders on a small screen', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _open(tester, _repository(_FakeAdapter((_) => (200, <String, Object>{}))));

    expect(find.byType(ChangePasswordSheet), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
