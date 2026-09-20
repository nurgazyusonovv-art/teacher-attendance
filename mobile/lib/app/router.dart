import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import '../features/leaves/presentation/leave_screen.dart';
import '../features/admin/data/repositories/admin_mobile_repository.dart';
import '../features/admin/presentation/screens/add_teacher_screen.dart';
import '../features/admin/presentation/screens/admin_main_screen.dart';
import '../features/admin/presentation/screens/admin_devices_screen.dart';
import '../features/admin/presentation/screens/admin_qr_code_screen.dart';
import '../features/admin/presentation/screens/teacher_detail_screen.dart';
import '../features/attendance/presentation/screens/home_screen.dart';
import '../features/attendance/presentation/screens/qr_scanner_screen.dart';
import '../features/auth/presentation/cubit/auth_cubit.dart';
import '../features/auth/presentation/cubit/auth_state.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/history/presentation/screens/history_screen.dart';
import '../features/profile/presentation/screens/profile_screen.dart';
import '../features/splash/presentation/screens/splash_screen.dart';

/// Routes reachable without a session.
const _publicRoutes = {'/splash', '/login'};

/// Routes only an administrator may open.
bool _isAdminRoute(String location) => location.startsWith('/admin');

/// Rebuilds the router's redirect whenever the session changes.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Stream<AuthState> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

/// Builds the app router with session and role guards.
///
/// Without these, a deep link reaches an admin or teacher screen with no
/// session at all. The backend still rejects the requests, but the user lands
/// on a screen that can only fail.
GoRouter createAppRouter(AuthCubit authCubit) {
  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: _AuthRefreshNotifier(authCubit.stream),
    redirect: (context, state) {
      final location = state.matchedLocation;
      final authState = authCubit.state;

      // Session not resolved yet: the splash screen owns this window and
      // navigates once the check finishes.
      if (authState is AuthInitial || authState is AuthLoading) {
        return location == '/splash' ? null : '/splash';
      }

      if (authState is! Authenticated) {
        return _publicRoutes.contains(location) ? null : '/login';
      }

      // Signed in: never leave the user sitting on the login screen.
      if (location == '/login') {
        return authState.user.isAdmin ? '/admin' : '/home';
      }
      if (_isAdminRoute(location) && !authState.user.isAdmin) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/leaves', builder: (_, _) => const LeaveScreen()),
      GoRoute(
        path: '/admin/leaves',
        builder: (_, _) => const LeaveScreen(admin: true),
      ),
      GoRoute(path: '/splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
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
        path: '/admin/devices',
        builder: (context, state) => const AdminDevicesScreen(),
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
}
