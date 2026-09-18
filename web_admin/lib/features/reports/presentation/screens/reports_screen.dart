import 'package:flutter/material.dart';
import 'package:teacher_admin/features/attendance/presentation/widgets/attendance_details.dart';
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
  int _days = 1;
  int _request = 0;
  bool _failed = false;
  List<AdminDailyAttendanceItem> _records = [];

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  Future<void> _loadReport() async {
    final request = ++_request;
    final days = _days;
    setState(() {
      _isLoading = true;
      _failed = false;
    });
    try {
      final data = await _repository.getTodayDashboard();
      if (data == null) throw StateError('Unavailable');
      final end = DateTime.parse(data.date);
      // days == 0 means the whole stored history; otherwise the server
      // narrows the period so the client never pulls every record.
      final start = days == 0 ? null : end.subtract(Duration(days: days - 1));
      final records = days == 1
          ? data.records
          : await _repository.getReportHistory(start: start, end: end);
      if (!mounted || request != _request) return;
      setState(() {
        _reportData = data;
        _records = records;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || request != _request) return;
      setState(() {
        _failed = true;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredRecords = _records.where((r) {
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
                    'Келүү-кетүү боюнча күндүк жана мезгилдик отчеттор',
                    style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _loadReport,
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final entry in const {
                1: 'Бүгүн',
                7: 'Бир жума',
                30: 'Бир ай',
                0: 'Баары',
              }.entries)
                ChoiceChip(
                  label: Text(entry.value),
                  selected: _days == entry.key,
                  onSelected: (_) {
                    setState(() => _days = entry.key);
                    _loadReport();
                  },
                ),
            ],
          ),
          if (_days != 1)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Сакталган каттоолор көрсөтүлөт; катталбаган күндөр автоматтык түрдө «Келген жок» деп эсептелбейт.',
              ),
            ),

          // Filters Card
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Wrap(
                spacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'Статус боюнча чыпка: ',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: _selectedStatusFilter,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('Бардыгы')),
                      DropdownMenuItem(
                        value: 'ON_TIME',
                        child: Text('Өз убагында'),
                      ),
                      DropdownMenuItem(value: 'LATE', child: Text('Кечиккен')),
                      DropdownMenuItem(
                        value: 'EXCUSED',
                        child: Text('Себептүү'),
                      ),
                      DropdownMenuItem(
                        value: 'ABSENT',
                        child: Text('Келген жок'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedStatusFilter = val);
                      }
                    },
                  ),
                  Text(
                    '${_days == 0
                        ? "Бардык тарых"
                        : _days == 1
                        ? "Бүгүн"
                        : "Акыркы $_days күн"} • ${_reportData?.date ?? ""} • ${_isLoading ? "…" : filteredRecords.length} жазуу',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF64748B),
                    ),
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
                  : _failed
                  ? Center(
                      child: TextButton(
                        onPressed: _loadReport,
                        child: const Text('Отчет жүктөлгөн жок. Кайра жүктөө'),
                      ),
                    )
                  : filteredRecords.isEmpty
                  ? const Center(
                      child: Text(
                        'Тандалган чыпка боюнча маалымат табылган жок',
                      ),
                    )
                  : AttendanceDetails(records: filteredRecords),
            ),
          ),
        ],
      ),
    );
  }
}
