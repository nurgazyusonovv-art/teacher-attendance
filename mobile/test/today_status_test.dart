import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:teacher_mobile/core/network/api_client.dart';
import 'package:teacher_mobile/core/storage/secure_storage_service.dart';
import 'package:teacher_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:teacher_mobile/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:teacher_mobile/features/attendance/presentation/cubit/attendance_cubit.dart';
import 'package:teacher_mobile/features/attendance/presentation/cubit/attendance_state.dart';
import 'package:teacher_mobile/features/attendance/data/repositories/attendance_repository.dart';
import 'package:teacher_mobile/features/attendance/presentation/screens/home_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final status in [
    'PENDING',
    'EXCUSED',
    'DAY_OFF',
    'NO_SCHEDULE',
    'ABSENT',
    'ON_TIME',
    'LATE',
  ]) {
    testWidgets('$status fits a small screen with large text', (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final attendance = _TodayCubit(status);
      final storage = SecureStorageService();
      final auth = AuthCubit(
        authRepository: AuthRepository(
          apiClient: ApiClient(storageService: storage),
          storageService: storage,
        ),
      );
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider<AttendanceCubit>.value(value: attendance),
            BlocProvider<AuthCubit>.value(value: auth),
          ],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.8)),
              child: child!,
            ),
            home: const HomeScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text(todayStatusLabel(status)), findsOneWidget);
      expect(tester.takeException(), isNull);

      // At this text scale the scan card sits below the fold, and a ListView
      // does not build what is off-screen — scroll to it before asserting.
      await tester.scrollUntilVisible(
        find.byType(FilledButton),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(
        button.onPressed != null,
        ['PENDING', 'ABSENT', 'ON_TIME', 'LATE'].contains(status),
      );
      await tester.pumpWidget(const SizedBox());
      await attendance.close();
      await auth.close();
    });
  }
  test('Server presentation statuses retain their Kyrgyz meaning', () {
    const labels = {
      'PENDING': 'Азырынча каттала элек',
      'ABSENT': 'Келген жок',
      'EXCUSED': 'Себептүү',
      'DAY_OFF': 'Дем алыш',
      'NO_SCHEDULE': 'Иш графиги жок',
      'ON_TIME': 'Өз убагында келди',
      'LATE': 'Кечигип келди',
    };
    for (final entry in labels.entries) {
      final model = TodayStatusModel.fromJson({
        'date': '2026-09-07',
        'display_status': entry.key,
      });
      expect(todayStatusLabel(model.displayStatus!), entry.value);
      expect(model.scheduledStart, isNull);
    }
  });
  test('Older server never implies pending or on-time from phone time', () {
    final model = TodayStatusModel.fromJson({'date': '2026-09-07'});
    expect(model.displayStatus, isNull);
    expect(model.status, isNull);
    expect(todayStatusLabel('UNKNOWN'), contains('жеткиликсиз'));
  });
}

class _TodayCubit extends AttendanceCubit {
  final String status;
  _TodayCubit(this.status);
  @override
  Future<void> loadTodayStatus() async {
    emit(
      AttendanceTodayLoaded(
        TodayStatusModel.fromJson({
          'date': '2026-09-07',
          'display_status': status,
          'has_checked_in': ['ON_TIME', 'LATE'].contains(status),
          'scheduled_start': '08:00:00',
          'scheduled_end': '17:00:00',
        }),
      ),
    );
  }
}
