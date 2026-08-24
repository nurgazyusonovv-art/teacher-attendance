import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/datetime_utils.dart';
import '../../../admin/data/repositories/admin_mobile_repository.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../data/repositories/profile_repository.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileRepository _repository = ProfileRepository();
  final AdminMobileRepository _adminRepository = AdminMobileRepository();

  TeacherProfileData? _profile;
  List<MobileScheduleItem> _schedules = [];
  Map<String, dynamic>? _schoolData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() => _isLoading = true);
    final profile = await _repository.getMyProfile();
    final schedules = await _repository.getMySchedules();
    final school = await _adminRepository.getSchoolSettings();
    if (mounted) {
      setState(() {
        _profile = profile;
        _schedules = schedules;
        _schoolData = school;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Жеке Профиль'),
      ),
      body: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state is Unauthenticated) {
            context.go('/login');
          }
        },
        builder: (context, state) {
          final user = state is Authenticated ? state.user : null;
          final fullName = _profile?.fullName ?? user?.fullName ?? 'Мугалим';
          final username = _profile?.username ?? user?.username ?? 'teacher';
          final email = user?.email ?? '$username@school.edu.kg';
          final isDemo = _profile?.isDemo ?? user?.isDemo ?? false;
          final schoolName = _schoolData?['name'] as String? ?? '№1 Орто Мектеп';
          final radius = (_schoolData?['allowed_radius_meters'] as num?)?.toDouble() ?? 80.0;
          final subject = _profile?.subject ?? 'Жалпы предмет';
          final employeeCode = _profile?.employeeCode ?? 'TCH-001';
          final phone = _profile?.phoneNumber ?? 'Көрсөтүлгөн эмес';

          return RefreshIndicator(
            onRefresh: _loadProfileData,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              children: [
                // Avatar Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppTheme.borderColor),
                    boxShadow: const [
                      BoxShadow(color: Color(0x06000000), blurRadius: 12, offset: Offset(0, 3)),
                    ],
                  ),
                  child: Column(
                    children: [
                      Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 38,
                            backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                            child: Text(
                              fullName.isNotEmpty ? fullName[0] : 'М',
                              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                            ),
                          ),
                          if (isDemo)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('DEMO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.black)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        fullName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        email,
                        style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(schoolName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryLight)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Teacher Info Block
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Column(
                    children: [
                      _buildInfoTile(
                        icon: Icons.badge_outlined,
                        title: 'Табель коду',
                        value: employeeCode,
                      ),
                      const Divider(height: 1),
                      _buildInfoTile(
                        icon: Icons.menu_book_outlined,
                        title: 'Предмети',
                        value: subject,
                      ),
                      const Divider(height: 1),
                      _buildInfoTile(
                        icon: Icons.phone_outlined,
                        title: 'Телефон',
                        value: phone,
                      ),
                      const Divider(height: 1),
                      _buildInfoTile(
                        icon: Icons.location_on_outlined,
                        title: 'GPS Текшерүү',
                        value: 'Радиус: ${radius.toInt()}м (Haversine)',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Weekly Work Schedule
                const Text(
                  'Жумалык иш графиги (Бишкек уб.)',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: _isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: 7,
                          separatorBuilder: (context, index) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final sched = _schedules.cast<MobileScheduleItem?>().firstWhere(
                                  (s) => s?.dayOfWeek == index,
                                  orElse: () => null,
                                );
                            final isOff = sched?.isDayOff ?? (index == 6);
                            final timeText = isOff
                                ? 'Дем алыш'
                                : '${sched != null ? DateTimeUtils.formatBishkekTime(sched.startTime) : "08:00"} — ${sched != null ? DateTimeUtils.formatBishkekTime(sched.endTime) : "17:00"}';

                            return Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      DateTimeUtils.getDayName(index),
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: isOff ? const Color(0xFFF1F5F9) : const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      timeText,
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.bold,
                                        color: isOff ? AppTheme.textSecondary : AppTheme.primaryLight,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 24),

                // Logout Button
                OutlinedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        title: const Text('Чыгуу', style: TextStyle(fontWeight: FontWeight.bold)),
                        content: const Text('Сиз чын эле өз аккаунтуңуздан чыгууну каалайсызбы?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Жокко чыгаруу'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              context.read<AuthCubit>().logout();
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.errorColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Чыгуу', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.logout_rounded, color: AppTheme.errorColor),
                  label: const Text('Аккаунттан чыгуу', style: TextStyle(color: AppTheme.errorColor, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.errorColor),
                    minimumSize: const Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
