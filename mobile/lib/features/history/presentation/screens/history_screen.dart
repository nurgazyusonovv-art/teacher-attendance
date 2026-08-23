import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:teacher_mobile/core/theme/app_theme.dart';
import 'package:teacher_mobile/features/attendance/data/repositories/attendance_repository.dart';
import 'package:teacher_mobile/features/attendance/presentation/cubit/attendance_cubit.dart';
import 'package:teacher_mobile/features/attendance/presentation/cubit/attendance_state.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DateTime _selectedDate = DateTime.now();
  String _selectedFilter = 'ALL'; // ALL, ON_TIME, LATE, EXCUSED

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  void _fetchHistory() {
    context.read<AttendanceCubit>().loadHistory(
      year: _selectedDate.year,
      month: _selectedDate.month,
    );
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

  String _formatDate(String dateString) {
    try {
      final dt = DateTime.parse(dateString);
      return DateFormat('d-MMMM, EEEE', 'ky').format(dt);
    } catch (_) {
      return dateString;
    }
  }

  String _formatMinutes(int totalMinutes) {
    if (totalMinutes <= 0) return '0 мүнөт';
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    if (hours == 0) return '$mins мүнөт';
    if (mins == 0) return '$hours саат';
    return '$hours саат $mins мүн';
  }

  void _showMonthPicker() async {
    final months = [
      'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
      'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'
    ];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Айды тандоо',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: 12,
                itemBuilder: (context, index) {
                  final monthNum = index + 1;
                  final isSelected = _selectedDate.month == monthNum;
                  return ListTile(
                    title: Text(months[index]),
                    trailing: isSelected
                        ? const Icon(Icons.check, color: AppTheme.primaryColor)
                        : null,
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _selectedDate = DateTime(_selectedDate.year, monthNum, 1);
                      });
                      _fetchHistory();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final monthName = DateFormat('MMMM yyyy', 'ky').format(_selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Каттоо тарыхы'),
      ),
      body: SafeArea(
        child: BlocBuilder<AttendanceCubit, AttendanceState>(
          builder: (context, state) {
            if (state is AttendanceLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            List<DailyAttendanceModel> records = [];
            if (state is AttendanceHistoryLoaded) {
              records = state.history;
            }

            // Calculations for Statistics
            final totalDays = records.length;
            final onTimeDays = records.where((r) => r.status == 'ON_TIME').length;
            final lateDays = records.where((r) => r.status == 'LATE').length;
            final excusedDays = records.where((r) => r.status == 'EXCUSED').length;
            final totalLateMinutes = records.fold<int>(0, (sum, r) => sum + r.lateMinutes);
            final totalWorkedMinutes = records.fold<int>(0, (sum, r) => sum + r.workedMinutes);

            final filteredRecords = records.where((r) {
              if (_selectedFilter == 'ALL') return true;
              if (_selectedFilter == 'ON_TIME') return r.status == 'ON_TIME';
              if (_selectedFilter == 'LATE') return r.status == 'LATE';
              if (_selectedFilter == 'EXCUSED') return r.status == 'EXCUSED';
              return true;
            }).toList();

            return RefreshIndicator(
              onRefresh: () async => _fetchHistory(),
              child: CustomScrollView(
                slivers: [
                  // Month Picker Card
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFEFF6FF),
                            child: Icon(Icons.calendar_today, color: AppTheme.primaryColor),
                          ),
                          title: Text(
                            monthName.isNotEmpty ? monthName : '${_selectedDate.month}-${_selectedDate.year}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          subtitle: const Text('Айлык катышуу аналитикасы'),
                          trailing: OutlinedButton.icon(
                            onPressed: _showMonthPicker,
                            icon: const Icon(Icons.tune, size: 16),
                            label: const Text('Айды тандоо'),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Overall Monthly Statistics Card (Жалпы статистика)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Card(
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.analytics_outlined, color: AppTheme.primaryColor, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'Жалпы айлык статистика',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 20),

                              // Top Row Metrics: Days
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildStatColumn('Күндөр', '$totalDays күн', const Color(0xFF0F172A)),
                                  _buildStatColumn('Өз убагында', '$onTimeDays күн', AppTheme.successColor),
                                  _buildStatColumn('Кечикти', '$lateDays күн', Colors.orange),
                                  if (excusedDays > 0)
                                    _buildStatColumn('Себептүү', '$excusedDays күн', Colors.blue),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Bottom Metrics: Minutes & Hours (Минута боюнча так эсеп)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Row(
                                  children: [
                                    // Total Late Minutes
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Row(
                                            children: [
                                              Icon(Icons.timer_outlined, size: 14, color: Colors.orange),
                                              SizedBox(width: 4),
                                              Text(
                                                'Жалпы кечигүү:',
                                                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _formatMinutes(totalLateMinutes),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.orange,
                                            ),
                                          ),
                                          Text(
                                            '($totalLateMinutes мүнөт)',
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      width: 1,
                                      height: 38,
                                      color: const Color(0xFFCBD5E1),
                                    ),
                                    const SizedBox(width: 16),

                                    // Total Worked Minutes / Hours
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Row(
                                            children: [
                                              Icon(Icons.access_time_filled, size: 14, color: AppTheme.primaryColor),
                                              SizedBox(width: 4),
                                              Text(
                                                'Жалпы иштеди:',
                                                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _formatMinutes(totalWorkedMinutes),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.primaryColor,
                                            ),
                                          ),
                                          Text(
                                            '($totalWorkedMinutes мүнөт)',
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Filter Chips Row
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip('ALL', 'Бардыгы ($totalDays)'),
                            const SizedBox(width: 8),
                            _buildFilterChip('ON_TIME', 'Өз убагында ($onTimeDays)'),
                            const SizedBox(width: 8),
                            _buildFilterChip('LATE', 'Кечиккен ($lateDays)'),
                            if (excusedDays > 0) ...[
                              const SizedBox(width: 8),
                              _buildFilterChip('EXCUSED', 'Себептүү ($excusedDays)'),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),

                  // List of records or Empty state
                  if (filteredRecords.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history_toggle_off, size: 64, color: Color(0xFF94A3B8)),
                            SizedBox(height: 12),
                            Text(
                              'Бул айда каттоо тарыхы жок',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final item = filteredRecords[index];
                            final checkIn = _formatTime(item.checkInTime);
                            final checkOut = _formatTime(item.checkOutTime);

                            Color statusColor = AppTheme.successColor;
                            String statusLabel = 'Өз убагында';

                            if (item.status == 'LATE') {
                              statusColor = Colors.orange;
                              statusLabel = 'Кечиккен (+${item.lateMinutes} мүн)';
                            } else if (item.status == 'EXCUSED') {
                              statusColor = Colors.blue;
                              statusLabel = 'Себептүү';
                            } else if (item.status == 'ABSENT') {
                              statusColor = AppTheme.errorColor;
                              statusLabel = 'Келген жок';
                            }

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Row 1: Date & Status Badge
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _formatDate(item.date),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 15,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: statusColor.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            statusLabel,
                                            style: TextStyle(
                                              color: statusColor,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 18),

                                    // Row 2: Check-in / Check-out / Minutes
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        // Check-in
                                        Row(
                                          children: [
                                            const Icon(Icons.login, size: 18, color: AppTheme.primaryColor),
                                            const SizedBox(width: 6),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text('Келүү', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                                Text(checkIn, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                              ],
                                            ),
                                          ],
                                        ),

                                        // Check-out
                                        Row(
                                          children: [
                                            const Icon(Icons.logout, size: 18, color: AppTheme.secondaryColor),
                                            const SizedBox(width: 6),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text('Кетүү', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                                Text(checkOut, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                              ],
                                            ),
                                          ],
                                        ),

                                        // Total Worked Duration (Hours and Minutes)
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            const Text('Иштеген убакыт', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                            Text(
                                              _formatMinutes(item.workedMinutes),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                            Text(
                                              '(${item.workedMinutes} мүн)',
                                              style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),

                                    // Row 3: Late breakdown if late
                                    if (item.lateMinutes > 0) ...[
                                      const SizedBox(height: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange),
                                            const SizedBox(width: 6),
                                            Text(
                                              'Кечигүү: ${item.lateMinutes} мүнөт (${_formatMinutes(item.lateMinutes)})',
                                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.orange),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],

                                    // Manual Correction Note
                                    if (item.isManuallyCorrected && item.correctionReason != null) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        children: [
                                          const Icon(Icons.verified_user, size: 14, color: Colors.blue),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              'Админ оңдогон себеби: ${item.correctionReason}',
                                              style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.blueGrey),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                          childCount: filteredRecords.length,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String filterKey, String label) {
    final isSelected = _selectedFilter == filterKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppTheme.primaryColor.withValues(alpha: 0.15),
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primaryColor : const Color(0xFF64748B),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 13,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedFilter = filterKey);
        }
      },
    );
  }
}
