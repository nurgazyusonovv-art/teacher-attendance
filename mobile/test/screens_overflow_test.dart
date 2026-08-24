import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:teacher_mobile/core/theme/app_theme.dart';
import 'package:teacher_mobile/features/admin/data/repositories/admin_mobile_repository.dart';
import 'package:teacher_mobile/features/admin/presentation/screens/tabs/admin_analytics_tab.dart';
import 'package:teacher_mobile/features/admin/presentation/screens/tabs/admin_dashboard_tab.dart';
import 'package:teacher_mobile/features/admin/presentation/screens/tabs/admin_schedules_tab.dart';
import 'package:teacher_mobile/features/admin/presentation/screens/tabs/admin_teachers_tab.dart';
import 'package:teacher_mobile/features/admin/presentation/screens/teacher_detail_screen.dart';
import 'package:teacher_mobile/features/admin/presentation/screens/add_teacher_screen.dart';
import 'package:teacher_mobile/features/admin/presentation/screens/admin_qr_code_screen.dart';
import 'package:teacher_mobile/features/attendance/presentation/screens/home_screen.dart';
import 'package:teacher_mobile/features/history/presentation/screens/history_screen.dart';
import 'package:teacher_mobile/features/profile/presentation/screens/profile_screen.dart';
import 'package:teacher_mobile/features/auth/presentation/screens/login_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:teacher_mobile/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:teacher_mobile/features/attendance/presentation/cubit/attendance_cubit.dart';
import 'package:teacher_mobile/features/attendance/data/repositories/attendance_repository.dart';
import 'package:teacher_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:teacher_mobile/core/network/api_client.dart';
import 'package:teacher_mobile/core/storage/secure_storage_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    FlutterSecureStorage.setMockInitialValues({});
    await initializeDateFormatting('ky', null);
  });

  Widget wrapWithTheme(Widget child, {Size size = const Size(360, 740)}) {
    final storage = SecureStorageService();
    final client = ApiClient(storageService: storage);
    final authRepo = AuthRepository(apiClient: client, storageService: storage);
    final authCubit = AuthCubit(authRepository: authRepo);
    final attRepo = AttendanceRepository();
    final attCubit = AttendanceCubit(repository: attRepo);

    return MediaQuery(
      data: MediaQueryData(size: size),
      child: MultiBlocProvider(
        providers: [
          BlocProvider<AuthCubit>.value(value: authCubit),
          BlocProvider<AttendanceCubit>.value(value: attCubit),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: child,
        ),
      ),
    );
  }

  testWidgets('AdminAnalyticsTab renders without overflow on small screens', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(wrapWithTheme(const Scaffold(body: AdminAnalyticsTab()), size: const Size(320, 640)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(AdminAnalyticsTab), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AdminTeachersTab renders without overflow on small screens', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(wrapWithTheme(const Scaffold(body: AdminTeachersTab()), size: const Size(320, 640)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(AdminTeachersTab), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AdminDashboardTab renders without overflow on small screens', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(wrapWithTheme(const Scaffold(body: AdminDashboardTab()), size: const Size(320, 640)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(AdminDashboardTab), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AdminSchedulesTab renders without overflow on small screens', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(wrapWithTheme(const Scaffold(body: AdminSchedulesTab()), size: const Size(320, 640)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(AdminSchedulesTab), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('TeacherDetailScreen renders without overflow on small screens', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final teacher = TeacherItemModel(
      id: 't-123',
      userId: 'u-123',
      schoolId: 'sch-1',
      fullName: 'Apple Review Demo Teacher Very Long Name',
      email: 'demo@school.kg',
      username: 'demo_teacher_long_name',
      subject: 'Математика',
      employeeCode: 'DEMO-001',
      phone: '+996555123456',
      isActive: true,
    );

    await tester.pumpWidget(wrapWithTheme(TeacherDetailScreen(teacher: teacher), size: const Size(320, 640)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(TeacherDetailScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('HomeScreen renders without overflow on small screens', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(wrapWithTheme(const HomeScreen(), size: const Size(320, 640)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('HistoryScreen renders without overflow on small screens', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(wrapWithTheme(const HistoryScreen(), size: const Size(320, 640)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(HistoryScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ProfileScreen renders without overflow on small screens', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(wrapWithTheme(const ProfileScreen(), size: const Size(320, 640)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('LoginScreen renders without overflow on small screens', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(wrapWithTheme(const LoginScreen(), size: const Size(320, 640)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AddTeacherScreen renders without overflow on small screens', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(wrapWithTheme(const AddTeacherScreen(), size: const Size(320, 640)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(AddTeacherScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('AdminQrCodeScreen renders without overflow on small screens', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(wrapWithTheme(const AdminQrCodeScreen(), size: const Size(320, 640)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(AdminQrCodeScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
