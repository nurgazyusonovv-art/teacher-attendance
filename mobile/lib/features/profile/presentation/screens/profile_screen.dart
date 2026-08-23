import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:teacher_mobile/core/theme/app_theme.dart';
import 'package:teacher_mobile/features/auth/presentation/cubit/auth_cubit.dart';
import 'package:teacher_mobile/features/auth/presentation/cubit/auth_state.dart';
import 'package:teacher_mobile/features/profile/data/repositories/profile_repository.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileRepository _repository = ProfileRepository();
  TeacherProfileData? _profile;
  List<MobileScheduleItem> _schedules = [];
  bool _isLoading = true;

  final List<String> _dayNames = [
    'Дүйшөмбү',
    'Шейшемби',
    'Шаршемби',
    'Бейшемби',
    'Жума',
    'Ишемби',
    'Жекшемби',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final profile = await _repository.getMyProfile();
    final schedules = await _repository.getMySchedules();
    if (mounted) {
      setState(() {
        _profile = profile;
        _schedules = schedules;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль'),
      ),
      body: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is Unauthenticated) {
            context.go('/login');
          }
        },
        builder: (context, state) {
          final user = state is Authenticated ? state.user : null;
          final fullName = user?.fullName ?? _profile?.fullName ?? 'Мугалим';
          final email = user?.email ?? 'teacher@school.edu.kg';
          final isDemo = user?.isDemo ?? _profile?.isDemo ?? false;

          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(20.0),
              children: [
                Center(
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      const CircleAvatar(
                        radius: 42,
                        backgroundColor: Color(0xFFEFF6FF),
                        child: Icon(Icons.person,
                            size: 52, color: AppTheme.primaryColor),
                      ),
                      if (isDemo)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'DEMO',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    fullName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    email,
                    style: const TextStyle(
                        fontSize: 14, color: Color(0xFF64748B)),
                  ),
                ),
                const SizedBox(height: 24),

                // Teacher Info Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.badge_outlined,
                              color: AppTheme.primaryColor),
                          title: const Text('Табель номери'),
                          trailing: Text(
                            _profile?.employeeCode ?? 'TCH-001',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.menu_book_outlined,
                              color: AppTheme.primaryColor),
                          title: const Text('Предмети'),
                          trailing: Text(
                            _profile?.subject ?? 'Математика',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        const Divider(height: 1),
                        const ListTile(
                          leading: Icon(Icons.location_on_outlined,
                              color: AppTheme.primaryColor),
                          title: Text('Геолокация текшерүү'),
                          trailing: Icon(Icons.check_circle,
                              color: AppTheme.successColor),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Weekly Work Schedule
                const Text(
                  'Жумалык иш графиги',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: _isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: 7,
                          separatorBuilder: (context, index) =>
                              const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final sched =
                                _schedules.cast<MobileScheduleItem?>().firstWhere(
                                      (s) => s?.dayOfWeek == index,
                                      orElse: () => null,
                                    );
                            final isOff = sched?.isDayOff ?? (index == 6);
                            final timeText = isOff
                                ? 'Дем алыш'
                                : '${sched != null ? sched.startTime.substring(0, 5) : "08:00"} - ${sched != null ? sched.endTime.substring(0, 5) : "17:00"}';

                            return ListTile(
                              dense: true,
                              title: Text(
                                _dayNames[index],
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                              trailing: Text(
                                timeText,
                                style: TextStyle(
                                  color: isOff
                                      ? Colors.grey
                                      : AppTheme.primaryColor,
                                  fontWeight: isOff
                                      ? FontWeight.normal
                                      : FontWeight.bold,
                                ),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 32),

                // Logout Button
                OutlinedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (dialogCtx) => AlertDialog(
                        title: const Text('Чыгуу'),
                        content: const Text(
                            'Чын эле аккаунттан чыгууну каалайсызбы?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogCtx),
                            child: const Text('Жок'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(dialogCtx);
                              context.read<AuthCubit>().logout();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.errorColor,
                              minimumSize: const Size(80, 40),
                            ),
                            child: const Text('Чыгуу'),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.logout, color: AppTheme.errorColor),
                  label: const Text('Чыгуу',
                      style: TextStyle(color: AppTheme.errorColor)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.errorColor),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
