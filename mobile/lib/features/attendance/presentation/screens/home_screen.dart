import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/datetime_utils.dart';
import '../../../../core/utils/attendance_presentation.dart';
import '../../../auth/presentation/cubit/auth_cubit.dart';
import '../../../auth/presentation/cubit/auth_state.dart';
import '../../data/repositories/attendance_repository.dart';
import '../cubit/attendance_cubit.dart';
import '../cubit/attendance_state.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() => context.read<AttendanceCubit>().loadTodayStatus();
  Future<void> _scan(TodayStatusModel today) async {
    await context.push(
      today.hasCheckedIn ? '/scanner?checkout=true' : '/scanner',
    );
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthCubit>().state;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Мугалим Каттоо'),
        actions: [
          IconButton(
            tooltip: 'Профиль',
            icon: const Icon(Icons.person_outline),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(20),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Text(
                auth is Authenticated
                    ? 'Саламатсызбы, ${auth.user.fullName}!'
                    : 'Саламатсызбы!',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (auth is Authenticated && auth.user.isDemo)
                const Text('Демо аккаунт'),
              const SizedBox(height: 24),
              BlocBuilder<AttendanceCubit, AttendanceState>(
                builder: (context, state) {
                  if (state is AttendanceTodayLoaded) {
                    return Column(
                      children: [
                        if (state.cached) ...[
                          const Text(
                            'Акыркы сакталган маалымат. Каттоо үчүн маалыматты жаңыртыңыз.',
                          ),
                          TextButton(
                            onPressed: _refresh,
                            child: const Text('Жаңыртуу'),
                          ),
                        ],
                        _today(state.status, cached: state.cached),
                      ],
                    );
                  }
                  if (state is AttendanceError) {
                    return Column(
                      children: [
                        const Icon(Icons.cloud_off_outlined, size: 40),
                        const SizedBox(height: 12),
                        const Text(
                          'Бүгүнкү маалымат жүктөлгөн жок. Интернет байланышын текшерип, кайра аракет кылыңыз.',
                          textAlign: TextAlign.center,
                        ),
                        OutlinedButton(
                          onPressed: _refresh,
                          child: const Text('Кайра аракет кылуу'),
                        ),
                      ],
                    );
                  }
                  return const Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 12),
                      Text('Бүгүнкү маалымат жүктөлүүдө…'),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                onPressed: () async {
                  await context.push('/leaves');
                  if (mounted) await _refresh();
                },
                icon: const Icon(Icons.event_available),
                label: const Text('Уруксат суроо жана арыздарым'),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  await context.push('/history');
                  if (mounted) await _refresh();
                },
                icon: const Icon(Icons.history),
                label: const Text('Каттоо тарыхы'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _today(TodayStatusModel today, {bool cached = false}) {
    final status =
        today.displayStatus ??
        today.status ??
        (today.isDayOff ? 'DAY_OFF' : 'UNKNOWN');
    final canScan =
        ['PENDING', 'ABSENT', 'ON_TIME', 'LATE'].contains(status) &&
        !today.hasCheckedOut &&
        !cached;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (today.schoolName?.isNotEmpty == true) Text(today.schoolName!),
        Text(DateTimeUtils.formatKyrgyzDate(DateTime.parse(today.date))),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Бүгүнкү статус'),
                const SizedBox(height: 8),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    todayStatusLabel(status),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                const SizedBox(height: 16),
                Text(attendanceGuidance(status, today.hasCheckedOut)),
                const SizedBox(height: 12),
                Text(
                  today.isDayOff
                      ? 'Дем алыш күнү'
                      : today.scheduledStart == null ||
                            today.scheduledEnd == null
                      ? 'График дайындалган эмес. Администраторго кайрылыңыз.'
                      : 'Иш убактысы: ${DateTimeUtils.formatSchoolTime(today.scheduledStart)} — ${DateTimeUtils.formatSchoolTime(today.scheduledEnd)}',
                ),
                const Divider(height: 28),
                Text(
                  'Келүү: ${DateTimeUtils.formatSchoolTime(today.checkInTime)}',
                ),
                const SizedBox(height: 8),
                Text(
                  'Кетүү: ${DateTimeUtils.formatSchoolTime(today.checkOutTime)}',
                ),
                if (today.totalLateMinutes > 0) ...[
                  const SizedBox(height: 8),
                  Text('Жалпы кечигүү: ${today.totalLateMinutes} мүнөт'),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: canScan ? () => _scan(today) : null,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          ),
          icon: Icon(
            today.hasCheckedOut
                ? Icons.check_circle_outline
                : Icons.qr_code_scanner,
          ),
          label: Text(
            today.hasCheckedOut
                ? 'Бүгүнкү каттоо бүттү'
                : today.hasCheckedIn
                ? 'Кетүүнү каттоо'
                : canScan
                ? 'QR менен келүүнү каттоо'
                : 'Каттоо жеткиликсиз',
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Мектептеги QR-кодду сканерлеңиз. Камера жана жайгашкан жер каттоо учурунда гана колдонулат.',
          textAlign: TextAlign.center,
        ),
      ],
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
