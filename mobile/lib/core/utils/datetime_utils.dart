import 'package:intl/intl.dart';

class DateTimeUtils {
  /// Matches the wall-clock time at the start of an ISO timestamp, or a bare
  /// `HH:mm` / `HH:mm:ss`.
  static final RegExp _wallClock = RegExp(
    r'^(?:\d{4}-\d{2}-\d{2}[T ])?(\d{2}):(\d{2})',
  );

  /// Renders a server time as `HH:mm`.
  ///
  /// The backend already localizes every timestamp to the school's timezone
  /// (`school.timezone`), so the wall clock it sends is the one to show. This
  /// used to add a hardcoded six hours, which was wrong for any school outside
  /// UTC+6 and double-counted a naive timestamp carrying microseconds.
  static String formatSchoolTime(dynamic value) {
    if (value == null) return '--:--';
    if (value is DateTime) return DateFormat('HH:mm').format(value);

    final text = value.toString().trim();
    if (text.isEmpty) return '--:--';

    final match = _wallClock.firstMatch(text);
    if (match != null) return '${match.group(1)}:${match.group(2)}';
    return '--:--';
  }

  /// Formats date in Kyrgyz language (e.g., "24-август 2026, Дүйшөмбү")
  static String formatKyrgyzDate(DateTime dt) {
    final months = [
      'январь', 'февраль', 'март', 'апрель', 'май', 'июнь',
      'июль', 'август', 'сентябрь', 'октябрь', 'ноябрь', 'декабрь'
    ];
    final days = [
      'Дүйшөмбү', 'Шейшемби', 'Шаршемби', 'Бейшемби', 'Жума', 'Ишемби', 'Жекшемби'
    ];

    final monthName = (dt.month >= 1 && dt.month <= 12) ? months[dt.month - 1] : '';
    final dayName = (dt.weekday >= 1 && dt.weekday <= 7) ? days[dt.weekday - 1] : '';

    return '${dt.day}-$monthName ${dt.year}, $dayName';
  }

  /// Formats Month and Year in Kyrgyz (e.g., "Август 2026")
  static String formatKyrgyzMonthYear(DateTime dt) {
    final months = [
      'Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
      'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'
    ];
    final monthName = (dt.month >= 1 && dt.month <= 12) ? months[dt.month - 1] : '';
    return '$monthName ${dt.year}';
  }

  /// Formats short day of week in Kyrgyz (e.g., "Дүй")
  static String formatShortDay(int weekdayIndex) {
    const shortDays = ['Дүй', 'Шей', 'Шар', 'Бей', 'Жум', 'Ишм', 'Жек'];
    if (weekdayIndex >= 0 && weekdayIndex < shortDays.length) {
      return shortDays[weekdayIndex];
    }
    return '';
  }

  /// Full day name in Kyrgyz (0 = Monday, 6 = Sunday)
  static String getDayName(int dayOfWeek) {
    const dayNames = [
      'Дүйшөмбү',
      'Шейшемби',
      'Шаршемби',
      'Бейшемби',
      'Жума',
      'Ишемби',
      'Жекшемби',
    ];
    if (dayOfWeek >= 0 && dayOfWeek < dayNames.length) {
      return dayNames[dayOfWeek];
    }
    return 'Дүйшөмбү';
  }
}
