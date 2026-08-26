import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../data/repositories/admin_mobile_repository.dart';
import 'tabs/admin_analytics_tab.dart';
import 'tabs/admin_dashboard_tab.dart';
import 'tabs/admin_schedules_tab.dart';
import 'tabs/admin_teachers_tab.dart';

class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  final AdminMobileRepository _repository = AdminMobileRepository();
  int _currentIndex = 0;

  final List<Widget> _tabs = const [
    AdminDashboardTab(),
    AdminTeachersTab(),
    AdminSchedulesTab(),
    AdminAnalyticsTab(),
  ];

  final List<String> _titles = const [
    'Админ Дашборд',
    'Мугалимдерди башкаруу',
    'Жумуш Графиктери',
    'Аналитика & Отчет',
  ];

  // --- QUICK ACTIONS BOTTOM SHEET ---
  void _showQuickActionsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              const Row(
                children: [
                  Icon(Icons.add_circle_outline_rounded, color: AppTheme.primaryColor, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'Ыкчам аракеттер',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Action 1: Add New Teacher
              _buildActionCard(
                icon: Icons.person_add_alt_1_rounded,
                iconBg: AppTheme.primaryColor.withValues(alpha: 0.12),
                iconColor: AppTheme.primaryColor,
                title: 'Жаңы мугалим кошуу',
                subtitle: 'Аты-жөнү, предмети жана коду менен каттоо',
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/admin/add-teacher');
                },
              ),
              const SizedBox(height: 12),

              // Action 2: Record Lesson Delay
              _buildActionCard(
                icon: Icons.alarm_add_rounded,
                iconBg: Colors.orange.withValues(alpha: 0.12),
                iconColor: Colors.orange,
                title: 'Сабакка кечигүү белгилөө',
                subtitle: 'Каалаган мугалимге сабак боюнча кечигүү жазуу',
                onTap: () {
                  Navigator.pop(ctx);
                  _showQuickLessonDelayModal();
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Color(0xFF94A3B8)),
            ],
          ),
        ),
      ),
    );
  }

  // --- QUICK LESSON DELAY MODAL (Choose Teacher & Record Delay) ---
  void _showQuickLessonDelayModal() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    final teachers = await _repository.getTeachers();
    if (mounted) Navigator.pop(context); // close loader

    if (!mounted) return;
    if (teachers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Катталган мугалимдер табылган жок')),
      );
      return;
    }

    TeacherItemModel? selectedTeacher = teachers.first;
    int selectedLesson = 1;
    int selectedMinutes = 10;
    final reasonController = TextEditingController();
    DateTime pickedDate = DateTime.now();
    final customMinutesController = TextEditingController(text: '10');

    final presetMinutes = [5, 10, 15, 20, 30, 45];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),

                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.alarm_add_rounded, color: Colors.orange, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Сабакка кечигүү белгилөө',
                            style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Мугалимди тандап, кечигүүнү жазыңыз',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Teacher Selector Dropdown
                const Text('Мугалимди тандоо *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
                const SizedBox(height: 6),
                DropdownButtonFormField<TeacherItemModel>(
                  value: selectedTeacher,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.person_rounded, color: AppTheme.primaryColor),
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  isExpanded: true,
                  items: teachers.map((t) {
                    final subj = t.subject != null && t.subject!.isNotEmpty ? ' (${t.subject})' : '';
                    return DropdownMenuItem(
                      value: t,
                      child: Text(
                        '${t.fullName}$subj',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedTeacher = val);
                  },
                ),
                const SizedBox(height: 14),

                // Date Picker
                const Text('Күнү *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: pickedDate,
                      firstDate: DateTime(2025),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                    );
                    if (picked != null) {
                      setModalState(() => pickedDate = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, size: 18, color: AppTheme.primaryColor),
                        const SizedBox(width: 10),
                        Text(
                          DateFormat('d-MMMM yyyy (EEEE)', 'ky').format(pickedDate),
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                        ),
                        const Spacer(),
                        const Text('Өзгөртүү', style: TextStyle(fontSize: 12, color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Lesson Number (1-8)
                const Text('Канчанчы сабак? *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: List.generate(8, (i) {
                    final lessonNum = i + 1;
                    final isSel = selectedLesson == lessonNum;
                    return InkWell(
                      onTap: () => setModalState(() => selectedLesson = lessonNum),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: isSel ? Colors.orange : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isSel ? Colors.orange : AppTheme.borderColor),
                        ),
                        child: Text(
                          '$lessonNum-сабак',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                            color: isSel ? Colors.white : AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 14),

                // Delay Minutes
                const Text('Канча минута кечикти? *', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: presetMinutes.map((mins) {
                    final isSel = selectedMinutes == mins;
                    return InkWell(
                      onTap: () {
                        setModalState(() {
                          selectedMinutes = mins;
                          customMinutesController.text = mins.toString();
                        });
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSel ? Colors.orange : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isSel ? Colors.orange : AppTheme.borderColor),
                        ),
                        child: Text(
                          '$mins мүн',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                            color: isSel ? Colors.white : AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: customMinutesController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Кечигүү мүнөтү',
                    prefixIcon: Icon(Icons.timelapse_rounded),
                  ),
                  onChanged: (val) {
                    final parsed = int.tryParse(val);
                    if (parsed != null) setModalState(() => selectedMinutes = parsed);
                  },
                ),
                const SizedBox(height: 14),

                // Reason input
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Себеби / Эскертүү (кааласаңыз)',
                    hintText: 'Мис: Тыгында калды, чакыруу болду',
                    prefixIcon: Icon(Icons.note_alt_outlined),
                  ),
                ),
                const SizedBox(height: 20),

                // Save button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                    ),
                    onPressed: () async {
                      if (selectedTeacher == null) return;
                      final mins = int.tryParse(customMinutesController.text.trim()) ?? selectedMinutes;
                      if (mins <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Кечигүү мүнөтүн туура жазыңыз!'), backgroundColor: Colors.red),
                        );
                        return;
                      }

                      final dateStr = DateFormat('yyyy-MM-dd').format(pickedDate);
                      final messenger = ScaffoldMessenger.of(context);

                      final (ok, err) = await _repository.addLessonDelay(
                        teacherId: selectedTeacher!.id,
                        date: dateStr,
                        lessonNumber: selectedLesson,
                        delayMinutes: mins,
                        reason: reasonController.text.trim().isNotEmpty ? reasonController.text.trim() : null,
                      );

                      if (ctx.mounted) Navigator.pop(ctx);
                      if (ok) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('${selectedTeacher!.fullName}: $selectedLesson-сабакка $mins мүнөт кечигүү сакталды!'),
                            backgroundColor: AppTheme.successColor,
                          ),
                        );
                      } else {
                        messenger.showSnackBar(
                          SnackBar(content: Text(err ?? 'Кечигүүнү сактоодо ката кетти'), backgroundColor: Colors.red),
                        );
                      }
                    },
                    child: const Text('Кечигүүнү сактоо', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 14, top: 8, bottom: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset('assets/images/app_logo.png', fit: BoxFit.cover),
          ),
        ),
        title: Text(_titles[_currentIndex]),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
              ),
              child: const Icon(Icons.qr_code_rounded, color: AppTheme.primaryColor, size: 18),
            ),
            tooltip: 'Мектептин QR-коду',
            onPressed: () => context.push('/admin/qr-code'),
          ),
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: const Icon(Icons.logout_rounded, color: AppTheme.errorColor, size: 18),
            ),
            tooltip: 'Чыгуу',
            onPressed: () {
              showDialog(
                context: context,
                builder: (dialogCtx) => AlertDialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  title: const Text('Чыгуу', style: TextStyle(fontWeight: FontWeight.bold)),
                  content: const Text('Чын эле администратор аккаунтунан чыгууну каалайсызбы?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogCtx),
                      child: const Text('Жок'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(dialogCtx);
                        context.read<AuthCubit>().logout();
                        context.go('/login');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.errorColor,
                        minimumSize: const Size(90, 42),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Чыгуу'),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _tabs,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppTheme.borderColor.withValues(alpha: 0.8), width: 1)),
          boxShadow: const [
            BoxShadow(color: Color(0x08000000), blurRadius: 16, offset: Offset(0, -4)),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // 1. Dashboard Tab
                _buildNavItem(
                  index: 0,
                  icon: Icons.dashboard_outlined,
                  activeIcon: Icons.dashboard_rounded,
                  label: 'Дашборд',
                ),

                // 2. Teachers Tab
                _buildNavItem(
                  index: 1,
                  icon: Icons.people_outline_rounded,
                  activeIcon: Icons.people_rounded,
                  label: 'Мугалимдер',
                ),

                // 3. CENTER PLUS (+) ACTION BUTTON
                GestureDetector(
                  onTap: _showQuickActionsBottomSheet,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primaryColor, AppTheme.primaryLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryColor.withValues(alpha: 0.35),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
                  ),
                ),

                // 4. Schedules Tab
                _buildNavItem(
                  index: 2,
                  icon: Icons.schedule_outlined,
                  activeIcon: Icons.schedule_rounded,
                  label: 'Графиктер',
                ),

                // 5. Analytics Tab
                _buildNavItem(
                  index: 3,
                  icon: Icons.analytics_outlined,
                  activeIcon: Icons.analytics_rounded,
                  label: 'Аналитика',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? AppTheme.primaryColor : const Color(0xFF64748B);

    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 4.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isSelected ? activeIcon : icon, color: color, size: 22),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: color,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
