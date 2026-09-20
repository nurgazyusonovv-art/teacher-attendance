import 'dart:convert';

import 'package:admin_core/admin_core.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

/// Answers requests from a canned table instead of the network.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.respond);

  final ResponseBody Function(RequestOptions options) respond;
  final List<RequestOptions> received = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    received.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

Dio _dioReturning(
  Object body, {
  int status = 200,
  List<RequestOptions>? capture,
}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://example.test'));
  final adapter = _FakeAdapter(
    (options) => ResponseBody.fromString(
      _encode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    ),
  );
  dio.httpClientAdapter = adapter;
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

String _encode(Object body) =>
    body is String ? body : jsonEncode(body);

const _teacherJson = {
  'id': 't-1',
  'user_id': 'u-1',
  'school_id': 's-1',
  'employee_code': 'TCH-001',
  'phone_number': '+996555112233',
  'subject': 'Физика',
  'full_name': 'Асанов Үсөн',
  'username': 'asanov',
  'is_active': true,
  'is_demo': false,
};

void main() {
  group('Teacher', () {
    test('maps the API shape', () {
      final teacher = Teacher.fromJson(Map<String, dynamic>.from(_teacherJson));
      expect(teacher.id, 't-1');
      expect(teacher.schoolId, 's-1');
      expect(teacher.phoneNumber, '+996555112233');
      expect(teacher.fullName, 'Асанов Үсөн');
      expect(teacher.isActive, isTrue);
      expect(teacher.isDemo, isFalse);
    });

    test('accepts the legacy phone field the phone app used to send', () {
      final json = Map<String, dynamic>.from(_teacherJson)
        ..remove('phone_number')
        ..['phone'] = '+996700000000';
      expect(Teacher.fromJson(json).phoneNumber, '+996700000000');
    });

    test('tolerates a response missing the optional fields', () {
      final teacher = Teacher.fromJson({'id': 't-2'});
      expect(teacher.id, 't-2');
      expect(teacher.fullName, '');
      expect(teacher.phoneNumber, isNull);
      expect(teacher.isActive, isTrue, reason: 'the API defaults to active');
    });

    test('copyWith replaces only what it is given', () {
      final teacher = Teacher.fromJson(Map<String, dynamic>.from(_teacherJson));
      final renamed = teacher.copyWith(fullName: 'Жаңы Ат');
      expect(renamed.fullName, 'Жаңы Ат');
      expect(renamed.employeeCode, teacher.employeeCode);
      expect(renamed, isNot(teacher));
      expect(teacher.copyWith(), teacher);
    });
  });

  group('TeachersRepository', () {
    test('list parses a page', () async {
      final repo = TeachersRepository(
        dio: _dioReturning({
          'items': [_teacherJson],
          'total': 1,
        }),
      );
      final page = await repo.list();
      expect(page.total, 1);
      expect(page.items.single.username, 'asanov');
    });

    test('basePath keeps each app\'s URL shape', () async {
      final captured = <RequestOptions>[];
      final repo = TeachersRepository(
        dio: _dioReturning({'items': [], 'total': 0}, capture: captured),
        basePath: '/api/v1',
      );
      await repo.list();
      expect(captured.single.path, '/api/v1/teachers');
    });

    test('search and is_active reach the query string', () async {
      final captured = <RequestOptions>[];
      final repo = TeachersRepository(
        dio: _dioReturning({'items': [], 'total': 0}, capture: captured),
      );
      await repo.list(search: 'Асан', isActive: false);
      expect(captured.single.queryParameters['search'], 'Асан');
      expect(captured.single.queryParameters['is_active'], false);
    });

    test('update sends only the fields that were passed', () async {
      final captured = <RequestOptions>[];
      final repo = TeachersRepository(
        dio: _dioReturning(_teacherJson, capture: captured),
      );
      await repo.update(teacherId: 't-1', subject: 'Химия');
      expect(captured.single.data, {'subject': 'Химия'});
    });

    test('a hard delete carries the confirmation only when given', () async {
      final captured = <RequestOptions>[];
      final repo = TeachersRepository(
        dio: _dioReturning('', capture: captured),
      );
      await repo.remove('t-1', hardDelete: true);
      expect(captured.single.queryParameters.containsKey('confirmation'), isFalse);

      captured.clear();
      await repo.remove(
        't-1',
        hardDelete: true,
        confirmation: hardDeleteConfirmation,
      );
      expect(
        captured.single.queryParameters['confirmation'],
        'DELETE ATTENDANCE HISTORY',
      );
    });

    test('an API error keeps its code and message', () async {
      final repo = TeachersRepository(
        dio: _dioReturning({
          'success': false,
          'code': 'VALIDATION_ERROR',
          'message': 'Бул мугалимде 12 катышуу жазуусу бар.',
          'details': {'total': 12},
        }, status: 409),
      );

      await expectLater(
        repo.remove('t-1', hardDelete: true),
        throwsA(
          isA<AdminApiException>()
              .having((e) => e.code, 'code', 'VALIDATION_ERROR')
              .having((e) => e.statusCode, 'status', 409)
              .having((e) => e.details?['total'], 'details.total', 12)
              .having(
                (e) => e.message,
                'message',
                contains('12 катышуу жазуусу'),
              ),
        ),
      );
    });

    test('a body without a message falls back to a readable one', () async {
      final repo = TeachersRepository(
        dio: _dioReturning('gateway exploded', status: 502),
      );
      await expectLater(
        repo.list(),
        throwsA(
          isA<AdminApiException>()
              .having((e) => e.message, 'message', contains('ишке ашкан жок'))
              .having((e) => e.isAuthFailure, 'isAuthFailure', isFalse),
        ),
      );
    });

    test('a session failure is recognisable', () async {
      final repo = TeachersRepository(
        dio: _dioReturning({'message': 'Сессия жараксыз.'}, status: 401),
      );
      await expectLater(
        repo.list(),
        throwsA(
          isA<AdminApiException>().having(
            (e) => e.isAuthFailure,
            'isAuthFailure',
            isTrue,
          ),
        ),
      );
    });
  });
}
