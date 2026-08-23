import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/admin_theme.dart';
import 'package:teacher_admin/features/auth/presentation/cubit/admin_auth_cubit.dart';
import 'package:teacher_admin/features/auth/presentation/cubit/admin_auth_state.dart';

class AdminShell extends StatelessWidget {
  final Widget child;
  final String currentRoute;

  const AdminShell({
    super.key,
    required this.child,
    required this.currentRoute,
  });

  @override
  Widget build(BuildContext context) {
    return BlocListener<AdminAuthCubit, AdminAuthState>(
      listener: (context, state) {
        if (state is AdminUnauthenticated) {
          context.go('/login');
        }
      },
      child: Scaffold(
        body: Row(
          children: [
            // Sidebar
            Container(
              width: 240,
              color: AdminTheme.sidebarColor,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                    alignment: Alignment.centerLeft,
                    child: const Row(
                      children: [
                        Icon(Icons.school, color: Colors.white, size: 28),
                        SizedBox(width: 12),
                        Text(
                          'Teacher Admin',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Color(0xFF334155), height: 1),
                  const SizedBox(height: 12),
                  _buildNavItem(context, 'Дашборд', Icons.dashboard_outlined, '/dashboard'),
                  _buildNavItem(context, 'Мугалимдер', Icons.people_outline, '/teachers'),
                  _buildNavItem(context, 'Иш графиги', Icons.schedule, '/schedules'),
                  _buildNavItem(context, 'Отчеттор', Icons.bar_chart, '/reports'),
                  _buildNavItem(context, 'Настройкалар', Icons.settings_outlined, '/settings'),
                  const Spacer(),
                  const Divider(color: Color(0xFF334155), height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Color(0xFF94A3B8)),
                    title: const Text(
                      'Чыгуу',
                      style: TextStyle(color: Color(0xFF94A3B8)),
                    ),
                    onTap: () {
                      context.read<AdminAuthCubit>().logout();
                    },
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            // Main content area
            Expanded(
              child: Column(
                children: [
                  // Top navbar
                  Container(
                    height: 64,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    color: Colors.white,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '№1 Орто Мектептин Администрациясы',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        BlocBuilder<AdminAuthCubit, AdminAuthState>(
                          builder: (context, state) {
                            final name = state is AdminAuthenticated
                                ? state.user.fullName
                                : 'Админ';
                            return Row(
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const CircleAvatar(
                                  radius: 18,
                                  backgroundColor: AdminTheme.accentColor,
                                  child: Text(
                                    'A',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Color(0xFFE2E8F0)),
                  // Screen content
                  Expanded(child: child),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    String title,
    IconData icon,
    String route,
  ) {
    final isSelected = currentRoute.startsWith(route);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        tileColor: isSelected ? AdminTheme.accentColor : Colors.transparent,
        leading: Icon(
          icon,
          color: isSelected ? Colors.white : const Color(0xFF94A3B8),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        onTap: () => context.go(route),
      ),
    );
  }
}
