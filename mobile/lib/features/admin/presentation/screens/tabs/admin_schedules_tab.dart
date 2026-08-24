import 'package:flutter/material.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../data/repositories/admin_mobile_repository.dart';

class AdminSchedulesTab extends StatefulWidget {
  const AdminSchedulesTab({super.key});

  @override
  State<AdminSchedulesTab> createState() => _AdminSchedulesTabState();
}

class _AdminSchedulesTabState extends State<AdminSchedulesTab> {
  final AdminMobileRepository _repository = AdminMobileRepository();
  List<WorkScheduleItemModel> _schedules = [];
  bool _isLoading = true;

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
    _loadSchedules();
  }

  Future<void> _loadSchedules() async {
    setState(() => _isLoading = true);
    final list = await _repository.getWeeklySchedules();
    if (mounted) {
      setState(() {
        _schedules = list;
        _isLoading = false;
      });
    }
  }

  void _showEditScheduleDialog(WorkScheduleItemModel item) {
    TimeOfDay startTime = const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 17, minute: 0);
    int graceMinutes = item.graceMinutes;
    bool isDayOff = item.isDayOff;

    if (item.startTime != null) {
      final parts = item.startTime!.split(':');
      startTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }
    if (item.endTime != null) {
      final parts = item.endTime!.split(':');
      endTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    }

    final graceController = TextEditingController(text: graceMinutes.toString());

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('${_dayNames[item.dayOfWeek]} графиги', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                    title: const Text('Башталуу убактысы'),
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
                    title: const Text('Аяктоо убактысы'),
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

                final updated = WorkScheduleItemModel(
                  id: item.id,
                  dayOfWeek: item.dayOfWeek,
                  startTime: startStr,
                  endTime: endStr,
                  graceMinutes: grace,
                  isDayOff: isDayOff,
                );

                final messenger = ScaffoldMessenger.of(context);
                final success = await _repository.updateSchedule(updated);
                if (ctx.mounted) Navigator.pop(ctx);
                if (success) {
                  _loadSchedules();
                  messenger.showSnackBar(
                    const SnackBar(content: Text('График ийгиликтүү сакталды!'), backgroundColor: AppTheme.successColor),
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

    return RefreshIndicator(
      onRefresh: _loadSchedules,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.borderColor),
              boxShadow: const [
                BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
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
                  child: const Icon(Icons.schedule_rounded, color: AppTheme.primaryColor, size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Мектептин жумалык графиги',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: AppTheme.textPrimary),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Бардык мугалимдер үчүн негизги тартип',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          ...List.generate(7, (dayIdx) {
            final schedule = _schedules.firstWhere(
              (s) => s.dayOfWeek == dayIdx,
              orElse: () => WorkScheduleItemModel(dayOfWeek: dayIdx, graceMinutes: 15, isDayOff: dayIdx == 6),
            );

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                    radius: 20,
                    backgroundColor: schedule.isDayOff ? const Color(0xFFF1F5F9) : AppTheme.primaryColor.withValues(alpha: 0.1),
                    child: Icon(
                      schedule.isDayOff ? Icons.weekend_rounded : Icons.work_history_rounded,
                      color: schedule.isDayOff ? AppTheme.textMuted : AppTheme.primaryColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_dayNames[dayIdx], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        const SizedBox(height: 2),
                        Text(
                          schedule.isDayOff
                              ? 'Дем алыш күн'
                              : '${schedule.startTime?.substring(0, 5) ?? "08:00"} — ${schedule.endTime?.substring(0, 5) ?? "17:00"} (Жеңилдик: ${schedule.graceMinutes} мүн)',
                          style: TextStyle(
                            color: schedule.isDayOff ? AppTheme.textMuted : AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.edit_rounded, color: AppTheme.primaryColor, size: 18),
                    ),
                    onPressed: () => _showEditScheduleDialog(schedule),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
