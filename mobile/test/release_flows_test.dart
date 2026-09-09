import 'dart:async';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:teacher_mobile/core/network/api_client.dart';
import 'package:teacher_mobile/core/storage/secure_storage_service.dart';
import 'package:teacher_mobile/features/leaves/data/leave_repository.dart';
import 'package:teacher_mobile/features/leaves/presentation/leave_cubit.dart';
import 'package:teacher_mobile/features/attendance/data/repositories/attendance_repository.dart';
import 'package:teacher_mobile/features/attendance/presentation/cubit/attendance_cubit.dart';

class Adapter implements HttpClientAdapter {
  final Future<ResponseBody> Function(RequestOptions) respond;
  Adapter(this.respond);
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? stream,
    Future<void>? cancel,
  ) => respond(options);
  @override
  void close({bool force = false}) {}
}

class PendingLeaves extends LeaveRepository {
  final gate = Completer<void>();
  int writes = 0;
  @override
  Future<void> submit(String date, String reason) {
    writes++;
    return gate.future;
  }

  @override
  Future<List<Map<String, dynamic>>> list(bool admin, int offset) async => [];
}

class PendingAttendance extends AttendanceRepository {
  final gate = Completer<TodayStatusModel?>();
  int reads = 0;
  @override
  Future<TodayStatusModel?> getTodayStatus() {
    reads++;
    return gate.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  test('Separate repositories share one token rotation', () async {
    final storage = SecureStorageService();
    await storage.saveTokens(accessToken: 'old', refreshToken: 'rotate-once');
    var rotations = 0;
    final refresh = Dio();
    refresh.httpClientAdapter = Adapter((_) async {
      rotations++;
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return ResponseBody.fromString(
        '{"data":{"access_token":"new","refresh_token":"rotated"}}',
        200,
        headers: {
          Headers.contentTypeHeader: ['application/json'],
        },
      );
    });
    final clients = List.generate(
      2,
      (_) => ApiClient(storageService: storage, refreshClient: refresh),
    );
    for (final client in clients) {
      client.dio.httpClientAdapter = Adapter(
        (options) async => ResponseBody.fromString(
          '{}',
          options.headers['Authorization'] == 'Bearer new' ? 200 : 401,
        ),
      );
    }
    await Future.wait(
      clients.map((client) => client.dio.get('/attendance/today')),
    );
    expect(rotations, 1);
    expect(await storage.getRefreshToken(), 'rotated');
  });
  test('Repeated leave submission sends one request', () async {
    final repo = PendingLeaves();
    final cubit = LeaveCubit(repo, admin: false);
    final first = cubit.submit('2026-09-10', 'Текшерүү себеби');
    expect(await cubit.submit('2026-09-10', 'Текшерүү себеби'), isFalse);
    expect(repo.writes, 1);
    repo.gate.complete();
    expect(await first, isTrue);
    expect(cubit.state.busy, isFalse);
    await cubit.close();
  });
  test(
    'Reopening/loading during request does not duplicate or emit after close',
    () async {
      final repo = PendingAttendance();
      final cubit = AttendanceCubit(repository: repo);
      final first = cubit.loadTodayStatus();
      await cubit.loadTodayStatus();
      expect(repo.reads, 1);
      await cubit.close();
      repo.gate.complete(null);
      await first;
    },
  );
  test(
    'Offline refresh retains session while rejected refresh clears it',
    () async {
      final storage = SecureStorageService();
      for (final offline in [true, false]) {
        await storage.saveTokens(
          accessToken: 'test-access',
          refreshToken: 'test-refresh',
        );
        final refresh = Dio();
        refresh.httpClientAdapter = Adapter((options) async {
          if (offline) {
            throw DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
            );
          }
          return ResponseBody.fromString(
            '{}',
            401,
            headers: {
              Headers.contentTypeHeader: ['application/json'],
            },
          );
        });
        final client = ApiClient(
          storageService: storage,
          refreshClient: refresh,
        );
        client.dio.httpClientAdapter = Adapter(
          (_) async => ResponseBody.fromString('{}', 401),
        );
        try {
          await client.dio.get('/auth/me');
          fail('Must not succeed');
        } on DioException catch (error) {
          expect(
            offline
                ? error.type == DioExceptionType.connectionError
                : error.response?.statusCode == 401,
            isTrue,
          );
        }
        expect(
          await storage.getRefreshToken(),
          offline ? 'test-refresh' : null,
        );
      }
    },
  );
}
