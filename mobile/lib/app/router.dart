import 'package:go_router/go_router.dart';
import '../features/admin/presentation/screens/admin_main_screen.dart';
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
