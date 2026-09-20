/// The school's clock, anchored to the server rather than the device.
///
/// Attendance is decided by the server's clock (AGENTS.md §5). A phone running
/// minutes behind would otherwise show a teacher that they are comfortably on
/// time while the server is recording them late, so the home screen ticks
/// forward from the moment the server answered instead of reading the device.
///
/// The device clock is still used for *elapsed* time since that response,
/// which is safe: a wrong wall clock does not make seconds pass at a
/// different rate, and a stale anchor is corrected on the next refresh.
class SchoolClock {
  const SchoolClock._({required this.anchor, required this.capturedAt});

  /// The school's wall time reported by the server.
  final DateTime anchor;

  /// The device reading when that response arrived.
  final DateTime capturedAt;

  /// Builds a clock from `server_time`, or null when the server sent none —
  /// an older backend, or a cached response from before this existed.
  static final RegExp _zone = RegExp(r'(Z|[+-]\d{2}:?\d{2})$');

  static SchoolClock? fromServerTime(String? serverTime, {DateTime? now}) {
    if (serverTime == null || serverTime.isEmpty) return null;
    // The server sends the school's wall clock with its offset attached.
    // Dropping the offset keeps those components as-is; parsing with it would
    // convert into the device's zone, which is not what is displayed.
    final wallClock = serverTime.trim().replaceFirst(_zone, '');
    final anchor = DateTime.tryParse(wallClock);
    if (anchor == null) return null;
    return SchoolClock._(anchor: anchor, capturedAt: now ?? DateTime.now());
  }

  /// The school's time now, moved on by however long the app has been holding
  /// this response.
  DateTime now({DateTime? deviceNow}) {
    final elapsed = (deviceNow ?? DateTime.now()).difference(capturedAt);
    // A device clock that jumps backwards must not rewind the display.
    return anchor.add(elapsed.isNegative ? Duration.zero : elapsed);
  }

  /// `HH:mm` for display.
  String formatted({DateTime? deviceNow}) {
    final value = now(deviceNow: deviceNow);
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  /// How stale the anchor is. The screen refreshes long before this matters,
  /// but a device resumed after hours should not be trusted to the minute.
  Duration age({DateTime? deviceNow}) {
    final elapsed = (deviceNow ?? DateTime.now()).difference(capturedAt);
    return elapsed.isNegative ? Duration.zero : elapsed;
  }
}
