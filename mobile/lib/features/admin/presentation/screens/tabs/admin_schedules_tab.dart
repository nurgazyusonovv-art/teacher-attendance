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

  void _showEditScheduleModal(WorkScheduleItemModel item) {
    TimeOfDay startTime = const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 17, minute: 0);
    int graceMinutes = item.graceMinutes;
    bool isDayOff = item.isDayOff;

    if (item.startTime != null && item.startTime!.contains(':')) {
      final parts = item.startTime!.split(':');
      startTime = TimeOfDay(hour: int.tryParse(parts[0]) ?? 8, minute: int.tryParse(parts[1]) ?? 0);
    }
    if (item.endTime != null && item.endTime!.contains(':')) {
      final parts = item.endTime!.split(':');
      endTime = TimeOfDay(hour: int.tryParse(parts[0]) ?? 17, minute: int.tryParse(parts[1]) ?? 0);
    }

    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            left: 22,
            right: 22,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${_dayNames[item.dayOfWeek]} графиги',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.textPrimary),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Иш жана дем алыш убактысын коюу',
                          style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Day Off Toggle Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDayOff ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDayOff ? const Color(0xFFFECACA) : const Color(0xFFBBF7D0),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          isDayOff ? Icons.weekend_rounded : Icons.work_history_rounded,
                          color: isDayOff ? AppTheme.errorColor : AppTheme.successColor,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          isDayOff ? 'Дем алыш күн' : 'Иш күнү',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isDayOff ? AppTheme.errorColor : AppTheme.successColor,
                          ),
                        ),
                      ],
                    ),
                    Switch(
                      value: !isDayOff,
                      activeTrackColor: AppTheme.successColor.withValues(alpha: 0.5),
                      activeThumbColor: AppTheme.successColor,
                      onChanged: (val) => setModalState(() => isDayOff = !val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              if (!isDayOff) ...[
                // Time Selectors Row
                Row(
                  children: [
                    // Start Time Picker
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: startTime,
                          );
                          if (picked != null) {
                            setModalState(() => startTime = picked);
                          }
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.login_rounded, size: 14, color: AppTheme.successColor),
                                  SizedBox(width: 4),
                                  Text('Келүү убактысы', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${startTime.hour.toString().padLeft(2, "0")}:${startTime.minute.toString().padLeft(2, "0")}',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),

                    // End Time Picker
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: endTime,
                          );
                          if (picked != null) {
                            setModalState(() => endTime = picked);
                          }
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.borderColor),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.logout_rounded, size: 14, color: AppTheme.secondaryColor),
                                  SizedBox(width: 4),
                                  Text('Кетүү убактысы', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${endTime.hour.toString().padLeft(2, "0")}:${endTime.minute.toString().padLeft(2, "0")}',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Grace Minutes Selector
                const Text(
                  'Кечигүүгө жеңилдик чеги:',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [0, 5, 10, 15, 20, 30].map((mins) {
                    final isSelected = graceMinutes == mins;
                    return InkWell(
                      onTap: () => setModalState(() => graceMinutes = mins),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primaryColor : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor,
                          ),
                        ),
                        child: Text(
                          '$mins мүнөт',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? Colors.white : AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 22),

              // Save Button
              ElevatedButton(
                onPressed: isSaving
                    ? null
                    : () async {
                        setModalState(() => isSaving = true);
                        final startStr = '${startTime.hour.toString().padLeft(2, "0")}:${startTime.minute.toString().padLeft(2, "0")}:00';
                        final endStr = '${endTime.hour.toString().padLeft(2, "0")}:${endTime.minute.toString().padLeft(2, "0")}:00';

                        final updated = WorkScheduleItemModel(
                          id: item.id,
                          dayOfWeek: item.dayOfWeek,
                          startTime: startStr,
                          endTime: endStr,
                          graceMinutes: graceMinutes,
                          isDayOff: isDayOff,
                        );

                        final messenger = ScaffoldMessenger.of(context);
                        final success = await _repository.updateSchedule(updated);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (success) {
                          _loadSchedules();
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('График ийгиликтүү сакталды!'),
                              backgroundColor: AppTheme.successColor,
                            ),
                          );
                        } else {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Графикти сактоодо ката кетти'),
                              backgroundColor: AppTheme.errorColor,
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text(
                        'Графикти сактоо',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
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
                        'Өзгөртүү үчүн каалаган күндү басыңыз',
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
              orElse: () => WorkScheduleItemModel(
                dayOfWeek: dayIdx,
                startTime: '08:00:00',
                endTime: '17:00:00',
                graceMinutes: 15,
                isDayOff: dayIdx == 5 || dayIdx == 6,
              ),
            );

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.borderColor),
                boxShadow: const [
                  BoxShadow(color: Color(0x04000000), blurRadius: 6, offset: Offset(0, 2)),
                ],
              ),
              child: InkWell(
                onTap: () => _showEditScheduleModal(schedule),
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: schedule.isDayOff
                            ? const Color(0xFFF1F5F9)
                            : AppTheme.primaryColor.withValues(alpha: 0.1),
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
                            Text(_dayNames[dayIdx], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                            const SizedBox(height: 2),
                            Text(
                              schedule.isDayOff
                                  ? 'Дем алыш күн'
                                  : '${schedule.startTime?.substring(0, 5) ?? "08:00"} — ${schedule.endTime?.substring(0, 5) ?? "17:00"} (Жеңилдик: ${schedule.graceMinutes} мүн)',
                              style: TextStyle(
                                color: schedule.isDayOff ? AppTheme.textMuted : AppTheme.textSecondary,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.edit_rounded, color: AppTheme.primaryColor, size: 18),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
