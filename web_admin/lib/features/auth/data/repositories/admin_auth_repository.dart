import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:teacher_admin/core/constants/app_constants.dart';

class AdminUser {
  final String id;
  final String email;
  final String username;
  final String fullName;
  final String role;

  const AdminUser({
    required this.id,
    required this.email,
    required this.username,
    required this.fullName,
    required this.role,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    return AdminUser(
      id: json['id'] as String,
      email: json['email'] as String,
      username: json['username'] as String,
      fullName: json['full_name'] as String,
      role: json['role'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'full_name': fullName,
      'role': role,
    };
  }
}

class AdminAuthRepository {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  AdminAuthRepository({
    Dio? dio,
    FlutterSecureStorage? storage,
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: AppConstants.defaultBaseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 15),
              ),
            ),
        _storage = storage ?? const FlutterSecureStorage();

  Future<AdminUser> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {
          'username_or_email': usernameOrEmail.trim(),
          'password': password,
        },
      );

      final data = response.data['data'];
      final user = AdminUser.fromJson(data['user']);

      if (user.role != 'ADMIN' && user.role != 'SUPER_ADMIN') {
        throw Exception('Бул панелге администраторлор гана кире алышат.');
      }

      final accessToken = data['access_token'] as String;
      final refreshToken = data['refresh_token'] as String;

      await _storage.write(key: AppConstants.keyAccessToken, value: accessToken);
      await _storage.write(key: AppConstants.keyRefreshToken, value: refreshToken);
      await _storage.write(key: 'admin_user_data', value: jsonEncode(user.toJson()));

      return user;
    } on DioException catch (e) {
      final res = e.response?.data;
      final msg = res is Map ? res['message'] as String? : null;
      throw Exception(msg ?? 'Логин же сырсөз туура эмес.');
    }
  }

  Future<AdminUser?> restoreSession() async {
    final token = await _storage.read(key: AppConstants.keyAccessToken);
    if (token == null || token.isEmpty) return null;

    try {
      final response = await _dio.get(
        '/auth/me',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      if (response.data['success'] == true) {
        final user = AdminUser.fromJson(response.data['data']);
        if (user.role == 'ADMIN' || user.role == 'SUPER_ADMIN') {
          return user;
        }
      }
    } catch (_) {
      await _storage.deleteAll();
    }
    return null;
  }

  Future<void> logout() async {
    await _storage.deleteAll();
  }
}
