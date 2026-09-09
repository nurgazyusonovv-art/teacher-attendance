import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';
import '../../../../core/network/api_client.dart';
import '../../data/repositories/auth_repository.dart';
import 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthRepository authRepository;

  late final StreamSubscription<void> _expiredSubscription;
  AuthCubit({required this.authRepository}) : super(const AuthInitial()) {
    _expiredSubscription = ApiClient.sessionExpired.listen((_) {
      if (!isClosed) emit(const Unauthenticated());
    });
  }
  @override
  Future<void> close() {
    unawaited(_expiredSubscription.cancel());
    return super.close();
  }

  Future<void> checkAuthStatus() async {
    emit(const AuthLoading());
    try {
      final user = await authRepository.restoreSession();
      if (user != null) {
        emit(Authenticated(user));
      } else {
        emit(const Unauthenticated());
      }
    } catch (_) {
      emit(const Unauthenticated());
    }
  }

  Future<void> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    emit(const AuthLoading());
    try {
      final user = await authRepository.login(
        usernameOrEmail: usernameOrEmail,
        password: password,
      );
      emit(Authenticated(user));
    } catch (e) {
      emit(AuthError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> logout() async {
    emit(const AuthLoading());
    await authRepository.logout();
    emit(const Unauthenticated());
  }
}
