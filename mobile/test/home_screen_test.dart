import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_mobile/core/network/api_client.dart';
import 'package:teacher_mobile/core/storage/secure_storage_service.dart';
import 'package:teacher_mobile/core/theme/app_theme.dart';
import 'package:teacher_mobile/features/attendance/data/repositories/attendance_repository.dart';
import 'package:teacher_mobile/features/attendance/presentation/cubit/attendance_cubit.dart';
import 'package:teacher_mobile/features/attendance/presentation/cubit/attendance_state.dart';
import 'package:teacher_mobile/features/attendance/presentation/screens/home_screen.dart';
import 'package:teacher_mobile/features/attendance/presentation/widgets/home_sections.dart';
import 'package:teacher_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:teacher_mobile/features/auth/presentation/cubit/auth_cubit.dart';

/// Emits one fixed day; the screen never reaches the network for it.
class _FixedCubit extends AttendanceCubit {
  _FixedCubit(this.json, {this.cached = false});

  final Map<String, dynamic> json;
  final bool cached;

  @override
  Future<void> loadTodayStatus() async {
    emit(AttendanceTodayLoaded(TodayStatusModel.fromJson(json), cached: cached));
  }
}

/// Returns a canned history without touching the network.
class _FixedHistory extends AttendanceRepository {
  _FixedHistory(this.rows);

  final List<Map<String, dynamic>> rows;
  int calls = 0;

  @override
  Future<List<DailyAttendanceModel>> getMyHistory({int? year, int? month}) async {
    calls++;
    return rows.map(DailyAttendanceModel.fromJson).toList();
  }
}

Map<String, dynamic> _today({
  String status = 'ON_TIME',
  String? checkIn = '2026-09-18T07:50:00+06:00',
  String? checkOut,
  String? serverTime = '2026-09-18T15:55:00+06:00',
  int lateMinutes = 0,
}) => {
  'date': '2026-09-18',
  'display_status': status,
  'school_name': '№24 ТМГ',
  'utc_offset_minutes': 360,
  'server_time': serverTime,
  'has_checked_in': checkIn != null,
  'has_checked_out': checkOut != null,
  'check_in_time': checkIn,
  'check_out_time': checkOut,
  'late_minutes': lateMinutes,
  'worked_minutes': 0,
  'scheduled_start': '08:00:00',
  'scheduled_end': '17:00:00',
};

Future<AuthCubit> _pump(
  WidgetTester tester, {
  required AttendanceCubit cubit,
  AttendanceRepository? history,
  Size size = const Size(390, 900),
}) async {
  FlutterSecureStorage.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

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
        BlocProvider<AttendanceCubit>.value(value: cubit),
        BlocProvider<AuthCubit>.value(value: auth),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: HomeScreen(historyRepository: history ?? _FixedHistory(const [])),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 100));
  return auth;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the clock shows the school time the server reported', (
    tester,
  ) async {
    final auth = await _pump(tester, cubit: _FixedCubit(_today()));

    // Not the device clock: the test machine is not at 15:55 Bishkek time.
    expect(find.text('15:55'), findsOneWidget);
    expect(find.text('№24 ТМГ'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await auth.close();
  });

  testWidgets('a response without a server clock shows no time at all', (
    tester,
  ) async {
    // Better an honest placeholder than the device's own clock.
    final auth = await _pump(
      tester,
      cubit: _FixedCubit(_today(serverTime: null)),
    );

    expect(find.text('--:--'), findsWidgets);

    await tester.pumpWidget(const SizedBox());
    await auth.close();
  });

  testWidgets('both stamps are shown, with the arrival time', (tester) async {
    final auth = await _pump(tester, cubit: _FixedCubit(_today()));

    expect(find.text('КЕЛҮҮ'), findsOneWidget);
    expect(find.text('КЕТҮҮ'), findsOneWidget);
    expect(find.text('07:50'), findsOneWidget);
    expect(find.text('Өз убагында'), findsOneWidget);
    expect(find.text('Каттала элек'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await auth.close();
  });

  testWidgets('lateness is named rather than shown as on time', (tester) async {
    final auth = await _pump(
      tester,
      cubit: _FixedCubit(_today(status: 'LATE', lateMinutes: 7)),
    );

    expect(find.text('7 мүнөт кечигүү'), findsOneWidget);
    expect(find.text('Өз убагында'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await auth.close();
  });

  testWidgets('the leave request action is reachable from the home screen', (
    tester,
  ) async {
    final auth = await _pump(tester, cubit: _FixedCubit(_today()));

    final leave = find.text('Уруксат суроо жана арыздарым');
    await tester.scrollUntilVisible(
      leave,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(leave, findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await auth.close();
  });

  testWidgets('recent days are listed newest first, capped at four', (
    tester,
  ) async {
    final history = _FixedHistory([
      for (var day = 21; day >= 15; day--)
        {
          'id': 'a-$day',
          'teacher_id': 't-1',
          'school_id': 's-1',
          'date': '2026-09-$day',
          'status': 'ON_TIME',
          'check_in_time': '2026-09-${day}T07:55:00+06:00',
          'check_out_time': '2026-09-${day}T16:05:00+06:00',
          'worked_minutes': 490,
          'late_minutes': 0,
          'is_manually_corrected': false,
        },
    ]);
    final auth = await _pump(
      tester,
      cubit: _FixedCubit(_today()),
      history: history,
    );

    await tester.scrollUntilVisible(
      find.byType(HomeHistory),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    expect(history.calls, greaterThan(0));
    expect(find.text('07:55 — 16:05'), findsNWidgets(4));

    await tester.pumpWidget(const SizedBox());
    await auth.close();
  });

  testWidgets('a cached day cannot be scanned and says why', (tester) async {
    final auth = await _pump(
      tester,
      cubit: _FixedCubit(_today(status: 'PENDING', checkIn: null), cached: true),
    );

    expect(find.textContaining('Акыркы сакталган маалымат'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byType(FilledButton),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull, reason: 'a stale day must not be scanned');

    await tester.pumpWidget(const SizedBox());
    await auth.close();
  });

  testWidgets('renders on a 320px screen without overflow', (tester) async {
    final auth = await _pump(
      tester,
      cubit: _FixedCubit(_today(checkOut: '2026-09-18T16:05:00+06:00')),
      size: const Size(320, 640),
    );

    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
    await auth.close();
  });
}
