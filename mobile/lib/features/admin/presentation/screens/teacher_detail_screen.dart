import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/datetime_utils.dart';
import '../../../../core/widgets/ios_time_picker.dart';
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
  late TeacherItemModel _currentTeacher;
  late bool _isActive;

  // Schedules state
  List<WorkScheduleItemModel> _teacherSchedules = [];
  bool _isLoadingSchedules = true;

  // Lesson Delays state
  List<LessonDelayModel> _lessonDelays = [];
  bool _isLoadingDelays = true;

  // History & Statistics state
  List<Map<String, dynamic>> _historyRecords = [];
  bool _isLoadingHistory = true;
  DateTime _selectedMonth = DateTime.now();

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
    _tabController = TabController(length: 3, vsync: this);
    _currentTeacher = widget.teacher;
    _isActive = widget.teacher.isActive;
    _loadTeacherSchedules();
    _loadLessonDelays();
    _loadTeacherHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadTeacherSchedules() async {
    setState(() => _isLoadingSchedules = true);
    final list = await _repository.getTeacherSchedules(teacherId: _currentTeacher.id);
    if (mounted) {
      setState(() {
        _teacherSchedules = list;
        _isLoadingSchedules = false;
      });
    }
  }

  Future<void> _loadLessonDelays() async {
    setState(() => _isLoadingDelays = true);
    final list = await _repository.getLessonDelays(
      teacherId: _currentTeacher.id,
      year: _selectedMonth.year,
      month: _selectedMonth.month,
    );
    if (mounted) {
      setState(() {
        _lessonDelays = list;
        _isLoadingDelays = false;
      });
    }
  }

  Future<void> _loadTeacherHistory() async {
    setState(() => _isLoadingHistory = true);
    final list = await _repository.getTeacherHistory(
      teacherId: _currentTeacher.id,
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

  // --- TEACHER EDIT MODAL ---
  void _showEditTeacherDialog() {
    final nameController = TextEditingController(text: _currentTeacher.fullName);
    final subjectController = TextEditingController(text: _currentTeacher.subject ?? '');
    final phoneController = TextEditingController(text: _currentTeacher.phone ?? '');
    final codeController = TextEditingController(text: _currentTeacher.employeeCode);
    final passController = TextEditingController();
    bool activeVal = _isActive;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.edit_note_rounded, color: AppTheme.primaryColor, size: 28),
              SizedBox(width: 8),
              Expanded(
                child: Text('Мугалимди оңдоо', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Аты-жөнү *',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: subjectController,
                  decoration: const InputDecoration(
                    labelText: 'Окуткан предмети',
                    prefixIcon: Icon(Icons.menu_book_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Телефон номери',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: codeController,
                  decoration: const InputDecoration(
                    labelText: 'Табель / кызматкер коду *',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Жаңы сырсөз (кааласаңыз)',
                    hintText: 'Өзгөртпөө үчүн бош калтырыңыз',
                    prefixIcon: Icon(Icons.lock_outline_rounded),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('Активдүү статус', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  value: activeVal,
                  contentPadding: EdgeInsets.zero,
                  activeTrackColor: AppTheme.successColor.withValues(alpha: 0.5),
                  activeThumbColor: AppTheme.successColor,
                  onChanged: (val) => setModalState(() => activeVal = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Жокко чыгаруу', style: TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final code = codeController.text.trim();
                if (name.isEmpty || code.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Аты-жөнү жана коду бош болбошу керек!'), backgroundColor: Colors.red),
                  );
                  return;
                }

                final messenger = ScaffoldMessenger.of(context);
                final (success, errorMsg) = await _repository.updateTeacher(
                  teacherId: _currentTeacher.id,
                  fullName: name,
                  subject: subjectController.text.trim(),
                  phone: phoneController.text.trim(),
                  employeeCode: code,
                  password: passController.text.trim().isNotEmpty ? passController.text.trim() : null,
                  isActive: activeVal,
                );

                if (ctx.mounted) Navigator.pop(ctx);
                if (success) {
                  setState(() {
                    _currentTeacher = _currentTeacher.copyWith(
                      fullName: name,
                      subject: subjectController.text.trim(),
                      phone: phoneController.text.trim(),
                      employeeCode: code,
                      isActive: activeVal,
                    );
                    _isActive = activeVal;
                  });
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Мугалимдин маалыматы ийгиликтүү өзгөртүлдү!'), backgroundColor: AppTheme.successColor),
                  );
                } else {
                  messenger.showSnackBar(
                    SnackBar(content: Text(errorMsg ?? 'Ката кетти'), backgroundColor: Colors.red),
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

  // --- TEACHER DELETE / DEACTIVATE MODAL ---
  void _showDeleteTeacherDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text('Мугалимди өчүрүү', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Text(
          '${_currentTeacher.fullName} аттуу мугалимди базадан толук өчүрүүнү каалайсызбы же убактылуу деактивациялайсызбы?',
          style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Жокко чыгаруу', style: TextStyle(color: Color(0xFF64748B))),
          ),
          OutlinedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final messenger = ScaffoldMessenger.of(context);
              final ok = await _repository.toggleTeacherActive(_currentTeacher.id, false);
              if (ok) {
                setState(() => _isActive = false);
                messenger.showSnackBar(
                  const SnackBar(content: Text('Мугалим деактивацияланды'), backgroundColor: Colors.orange),
                );
              }
            },
            child: const Text('Деактивациялоо', style: TextStyle(color: Colors.orange)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              final messenger = ScaffoldMessenger.of(context);
              final (ok, err) = await _repository.deleteTeacher(_currentTeacher.id, hardDelete: true);
              if (ok) {
                messenger.showSnackBar(
                  const SnackBar(content: Text('Мугалим базадан толук өчүрүлдү!'), backgroundColor: AppTheme.successColor),
                );
                if (mounted) Navigator.pop(context, true);
              } else {
                messenger.showSnackBar(
                  SnackBar(content: Text(err ?? 'Өчүрүүдө ката кетти'), backgroundColor: Colors.red),
                );
              }
            },
            child: const Text('Толук өчүрүү'),
          ),
        ],
      ),
    );
  }

  // --- ADD LESSON DELAY MODAL ---
  void _showAddLessonDelayDialog() {
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
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
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.timer_outlined, color: Colors.orange, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Сабакка кечигүү белгилөө', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                          Text('Канчанчы сабак жана канча мүнөт кечиккени', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Date selector
                const Text('Датасы:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                const SizedBox(height: 6),
                InkWell(
                  onTap: () async {
                    final d = await showDatePicker(
                      context: context,
                      initialDate: pickedDate,
                      firstDate: DateTime(2025),
                      lastDate: DateTime(2030),
                    );
                    if (d != null) setModalState(() => pickedDate = d);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateTimeUtils.formatKyrgyzDate(pickedDate),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: AppTheme.textPrimary),
                        ),
                        const Icon(Icons.calendar_today_rounded, size: 18, color: AppTheme.primaryColor),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Lesson number selector (1..8)
                const Text('Кайсы сабакка кечикти:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: List.generate(8, (i) {
                    final lessonNum = i + 1;
                    final isSel = selectedLesson == lessonNum;
                    return InkWell(
                      onTap: () => setModalState(() => selectedLesson = lessonNum),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSel ? AppTheme.primaryColor : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isSel ? AppTheme.primaryColor : AppTheme.borderColor),
                        ),
                        child: Text(
                          '$lessonNum-сабак',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                            color: isSel ? Colors.white : AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 16),

                // Delay minutes selector
                const Text('Кечиккен убактысы (мүнөт):', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
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
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: isSel ? Colors.orange : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: isSel ? Colors.orange : AppTheme.borderColor),
                        ),
                        child: Text(
                          '$mins мүнөт',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
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
                    labelText: 'Же кол менен жазыңыз (мүнөт)',
                    suffixText: 'мин',
                  ),
                  onChanged: (val) {
                    final parsed = int.tryParse(val);
                    if (parsed != null && parsed > 0) {
                      setModalState(() => selectedMinutes = parsed);
                    }
                  },
                ),
                const SizedBox(height: 16),

                // Reason input
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: 'Кечигүүнүн себеби (кааласаңыз)',
                    hintText: 'Мис: Жол тыгыны, Себепсиз, Журнал...',
                    prefixIcon: Icon(Icons.comment_outlined),
                  ),
                ),
                const SizedBox(height: 24),

                // Save button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor, foregroundColor: Colors.white),
                    onPressed: () async {
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
                        teacherId: _currentTeacher.id,
                        date: dateStr,
                        lessonNumber: selectedLesson,
                        delayMinutes: mins,
                        reason: reasonController.text.trim().isNotEmpty ? reasonController.text.trim() : null,
                      );

                      if (ctx.mounted) Navigator.pop(ctx);
                      if (ok) {
                        _loadLessonDelays();
                        _loadTeacherHistory();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('$selectedLesson-сабакка $mins мүнөт кечигүү сакталды!'),
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

  // --- SCHEDULE EDIT DIALOG ---
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
                      final picked = await showIosTimePicker(context: context, initialTime: startTime, title: 'Келүү убактысы');
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
                      final picked = await showIosTimePicker(context: context, initialTime: endTime, title: 'Кетүү убактысы');
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
                  teacherId: _currentTeacher.id,
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
                    DropdownMenuItem(value: 'ABSENT', child: Text('Келген эмес (Себепсиз)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setModalState(() => selectedStatus = val);
                  },
                ),
                const SizedBox(height: 14),
                const Text('Келүү / Кетүү убактысын тактоо:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: checkInController,
                        decoration: const InputDecoration(labelText: 'Келүү (HH:mm)', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: checkOutController,
                        decoration: const InputDecoration(labelText: 'Кетүү (HH:mm)', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Text('Оңдоонун себеби / Буйрук негизи:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
                const SizedBox(height: 8),
                TextField(
                  controller: reasonController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Мис: Ооруп жатат, справка көрсөттү, иш сапар...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Жокко чыгаруу')),
            ElevatedButton(
              onPressed: () async {
                final reason = reasonController.text.trim();
                if (reason.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Оңдоонун себебин сөзсүз жазыңыз!'), backgroundColor: Colors.red),
                  );
                  return;
                }

                String? checkInIso;
                String? checkOutIso;
                final dateStr = record['date'] as String;

                if (checkInController.text.trim().isNotEmpty) {
                  checkInIso = '${dateStr}T${checkInController.text.trim()}:00';
                }
                if (checkOutController.text.trim().isNotEmpty) {
                  checkOutIso = '${dateStr}T${checkOutController.text.trim()}:00';
                }

                final messenger = ScaffoldMessenger.of(context);
                final ok = await _repository.manualCorrection(
                  teacherId: _currentTeacher.id,
                  targetDate: dateStr,
                  status: selectedStatus,
                  reason: reason,
                  checkInTime: checkInIso,
                  checkOutTime: checkOutIso,
                );

                if (ctx.mounted) Navigator.pop(ctx);
                if (ok) {
                  _loadTeacherHistory();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Катышуу статусу оңдолду!'), backgroundColor: AppTheme.successColor),
                  );
                } else {
                  messenger.showSnackBar(
                    const SnackBar(content: Text('Оңдоодо ката кетти'), backgroundColor: Colors.red),
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
        title: Text(_currentTeacher.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note_rounded, color: AppTheme.primaryColor),
            tooltip: 'Мугалимди оңдоо',
            onPressed: _showEditTeacherDialog,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
            tooltip: 'Өчүрүү',
            onPressed: _showDeleteTeacherDialog,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: const Color(0xFF64748B),
          indicatorColor: AppTheme.primaryColor,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
          tabs: const [
            Tab(icon: Icon(Icons.access_time_filled_rounded, size: 20), text: 'График'),
            Tab(icon: Icon(Icons.timer_outlined, size: 20), text: 'Кечигүүлөр'),
            Tab(icon: Icon(Icons.calendar_month_rounded, size: 20), text: 'Тарых'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Teacher Info Banner
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.15),
                  child: Text(
                    _currentTeacher.fullName.isNotEmpty ? _currentTeacher.fullName[0] : 'М',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _currentTeacher.fullName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Wrap(
                        spacing: 6,
                        runSpacing: 2,
                        children: [
                          Text('Код: ${_currentTeacher.employeeCode}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11.5)),
                          Text('•  Логин: ${_currentTeacher.username}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 11.5)),
                        ],
                      ),
                      if (_currentTeacher.subject != null && _currentTeacher.subject!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Row(
                            children: [
                              const Icon(Icons.menu_book_rounded, size: 12, color: AppTheme.primaryColor),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Сабагы: ${_currentTeacher.subject!}',
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.primaryColor),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_currentTeacher.phone != null && _currentTeacher.phone!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text('Тел: ${_currentTeacher.phone}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
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
                        final ok = await _repository.toggleTeacherActive(_currentTeacher.id, val);
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
                _buildLessonDelaysTab(),
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

  // TAB 2: Lesson Delays
  Widget _buildLessonDelaysTab() {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddLessonDelayDialog,
        icon: const Icon(Icons.add_alarm_rounded),
        label: const Text('Кечигүү кошуу'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: _isLoadingDelays
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // Header card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Colors.orange, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Сабактардагы кечигүүлөр мугалимдин экранында көрүнүп, жалпы кечигүү убактысына кошулат.',
                          style: TextStyle(fontSize: 12, color: Colors.orange.shade900, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (_lessonDelays.isEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 20),
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.alarm_off_rounded, size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 10),
                        const Text(
                          'Сабакка кечигүүлөр катталган эмес',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Кечигүү кошуу үчүн төмөнкү баскычты басыңыз',
                          style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                        ),
                      ],
                    ),
                  )
                else
                  ..._lessonDelays.map((delay) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.borderColor),
                        boxShadow: const [
                          BoxShadow(color: Color(0x04000000), blurRadius: 6, offset: Offset(0, 2)),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${delay.lessonNumber}-сабак',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      '${delay.delayMinutes} мүнөт кечикти',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.red),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      delay.date,
                                      style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                                    ),
                                  ],
                                ),
                                if (delay.reason != null && delay.reason!.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Text(
                                    'Себеби: ${delay.reason}',
                                    style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                            tooltip: 'Өчүрүү',
                            onPressed: () async {
                              final messenger = ScaffoldMessenger.of(context);
                              final ok = await _repository.deleteLessonDelay(delay.id);
                              if (ok) {
                                _loadLessonDelays();
                                _loadTeacherHistory();
                                messenger.showSnackBar(
                                  const SnackBar(content: Text('Сабак кечигүүсү өчүрүлдү'), backgroundColor: AppTheme.successColor),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 80),
              ],
            ),
    );
  }

  // TAB 3: History & Analytics
  Widget _buildHistoryAndAnalyticsTab() {
    if (_isLoadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }

    final totalDays = _historyRecords.length;
    final onTimeDays = _historyRecords.where((r) => r['status'] == 'ON_TIME').length;
    final lateDays = _historyRecords.where((r) => r['status'] == 'LATE').length;
    final absentDays = _historyRecords.where((r) => r['status'] == 'ABSENT').length;
    final excusedDays = _historyRecords.where((r) => r['status'] == 'EXCUSED').length;

    final attendancePercent = totalDays > 0 ? (((onTimeDays + lateDays + excusedDays) / totalDays) * 100).toInt() : 0;
    final totalWorkedMinutes = _historyRecords.fold<int>(0, (sum, r) => sum + (r['worked_minutes'] as int? ?? 0));
    final totalWorkedHours = (totalWorkedMinutes / 60).toStringAsFixed(1);
    final totalLateMinutes = _historyRecords.fold<int>(0, (sum, r) => sum + (r['total_late_minutes'] as int? ?? r['late_minutes'] as int? ?? 0));

    return RefreshIndicator(
      onRefresh: () async {
        await _loadTeacherHistory();
        await _loadLessonDelays();
      },
      child: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // Month Selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: () {
                  setState(() {
                    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
                  });
                  _loadTeacherHistory();
                  _loadLessonDelays();
                },
              ),
              Text(
                DateTimeUtils.formatKyrgyzMonthYear(_selectedMonth),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right_rounded),
                onPressed: () {
                  setState(() {
                    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
                  });
                  _loadTeacherHistory();
                  _loadLessonDelays();
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // KPI Summary Cards
          Row(
            children: [
              Expanded(child: _buildKpiCard('Катышуу', '$attendancePercent%', AppTheme.primaryColor)),
              const SizedBox(width: 8),
              Expanded(child: _buildKpiCard('Иштеген убакыт', '${totalWorkedHours}с', AppTheme.successColor)),
              const SizedBox(width: 8),
              Expanded(child: _buildKpiCard('Жалпы кечигүү', '${totalLateMinutes}м', Colors.orange)),
            ],
          ),
          const SizedBox(height: 16),

          const Text('Күндөлүк катышуу журналы', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),

          if (_historyRecords.isEmpty)
            Container(
              margin: const EdgeInsets.only(top: 20),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppTheme.borderColor)),
              child: const Center(child: Text('Бул айда катышуу маалыматы жок', style: TextStyle(color: AppTheme.textSecondary))),
            )
          else
            ..._historyRecords.map((r) {
              final status = r['status'] as String? ?? 'ON_TIME';
              final isCorrected = r['is_manually_corrected'] as bool? ?? false;
              final checkIn = _formatTime(r['check_in_time']);
              final checkOut = _formatTime(r['check_out_time']);
              final rawLateMins = r['late_minutes'] as int? ?? 0;
              final rawTotalLate = r['total_late_minutes'] as int? ?? rawLateMins;
              final lessonDelaysList = (r['lesson_delays'] as List? ?? [])
                  .map((e) => LessonDelayModel.fromJson(e as Map<String, dynamic>))
                  .toList();

              Color badgeColor;
              String statusText;
              switch (status) {
                case 'ON_TIME':
                  badgeColor = AppTheme.successColor;
                  statusText = 'Өз убагында';
                  break;
                case 'LATE':
                  badgeColor = Colors.orange;
                  statusText = 'Кечиккен ($rawTotalLate мүн)';
                  break;
                case 'EXCUSED':
                  badgeColor = Colors.blue;
                  statusText = 'Себептүү';
                  break;
                case 'ABSENT':
                default:
                  badgeColor = Colors.red;
                  statusText = 'Келген жок';
                  break;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
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
                        Text(r['date'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: badgeColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                          child: Text(statusText, style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 11)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.login_rounded, size: 14, color: AppTheme.textMuted),
                        const SizedBox(width: 4),
                        Text('Келүү: $checkIn', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        const SizedBox(width: 14),
                        const Icon(Icons.logout_rounded, size: 14, color: AppTheme.textMuted),
                        const SizedBox(width: 4),
                        Text('Кетүү: $checkOut', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        const Spacer(),
                        InkWell(
                          onTap: () => _showExcuseReplyDialog(r),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(6)),
                            child: const Row(
                              children: [
                                Icon(Icons.edit, size: 12, color: AppTheme.primaryColor),
                                SizedBox(width: 3),
                                Text('Оңдоо', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (lessonDelaysList.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: lessonDelaysList.map((ld) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
                            ),
                            child: Text(
                              '${ld.lessonNumber}-сабак: ${ld.delayMinutes}м',
                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.orange),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                    if (isCorrected && r['correction_reason'] != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Оңдолгон себеби: ${r["correction_reason"]}',
                        style: const TextStyle(fontSize: 11, color: Colors.blueGrey, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderColor),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}
