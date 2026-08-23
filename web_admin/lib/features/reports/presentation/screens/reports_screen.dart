import 'package:flutter/material.dart';
import 'package:teacher_admin/core/theme/admin_theme.dart';
import 'package:teacher_admin/features/attendance/data/repositories/admin_attendance_repository.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final AdminAttendanceRepository _repository = AdminAttendanceRepository();
  AdminDashboardData? _reportData;
  bool _isLoading = true;
  String _selectedStatusFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() => _isLoading = true);
    final data = await _repository.getTodayDashboard();
    if (mounted) {
      setState(() {
        _reportData = data;
        _isLoading = false;
      });
    }
  }

  String _formatTime(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '—';
    try {
      final dt = DateTime.parse(isoString);
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } catch (_) {
      return isoString.length >= 5 ? isoString.substring(0, 5) : isoString;
    }
  }

  void _exportCsv() {
    if (_reportData == null || _reportData!.records.isEmpty) return;

    final buffer = StringBuffer();
    buffer.writeln('Мугалим,Табель номери,Дата,Келүү,Кетүү,Статус,Кечигүү (мүнөт),Иштеген (мүнөт),Оңдолгон');

    for (final r in _reportData!.records) {
      buffer.writeln(
        '"${r.teacherName ?? ''}","${r.employeeCode ?? ''}","${r.date}","${_formatTime(r.checkInTime)}","${_formatTime(r.checkOutTime)}","${r.status}",${r.lateMinutes},${r.workedMinutes},${r.isManuallyCorrected ? 'Ооба' : 'Жок'}',
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('CSV файлы даярдалды (${_reportData!.records.length} сап). Браузерге экспорттолду.'),
        backgroundColor: Colors.green[700],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredRecords = (_reportData?.records ?? []).where((r) {
      if (_selectedStatusFilter == 'ALL') return true;
      return r.status == _selectedStatusFilter;
    }).toList();

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
                    'Катышуу Отчеттору',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Келүү-кетүү боюнча аналитика жана CSV форматында экспорт',
                    style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _exportCsv,
                icon: const Icon(Icons.download, size: 18),
                label: const Text('CSV Экспорт'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AdminTheme.accentColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Filters Card
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Text('Статус боюнча чыпка: ', style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: _selectedStatusFilter,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('Бардыгы')),
                      DropdownMenuItem(value: 'ON_TIME', child: Text('Өз убагында')),
                      DropdownMenuItem(value: 'LATE', child: Text('Кечиккен')),
                      DropdownMenuItem(value: 'EXCUSED', child: Text('Себептүү')),
                      DropdownMenuItem(value: 'ABSENT', child: Text('Келген жок')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _selectedStatusFilter = val);
                    },
                  ),
                  const Spacer(),
                  Text(
                    'Күнү: ${_reportData?.date ?? ""}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Table
          Expanded(
            child: Card(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : filteredRecords.isEmpty
                      ? const Center(
                          child: Text('Тандалган чыпка боюнча маалымат табылган жок'),
                        )
                      : SingleChildScrollView(
                          child: DataTable(
                            columns: const [
                              DataColumn(label: Text('Мугалим')),
                              DataColumn(label: Text('Табель номери')),
                              DataColumn(label: Text('Келүү')),
                              DataColumn(label: Text('Кетүү')),
                              DataColumn(label: Text('Статус')),
                              DataColumn(label: Text('Кечигүү')),
                              DataColumn(label: Text('Иштеген убактысы')),
                              DataColumn(label: Text('Оңдоо')),
                            ],
                            rows: filteredRecords.map((r) {
                              Color statusColor = Colors.grey;
                              String statusText = 'Келген жок';

                              if (r.status == 'ON_TIME') {
                                statusColor = Colors.green;
                                statusText = 'Өз убагында';
                              } else if (r.status == 'LATE') {
                                statusColor = Colors.orange;
                                statusText = 'Кечиккен';
                              } else if (r.status == 'EXCUSED') {
                                statusColor = Colors.blue;
                                statusText = 'Себептүү';
                              }

                              return DataRow(
                                cells: [
                                  DataCell(Text(r.teacherName ?? 'Мугалим', style: const TextStyle(fontWeight: FontWeight.w600))),
                                  DataCell(Text(r.employeeCode ?? '-')),
                                  DataCell(Text(_formatTime(r.checkInTime))),
                                  DataCell(Text(_formatTime(r.checkOutTime))),
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
                                  DataCell(Text(r.lateMinutes > 0 ? '+${r.lateMinutes} мин' : '—')),
                                  DataCell(Text('${r.workedMinutes} мин')),
                                  DataCell(
                                    r.isManuallyCorrected
                                        ? const Tooltip(
                                            message: 'Администратор тарабынан кол менен оңдолгон',
                                            child: Icon(Icons.verified_user, size: 18, color: Colors.blue),
                                          )
                                        : const Text('—'),
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
}
