import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/datetime_utils.dart';
import '../../../attendance/data/repositories/attendance_repository.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final AttendanceRepository _attendanceRepository = AttendanceRepository();

  List<DailyAttendanceModel> _records = [];
  bool _isLoading = true;
  String _selectedFilter = 'ALL';
  DateTime _currentMonth = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final list = await _attendanceRepository.getMyHistory(
      year: _currentMonth.year,
      month: _currentMonth.month,
    );
    if (mounted) {
      setState(() {
        _records = list;
        _isLoading = false;
      });
    }
  }

  void _changeMonth(int offset) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + offset);
    });
    _loadHistory();
  }

  String _formatTime(String? isoString) {
    return DateTimeUtils.formatBishkekTime(isoString);
  }

  String _formatMonthYear(DateTime dt) {
    return DateTimeUtils.formatKyrgyzMonthYear(dt);
  }

  String _formatDayOfWeek(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return DateTimeUtils.formatShortDay(dt.weekday - 1);
    } catch (_) {
      return '';
    }
  }

  String _formatDayNumber(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return dt.day.toString().padLeft(2, '0');
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final onTimeCount = _records.where((r) => r.status == 'ON_TIME').length;
    final lateCount = _records.where((r) => r.status == 'LATE').length;
    final excusedCount = _records.where((r) => r.status == 'EXCUSED').length;
    final totalDays = _records.length;

    final onTimeRate = totalDays > 0 ? ((onTimeCount / totalDays) * 100).toStringAsFixed(0) : '0';

    final totalLateMinutes = _records.fold<int>(0, (sum, r) => sum + r.lateMinutes);
    final totalWorkedMinutes = _records.fold<int>(0, (sum, r) => sum + r.workedMinutes);

    final lateHours = totalLateMinutes ~/ 60;
    final lateMins = totalLateMinutes % 60;
    final workedHours = totalWorkedMinutes ~/ 60;
    final workedMins = totalWorkedMinutes % 60;

    final filteredRecords = _records.where((r) {
      if (_selectedFilter == 'ALL') return true;
      return r.status == _selectedFilter;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Каттоо тарыхы'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadHistory,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          children: [
            // Month Selector Carousel
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderColor),
                boxShadow: const [
                  BoxShadow(color: Color(0x06000000), blurRadius: 8, offset: Offset(0, 2)),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: () => _changeMonth(-1),
                    color: AppTheme.primaryColor,
                  ),
                  Flexible(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_month_rounded, size: 18, color: AppTheme.primaryColor),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _formatMonthYear(_currentMonth),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded),
                    onPressed: () => _changeMonth(1),
                    color: AppTheme.primaryColor,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Monthly Statistics Card with Circular Rate
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppTheme.borderColor),
                boxShadow: const [
                  BoxShadow(color: Color(0x08000000), blurRadius: 16, offset: Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.analytics_rounded, size: 18, color: AppTheme.primaryColor),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Жалпы айлык көрсөткүчтөр',
                          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Circular Rate + Metric Grid
                  Row(
                    children: [
                      // Progress Ring
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 68,
                            height: 68,
                            child: CircularProgressIndicator(
                              value: totalDays > 0 ? (onTimeCount / totalDays) : 0,
                              strokeWidth: 6.5,
                              backgroundColor: const Color(0xFFF1F5F9),
                              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.successColor),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '$onTimeRate%',
                                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                              ),
                              const Text(
                                'өз уб.',
                                style: TextStyle(fontSize: 8.5, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),

                      // Metric counts
                      Expanded(
                        child: GridView.count(
                          crossAxisCount: 2,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          childAspectRatio: 1.6,
                          crossAxisSpacing: 6,
                          mainAxisSpacing: 6,
                          children: [
                            _buildStatBadge('Күндөр', '$totalDays', AppTheme.primaryColor),
                            _buildStatBadge('Өз уб.', '$onTimeCount', AppTheme.successColor),
                            _buildStatBadge('Кечикти', '$lateCount', Colors.orange),
                            _buildStatBadge('Себептүү', '$excusedCount', Colors.blue),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Minute Breakdown Footer
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.borderColor),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.timer_outlined, size: 14, color: Colors.orange),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Кечигүү: ${lateHours > 0 ? "$lateHours с " : ""}$lateMins мүн',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.orange),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Row(
                            children: [
                              const Icon(Icons.work_outline_rounded, size: 14, color: AppTheme.successColor),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  'Иштеди: $workedHours с $workedMins мүн',
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.successColor),
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
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('Бардыгы ($totalDays)', 'ALL'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Өз убагында ($onTimeCount)', 'ON_TIME'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Кечиккен ($lateCount)', 'LATE'),
                  const SizedBox(width: 8),
                  _buildFilterChip('Себептүү ($excusedCount)', 'EXCUSED'),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Record List
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(40.0),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (filteredRecords.isEmpty)
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
                    Icon(Icons.event_busy_rounded, size: 48, color: AppTheme.textMuted.withValues(alpha: 0.5)),
                    const SizedBox(height: 12),
                    const Text(
                      'Бул чыпка боюнча жазуулар жок',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              )
            else
              ...filteredRecords.map((r) {
                Color statusColor = AppTheme.successColor;
                String statusText = 'Өз убагында';

                if (r.status == 'LATE') {
                  statusColor = Colors.orange;
                  statusText = 'Кечиккен (+${r.lateMinutes} мүн)';
                } else if (r.status == 'EXCUSED') {
                  statusColor = Colors.blue;
                  statusText = 'Себептүү';
                } else if (r.status == 'ABSENT') {
                  statusColor = Colors.red;
                  statusText = 'Келген жок';
                }

                final checkIn = _formatTime(r.checkInTime);
                final checkOut = _formatTime(r.checkOutTime);
                final dayNumber = _formatDayNumber(r.date);
                final dayOfWeek = _formatDayOfWeek(r.date);

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppTheme.borderColor),
                    boxShadow: const [
                      BoxShadow(color: Color(0x04000000), blurRadius: 8, offset: Offset(0, 2)),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Date Badge on Left
                      Container(
                        width: 44,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Text(
                              dayNumber,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                            ),
                            Text(
                              dayOfWeek,
                              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Time Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.login_rounded, size: 13, color: AppTheme.successColor),
                                    const SizedBox(width: 3),
                                    Text('Келди: $checkIn', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: statusColor.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    statusText,
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.logout_rounded, size: 13, color: AppTheme.secondaryColor),
                                    const SizedBox(width: 3),
                                    Text('Кетти: $checkOut', style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
                                  ],
                                ),
                                const Spacer(),
                                if (r.workedMinutes > 0)
                                  Text(
                                    '${r.workedMinutes ~/ 60}с ${r.workedMinutes % 60}мүн',
                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBadge(String title, String val, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(val, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: color)),
          Text(
            title,
            style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? AppTheme.primaryColor : AppTheme.borderColor),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}
