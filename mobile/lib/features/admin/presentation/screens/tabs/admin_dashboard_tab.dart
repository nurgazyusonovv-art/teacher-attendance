import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../data/repositories/admin_mobile_repository.dart';

enum KpiCategory {
  total,
  checkedIn,
  onTime,
  lateArrival,
  absent,
}

class AdminDashboardTab extends StatefulWidget {
  const AdminDashboardTab({super.key});

  @override
  State<AdminDashboardTab> createState() => _AdminDashboardTabState();
}

class _AdminDashboardTabState extends State<AdminDashboardTab> {
  final AdminMobileRepository _repository = AdminMobileRepository();
  Map<String, dynamic>? _dashboardData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = await _repository.getTodayDashboard();
    if (mounted) {
      setState(() {
        _dashboardData = data;
        _isLoading = false;
      });
    }
  }

  String _formatTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '--:--';
    try {
      final dt = DateTime.parse(isoString);
      return DateFormat('HH:mm').format(dt);
    } catch (_) {
      return isoString.length >= 5 ? isoString.substring(0, 5) : isoString;
    }
  }

  String _formatHeaderDate(DateTime dt) {
    try {
      return DateFormat('d-MMMM yyyy, EEEE', 'ky').format(dt);
    } catch (_) {
      return '${dt.day}.${dt.month}.${dt.year}';
    }
  }

  void _showManualCorrectionDialog(Map<String, dynamic> record) {
    String selectedStatus = record['status'] == 'ABSENT' ? 'EXCUSED' : (record['status'] ?? 'ON_TIME');
    final reasonController = TextEditingController(text: record['correction_reason'] ?? '');
    final checkInController = TextEditingController(
      text: record['check_in_time'] != null ? _formatTime(record['check_in_time']) : '08:00',
    );
    final checkOutController = TextEditingController(
      text: record['check_out_time'] != null ? _formatTime(record['check_out_time']) : '17:00',
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            '${record["teacher_name"] ?? "Мугалим"}\nКатышууну оңдоо',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Статусту тандоо:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedStatus,
                  decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                  items: const [
                    DropdownMenuItem(value: 'ON_TIME', child: Text('Өз убагында')),
                    DropdownMenuItem(value: 'LATE', child: Text('Кечиккен')),
                    DropdownMenuItem(value: 'EXCUSED', child: Text('Себептүү (EXCUSED)')),
                    DropdownMenuItem(value: 'ABSENT', child: Text('Келген жок')),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedStatus = val);
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: checkInController,
                        decoration: const InputDecoration(labelText: 'Келүү (08:00)', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: checkOutController,
                        decoration: const InputDecoration(labelText: 'Кетүү (17:00)', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Оңдоонун себеби * (Аудит)',
                    hintText: 'Мис: Справка тапшырды',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Жокко чыгаруу')),
            ElevatedButton(
              onPressed: () async {
                if (reasonController.text.trim().length < 3) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Оңдоонун себебин жазыңыз!')),
                  );
                  return;
                }
                final dateStr = record['date'] as String;
                final checkInIso = checkInController.text.trim().isNotEmpty ? '${dateStr}T${checkInController.text.trim()}:00' : null;
                final checkOutIso = checkOutController.text.trim().isNotEmpty ? '${dateStr}T${checkOutController.text.trim()}:00' : null;

                final messenger = ScaffoldMessenger.of(context);
                final success = await _repository.manualCorrection(
                  teacherId: record['teacher_id'],
                  targetDate: dateStr,
                  status: selectedStatus,
                  reason: reasonController.text.trim(),
                  checkInTime: checkInIso,
                  checkOutTime: checkOutIso,
                );

                if (ctx.mounted) Navigator.pop(ctx);
                if (success) {
                  _loadData();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Катышуу ийгиликтүү оңдолду!'), backgroundColor: AppTheme.successColor),
                  );
                }
              },
              child: const Text('Сактоо'),
            ),
          ],
        ),
      ),
    );
  }

  // --- KPI DETAIL BOTTOM SHEET ---
  void _showKpiDetailBottomSheet(KpiCategory category) {
    final records = (_dashboardData?['records'] as List? ?? []).cast<Map<String, dynamic>>();

    String title;
    String subtitle;
    IconData icon;
    Color themeColor;
    List<Map<String, dynamic>> filteredList;

    switch (category) {
      case KpiCategory.total:
        title = 'Бардык мугалимдер';
        subtitle = 'Мектепте катталган бардык кызматкерлер';
        icon = Icons.people_alt_rounded;
        themeColor = AppTheme.primaryColor;
        filteredList = records;
        break;

      case KpiCategory.checkedIn:
        title = 'Бүгүн келгендер';
        subtitle = 'QR-код сканерлеп катталган мугалимдер';
        icon = Icons.how_to_reg_rounded;
        themeColor = AppTheme.successColor;
        filteredList = records.where((r) => r['check_in_time'] != null).toList();
        break;

      case KpiCategory.onTime:
        title = 'Өз убагында келгендер';
        subtitle = 'График боюнча кечикпестен келгендер';
        icon = Icons.check_circle_outline_rounded;
        themeColor = AppTheme.successColor;
        filteredList = records.where((r) {
          final hasCheckIn = r['check_in_time'] != null;
          final status = r['status'];
          final lateMins = r['late_minutes'] ?? 0;
          final lessonLate = r['lesson_late_minutes'] ?? 0;
          return hasCheckIn && status == 'ON_TIME' && lateMins == 0 && lessonLate == 0;
        }).toList();
        break;

      case KpiCategory.lateArrival:
        title = 'Кечиккен мугалимдер';
        subtitle = 'Эртең мененки же сабакка кечигүүлөр';
        icon = Icons.alarm_rounded;
        themeColor = Colors.orange;
        filteredList = records.where((r) {
          final status = r['status'];
          final lateMins = r['late_minutes'] ?? 0;
          final lessonLate = r['lesson_late_minutes'] ?? 0;
          final totalLate = r['total_late_minutes'] ?? (lateMins + lessonLate);
          return status == 'LATE' || totalLate > 0;
        }).toList();
        break;

      case KpiCategory.absent:
        title = 'Бүгүн келбегендер';
        subtitle = 'Азырынча QR-код сканерлебеген мугалимдер';
        icon = Icons.person_off_rounded;
        themeColor = AppTheme.errorColor;
        filteredList = records.where((r) => r['check_in_time'] == null || r['status'] == 'ABSENT').toList();
        break;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Drag handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: themeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(icon, color: themeColor, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    title,
                                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: themeColor,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${filteredList.length}',
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
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
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // Teacher List
                Expanded(
                  child: filteredList.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_outline_rounded, size: 48, color: themeColor.withValues(alpha: 0.4)),
                                const SizedBox(height: 12),
                                Text(
                                  category == KpiCategory.absent
                                      ? 'Бардык мугалимдер келишти! 🎉'
                                      : (category == KpiCategory.lateArrival
                                          ? 'Бүгүн кечиккен мугалимдер жок! 👏'
                                          : 'Бул категорияда тизме бош'),
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: filteredList.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final r = filteredList[index];
                            final name = r['teacher_name'] as String? ?? 'Мугалим';
                            final code = r['employee_code'] as String? ?? '';
                            final subject = r['subject'] as String?;
                            final phone = r['phone_number'] as String?;
                            final checkIn = _formatTime(r['check_in_time']);
                            final checkOut = _formatTime(r['check_out_time']);
                            final hasCheckedIn = r['check_in_time'] != null;
                            final status = r['status'] as String? ?? 'ABSENT';
                            final lateMins = r['late_minutes'] as int? ?? 0;
                            final lessonDelays = (r['lesson_delays'] as List? ?? []);
                            final totalLate = r['total_late_minutes'] as int? ?? lateMins;

                            Color badgeColor;
                            String badgeText;

                            if (!hasCheckedIn || status == 'ABSENT') {
                              badgeColor = AppTheme.errorColor;
                              badgeText = 'Келген жок';
                            } else if (status == 'LATE' || totalLate > 0) {
                              badgeColor = Colors.orange;
                              badgeText = 'Кечиккен (+$totalLate мүн)';
                            } else if (status == 'EXCUSED') {
                              badgeColor = Colors.blue;
                              badgeText = 'Себептүү';
                            } else {
                              badgeColor = AppTheme.successColor;
                              badgeText = 'Өз убагында';
                            }

                            return Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: AppTheme.borderColor),
                              ),
                              child: InkWell(
                                onTap: () {
                                  Navigator.pop(ctx);
                                  final item = TeacherItemModel(
                                    id: r['teacher_id'] as String,
                                    userId: '',
                                    schoolId: r['school_id'] as String? ?? '',
                                    fullName: name,
                                    email: '',
                                    username: '',
                                    employeeCode: code,
                                    subject: subject,
                                    phone: phone,
                                    isActive: true,
                                  );
                                  context.push('/admin/teacher-detail', extra: item);
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 20,
                                            backgroundColor: badgeColor.withValues(alpha: 0.15),
                                            child: Text(
                                              name.isNotEmpty ? name[0] : 'М',
                                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: badgeColor),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  name,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                const SizedBox(height: 2),
                                                Wrap(
                                                  spacing: 6,
                                                  children: [
                                                    if (subject != null && subject.isNotEmpty)
                                                      Text(
                                                        subject,
                                                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.primaryColor),
                                                      ),
                                                    if (code.isNotEmpty)
                                                      Text(
                                                        '• Код: $code',
                                                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                                                      ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: badgeColor.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              badgeText,
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: badgeColor),
                                            ),
                                          ),
                                        ],
                                      ),

                                      // Time / Details row
                                      if (hasCheckedIn) ...[
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            const Icon(Icons.login_rounded, size: 13, color: AppTheme.successColor),
                                            const SizedBox(width: 4),
                                            Text('Келүү: $checkIn', style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
                                            const SizedBox(width: 12),
                                            const Icon(Icons.logout_rounded, size: 13, color: AppTheme.secondaryColor),
                                            const SizedBox(width: 4),
                                            Text('Кетүү: $checkOut', style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
                                          ],
                                        ),
                                      ],

                                      // Lesson Delays tags
                                      if (lessonDelays.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: lessonDelays.map((d) {
                                            final num = d['lesson_number'];
                                            final mins = d['delay_minutes'];
                                            return Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                              decoration: BoxDecoration(
                                                color: Colors.orange.withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
                                              ),
                                              child: Text(
                                                '$num-сабак: ${mins}м',
                                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange),
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                      ],

                                      // Phone number (if present and absent)
                                      if (phone != null && phone.isNotEmpty && !hasCheckedIn) ...[
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            const Icon(Icons.phone_outlined, size: 13, color: Color(0xFF64748B)),
                                            const SizedBox(width: 4),
                                            Text(phone, style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                                            const Spacer(),
                                            InkWell(
                                              onTap: () => _showManualCorrectionDialog(r),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: Colors.white,
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(color: AppTheme.borderColor),
                                                ),
                                                child: const Text('Түшүндүрмө / Оңдоо', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final total = _dashboardData?['total_teachers'] ?? 0;
    final checkedIn = _dashboardData?['checked_in_count'] ?? 0;
    final onTime = _dashboardData?['on_time_count'] ?? 0;
    final lateCount = _dashboardData?['late_count'] ?? 0;
    final notCheckedIn = _dashboardData?['not_checked_in_count'] ?? 0;
    final records = (_dashboardData?['records'] as List? ?? []).cast<Map<String, dynamic>>();

    final attendancePercentage = total > 0 ? ((checkedIn / total) * 100).toStringAsFixed(0) : '0';

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        children: [
          // Header Date Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.borderColor),
              boxShadow: const [
                BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 2)),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.event_available_rounded, color: AppTheme.primaryColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatHeaderDate(DateTime.now()),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Катышуу: $attendancePercentage% ($checkedIn / $total мугалим)',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Instruction hint
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Row(
              children: [
                Icon(Icons.touch_app_rounded, size: 14, color: AppTheme.primaryLight),
                SizedBox(width: 4),
                Expanded(
                  child: Text(
                    'Карточкаларды басып, тиешелүү мугалимдерди көрүңүз',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // KPI Grid (5 Interactive Cards with BottomSheet on Tap)
          GridView.count(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 0.95,
            children: [
              _buildInteractiveKpiCard(
                label: 'Жалпы',
                value: '$total',
                icon: Icons.people_alt_outlined,
                color: AppTheme.primaryColor,
                onTap: () => _showKpiDetailBottomSheet(KpiCategory.total),
              ),
              _buildInteractiveKpiCard(
                label: 'Келди',
                value: '$checkedIn',
                icon: Icons.how_to_reg_rounded,
                color: AppTheme.successColor,
                onTap: () => _showKpiDetailBottomSheet(KpiCategory.checkedIn),
              ),
              _buildInteractiveKpiCard(
                label: 'Өз уб.',
                value: '$onTime',
                icon: Icons.check_circle_outline_rounded,
                color: AppTheme.successColor,
                onTap: () => _showKpiDetailBottomSheet(KpiCategory.onTime),
              ),
              _buildInteractiveKpiCard(
                label: 'Кечикти',
                value: '$lateCount',
                icon: Icons.alarm_rounded,
                color: Colors.orange,
                onTap: () => _showKpiDetailBottomSheet(KpiCategory.lateArrival),
              ),
              _buildInteractiveKpiCard(
                label: 'Келген жок',
                value: '$notCheckedIn',
                icon: Icons.person_off_outlined,
                color: AppTheme.errorColor,
                onTap: () => _showKpiDetailBottomSheet(KpiCategory.absent),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Live Teacher Records Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.list_alt_rounded, size: 18, color: AppTheme.primaryColor),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Бүгүнкү келүүлөр тизмеси',
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                child: Text('${records.length} мугалим', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 10),

          if (records.isEmpty)
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: const Center(
                child: Text('Бүгүн азырынча катышуу жазуусу жок', style: TextStyle(color: AppTheme.textSecondary)),
              ),
            )
          else
            ...records.map((r) {
              final status = r['status'] ?? 'ON_TIME';
              Color statusColor = AppTheme.successColor;
              String statusLabel = 'Өз уб.';

              if (status == 'LATE') {
                statusColor = Colors.orange;
                statusLabel = 'Кечиккен';
              } else if (status == 'EXCUSED') {
                statusColor = Colors.blue;
                statusLabel = 'Себептүү';
              } else if (status == 'ABSENT') {
                statusColor = Colors.grey;
                statusLabel = 'Келген жок';
              }

              final checkIn = _formatTime(r['check_in_time']);
              final checkOut = _formatTime(r['check_out_time']);

              return InkWell(
                onTap: () {
                  final item = TeacherItemModel(
                    id: r['teacher_id'] as String,
                    userId: '',
                    schoolId: r['school_id'] as String? ?? '',
                    fullName: r['teacher_name'] as String? ?? 'Мугалим',
                    email: '',
                    username: '',
                    employeeCode: r['employee_code'] as String? ?? '',
                    subject: r['subject'] as String?,
                    phone: r['phone_number'] as String?,
                    isActive: true,
                  );
                  context.push('/admin/teacher-detail', extra: item);
                },
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.borderColor),
                    boxShadow: const [
                      BoxShadow(color: Color(0x04000000), blurRadius: 6, offset: Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: statusColor.withValues(alpha: 0.12),
                        child: Icon(
                          status == 'ABSENT' ? Icons.person_off_rounded : Icons.person_rounded,
                          color: statusColor,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r['teacher_name'] ?? 'Мугалим',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Келүү: $checkIn  •  Кетүү: $checkOut',
                              style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if ((r['late_minutes'] ?? 0) > 0)
                              Text(
                                'Кечигүү: +${r["late_minutes"]} мүнөт',
                                style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 10.5),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              statusLabel,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                            ),
                          ),
                          const SizedBox(height: 4),
                          InkWell(
                            onTap: () => _showManualCorrectionDialog(r),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppTheme.borderColor),
                              ),
                              child: const Text('Оңдоо', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppTheme.primaryColor)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildInteractiveKpiCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.borderColor),
            boxShadow: const [
              BoxShadow(color: Color(0x04000000), blurRadius: 6, offset: Offset(0, 2)),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 16, color: color),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 9, color: Color(0xFF94A3B8)),
                ],
              ),
              const SizedBox(height: 3),
              Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
              const SizedBox(height: 1),
              Text(
                label,
                style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
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
