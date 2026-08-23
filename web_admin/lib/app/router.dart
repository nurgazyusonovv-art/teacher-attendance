import 'package:go_router/go_router.dart';
import '../features/auth/presentation/screens/admin_login_screen.dart';
import '../features/shell/presentation/screens/admin_shell.dart';
import '../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../features/teachers/presentation/screens/teachers_screen.dart';
import '../features/schedules/presentation/screens/schedules_screen.dart';
import '../features/reports/presentation/screens/reports_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';

final GoRouter adminRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(
      path: '/login',
      builder: (context, state) => const AdminLoginScreen(),
    ),
    ShellRoute(
      builder: (context, state, child) => AdminShell(
        currentRoute: state.uri.toString(),
        child: child,
      ),
      routes: [
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const DashboardScreen(),
        ),
        GoRoute(
          path: '/teachers',
          builder: (context, state) => const TeachersScreen(),
        ),
        GoRoute(
          path: '/schedules',
          builder: (context, state) => const SchedulesScreen(),
        ),
        GoRoute(
          path: '/reports',
          builder: (context, state) => const ReportsScreen(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    ),
  ],
);
