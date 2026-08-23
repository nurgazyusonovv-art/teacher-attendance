import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_mobile/core/theme/app_theme.dart';
import 'package:teacher_mobile/features/attendance/data/repositories/attendance_repository.dart';
import 'package:teacher_mobile/features/attendance/presentation/cubit/attendance_cubit.dart';
import 'package:teacher_mobile/features/attendance/presentation/cubit/attendance_state.dart';
import 'package:teacher_mobile/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:teacher_mobile/features/auth/presentation/cubit/auth_state.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  TodayStatusModel? _todayStatus;

  @override
  void initState() {
    super.initState();
    context.read<AttendanceCubit>().loadTodayStatus();
  }

  String _formatTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '--:--';
    try {
      final dt = DateTime.parse(isoString);
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } catch (_) {
      return isoString.substring(0, 5);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Башкы бет'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: BlocConsumer<AttendanceCubit, AttendanceState>(
        listener: (context, state) {
          if (state is AttendanceTodayLoaded) {
            setState(() => _todayStatus = state.status);
          } else if (state is AttendanceActionSuccess) {
            context.read<AttendanceCubit>().loadTodayStatus();
          }
        },
        builder: (context, attendanceState) {
          return BlocBuilder<AuthCubit, AuthState>(
            builder: (context, authState) {
              final teacherName = authState is Authenticated
                  ? authState.user.fullName
                  : 'Мугалим';
              final isDemo = authState is Authenticated ? authState.user.isDemo : false;

              final hasCheckedIn = _todayStatus?.hasCheckedIn ?? false;
              final hasCheckedOut = _todayStatus?.hasCheckedOut ?? false;
              final checkInTime = _formatTime(_todayStatus?.checkInTime);
              final checkOutTime = _formatTime(_todayStatus?.checkOutTime);

              String buttonText = 'КЕЛҮҮ QR СКАНЕРЛӨӨ';
              bool isCheckOutMode = false;

              if (hasCheckedIn && !hasCheckedOut) {
                buttonText = 'КЕТҮҮ QR СКАНЕРЛӨӨ';
                isCheckOutMode = true;
              } else if (hasCheckedIn && hasCheckedOut) {
                buttonText = 'БҮГҮНКҮ ЖУМУШ БҮТТҮ';
              }

              return SafeArea(
                child: RefreshIndicator(
                  onRefresh: () => context.read<AttendanceCubit>().loadTodayStatus(),
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Greeting & Teacher Card
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(18.0),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor:
                                      AppTheme.primaryColor.withValues(alpha: 0.1),
                                  child: const Icon(
                                    Icons.person,
                                    size: 32,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              'Саламатсызбы, $teacherName!',
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                          ),
                                          if (isDemo)
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.amber,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                'DEMO',
                                                style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.black),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        '№1 Орто Мектеп',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Today's schedule & status card
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(18.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Бүгүнкү график',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    Chip(
                                      label: Text(
                                        _todayStatus?.scheduledStart != null
                                            ? '${_todayStatus!.scheduledStart!.substring(0, 5)} — ${_todayStatus!.scheduledEnd!.substring(0, 5)}'
                                            : '08:00 — 17:00',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppTheme.primaryColor,
                                        ),
                                      ),
                                      backgroundColor: const Color(0xFFEFF6FF),
                                      padding: EdgeInsets.zero,
                                    ),
                                  ],
                                ),
                                const Divider(height: 24),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildTimeStatus(
                                        icon: Icons.login_rounded,
                                        title: 'Келүү (Check-in)',
                                        time: checkInTime,
                                        color: hasCheckedIn
                                            ? AppTheme.successColor
                                            : AppTheme.primaryColor,
                                      ),
                                    ),
                                    Container(
                                      height: 40,
                                      width: 1,
                                      color: const Color(0xFFE2E8F0),
                                    ),
                                    Expanded(
                                      child: _buildTimeStatus(
                                        icon: Icons.logout_rounded,
                                        title: 'Кетүү (Check-out)',
                                        time: checkOutTime,
                                        color: hasCheckedOut
                                            ? AppTheme.successColor
                                            : AppTheme.secondaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Big Action Button
                        ElevatedButton.icon(
                          onPressed: (hasCheckedIn && hasCheckedOut)
                              ? null
                              : () async {
                                  final result = await context.push(
                                    isCheckOutMode
                                        ? '/scanner?checkout=true'
                                        : '/scanner',
                                  );
                                  if (result == true && context.mounted) {
                                    context.read<AttendanceCubit>().loadTodayStatus();
                                  }
                                },
                          icon: const Icon(Icons.qr_code_scanner, size: 28),
                          label: Text(
                            buttonText,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 60),
                            backgroundColor: isCheckOutMode
                                ? Colors.amber[800]
                                : AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Quick Attendance History Card
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(18.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Катышуу тарыхы',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () => context.push('/history'),
                                      child: const Text('Толук көрүү'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildStatItem('Статус',
                                        hasCheckedIn ? 'Келди' : 'Келе элек',
                                        hasCheckedIn ? AppTheme.successColor : Colors.grey),
                                    _buildStatItem('Кечигүү',
                                        '${_todayStatus?.lateMinutes ?? 0} мүн',
                                        (_todayStatus?.lateMinutes ?? 0) > 0 ? Colors.orange : AppTheme.primaryColor),
                                    _buildStatItem('Иштеди',
                                        '${_todayStatus?.workedMinutes ?? 0} мүн',
                                        AppTheme.primaryColor),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTimeStatus({
    required IconData icon,
    required String title,
    required String time,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 6),
        Text(
          title,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 4),
        Text(
          time,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
      ],
    );
  }
}
