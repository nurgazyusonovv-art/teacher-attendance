import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_mobile/core/utils/datetime_utils.dart';

void main() {
  _timezoneRegressionTests();

  group('formatSchoolTime', () {
    test('renders the wall clock the server sent, whatever the offset', () {
      // The backend localizes to school.timezone before serializing, so the
      // time in the string is already the one to display.
      expect(
        DateTimeUtils.formatSchoolTime('2026-09-18T08:07:00+06:00'),
        '08:07',
      );
      // A school on another timezone used to be shifted by a hardcoded +6.
      expect(
        DateTimeUtils.formatSchoolTime('2026-09-18T08:07:00+03:00'),
        '08:07',
      );
      expect(
        DateTimeUtils.formatSchoolTime('2026-09-18T23:45:00-05:00'),
        '23:45',
      );
    });

    test('a naive timestamp with microseconds is not treated as UTC', () {
      // This is the regression: the old check was
      // `contains('-') && length > 19`, and every ISO date contains dashes, so
      // a microsecond timestamp was shifted six hours forward.
      expect(
        DateTimeUtils.formatSchoolTime('2026-09-18T08:07:00.123456'),
        '08:07',
      );
      expect(DateTimeUtils.formatSchoolTime('2026-09-18T08:07:00'), '08:07');
    });

    test('accepts bare time values from schedule fields', () {
      expect(DateTimeUtils.formatSchoolTime('08:00:00'), '08:00');
      expect(DateTimeUtils.formatSchoolTime('17:30'), '17:30');
    });

    test('space separated timestamps are handled', () {
      expect(DateTimeUtils.formatSchoolTime('2026-09-18 08:07:00'), '08:07');
    });

    test('missing or unparsable values render as a placeholder', () {
      expect(DateTimeUtils.formatSchoolTime(null), '--:--');
      expect(DateTimeUtils.formatSchoolTime(''), '--:--');
      expect(DateTimeUtils.formatSchoolTime('   '), '--:--');
      expect(DateTimeUtils.formatSchoolTime('not a time'), '--:--');
    });

    test('a DateTime is rendered as given, never shifted', () {
      expect(
        DateTimeUtils.formatSchoolTime(DateTime(2026, 9, 18, 8, 7)),
        '08:07',
      );
    });
  });

  group('Kyrgyz formatting', () {
    test('formats a date with month and weekday names', () {
      expect(
        DateTimeUtils.formatKyrgyzDate(DateTime(2026, 9, 18)),
        '18-сентябрь 2026, Жума',
      );
    });

    test('formats month and year', () {
      expect(
        DateTimeUtils.formatKyrgyzMonthYear(DateTime(2026, 9, 18)),
        'Сентябрь 2026',
      );
    });

    test('day names are indexed from Monday', () {
      expect(DateTimeUtils.getDayName(0), 'Дүйшөмбү');
      expect(DateTimeUtils.getDayName(6), 'Жекшемби');
      expect(DateTimeUtils.formatShortDay(0), 'Дүй');
    });
  });
}

void _timezoneRegressionTests() {
  group('formatSchoolTime with a known school offset', () {
    // The columns are TIMESTAMPTZ, so a server that forgets to localize sends
    // UTC. Rendering that literally showed 08:57 for a 14:57 check-in.
    test('a UTC timestamp is converted, not shown literally', () {
      expect(
        DateTimeUtils.formatSchoolTime(
          '2026-09-18T08:57:43.020697Z',
          utcOffsetMinutes: 360,
        ),
        '14:57',
      );
    });

    test('an already localized timestamp survives the round trip', () {
      expect(
        DateTimeUtils.formatSchoolTime(
          '2026-09-18T14:57:43+06:00',
          utcOffsetMinutes: 360,
        ),
        '14:57',
      );
    });

    test('the offset used is the school\'s, not the string\'s', () {
      expect(
        DateTimeUtils.formatSchoolTime(
          '2026-09-18T08:57:43Z',
          utcOffsetMinutes: -300,
        ),
        '03:57',
      );
    });

    test('a bare schedule time is left alone', () {
      expect(
        DateTimeUtils.formatSchoolTime('08:00:00', utcOffsetMinutes: 360),
        '08:00',
      );
    });

    test('without an offset the wall clock is taken as sent', () {
      expect(
        DateTimeUtils.formatSchoolTime('2026-09-18T14:57:43+06:00'),
        '14:57',
      );
    });
  });
}
