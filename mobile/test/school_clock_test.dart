import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_mobile/core/utils/school_clock.dart';

void main() {
  group('SchoolClock', () {
    test('shows the wall clock the server sent, not the device zone', () {
      // A device in another zone must still read the school's clock.
      final clock = SchoolClock.fromServerTime(
        '2026-09-18T15:55:00+06:00',
        now: DateTime(2026, 9, 18, 9, 55),
      );
      expect(clock, isNotNull);
      expect(clock!.formatted(deviceNow: DateTime(2026, 9, 18, 9, 55)), '15:55');
    });

    test('a wrong device clock does not move the displayed time', () {
      // The whole point: a phone ten minutes behind must not tell a teacher
      // they are on time while the server records them late.
      final clock = SchoolClock.fromServerTime(
        '2026-09-18T08:05:00+06:00',
        now: DateTime(2026, 9, 18, 7, 55),
      );
      expect(clock!.formatted(deviceNow: DateTime(2026, 9, 18, 7, 55)), '08:05');
    });

    test('ticks forward by however long the response has been held', () {
      final captured = DateTime(2026, 9, 18, 9, 0);
      final clock = SchoolClock.fromServerTime(
        '2026-09-18T15:55:00+06:00',
        now: captured,
      );
      expect(
        clock!.formatted(deviceNow: captured.add(const Duration(minutes: 7))),
        '16:02',
      );
    });

    test('a device clock jumping backwards never rewinds the display', () {
      final captured = DateTime(2026, 9, 18, 9, 0);
      final clock = SchoolClock.fromServerTime(
        '2026-09-18T15:55:00+06:00',
        now: captured,
      );
      expect(
        clock!.formatted(deviceNow: captured.subtract(const Duration(hours: 2))),
        '15:55',
      );
      expect(clock.age(deviceNow: captured.subtract(const Duration(hours: 2))),
          Duration.zero);
    });

    test('handles a Z timestamp and one with no zone at all', () {
      expect(
        SchoolClock.fromServerTime(
          '2026-09-18T15:55:00Z',
          now: DateTime(2026, 9, 18),
        )!.formatted(deviceNow: DateTime(2026, 9, 18)),
        '15:55',
      );
      expect(
        SchoolClock.fromServerTime(
          '2026-09-18T15:55:00',
          now: DateTime(2026, 9, 18),
        )!.formatted(deviceNow: DateTime(2026, 9, 18)),
        '15:55',
      );
    });

    test('is absent when the server sent nothing usable', () {
      // An older backend, or a cached response from before the field existed.
      expect(SchoolClock.fromServerTime(null), isNull);
      expect(SchoolClock.fromServerTime(''), isNull);
      expect(SchoolClock.fromServerTime('not a time'), isNull);
    });

    test('reports how stale the anchor is', () {
      final captured = DateTime(2026, 9, 18, 9, 0);
      final clock = SchoolClock.fromServerTime(
        '2026-09-18T15:55:00+06:00',
        now: captured,
      );
      expect(
        clock!.age(deviceNow: captured.add(const Duration(minutes: 3))),
        const Duration(minutes: 3),
      );
    });
  });
}
