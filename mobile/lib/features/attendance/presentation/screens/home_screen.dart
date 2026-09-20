import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/attendance_presentation.dart';
import '../../../../core/utils/school_clock.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../data/repositories/attendance_repository.dart';
import '../cubit/attendance_cubit.dart';
import '../cubit/attendance_state.dart';
import '../widgets/home_sections.dart';

const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _canvas = Color(0xFFF6F7F9);
const _good = Color(0xFF16A34A);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.historyRepository});

  /// Injectable for tests; defaults to the app's authenticated client.
  final AttendanceRepository? historyRepository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late final AttendanceRepository _history =
      widget.historyRepository ?? AttendanceRepository();

  /// Ticks the displayed clock. The value itself comes from the server.
  Timer? _ticker;

  List<DailyAttendanceModel> _recent = const [];
  bool _recentLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _ticker = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // A resumed app may have been asleep for hours; re-anchor the clock.
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    await context.read<AttendanceCubit>().loadTodayStatus();
    await _loadRecent();
  }

  Future<void> _loadRecent() async {
    if (!mounted) return;
    setState(() => _recentLoading = true);
    try {
      final rows = await _history.getMyHistory();
      if (!mounted) return;
      setState(() {
        _recent = rows.take(4).toList();
        _recentLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _recentLoading = false);
    }
  }

  Future<void> _scan(TodayStatusModel today) async {
    await context.push(
      today.hasCheckedIn ? '/scanner?checkout=true' : '/scanner',
    );
    if (mounted) await _refresh();
  }

  Future<void> _go(String route) async {
    await context.push(route);
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthCubit>().state;
    final user = auth is Authenticated ? auth.user : null;

    return Scaffold(
      backgroundColor: _canvas,
      body: SafeArea(
        bottom: false,
        child: BlocBuilder<AttendanceCubit, AttendanceState>(
          builder: (context, state) {
            final loaded = state is AttendanceTodayLoaded ? state : null;
            return Column(
              children: [
                HomeHeader(
                  fullName: user?.fullName ?? 'Мугалим',
                  subtitle: loaded?.status.schoolName?.isNotEmpty == true
                      ? loaded!.status.schoolName!
                      : 'Мугалимдик каттоо',
                  online: loaded == null || !loaded.cached,
                  onProfile: () => _go('/profile'),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
                      children: _body(state),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  List<Widget> _body(AttendanceState state) {
    if (state is AttendanceTodayLoaded) {
      return _loaded(state.status, cached: state.cached);
    }
    if (state is AttendanceError) {
      return [
        const SizedBox(height: 60),
        const Icon(Icons.cloud_off_outlined, size: 44, color: _muted),
        const SizedBox(height: 14),
        const Text(
          'Бүгүнкү маалымат жүктөлгөн жок. Интернет байланышын текшерип, '
          'кайра аракет кылыңыз.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted),
        ),
        const SizedBox(height: 16),
        Center(
          child: OutlinedButton(
            onPressed: _refresh,
            child: const Text('Кайра аракет кылуу'),
          ),
        ),
      ];
    }
    return const [
      SizedBox(height: 80),
      Center(child: CircularProgressIndicator()),
      SizedBox(height: 14),
      Text(
        'Бүгүнкү маалымат жүктөлүүдө…',
        textAlign: TextAlign.center,
        style: TextStyle(color: _muted),
      ),
    ];
  }

  List<Widget> _loaded(TodayStatusModel today, {required bool cached}) {
    final status =
        today.displayStatus ??
        today.status ??
        (today.isDayOff ? 'DAY_OFF' : 'UNKNOWN');
    final canScan =
        ['PENDING', 'ABSENT', 'ON_TIME', 'LATE'].contains(status) &&
        !today.hasCheckedOut &&
        !cached;
    final clock = SchoolClock.fromServerTime(today.serverTime);

    return [
      HomeClock(
        clock: clock,
        date: DateTime.tryParse(today.date) ?? DateTime.now(),
        statusLabel: todayStatusLabel(status),
        statusColor: today.hasCheckedIn ? _good : _muted,
      ),
      const SizedBox(height: 22),
      HomeStamps(today: today),
      const SizedBox(height: 18),
      HomeScanCard(
        enabled: canScan,
        title: today.hasCheckedOut
            ? 'Бүгүнкү каттоо бүттү'
            : today.hasCheckedIn
            ? 'Кетүүнү каттоо'
            : 'QR-кодду скандоо',
        subtitle: attendanceGuidance(status, today.hasCheckedOut),
        footnote: 'Камера жана жайгашкан жер каттоо учурунда гана колдонулат',
        onScan: () => _scan(today),
      ),
      if (cached) ...[
        const SizedBox(height: 12),
        _CachedNotice(onRefresh: _refresh),
      ],
      const SizedBox(height: 14),
      // Leave requests sit directly under the scan card: the second thing a
      // teacher comes here to do, and the one they reach for on a day they
      // cannot scan at all.
      OutlinedButton.icon(
        onPressed: () => _go('/leaves'),
        icon: const Icon(Icons.event_available_outlined, size: 18),
        label: const Text('Уруксат суроо жана арыздарым'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          foregroundColor: _ink,
          side: const BorderSide(color: Color(0xFFE2E8F0)),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      const SizedBox(height: 24),
      HomeHistory(
        days: _recent,
        loading: _recentLoading && _recent.isEmpty,
        onSeeAll: () => _go('/history'),
      ),
    ];
  }
}

class _CachedNotice extends StatelessWidget {
  const _CachedNotice({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Акыркы сакталган маалымат. Каттоо үчүн жаңыртыңыз.',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF92400E)),
            ),
          ),
          TextButton(onPressed: onRefresh, child: const Text('Жаңыртуу')),
        ],
      ),
    );
  }
}

String todayStatusLabel(String status) => attendanceLabel(status);

String attendanceGuidance(String status, bool checkedOut) {
  if (checkedOut) {
    return 'Келүү жана кетүү сакталды. Бүгүн кайра каттоонун кереги жок.';
  }
  return switch (status) {
    'ON_TIME' ||
    'LATE' => 'Келүүңүз сакталды. Мектептен кетерде кетүүнү каттаңыз.',
    'PENDING' ||
    'ABSENT' => 'Мектепке келгенде QR-код аркылуу келүүнү каттаңыз.',
    'EXCUSED' => 'Бүгүнкү уруксатыңыз бекитилген. Каттоонун кереги жок.',
    'DAY_OFF' => 'Бүгүн дем алыш. Каттоонун кереги жок.',
    'NO_SCHEDULE' => 'Иш графигин дайындоо үчүн администраторго кайрылыңыз.',
    _ => 'Маалыматты жаңыртуу үчүн экранды ылдый тартыңыз.',
  };
}
