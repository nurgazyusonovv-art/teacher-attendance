import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:teacher_mobile/core/storage/secure_storage_service.dart';
import 'package:teacher_mobile/core/network/api_client.dart';
import 'package:teacher_mobile/features/attendance/data/repositories/attendance_repository.dart';

/// The school day the cache is checked against, for a given UTC offset.
String _schoolDate(int offsetMinutes) => DateTime.now()
    .toUtc()
    .add(Duration(minutes: offsetMinutes))
    .toIso8601String()
    .substring(0, 10);

Future<AttendanceRepository> _freshRepository() async {
  FlutterSecureStorage.setMockInitialValues({});
  final storage = SecureStorageService();
  final repository = AttendanceRepository(
    apiClient: ApiClient(storageService: storage),
  );
  await storage.saveUserData(jsonEncode({'id': 'teacher-a'}));
  return repository;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Cache round trip is scoped to the signed-in user and cleared on logout',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final storage = SecureStorageService();
      final repository = AttendanceRepository(
        apiClient: ApiClient(storageService: storage),
      );
      await storage.saveUserData(jsonEncode({'id': 'teacher-a'}));

      const offset = 360; // Asia/Bishkek
      final model = TodayStatusModel.fromJson({
        'date': _schoolDate(offset),
        'utc_offset_minutes': offset,
        'display_status': 'ON_TIME',
        'has_checked_in': true,
      });
      await repository.cacheTodayStatus(model);
      expect((await repository.getCachedTodayStatus())?.hasCheckedIn, isTrue);

      await storage.saveUserData(jsonEncode({'id': 'teacher-b'}));
      expect(await repository.getCachedTodayStatus(), isNull);
      await storage.clearAll();
      expect(await repository.getCachedTodayStatus(), isNull);
    },
  );

  test('Yesterday\'s cache is not served as today', () async {
    final repository = await _freshRepository();
    const offset = 360;
    final yesterday = DateTime.now()
        .toUtc()
        .add(const Duration(minutes: offset))
        .subtract(const Duration(days: 1))
        .toIso8601String()
        .substring(0, 10);

    await repository.cacheTodayStatus(
      TodayStatusModel.fromJson({
        'date': yesterday,
        'utc_offset_minutes': offset,
        'display_status': 'ON_TIME',
        'has_checked_in': true,
      }),
    );
    expect(await repository.getCachedTodayStatus(), isNull);
  });

  test('The school day comes from the server offset, not a fixed UTC+6', () async {
    // A school well away from UTC+6: the cache must be judged against its own
    // day. The old code assumed +6 for every school.
    const offset = -300; // UTC-5
    final repository = await _freshRepository();

    await repository.cacheTodayStatus(
      TodayStatusModel.fromJson({
        'date': _schoolDate(offset),
        'utc_offset_minutes': offset,
        'display_status': 'PENDING',
        'has_checked_in': false,
      }),
    );

    final cached = await repository.getCachedTodayStatus();
    expect(cached, isNotNull);
    expect(cached!.utcOffsetMinutes, offset);
    expect(cached.date, _schoolDate(offset));
  });
}
