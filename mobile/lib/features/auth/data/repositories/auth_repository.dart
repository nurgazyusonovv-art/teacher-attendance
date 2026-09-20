import 'dart:convert';
import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/device_identity_service.dart';
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
    DeviceIdentityService? deviceIdentity,
  }) : deviceIdentity =
           deviceIdentity ??
           DeviceIdentityService(storageService: storageService);

  final DeviceIdentityService deviceIdentity;

  /// Registers this install so device binding has something to approve.
  ///
  /// The first device is approved by the server on the spot; a later one
  /// waits for an administrator. A failure here must never block sign-in:
  /// binding is off for schools that have not enabled it, and the scan
  /// itself reports the real problem when it is on.
  Future<void> registerDevice() async {
    try {
      await apiClient.dio.post(
        '/devices/register',
        data: {
          'device_id': await deviceIdentity.getDeviceId(),
          'platform': DeviceIdentityService.platform,
        },
      );
    } catch (_) {
      // Retried on the next sign-in or session restore.
    }
  }

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
      await registerDevice();

      return user;
    } on DioException catch (e) {
      final responseData = e.response?.data;
      final errorCode = responseData is Map
          ? responseData['code'] as String?
          : null;
      final serverMessage = responseData is Map
          ? responseData['message'] as String?
          : null;
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
        // Covers installs that signed in before binding existed, and retries
        // a registration that failed at sign-in.
        await registerDevice();
        return user;
      }
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        await storageService.clearAll();
        return null;
      }
      // Try cached user data if network fails temporarily
      final cachedJson = await storageService.getUserData();
      if (cachedJson != null && cachedJson.isNotEmpty) {
        try {
          return UserModel.fromJson(jsonDecode(cachedJson));
        } catch (_) {}
      }
      await storageService.clearAll();
    } catch (_) {
      await storageService.clearAll();
    }
    return null;
  }

  /// Changes the signed-in user's own password.
  ///
  /// A teacher receives a password chosen by their administrator, who also
  /// knows it; without this there is no way to replace it. The server revokes
  /// every other session, so a device holding the old password is signed out.
  ///
  /// Returns null on success, or a message to show.
  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await apiClient.dio.post(
        '/auth/change-password',
        data: {
          'current_password': currentPassword,
          'new_password': newPassword,
        },
      );
      return null;
    } on DioException catch (error) {
      final data = error.response?.data;
      final code = data is Map ? data['code'] as String? : null;
      final message = data is Map ? data['message'] as String? : null;
      return ErrorMessages.getKyrgyzMessage(code, message);
    } catch (_) {
      return 'Сырсөздү өзгөртүү ишке ашкан жок. Кайра аракет кылыңыз.';
    }
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
