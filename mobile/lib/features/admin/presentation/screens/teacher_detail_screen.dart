import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/repositories/admin_mobile_repository.dart';

class TeacherDetailScreen extends StatefulWidget {
  final TeacherItemModel teacher;

  const TeacherDetailScreen({super.key, required this.teacher});

  @override
  State<TeacherDetailScreen> createState() => _TeacherDetailScreenState();
}

class _TeacherDetailScreenState extends State<TeacherDetailScreen> with SingleTickerProviderStateMixin {
  final AdminMobileRepository _repository = AdminMobileRepository();
  late TabController _tabController;
  late bool _isActive;

  // Schedules state
  List<WorkScheduleItemModel> _teacherSchedules = [];
  bool _isLoadingSchedules = true;

  // History & Statistics state
  List<Map<String, dynamic>> _historyRecords = [];
  bool _isLoadingHistory = true;
  final DateTime _selectedMonth = DateTime.now();

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
    _tabController = TabController(length: 2, vsync: this);
    _isActive = widget.teacher.isActive;
    _loadTeacherSchedules();
    _loadTeacherHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTeacherSchedules() async {
    setState(() => _isLoadingSchedules = true);
    final list = await _repository.getTeacherSchedules(teacherId: widget.teacher.id);
    if (mounted) {
      setState(() {
        _teacherSchedules = list;
        _isLoadingSchedules = false;
      });
    }
  }

