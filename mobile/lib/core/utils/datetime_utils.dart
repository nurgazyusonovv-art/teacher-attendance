import 'package:intl/intl.dart';

class DateTimeUtils {
  /// Returns current DateTime localized to Asia/Bishkek (UTC+6)
  static DateTime get bishkekNow {
    return DateTime.now().toUtc().add(const Duration(hours: 6));
  }

  /// Converts any ISO datetime or time string to Bishkek time (HH:mm)
  static String formatBishkekTime(dynamic value) {
    if (value == null) return '--:--';
    if (value is DateTime) {
      final bishkek = value.isUtc ? value.add(const Duration(hours: 6)) : value;
      return DateFormat('HH:mm').format(bishkek);
    }
    final str = value.toString().trim();
    if (str.isEmpty) return '--:--';

    // If string is already in HH:mm or HH:mm:ss format
    if (RegExp(r'^\d{2}:\d{2}(:\d{2})?$').hasMatch(str)) {
      return str.substring(0, 5);
    }

    try {
      final parsed = DateTime.parse(str);
      // If parsed contains UTC timezone 'Z' or offset, convert to Bishkek
      if (str.endsWith('Z') || str.contains('+') || str.contains('-') && str.length > 19) {
        final bishkek = parsed.toUtc().add(const Duration(hours: 6));
        return DateFormat('HH:mm').format(bishkek);
      }
      return DateFormat('HH:mm').format(parsed);
    } catch (_) {
      return str.length >= 5 ? str.substring(0, 5) : str;
    }
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
