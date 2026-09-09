import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage_service.dart';

class LeaveRepository {
  final Dio dio;
  LeaveRepository({Dio? dio})
    : dio = dio ?? ApiClient(storageService: SecureStorageService()).dio;
  Future<List<Map<String, dynamic>>> list(bool admin, int offset) async {
    final response = await dio.get(
      admin ? '/leaves/admin' : '/leaves/mine',
      queryParameters: {'offset': offset, 'limit': 50},
    );
    return (response.data as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> submit(String date, String reason) async {
    await dio.post(
      '/leaves',
      data: {'target_date': date, 'reason': reason.trim()},
    );
  }

  Future<void> decide(String id, String status, String reason) async {
    await dio.post(
      '/leaves/admin/$id/decision',
      data: {'status': status, 'reason': reason.trim()},
    );
  }
}
