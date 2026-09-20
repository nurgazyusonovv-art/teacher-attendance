import '../api.dart';
import '../models/leave_request.dart';

/// Leave requests, from both sides: a teacher submits, an administrator
/// decides.
class LeavesRepository extends AdminApi {
  const LeavesRepository({required super.dio, super.basePath});

  /// The signed-in teacher's own requests, or every request in the school
  /// when [admin] is set.
  Future<List<LeaveRequest>> list({
    bool admin = false,
    int offset = 0,
    int limit = 50,
  }) {
    return guard(() async {
      final response = await dio.get(
        url(admin ? '/leaves/admin' : '/leaves/mine'),
        queryParameters: {'offset': offset, 'limit': limit},
      );
      return (response.data as List<dynamic>)
          .map((e) => LeaveRequest.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }, 'Уруксат арыздарын жүктөө ишке ашкан жок.');
  }

  Future<void> submit({required String targetDate, required String reason}) {
    return guard(() async {
      await dio.post(
        url('/leaves'),
        data: {'target_date': targetDate, 'reason': reason.trim()},
      );
    }, 'Арызды жөнөтүү ишке ашкан жок.');
  }

  /// Approves or rejects one request. Approving marks the day EXCUSED, so the
  /// API audits the decision and refuses one that conflicts with a scan.
  Future<void> decide({
    required String requestId,
    required LeaveStatus status,
    String reason = '',
  }) {
    return guard(() async {
      await dio.post(
        url('/leaves/admin/${Uri.encodeComponent(requestId)}/decision'),
        data: {'status': status.wireName, 'reason': reason.trim()},
      );
    }, 'Чечимди сактоо ишке ашкан жок.');
  }
}
