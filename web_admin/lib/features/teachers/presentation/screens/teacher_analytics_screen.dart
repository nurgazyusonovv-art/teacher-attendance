import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/repositories/teachers_repository.dart';
import '../../domain/teacher_analytics.dart';
import '../../../attendance/data/repositories/admin_attendance_repository.dart';
import '../../../attendance/presentation/widgets/attendance_details.dart';

class TeacherAnalyticsScreen extends StatefulWidget {
  const TeacherAnalyticsScreen({
    super.key,
    required this.teacherId,
    this.repository,
    this.attendanceRepository,
  });
  final String teacherId;
  final TeachersRepository? repository;
  final AdminAttendanceRepository? attendanceRepository;
  @override
  State<TeacherAnalyticsScreen> createState() => _TeacherAnalyticsScreenState();
}

class _TeacherAnalyticsScreenState extends State<TeacherAnalyticsScreen> {
  TeacherItem? _teacher;
  List<AdminDailyAttendanceItem> _history = [];
  String? _today;
  bool _loading = true;
  bool _failed = false;
  int _days = 30;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant TeacherAnalyticsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.teacherId != widget.teacherId) {
      _load();
    }
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final repository = widget.repository ?? TeachersRepository();
      final teacher = await repository.getTeacher(widget.teacherId);
      final history = await repository.getHistory(widget.teacherId);
      final dashboard =
          await (widget.attendanceRepository ?? AdminAttendanceRepository())
              .getTodayDashboard();
      if (dashboard == null) {
        throw StateError('School date unavailable');
      }
      if (!mounted || request != _request) {
        return;
      }
      setState(() {
        _teacher = teacher;
        _history = history;
        _today = dashboard.date;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || request != _request) {
        return;
      }
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_failed) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Маалымат жүктөлгөн жок же көрүүгө уруксат жок.'),
            TextButton(onPressed: _load, child: const Text('Кайра жүктөө')),
            TextButton(
              onPressed: () => context.go('/teachers'),
              child: const Text('Мугалимдерге кайтуу'),
            ),
          ],
        ),
      );
    }
    final teacher = _teacher!;
    final stats = TeacherAnalytics(_history, _today!, _days);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Мугалимдерге кайтуу',
                onPressed: () => context.go('/teachers'),
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: Text(
                  teacher.fullName,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Жаңылоо',
                onPressed: _load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text(teacher.isActive ? 'Активдүү' : 'Активдүү эмес'),
                ),
                if (teacher.isDemo)
                  const Chip(label: Text('DEMO • Сыноо аккаунту')),
                Chip(label: Text('Табель: ${teacher.employeeCode}')),
                if (teacher.subject != null)
                  Chip(label: Text(teacher.subject!)),
                if (teacher.phoneNumber != null)
                  Chip(label: Text(teacher.phoneNumber!)),
              ],
            ),
          ),
          Wrap(
            spacing: 8,
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
                  onSelected: (_) => setState(() => _days = entry.key),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${_days == 0 ? "Бардык сакталган тарых" : "Акыркы $_days күн"} • ${_today!} чейин • ${stats.records.length} жазуу',
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _metric(
                'Келген күндөр',
                '${stats.checkedIn}',
                Icons.login,
                Colors.blue,
              ),
              _metric(
                'Өз убагында',
                '${stats.onTime}',
                Icons.check_circle_outline,
                Colors.teal,
              ),
              _metric(
                'Кечиккен күндөр',
                '${stats.late}',
                Icons.timer_outlined,
                Colors.orange,
              ),
              _metric(
                'Катталган келбей калуу',
                '${stats.absent}',
                Icons.person_off_outlined,
                Colors.red,
              ),
              _metric(
                'Жалпы кечигүү',
                '${stats.lateMinutes} мүн',
                Icons.schedule,
                Colors.deepOrange,
              ),
              _metric(
                'Катталган иш убактысы',
                '${stats.workedMinutes ~/ 60} с ${stats.workedMinutes % 60} мүн',
                Icons.work_outline,
                Colors.indigo,
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (stats.records.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('Бул мезгилде сакталган каттоолор жок.'),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth > 850
                    ? (constraints.maxWidth - 16) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: width,
                      child: _chart(
                        'Каттоолордун статусу',
                        {
                          for (final e in stats.statuses.entries)
                            attendanceStatus(e.key): e.value,
                        },
                        'күн',
                        Colors.blue,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _chart(
                        'Айлар боюнча жалпы кечигүү',
                        stats.monthlyLate,
                        'мүн',
                        Colors.orange,
                      ),
                    ),
                  ],
                );
              },
            ),
          const SizedBox(height: 16),
          const Text(
            'Булак: катышуу тарыхы. Каттоо жок күндөр келбей калуу деп эсептелбейт. Кечигүүгө сабактагы кечигүү да кошулат; иш убактысы серверде сакталган мааниден алынат.',
            style: TextStyle(color: Colors.blueGrey),
          ),
          const SizedBox(height: 20),
          const Text(
            'Катышуунун деталдуу тарыхы',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 400,
            child: Card(child: AttendanceDetails(records: stats.records)),
          ),
        ],
      ),
    );
  }

  Widget _metric(String title, String value, IconData icon, Color color) =>
      SizedBox(
        width: 220,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color),
                const SizedBox(height: 12),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 8),
                Text(title),
              ],
            ),
          ),
        ),
      );

  Widget _chart(
    String title,
    Map<String, int> values,
    String unit,
    Color color,
  ) {
    final max = values.values.fold(1, (a, b) => a > b ? a : b);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 230,
              child: ListView(
                children: [
                  for (final entry in values.entries)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(entry.key)),
                              Text('${entry.value} $unit'),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Semantics(
                            label: '${entry.key}: ${entry.value} $unit',
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: entry.value / max,
                                minHeight: 16,
                                color: color,
                                backgroundColor: color.withValues(alpha: 0.08),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Text(
              'Масштаб: 0–$max $unit',
              style: const TextStyle(color: Colors.blueGrey),
            ),
          ],
        ),
      ),
    );
  }
}
