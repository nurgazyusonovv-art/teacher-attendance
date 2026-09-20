import 'package:admin_core/admin_core.dart' as core;
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage_service.dart';

class LeaveRepository {
  LeaveRepository({Dio? dio})
    : _leaves = core.LeavesRepository(
        dio: dio ?? ApiClient(storageService: SecureStorageService()).dio,
      );

  final core.LeavesRepository _leaves;

  Future<List<core.LeaveRequest>> list(bool admin, int offset) =>
      _leaves.list(admin: admin, offset: offset);

  Future<void> submit(String date, String reason) =>
      _leaves.submit(targetDate: date, reason: reason);

  Future<void> decide(String id, String status, String reason) => _leaves.decide(
    requestId: id,
    status: core.LeaveStatus.parse(status),
    reason: reason,
  );
}
