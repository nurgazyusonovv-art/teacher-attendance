import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../data/repositories/admin_mobile_repository.dart';

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
    final records = (_dashboardData?['records'] as List? ?? []);

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

          // KPI Grid (5 Cards)
          GridView.count(
            crossAxisCount: 3,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 0.95,
            children: [
              _buildKpiCard('Жалпы', '$total', Icons.people_alt_outlined, AppTheme.primaryColor),
              _buildKpiCard('Келди', '$checkedIn', Icons.how_to_reg_rounded, AppTheme.successColor),
              _buildKpiCard('Өз уб.', '$onTime', Icons.check_circle_outline_rounded, AppTheme.successColor),
              _buildKpiCard('Кечикти', '$lateCount', Icons.alarm_rounded, Colors.orange),
              _buildKpiCard('Келген жок', '$notCheckedIn', Icons.person_off_outlined, AppTheme.errorColor),
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

  Widget _buildKpiCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderColor),
        boxShadow: const [
          BoxShadow(color: Color(0x04000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 3),
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 1),
          Text(
            label,
            style: const TextStyle(fontSize: 9.5, color: AppTheme.textSecondary),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