  Future<void> _loadTeacherHistory() async {
    setState(() => _isLoadingHistory = true);
    final list = await _repository.getTeacherHistory(
      teacherId: widget.teacher.id,
      year: _selectedMonth.year,
      month: _selectedMonth.month,
    );
    if (mounted) {
      setState(() {
        _historyRecords = list;
        _isLoadingHistory = false;
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

  void _showEditScheduleDialog(int dayIdx) {
    final existing = _teacherSchedules.firstWhere(
      (s) => s.dayOfWeek == dayIdx,
      orElse: () => WorkScheduleItemModel(dayOfWeek: dayIdx, graceMinutes: 15, isDayOff: dayIdx == 6),
    );

    TimeOfDay startTime = const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 17, minute: 0);
    int graceMinutes = existing.graceMinutes;
    bool isDayOff = existing.isDayOff;

    if (existing.startTime != null) {
      final parts = existing.startTime!.split(':');
      startTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }
    if (existing.endTime != null) {
      final parts = existing.endTime!.split(':');
      endTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }

    final graceController = TextEditingController(text: graceMinutes.toString());

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('${_dayNames[dayIdx]} жеке графиги', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  title: const Text('Дем алыш күн (Day Off)', style: TextStyle(fontWeight: FontWeight.w600)),
                  value: isDayOff,
                  contentPadding: EdgeInsets.zero,
                  activeTrackColor: AppTheme.primaryColor.withValues(alpha: 0.5),
                  activeThumbColor: AppTheme.primaryColor,
                  onChanged: (val) => setModalState(() => isDayOff = val),
                ),
                if (!isDayOff) ...[
                  const Divider(),
                  ListTile(
                    title: const Text('Келүү убактысы'),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                      child: Text('${startTime.hour.toString().padLeft(2, "0")}:${startTime.minute.toString().padLeft(2, "0")}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                    ),
                    contentPadding: EdgeInsets.zero,
                    onTap: () async {
                      final picked = await showTimePicker(context: context, initialTime: startTime);
                      if (picked != null) setModalState(() => startTime = picked);
                    },
                  ),
                  ListTile(
                    title: const Text('Кетүү убактысы'),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFEFF6FF), borderRadius: BorderRadius.circular(8)),
                      child: Text('${endTime.hour.toString().padLeft(2, "0")}:${endTime.minute.toString().padLeft(2, "0")}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                    ),
                    contentPadding: EdgeInsets.zero,
                    onTap: () async {
                      final picked = await showTimePicker(context: context, initialTime: endTime);
                      if (picked != null) setModalState(() => endTime = picked);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: graceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Жеңилдик убактысы (мүнөт)',
                      hintText: '15',
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Жокко чыгаруу')),
            ElevatedButton(
              onPressed: () async {
                final startStr = isDayOff ? null : '${startTime.hour.toString().padLeft(2, "0")}:${startTime.minute.toString().padLeft(2, "0")}:00';
                final endStr = isDayOff ? null : '${endTime.hour.toString().padLeft(2, "0")}:${endTime.minute.toString().padLeft(2, "0")}:00';
                final grace = int.tryParse(graceController.text.trim()) ?? 15;

                final schedule = WorkScheduleItemModel(
                  id: existing.id,
                  dayOfWeek: dayIdx,
                  startTime: startStr,
                  endTime: endStr,
                  graceMinutes: grace,
                  isDayOff: isDayOff,
                );

                final messenger = ScaffoldMessenger.of(context);
                final success = await _repository.saveTeacherSchedule(
                  teacherId: widget.teacher.id,
                  schedule: schedule,
                );
                if (ctx.mounted) Navigator.pop(ctx);
                if (success) {
                  _loadTeacherSchedules();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Жеке график сакталды!'), backgroundColor: AppTheme.successColor),
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

  void _resetToDefaultSchedule(String scheduleId) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await _repository.deleteTeacherSchedule(scheduleId);
    if (ok) {
      _loadTeacherSchedules();
      messenger.showSnackBar(
        const SnackBar(content: Text('Мектептин жалпы графигине кайтарылды!'), backgroundColor: AppTheme.successColor),
      );
    }
  }

  void _showExcuseReplyDialog(Map<String, dynamic> record) {
    String selectedStatus = record['status'] == 'ABSENT' ? 'EXCUSED' : (record['status'] as String? ?? 'ON_TIME');
    final reasonController = TextEditingController(text: record['correction_reason'] as String? ?? '');
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
          title: Text('${record["date"]}\nТүшүндүрмө / Катышууну оңдоо', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Статус коюу:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: selectedStatus,
                  decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                  items: const [
                    DropdownMenuItem(value: 'EXCUSED', child: Text('Себептүү (EXCUSED) - Кабыл алуу')),
                    DropdownMenuItem(value: 'ON_TIME', child: Text('Өз убагында')),
                    DropdownMenuItem(value: 'LATE', child: Text('Кечиккен')),
                    DropdownMenuItem(value: 'ABSENT', child: Text('Себепсиз келген жок')),
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
                    labelText: 'Түшүндүрмө же Админдин жообу *',
                    hintText: 'Мис: Справка көрсөттү, кабыл алынды',
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
                    const SnackBar(content: Text('Жооптун же себептин текстин жазыңыз!')),
                  );
                  return;
                }
                final dateStr = record['date'] as String;
                final checkInIso = checkInController.text.trim().isNotEmpty ? '${dateStr}T${checkInController.text.trim()}:00' : null;
                final checkOutIso = checkOutController.text.trim().isNotEmpty ? '${dateStr}T${checkOutController.text.trim()}:00' : null;

                final messenger = ScaffoldMessenger.of(context);
                final success = await _repository.manualCorrection(
                  teacherId: widget.teacher.id,
                  targetDate: dateStr,
                  status: selectedStatus,
                  reason: reasonController.text.trim(),
                  checkInTime: checkInIso,
                  checkOutTime: checkOutIso,
                );

                if (ctx.mounted) Navigator.pop(ctx);
                if (success) {
                  _loadTeacherHistory();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Жооп жана статус ийгиликтүү сакталды!'), backgroundColor: AppTheme.successColor),
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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(widget.teacher.fullName, maxLines: 1, overflow: TextOverflow.ellipsis),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primaryColor,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.schedule_rounded), text: 'Жеке График'),
            Tab(icon: Icon(Icons.analytics_rounded), text: 'Статистика & Тарых'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Teacher Header Info Card
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                  child: Text(
                    widget.teacher.fullName.isNotEmpty ? widget.teacher.fullName[0] : 'М',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.teacher.fullName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Wrap(
                        spacing: 6,
                        runSpacing: 2,
                        children: [
                          Text('Код: ${widget.teacher.employeeCode}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11.5)),
                          Text('•  Логин: ${widget.teacher.username}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11.5)),
                        ],
                      ),
                      if (widget.teacher.phone != null && widget.teacher.phone!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text('Тел: ${widget.teacher.phone}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(
                      value: _isActive,
                      activeTrackColor: AppTheme.successColor.withValues(alpha: 0.5),
                      activeThumbColor: AppTheme.successColor,
                      onChanged: (val) async {
                        final ok = await _repository.toggleTeacherActive(widget.teacher.id, val);
                        if (ok) setState(() => _isActive = val);
                      },
                    ),
                    Text(_isActive ? 'Активдүү' : 'Өчүрүлгөн', style: TextStyle(fontSize: 10, color: _isActive ? AppTheme.successColor : Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildScheduleTab(),
                _buildHistoryAndAnalyticsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // TAB 1: Individual Schedule
  Widget _buildScheduleTab() {
    if (_isLoadingSchedules) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        const Text(
          'Мугалимдин жеке жумуш убактысы',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
        ),
        const SizedBox(height: 4),
        const Text(
          'Бул мугалим үчүн өзүнчө график коюлса, мектептин жалпы графигинен артыкчылыктуу колдонулат.',
          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 14),

        ...List.generate(7, (dayIdx) {
          final custom = _teacherSchedules.where((s) => s.dayOfWeek == dayIdx).firstOrNull;
          final isCustom = custom != null;
          final isOff = custom?.isDayOff ?? (dayIdx == 6);
          final timeText = isOff
              ? 'Дем алыш күн'
              : '${custom?.startTime?.substring(0, 5) ?? "08:00"} — ${custom?.endTime?.substring(0, 5) ?? "17:00"} (Жеңилдик: ${custom?.graceMinutes ?? 15} мүн)';

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: isOff
                      ? const Color(0xFFF1F5F9)
                      : (isCustom ? AppTheme.primaryColor.withValues(alpha: 0.12) : const Color(0xFFF1F5F9)),
                  child: Icon(
                    isOff ? Icons.weekend_rounded : Icons.access_time_rounded,
                    color: isCustom ? AppTheme.primaryColor : const Color(0xFF64748B),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(_dayNames[dayIdx], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                          const SizedBox(width: 6),
                          if (isCustom)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(color: AppTheme.primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                              child: const Text('Жеке график', style: TextStyle(fontSize: 9.5, color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(timeText, style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_rounded, color: AppTheme.primaryColor, size: 18),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _showEditScheduleDialog(dayIdx),
                    ),
                    if (isCustom && custom.id != null) ...[
                      const SizedBox(width: 10),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => _resetToDefaultSchedule(custom.id!),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  // TAB 2: History & Analytics
  Widget _buildHistoryAndAnalyticsTab() {
    if (_isLoadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }

    final totalDays = _historyRecords.length;
    final onTimeCount = _historyRecords.where((r) => r['status'] == 'ON_TIME').length;
    final lateCount = _historyRecords.where((r) => r['status'] == 'LATE').length;
    final excusedCount = _historyRecords.where((r) => r['status'] == 'EXCUSED').length;
    final totalLateMinutes = _historyRecords.fold<int>(0, (acc, r) => acc + ((r['late_minutes'] as int?) ?? 0));
    final totalWorkedMinutes = _historyRecords.fold<int>(0, (acc, r) => acc + ((r['worked_minutes'] as int?) ?? 0));

    final lateHours = totalLateMinutes ~/ 60;
    final lateMins = totalLateMinutes % 60;
    final workedHours = totalWorkedMinutes ~/ 60;
    final workedMins = totalWorkedMinutes % 60;

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Monthly Summary Analytics Card
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${_selectedMonth.year}-жыл, ${_selectedMonth.month}-айдын көрсөткүчү',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Icon(Icons.bar_chart_rounded, color: AppTheme.primaryColor, size: 20),
                ],
              ),
              const Divider(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatCol('Жалпы күндөр', '$totalDays', AppTheme.primaryColor),
                  _buildStatCol('Өз убагында', '$onTimeCount', AppTheme.successColor),
                  _buildStatCol('Кечикти', '$lateCount', Colors.orange),
                  _buildStatCol('Себептүү', '$excusedCount', Colors.blue),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xFFF8FAFC), borderRadius: BorderRadius.circular(8)),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Кечигүү: ${lateHours > 0 ? "$lateHours с " : ""}$lateMins мүн',
                        style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 11.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Иштеди: $workedHours с $workedMins мүн',
                        style: const TextStyle(color: AppTheme.successColor, fontWeight: FontWeight.bold, fontSize: 11.5),
                        textAlign: TextAlign.end,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Каттоо тарыхы жана Жооптор',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: Color(0xFF0F172A)),
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, size: 20),
              onPressed: _loadTeacherHistory,
            ),
          ],
        ),
        const SizedBox(height: 6),

        if (_historyRecords.isEmpty)
          Container(
            padding: const EdgeInsets.all(28.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: const Center(child: Text('Бул айда катышуу жазуулары жок', style: TextStyle(color: AppTheme.textSecondary))),
          )
        else
          ..._historyRecords.map((r) {
            final status = r['status'] as String? ?? 'ON_TIME';
            Color color = AppTheme.successColor;
            String label = 'Өз убагында';

            if (status == 'LATE') {
              color = Colors.orange;
              label = 'Кечиккен (+${r["late_minutes"]} мүн)';
            } else if (status == 'EXCUSED') {
              color = Colors.blue;
              label = 'Себептүү';
            } else if (status == 'ABSENT') {
              color = Colors.grey;
              label = 'Келген жок';
            }

            final checkIn = _formatTime(r['check_in_time']);
            final checkOut = _formatTime(r['check_out_time']);
            final reason = r['correction_reason'] as String?;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        r['date'] as String? ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                        child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10.5)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text('Келүү: $checkIn', style: const TextStyle(fontSize: 12.5)),
                      const SizedBox(width: 10),
                      Text('Кетүү: $checkOut', style: const TextStyle(fontSize: 12.5)),
                      const Spacer(),
                      OutlinedButton(
                        onPressed: () => _showExcuseReplyDialog(r),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          visualDensity: VisualDensity.compact,
                        ),
                        child: const Text('Оңдоо / Жооп', style: TextStyle(fontSize: 11)),
                      ),
                    ],
                  ),
                  if (reason != null && reason.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Себеби: $reason',
                      style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF64748B)),
                    ),
                  ],
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildStatCol(String label, String val, Color col) {
    return Column(
      children: [
        Text(val, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: col)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B))),
      ],
    );
  }
}
