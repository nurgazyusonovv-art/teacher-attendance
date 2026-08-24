import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/datetime_utils.dart';
import '../../../admin/data/repositories/admin_mobile_repository.dart';
import '../../../profile/data/repositories/profile_repository.dart';
import '../../data/repositories/attendance_repository.dart';
import '../cubit/attendance_cubit.dart';
import '../cubit/attendance_state.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ProfileRepository _profileRepository = ProfileRepository();
  final AdminMobileRepository _adminRepository = AdminMobileRepository();

  TodayStatusModel? _todayStatus;
  TeacherProfileData? _teacherProfile;
  Map<String, dynamic>? _schoolData;
  late Timer _clockTimer;
  DateTime _currentTime = DateTimeUtils.bishkekNow;

  @override
  void initState() {
    super.initState();
    _loadAllData();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _currentTime = DateTimeUtils.bishkekNow);
      }
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  Future<void> _loadAllData() async {
    context.read<AttendanceCubit>().loadTodayStatus();
    final profile = await _profileRepository.getMyProfile();
    final school = await _adminRepository.getSchoolSettings();
    if (mounted) {
      setState(() {
        _teacherProfile = profile;
        _schoolData = school;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Мугалим Каттоо'),
        leading: Padding(
          padding: const EdgeInsets.only(left: 14, top: 8, bottom: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset('assets/images/app_logo.png', fit: BoxFit.cover),
          ),
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person_outline_rounded, color: AppTheme.textPrimary, size: 20),
            ),
            tooltip: 'Профиль',
            onPressed: () => context.push('/profile'),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: BlocConsumer<AttendanceCubit, AttendanceState>(
        listener: (context, state) {
          if (state is AttendanceTodayLoaded) {
            setState(() => _todayStatus = state.status);
          } else if (state is AttendanceActionSuccess) {
            _loadAllData();
          }
        },
        builder: (context, attendanceState) {
          return BlocBuilder<AuthCubit, AuthState>(
            builder: (context, authState) {
              final teacherName = _teacherProfile?.fullName ??
                  (authState is Authenticated ? authState.user.fullName : 'Мугалим');
              final isDemo = _teacherProfile?.isDemo ??
                  (authState is Authenticated ? authState.user.isDemo : false);
              final subject = _teacherProfile?.subject;
              final schoolName = _schoolData?['name'] as String? ?? '№1 Орто Мектеп';

              final hasCheckedIn = _todayStatus?.hasCheckedIn ?? false;
              final hasCheckedOut = _todayStatus?.hasCheckedOut ?? false;
              final checkInTime = DateTimeUtils.formatBishkekTime(_todayStatus?.checkInTime);
              final checkOutTime = DateTimeUtils.formatBishkekTime(_todayStatus?.checkOutTime);
              final lateMinutes = _todayStatus?.lateMinutes ?? 0;

              String heroButtonTitle = 'КЕЛҮҮ КАТТОО';
              String heroButtonSubtitle = 'Мектептин QR-кодун сканерлеңиз';
              bool isCheckOutMode = false;
              bool isCompleted = false;
              LinearGradient heroGradient = const LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF2563EB)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              );

              if (hasCheckedIn && !hasCheckedOut) {
                heroButtonTitle = 'КЕТҮҮ КАТТОО';
                heroButtonSubtitle = 'Жумуш күнүн жыйынтыктоо үчүн сканерлеңиз';
                isCheckOutMode = true;
                heroGradient = const LinearGradient(
                  colors: [Color(0xFFD97706), Color(0xFFF59E0B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                );
              } else if (hasCheckedIn && hasCheckedOut) {
                heroButtonTitle = 'БҮГҮНКҮ ЖУМУШ БҮТТҮ';
                heroButtonSubtitle = 'Келүү жана кетүү ийгиликтүү катталды';
                isCompleted = true;
                heroGradient = const LinearGradient(
                  colors: [Color(0xFF059669), Color(0xFF10B981)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                );
              }

              return SafeArea(
                child: RefreshIndicator(
                  onRefresh: _loadAllData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Greeting Header
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
                              child: Text(
                                teacherName.isNotEmpty ? teacherName[0] : 'М',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryColor),
                              ),
                            ),
                            const SizedBox(width: 10),
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
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.textPrimary,
                                            letterSpacing: -0.3,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      if (isDemo)
                                        Container(
                                          margin: const EdgeInsets.only(left: 6),
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: Colors.amber,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text('DEMO', style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: Colors.black)),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$schoolName ${subject != null && subject.isNotEmpty ? "• $subject" : "• Мугалим"}',
                                    style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Live Clock & Date Banner (Asia/Bishkek)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.borderColor),
                            boxShadow: const [
                              BoxShadow(color: Color(0x06000000), blurRadius: 12, offset: Offset(0, 3)),
                            ],
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        const Icon(Icons.calendar_today_rounded, size: 13, color: AppTheme.textSecondary),
                                        const SizedBox(width: 5),
                                        Expanded(
                                          child: Text(
                                            DateTimeUtils.formatKyrgyzDate(_currentTime),
                                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEFF6FF),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text('Бишкек уб. (UTC+6)', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppTheme.primaryLight)),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${_currentTime.hour.toString().padLeft(2, "0")}:${_currentTime.minute.toString().padLeft(2, "0")}:${_currentTime.second.toString().padLeft(2, "0")}',
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppTheme.borderColor),
                                ),
                                child: Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  alignment: WrapAlignment.center,
                                  children: [
                                    const Icon(Icons.schedule_rounded, size: 13, color: AppTheme.textSecondary),
                                    const SizedBox(width: 5),
                                    Text(
                                      _todayStatus?.isDayOff == true
                                          ? 'Бүгүн: Дем алыш күнү'
                                          : 'Иш убактысы: ${_todayStatus?.scheduledStart != null ? "${DateTimeUtils.formatBishkekTime(_todayStatus!.scheduledStart)} — ${DateTimeUtils.formatBishkekTime(_todayStatus!.scheduledEnd)}" : "08:00 — 17:00"}',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // HERO Scan Action Card
                        InkWell(
                          onTap: isCompleted
                              ? null
                              : () async {
                                  final result = await context.push(
                                    isCheckOutMode
                                        ? '/scanner?checkout=true'
                                        : '/scanner',
                                  );
                                  if (result == true && context.mounted) {
                                    _loadAllData();
                                  }
                                },
                          borderRadius: BorderRadius.circular(22),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                            decoration: BoxDecoration(
                              gradient: heroGradient,
                              borderRadius: BorderRadius.circular(22),
                              boxShadow: [
                                BoxShadow(
                                  color: (isCheckOutMode ? Colors.amber[800]! : (isCompleted ? AppTheme.successColor : AppTheme.primaryColor)).withValues(alpha: 0.35),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isCompleted ? Icons.check_circle_rounded : Icons.qr_code_scanner_rounded,
                                    size: 38,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  heroButtonTitle,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  heroButtonSubtitle,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 11.5,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Today's Check-in / Check-out Status Card (Real Data)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.borderColor),
                            boxShadow: const [
                              BoxShadow(color: Color(0x06000000), blurRadius: 12, offset: Offset(0, 3)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Бүгүнкү каттоолор',
                                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                                  ),
                                  Icon(Icons.history_toggle_off_rounded, size: 16, color: AppTheme.textSecondary),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildTimeMetric(
                                      title: 'Келүү',
                                      time: checkInTime,
                                      icon: Icons.login_rounded,
                                      color: hasCheckedIn ? AppTheme.successColor : AppTheme.textSecondary,
                                      badgeText: hasCheckedIn ? (lateMinutes > 0 ? '+$lateMinutes мүн' : 'Өз уб.') : 'Каттала элек',
                                      badgeColor: hasCheckedIn ? (lateMinutes > 0 ? Colors.orange : AppTheme.successColor) : Colors.grey,
                                    ),
                                  ),
                                  Container(height: 44, width: 1, color: AppTheme.borderColor, margin: const EdgeInsets.symmetric(horizontal: 6)),
                                  Expanded(
                                    child: _buildTimeMetric(
                                      title: 'Кетүү',
                                      time: checkOutTime,
                                      icon: Icons.logout_rounded,
                                      color: hasCheckedOut ? AppTheme.secondaryColor : AppTheme.textSecondary,
                                      badgeText: hasCheckedOut ? 'Кетти' : (hasCheckedIn ? 'Иштеп жатат' : '--'),
                                      badgeColor: hasCheckedOut ? AppTheme.secondaryColor : (hasCheckedIn ? AppTheme.primaryLight : Colors.grey),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Today's Lesson Delays (if any)
                        if (_todayStatus != null && _todayStatus!.lessonDelays.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBEB), // Amber soft background
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFFDE68A)),
                              boxShadow: const [
                                BoxShadow(color: Color(0x06000000), blurRadius: 12, offset: Offset(0, 3)),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Row(
                                      children: [
                                        Icon(Icons.timer_outlined, size: 18, color: Colors.orange),
                                        SizedBox(width: 6),
                                        Text(
                                          'Сабактардагы кечигүүлөр',
                                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: Color(0xFF92400E)),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Жалпы: ${_todayStatus!.totalLateMinutes} мүнөт',
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                ..._todayStatus!.lessonDelays.map((ld) {
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.orange,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            '${ld.lessonNumber}-сабак',
                                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${ld.delayMinutes} мүнөт кечиккен',
                                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF78350F)),
                                        ),
                                        if (ld.reason != null && ld.reason!.isNotEmpty) ...[
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              '(${ld.reason})',
                                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF92400E), fontStyle: FontStyle.italic),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  );
                                }),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],

                        // Quick Navigation Actions
                        Row(
                          children: [
                            Expanded(
                              child: _buildQuickActionCard(
                                title: 'Каттоо тарыхы',
                                subtitle: 'Айлык көрсөткүч',
                                icon: Icons.insights_rounded,
                                color: AppTheme.primaryColor,
                                onTap: () => context.push('/history'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildQuickActionCard(
                                title: 'Жеке Профиль',
                                subtitle: 'Жөндөөлөр',
                                icon: Icons.account_circle_outlined,
                                color: AppTheme.secondaryColor,
                                onTap: () => context.push('/profile'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
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

  Widget _buildTimeMetric({
    required String title,
    required String time,
    required IconData icon,
    required Color color,
    required String badgeText,
    required Color badgeColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          time,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(
            color: badgeColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            badgeText,
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: badgeColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderColor),
          boxShadow: const [
            BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: color.withValues(alpha: 0.12),
              child: Icon(icon, size: 14, color: color),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppTheme.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 9, color: AppTheme.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
