import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/repositories/admin_auth_repository.dart';
import 'admin_auth_state.dart';

class AdminAuthCubit extends Cubit<AdminAuthState> {
  final AdminAuthRepository authRepository;

  AdminAuthCubit({required this.authRepository})
      : super(const AdminAuthInitial());

  Future<void> checkAuthStatus() async {
    emit(const AdminAuthLoading());
    try {
      final user = await authRepository.restoreSession();
      if (user != null) {
        emit(AdminAuthenticated(user));
      } else {
        emit(const AdminUnauthenticated());
      }
    } catch (_) {
      emit(const AdminUnauthenticated());
    }
  }

  Future<void> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    emit(const AdminAuthLoading());
    try {
      final user = await authRepository.login(
        usernameOrEmail: usernameOrEmail,
        password: password,
      );
      emit(AdminAuthenticated(user));
    } catch (e) {
      emit(AdminAuthError(e.toString().replaceAll('Exception: ', '')));
    }
  }

  Future<void> logout() async {
    emit(const AdminAuthLoading());
    await authRepository.logout();
    emit(const AdminUnauthenticated());
  }
}
