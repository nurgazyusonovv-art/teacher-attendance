import 'package:flutter/material.dart';
import 'package:teacher_admin/core/theme/admin_theme.dart';
import 'package:teacher_admin/features/schedules/data/repositories/schedules_repository.dart';

class SchedulesScreen extends StatefulWidget {
  const SchedulesScreen({super.key});

  @override
  State<SchedulesScreen> createState() => _SchedulesScreenState();
}

class _SchedulesScreenState extends State<SchedulesScreen> {
  final SchedulesRepository _repository = SchedulesRepository();

  List<ScheduleItem> _schedules = [];
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

  void _showEditScheduleDialog(int dayOfWeek, ScheduleItem? existing) {
    final startController = TextEditingController(
      text: existing != null ? existing.startTime.substring(0, 5) : '08:00',
    );
    final endController = TextEditingController(
      text: existing != null ? existing.endTime.substring(0, 5) : '17:00',
    );
    final graceController = TextEditingController(
      text: existing != null ? existing.graceMinutes.toString() : '5',
    );
    bool isDayOff = existing?.isDayOff ?? (dayOfWeek == 6); // Sunday is day off by default

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text('${_dayNames[dayOfWeek]} — Графикти оңдоо'),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('Дем алыш күн'),
                  value: isDayOff,
                  onChanged: (val) {
                    setModalState(() => isDayOff = val);
                  },
                ),
                const SizedBox(height: 12),
                if (!isDayOff) ...[
                  TextField(
                    controller: startController,
                    decoration: const InputDecoration(
                      labelText: 'Келүү убактысы (мис: 08:00)',
                      prefixIcon: Icon(Icons.access_time),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: endController,
                    decoration: const InputDecoration(
                      labelText: 'Кетүү убактысы (мис: 17:00)',
                      prefixIcon: Icon(Icons.access_time_filled),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: graceController,
                    decoration: const InputDecoration(
                      labelText: 'Кечигүүгө жеңилдик (мүнөт)',
                      prefixIcon: Icon(Icons.timer_outlined),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Жокко чыгаруу'),
            ),
            ElevatedButton(
              onPressed: () async {
                String startTime = '${startController.text.trim()}:00';
                if (startTime.length == 5) startTime = '$startTime:00';
                String endTime = '${endController.text.trim()}:00';
                if (endTime.length == 5) endTime = '$endTime:00';

                final success = await _repository.createOrUpdateSchedule(
                  dayOfWeek: dayOfWeek,
                  startTime: isDayOff ? '00:00:00' : (startController.text.trim().length == 5 ? '${startController.text.trim()}:00' : startController.text.trim()),
                  endTime: isDayOff ? '00:00:00' : (endController.text.trim().length == 5 ? '${endController.text.trim()}:00' : endController.text.trim()),
                  graceMinutes: int.tryParse(graceController.text.trim()) ?? 5,
                  isDayOff: isDayOff,
                );
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
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Иш графиктери',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Жуманын 7 күнү боюнча жумуш убактысы жана дем алыштар',
                    style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Days List
          Expanded(
            child: Card(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: 7,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final schedule = _schedules.cast<ScheduleItem?>().firstWhere(
                              (s) => s?.dayOfWeek == index,
                              orElse: () => null,
                            );

                        final isOff = schedule?.isDayOff ?? (index == 6);
                        final timeRange = isOff
                            ? 'Дем алыш күн'
                            : '${schedule != null ? schedule.startTime.substring(0, 5) : "08:00"} — ${schedule != null ? schedule.endTime.substring(0, 5) : "17:00"}';

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: CircleAvatar(
                            backgroundColor: isOff
                                ? Colors.grey.withValues(alpha: 0.2)
                                : AdminTheme.accentColor.withValues(alpha: 0.1),
                            child: Icon(
                              isOff ? Icons.weekend : Icons.work_outline,
                              color: isOff ? Colors.grey : AdminTheme.accentColor,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            _dayNames[index],
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          subtitle: Text(
                            timeRange,
                            style: TextStyle(
                              color: isOff ? Colors.red[400] : const Color(0xFF334155),
                              fontWeight: isOff ? FontWeight.normal : FontWeight.w500,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!isOff && schedule != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'Жеңилдик: ${schedule.graceMinutes} мин',
                                    style: const TextStyle(fontSize: 12, color: Colors.amber, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              OutlinedButton.icon(
                                onPressed: () => _showEditScheduleDialog(index, schedule),
                                icon: const Icon(Icons.edit, size: 16),
                                label: const Text('Өзгөртүү'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
