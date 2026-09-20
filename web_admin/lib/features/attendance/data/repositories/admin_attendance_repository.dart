import 'package:admin_core/admin_core.dart' as core;
import 'package:dio/dio.dart';
import 'package:teacher_admin/core/network/admin_api_client.dart';

/// Shared models; this app's screens keep their original names.
typedef AdminDailyAttendanceItem = core.DailyAttendance;
typedef AdminDashboardData = core.AttendanceDashboard;

class AdminAttendanceRepository {
  AdminAttendanceRepository({Dio? dio})
    : _attendance = core.AttendanceRepository(
        dio: dio ?? AdminApiClient.instance.dio,
      );

  final core.AttendanceRepository _attendance;

  Future<AdminDashboardData?> getTodayDashboard({String? targetDate}) async {
    try {
      return await _attendance.dashboard(targetDate: targetDate);
    } on core.AdminApiException {
      // The dashboard distinguishes a failed load from an empty day itself.
      return null;
    }
  }

  /// The school's attendance history for a period, in one paged call.
  ///
  /// A partial failure surfaces as an error rather than as a short report.
  Future<List<AdminDailyAttendanceItem>> getReportHistory({
    DateTime? start,
    DateTime? end,
  }) {
    return _attendance.allHistory(
      startDate: start == null ? null : _isoDate(start),
      endDate: end == null ? null : _isoDate(end),
    );
  }

  static String _isoDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  Future<bool> manualCorrection({
    required String teacherId,
    required String targetDate,
    required String status,
    required String reason,
    String? checkInTime,
    String? checkOutTime,
  }) async {
    try {
      await _attendance.manualCorrection(
        teacherId: teacherId,
        targetDate: targetDate,
        status: status,
        reason: reason,
        checkInTime: checkInTime,
        checkOutTime: checkOutTime,
      );
      return true;
    } on core.AdminApiException {
      return false;
    }
  }
}
