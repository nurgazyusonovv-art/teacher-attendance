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

  String _formatHeaderDate(DateTime dt) {
    try {
      return DateFormat('d-MMMM yyyy, EEEE', 'ky').format(dt);
    } catch (_) {
      return '${dt.day}.${dt.month}.${dt.year}';
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

  void _showManualCorrectionDialog(Map<String, dynamic> record) {
    String selectedStatus = record['status'] == 'ABSENT' ? 'EXCUSED' : record['status'];
    final reasonController = TextEditingController();
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
          title: Text('${record["teacher_name"] ?? "Мугалим"} — Оңдоо'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Статусту тандоо:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedStatus,
                  decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
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
                if (reasonController.text.trim().length < 4) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Оңдоонун себебин жазыңыз!')),
                  );
                  return;
                }
                final dateStr = record['date'] as String;
                final checkInIso = checkInController.text.trim().isNotEmpty ? '${dateStr}T${checkInController.text.trim()}:00' : null;
                final checkOutIso = checkOutController.text.trim().isNotEmpty ? '${dateStr}T${checkOutController.text.trim()}:00' : null;

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

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Header Date
          Text(
            'Бүгүнкү дата: ${_formatHeaderDate(DateTime.now())}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 12),

          // KPI Grid (5 Cards)
          GridView.count(
            crossAxisCount: 3,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.2,
            children: [
              _buildKpiCard('Жалпы', '$total', Icons.people, AppTheme.primaryColor),
              _buildKpiCard('Келди', '$checkedIn', Icons.login, AppTheme.successColor),
              _buildKpiCard('Өз убагында', '$onTime', Icons.check_circle, AppTheme.successColor),
              _buildKpiCard('Кечикти', '$lateCount', Icons.timer, Colors.orange),
              _buildKpiCard('Келген жок', '$notCheckedIn', Icons.person_off, AppTheme.errorColor),
            ],
          ),
          const SizedBox(height: 20),

          // Live Teacher Records Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Келүүлөр тизмеси',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              ),
              Text('${records.length} мугалим', style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),

          if (records.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Center(child: Text('Азырынча эч ким каттала элек')),
              ),
            )
          else
            ...records.map((r) {
              final status = r['status'] as String? ?? 'ABSENT';
              Color statusColor = AppTheme.successColor;
              String statusLabel = 'Өз убагында';

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

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
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
                  leading: CircleAvatar(
                    backgroundColor: statusColor.withValues(alpha: 0.15),
                    child: Icon(
                      status == 'ABSENT' ? Icons.person_off : Icons.person,
                      color: statusColor,
                    ),
                  ),
                  title: Text(
                    r['teacher_name'] ?? 'Мугалим',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text('Келүү: $checkIn  •  Кетүү: $checkOut ($statusLabel)'),
                      if ((r['late_minutes'] ?? 0) > 0)
                        Text(
                          'Кечигүү: +${r["late_minutes"]} мүнөт',
                          style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                    ],
                  ),
                  trailing: OutlinedButton(
                    onPressed: () => _showManualCorrectionDialog(r),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    child: const Text('Оңдоо', style: TextStyle(fontSize: 12)),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
            Text(title, style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)), textAlign: TextAlign.center, maxLines: 1),
          ],
        ),
      ),
    );
  }
}
