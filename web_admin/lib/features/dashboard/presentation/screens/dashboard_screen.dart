import 'package:flutter/material.dart';
import 'package:teacher_admin/core/theme/admin_theme.dart';
import 'package:teacher_admin/features/attendance/data/repositories/admin_attendance_repository.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final AdminAttendanceRepository _repository = AdminAttendanceRepository();
  AdminDashboardData? _data;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);
    final data = await _repository.getTodayDashboard();
    if (mounted) {
      setState(() {
        _data = data;
        _isLoading = false;
      });
    }
  }

  String _formatTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '--:--';
    try {
      final dt = DateTime.parse(isoString);
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } catch (_) {
      return isoString.length >= 5 ? isoString.substring(0, 5) : isoString;
    }
  }

  void _showManualCorrectionDialog(AdminDailyAttendanceItem record) {
    String selectedStatus = record.status == 'ABSENT' ? 'EXCUSED' : record.status;
    final reasonController = TextEditingController();
    final checkInController = TextEditingController(
      text: record.checkInTime != null ? _formatTime(record.checkInTime) : '08:00',
    );
    final checkOutController = TextEditingController(
      text: record.checkOutTime != null ? _formatTime(record.checkOutTime) : '17:00',
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text('${record.teacherName ?? "Мугалим"} — Катышууну оңдоо'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Статусту тандоо:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedStatus,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'ON_TIME', child: Text('Өз убагында (ON_TIME)')),
                      DropdownMenuItem(value: 'LATE', child: Text('Кечиккен (LATE)')),
                      DropdownMenuItem(value: 'EXCUSED', child: Text('Себептүү / Кечирилген (EXCUSED)')),
                      DropdownMenuItem(value: 'ABSENT', child: Text('Келген жок (ABSENT)')),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedStatus = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: checkInController,
                          decoration: const InputDecoration(
                            labelText: 'Келүү убактысы',
                            hintText: '08:00',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: checkOutController,
                          decoration: const InputDecoration(
                            labelText: 'Кетүү убактысы',
                            hintText: '17:00',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: reasonController,
                    decoration: const InputDecoration(
                      labelText: 'Оңдоонун себеби * (Audit Trail)',
                      hintText: 'Мис: Ооруп жаткандыгы тууралуу справка тапшырды',
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Жокко чыгаруу'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (reasonController.text.trim().length < 4) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Сураныч, оңдоонун себебин жазыңыз!')),
                  );
                  return;
                }

                String? checkInIso;
                String? checkOutIso;
                final dateStr = record.date;

                if (checkInController.text.trim().isNotEmpty) {
                  checkInIso = '${dateStr}T${checkInController.text.trim()}:00';
                }
                if (checkOutController.text.trim().isNotEmpty) {
                  checkOutIso = '${dateStr}T${checkOutController.text.trim()}:00';
                }

                final success = await _repository.manualCorrection(
                  teacherId: record.teacherId,
                  targetDate: record.date,
                  status: selectedStatus,
                  reason: reasonController.text.trim(),
                  checkInTime: checkInIso,
                  checkOutTime: checkOutIso,
                );

                if (ctx.mounted) Navigator.pop(ctx);
                if (success) {
                  _loadDashboard();
                }
              },
              child: const Text('Сактоо жана Каттоо'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Бүгүнкү катышуу дашборду',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Реалдуу убакыттагы мугалимдердин келүү-кетүү абалы',
                    style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _loadDashboard,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Жаңылоо'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminTheme.accentColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // KPI Grid
          GridView.count(
            crossAxisCount: 5,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 2.2,
            children: [
              _buildKpiCard('Жалпы мугалим', '${_data?.totalTeachers ?? 0}', Icons.people, AdminTheme.accentColor),
              _buildKpiCard('Келди (Check-in)', '${_data?.checkedInCount ?? 0}', Icons.login, AdminTheme.successColor),
              _buildKpiCard('Өз убагында', '${_data?.onTimeCount ?? 0}', Icons.check_circle_outline, AdminTheme.successColor),
              _buildKpiCard('Кечикти', '${_data?.lateCount ?? 0}', Icons.timer_outlined, AdminTheme.warningColor),
              _buildKpiCard('Келген жок', '${_data?.notCheckedInCount ?? 0}', Icons.person_off_outlined, AdminTheme.errorColor),
            ],
          ),
          const SizedBox(height: 24),

          // Table
          Expanded(
            child: Card(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _data == null || _data!.records.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.inbox_outlined, size: 48, color: Color(0xFF94A3B8)),
                              SizedBox(height: 8),
                              Text(
                                'Бүгүн азырынча мугалимдердин тизмеси бош',
                                style: TextStyle(color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Мугалим')),
                              DataColumn(label: Text('Табель номери')),
                              DataColumn(label: Text('Келүү убактысы')),
                              DataColumn(label: Text('Кетүү убактысы')),
                              DataColumn(label: Text('Статус')),
                              DataColumn(label: Text('Кечигүү')),
                              DataColumn(label: Text('Аракеттер')),
                            ],
                            rows: _data!.records.map((record) {
                              Color statusColor = Colors.grey;
                              String statusText = 'Келген жок';

                              if (record.status == 'ON_TIME') {
                                statusColor = Colors.green;
                                statusText = 'Өз убагында';
                              } else if (record.status == 'LATE') {
                                statusColor = Colors.orange;
                                statusText = 'Кечиккен';
                              } else if (record.status == 'EXCUSED') {
                                statusColor = Colors.blue;
                                statusText = 'Себептүү';
                              }

                              return DataRow(
                                cells: [
                                  DataCell(
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 14,
                                          backgroundColor: AdminTheme.accentColor.withValues(alpha: 0.1),
                                          child: Text(
                                            (record.teacherName?.isNotEmpty ?? false)
                                                ? record.teacherName![0]
                                                : 'М',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AdminTheme.accentColor),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(record.teacherName ?? 'Мугалим', style: const TextStyle(fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                  DataCell(Text(record.employeeCode ?? '-')),
                                  DataCell(Text(_formatTime(record.checkInTime))),
                                  DataCell(Text(_formatTime(record.checkOutTime))),
                                  DataCell(
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        statusText,
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor),
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    Text(
                                      record.lateMinutes > 0 ? '+${record.lateMinutes} мин' : '—',
                                      style: TextStyle(
                                        fontWeight: record.lateMinutes > 0 ? FontWeight.bold : FontWeight.normal,
                                        color: record.lateMinutes > 0 ? Colors.orange : Colors.grey,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    OutlinedButton.icon(
                                      onPressed: () => _showManualCorrectionDialog(record),
                                      icon: const Icon(Icons.edit_note, size: 16),
                                      label: const Text('Оңдоо'),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: color.withValues(alpha: 0.1),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
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
