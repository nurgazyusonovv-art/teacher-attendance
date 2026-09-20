import 'package:flutter/material.dart';

import '../../../../core/utils/datetime_utils.dart';
import '../../../../core/utils/school_clock.dart';
import '../../data/repositories/attendance_repository.dart';

const _ink = Color(0xFF0F172A);
const _muted = Color(0xFF64748B);
const _line = Color(0xFFE2E8F0);
const _surface = Color(0xFFF6F7F9);
const _good = Color(0xFF16A34A);

/// The white header: who is signed in, and whether the app can reach the API.
class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.fullName,
    required this.subtitle,
    required this.online,
    required this.onProfile,
  });

  final String fullName;
  /// The school's name once loaded; a static label before then.
  final String subtitle;

  /// False while the screen is showing a cached response.
  final bool online;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final initials = fullName.trim().isEmpty
        ? '?'
        : fullName.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0]).join();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: 'Профиль',
            child: InkWell(
              onTap: onProfile,
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: _surface,
                    child: Text(
                      initials.toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: _ink,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: online ? _good : Colors.amber.shade700,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12.5, color: _muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: _Pill(
              text: online ? 'Иштеп жатат' : 'Сакталган',
              color: online ? _good : Colors.amber.shade800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The school's clock and today's date.
///
/// The time comes from the server, never the device — see [SchoolClock].
class HomeClock extends StatelessWidget {
  const HomeClock({
    super.key,
    required this.clock,
    required this.date,
    required this.statusLabel,
    required this.statusColor,
  });

  final SchoolClock? clock;
  final DateTime date;
  final String statusLabel;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Semantics(
          liveRegion: true,
          label: clock == null
              ? 'Мектептин убактысы жеткиликсиз'
              : 'Мектептеги убакыт ${clock!.formatted()}',
          child: Text(
            clock?.formatted() ?? '--:--',
            style: const TextStyle(
              fontSize: 52,
              fontWeight: FontWeight.w700,
              color: _ink,
              height: 1.05,
              letterSpacing: -1,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(
            children: [
              const WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Icon(
                    Icons.calendar_today_outlined,
                    size: 13,
                    color: _muted,
                  ),
                ),
              ),
              TextSpan(text: DateTimeUtils.formatKyrgyzDate(date)),
            ],
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12.5, color: _muted),
        ),
        const SizedBox(height: 4),
        Text(
          statusLabel,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: statusColor,
          ),
        ),
      ],
    );
  }
}

/// The check-in / check-out pair.
class HomeStamps extends StatelessWidget {
  const HomeStamps({super.key, required this.today});

  final TodayStatusModel today;

  @override
  Widget build(BuildContext context) {
    final late = today.lateMinutes;
    final worked = today.workedMinutes;
    // The Row stretches its children to equal heights, which needs a bounded
    // height — inside a ListView there is none without this.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _StampCard(
              icon: Icons.login_rounded,
              title: 'КЕЛҮҮ',
              time: DateTimeUtils.formatSchoolTime(
                today.checkInTime,
                utcOffsetMinutes: today.utcOffsetMinutes,
              ),
              done: today.hasCheckedIn,
              caption: today.hasCheckedIn
                  ? (late > 0 ? '$late мүнөт кечигүү' : 'Өз убагында')
                  : 'Каттала элек',
              captionColor: today.hasCheckedIn && late == 0 ? _good : _muted,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StampCard(
              icon: Icons.logout_rounded,
              title: 'КЕТҮҮ',
              time: DateTimeUtils.formatSchoolTime(
                today.checkOutTime,
                utcOffsetMinutes: today.utcOffsetMinutes,
              ),
              done: today.hasCheckedOut,
              caption: today.hasCheckedOut
                  ? '${worked ~/ 60} саат ${worked % 60} мүн'
                  : 'Каттала элек',
              captionColor: _muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _StampCard extends StatelessWidget {
  const _StampCard({
    required this.icon,
    required this.title,
    required this.time,
    required this.done,
    required this.caption,
    required this.captionColor,
  });

  final IconData icon;
  final String title;
  final String time;
  final bool done;
  final String caption;
  final Color captionColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: done ? _good.withValues(alpha: 0.35) : _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: done ? _good : _muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: done ? _good : _muted,
                  ),
                ),
              ),
              Icon(
                done ? Icons.check_circle : Icons.circle_outlined,
                size: 16,
                color: done ? _good : _line,
              ),
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              time,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, color: captionColor),
          ),
        ],
      ),
    );
  }
}

/// The dark scan card — the screen's primary action.
class HomeScanCard extends StatelessWidget {
  const HomeScanCard({
    super.key,
    required this.enabled,
    required this.title,
    required this.subtitle,
    required this.footnote,
    required this.onScan,
  });

  final bool enabled;
  final String title;
  final String subtitle;
  final String footnote;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: enabled ? onScan : null,
      style: FilledButton.styleFrom(
        backgroundColor: _ink,
        disabledBackgroundColor: const Color(0xFF334155),
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white70,
        padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.qr_code_scanner_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 12.5,
              height: 1.35,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 13,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    footnote,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Recent days, newest first.
class HomeHistory extends StatelessWidget {
  const HomeHistory({
    super.key,
    required this.days,
    required this.onSeeAll,
    this.loading = false,
  });

  final List<DailyAttendanceModel> days;
  final VoidCallback onSeeAll;
  final bool loading;

  static const _short = ['ДҮЙ', 'ШЕЙ', 'ШАР', 'БЕЙ', 'ЖУМ', 'ИШМ', 'ЖЕК'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Акыркы күндөрдүн тарыхы',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
            ),
            TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Баары', style: TextStyle(fontSize: 12.5)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (days.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Text(
              'Азырынча каттоо жок.',
              style: TextStyle(color: _muted, fontSize: 13),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _line),
            ),
            child: Column(
              children: [
                for (var i = 0; i < days.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: _line),
                  _row(days[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _row(DailyAttendanceModel day) {
    final parsed = DateTime.tryParse(day.date);
    final label = parsed == null
        ? '—'
        : _short[(parsed.weekday - 1).clamp(0, 6)];
    final worked = day.workedMinutes;
    final subtitle = day.checkOutTime != null
        ? '${worked ~/ 60} саат ${worked % 60} мүн'
        : day.checkInTime != null
        ? 'Иштеп жатат'
        : attendanceStatusWord(day.status);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  parsed == null
                      ? day.date
                      : DateTimeUtils.formatKyrgyzDate(parsed),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: _ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: _muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${DateTimeUtils.formatSchoolTime(day.checkInTime)} — '
            '${DateTimeUtils.formatSchoolTime(day.checkOutTime)}',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: _ink,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// A short word for a day's recorded status.
String attendanceStatusWord(String? status) => switch (status) {
  'EXCUSED' => 'Уруксат берилген',
  'DAY_OFF' => 'Дем алыш',
  'ABSENT' => 'Келген жок',
  _ => 'Катталган эмес',
};
