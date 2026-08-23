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
    'Дүйшөмбү (1-күн)',
    'Шейшемби (2-күн)',
    'Шаршемби (3-күн)',
    'Бейшемби (4-күн)',
    'Жума (5-күн)',
    'Ишемби (6-күн)',
    'Жекшемби (7-күн)',
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
          title: Text(_dayNames[item.dayOfWeek]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  title: const Text('Дем алыш күн (Day Off)'),
                  value: isDayOff,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) => setModalState(() => isDayOff = val),
                ),
                if (!isDayOff) ...[
                  const Divider(),
                  ListTile(
                    title: const Text('Башталуу убактысы'),
                    trailing: Chip(label: Text('${startTime.hour.toString().padLeft(2, "0")}:${startTime.minute.toString().padLeft(2, "0")}')),
                    contentPadding: EdgeInsets.zero,
                    onTap: () async {
                      final picked = await showTimePicker(context: context, initialTime: startTime);
                      if (picked != null) setModalState(() => startTime = picked);
                    },
                  ),
                  ListTile(
                    title: const Text('Аяктоо убактысы'),
                    trailing: Chip(label: Text('${endTime.hour.toString().padLeft(2, "0")}:${endTime.minute.toString().padLeft(2, "0")}')),
                    contentPadding: EdgeInsets.zero,
                    onTap: () async {
                      final picked = await showTimePicker(context: context, initialTime: endTime);
                      if (picked != null) setModalState(() => endTime = picked);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: graceController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Жеңилдик убактысы (мүнөт)',
                      hintText: '15',
                      border: OutlineInputBorder(),
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

                final success = await _repository.updateSchedule(updated);
                if (ctx.mounted) Navigator.pop(ctx);
                if (success) {
                  _loadSchedules();
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
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text(
            'Жумалык жумуш графиги',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Color(0xFF0F172A)),
          ),
          const SizedBox(height: 4),
          const Text(
            'Мугалимдердин жумушка келүү-кетүү тартибин жана кечигүү мүнөтүн көзөмөлдөөчү график',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),

          ...List.generate(7, (dayIdx) {
            final schedule = _schedules.firstWhere(
              (s) => s.dayOfWeek == dayIdx,
              orElse: () => WorkScheduleItemModel(dayOfWeek: dayIdx, graceMinutes: 15, isDayOff: dayIdx == 6),
            );

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: schedule.isDayOff ? Colors.grey.withValues(alpha: 0.2) : AppTheme.primaryColor.withValues(alpha: 0.1),
                  child: Icon(
                    schedule.isDayOff ? Icons.weekend : Icons.work_outline,
                    color: schedule.isDayOff ? Colors.grey : AppTheme.primaryColor,
                  ),
                ),
                title: Text(_dayNames[dayIdx], style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  schedule.isDayOff
                      ? 'Дем алыш күн'
                      : '${schedule.startTime?.substring(0, 5) ?? "08:00"} — ${schedule.endTime?.substring(0, 5) ?? "17:00"} (Жеңилдик: ${schedule.graceMinutes} мүн)',
                  style: TextStyle(
                    color: schedule.isDayOff ? Colors.grey : const Color(0xFF0F172A),
                    fontWeight: schedule.isDayOff ? FontWeight.normal : FontWeight.w500,
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.edit, color: AppTheme.primaryColor),
                  onPressed: () => _showEditScheduleDialog(schedule),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
