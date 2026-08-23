import 'dart:convert';
import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../../core/errors/error_messages.dart';
import '../models/auth_tokens_model.dart';
import '../models/user_model.dart';

class AuthRepository {
  final ApiClient apiClient;
  final SecureStorageService storageService;

  AuthRepository({
    required this.apiClient,
    required this.storageService,
  });

  Future<UserModel> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    try {
      final response = await apiClient.dio.post(
        '/auth/login',
        data: {
          'username_or_email': usernameOrEmail.trim(),
          'password': password,
        },
      );

      final data = response.data['data'];
      final tokens = AuthTokensModel.fromJson(data);
      final user = UserModel.fromJson(data['user']);

      // Persist tokens and user cache
      await storageService.saveTokens(
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
      );
      await storageService.saveUserData(jsonEncode(user.toJson()));

      return user;
    } on DioException catch (e) {
      final responseData = e.response?.data;
      final errorCode = responseData is Map ? responseData['code'] as String? : null;
      final serverMessage = responseData is Map ? responseData['message'] as String? : null;
      throw Exception(ErrorMessages.getKyrgyzMessage(errorCode, serverMessage));
    } catch (e) {
      throw Exception('Кирүүдө ката кетти: ${e.toString()}');
    }
  }

  Future<UserModel?> restoreSession() async {
    final token = await storageService.getAccessToken();
    if (token == null || token.isEmpty) {
      return null;
    }

    try {
      final response = await apiClient.dio.get('/auth/me');
      if (response.data['success'] == true) {
        final user = UserModel.fromJson(response.data['data']);
        await storageService.saveUserData(jsonEncode(user.toJson()));
        return user;
      }
    } catch (_) {
      // Try cached user data if network fails temporarily
      final cachedJson = await storageService.getUserData();
      if (cachedJson != null && cachedJson.isNotEmpty) {
        try {
          return UserModel.fromJson(jsonDecode(cachedJson));
        } catch (_) {}
      }
      await storageService.clearAll();
    }
    return null;
  }

  Future<void> logout() async {
    try {
      await apiClient.dio.post('/auth/logout');
    } catch (_) {
      // Ignore network errors on logout
    } finally {
      await storageService.clearAll();
    }
  }
}
