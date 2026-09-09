import '../../attendance/data/repositories/admin_attendance_repository.dart';

class TeacherAnalytics {
  TeacherAnalytics(
    List<AdminDailyAttendanceItem> history,
    String today,
    int days,
  ) {
    final end = DateTime.parse(today);
    final start = end.subtract(Duration(days: days > 0 ? days - 1 : 0));
    records = history.where((r) {
      final date = DateTime.parse(r.date);
      return !date.isAfter(end) && (days == 0 || !date.isBefore(start));
    }).toList()..sort((a, b) => b.date.compareTo(a.date));
  }
  late final List<AdminDailyAttendanceItem> records;
  int get checkedIn => records.where((r) => r.checkInTime != null).length;
  int get onTime => records
      .where(
        (r) =>
            r.checkInTime != null &&
            r.status == 'ON_TIME',
      )
      .length;
  int get late => records
      .where(
        (r) =>
            r.checkInTime != null &&
            r.status == 'LATE',
      )
      .length;
  int get absent => records.where((r) => r.status == 'ABSENT').length;
  int get lateMinutes =>
      records.fold(0, (sum, r) => sum + r.lateMinutes + r.lessonLateMinutes);
  int get workedMinutes => records.fold(0, (sum, r) => sum + r.workedMinutes);
  Map<String, int> get statuses {
    final result = <String, int>{};
    for (final r in records) {
      result.update(r.status, (n) => n + 1, ifAbsent: () => 1);
    }
    return result;
  }

  Map<String, int> get monthlyLate {
    final result = <String, int>{};
    for (final r in records.reversed) {
      result.update(
        r.date.substring(0, 7),
        (n) => n + r.lateMinutes + r.lessonLateMinutes,
        ifAbsent: () => r.lateMinutes + r.lessonLateMinutes,
      );
    }
    return result;
  }
}
