import 'package:go_router/go_router.dart';
import '../features/admin/data/repositories/admin_mobile_repository.dart';
import '../features/admin/presentation/screens/add_teacher_screen.dart';
import '../features/admin/presentation/screens/admin_main_screen.dart';
import '../features/admin/presentation/screens/admin_qr_code_screen.dart';
import '../features/admin/presentation/screens/teacher_detail_screen.dart';
import '../features/attendance/presentation/screens/home_screen.dart';
import '../features/attendance/presentation/screens/qr_scanner_screen.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/history/presentation/screens/history_screen.dart';
import '../features/profile/presentation/screens/profile_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminMainScreen(),
    ),
    GoRoute(
      path: '/admin/teacher-detail',
      builder: (context, state) {
        final teacher = state.extra as TeacherItemModel;
        return TeacherDetailScreen(teacher: teacher);
      },
    ),
    GoRoute(
      path: '/admin/add-teacher',
      builder: (context, state) => const AddTeacherScreen(),
    ),
    GoRoute(
      path: '/admin/qr-code',
      builder: (context, state) => const AdminQrCodeScreen(),
    ),
    GoRoute(
      path: '/scanner',
      builder: (context, state) {
        final isCheckOut = state.uri.queryParameters['checkout'] == 'true';
        return QrScannerScreen(isCheckOut: isCheckOut);
      },
    ),
    GoRoute(
      path: '/history',
      builder: (context, state) => const HistoryScreen(),
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
    ),
  ],
);
