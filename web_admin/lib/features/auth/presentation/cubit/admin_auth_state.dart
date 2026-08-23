import 'package:equatable/equatable.dart';
import '../../data/repositories/admin_auth_repository.dart';

abstract class AdminAuthState extends Equatable {
  const AdminAuthState();

  @override
  List<Object?> get props => [];
}

class AdminAuthInitial extends AdminAuthState {
  const AdminAuthInitial();
}

class AdminAuthLoading extends AdminAuthState {
  const AdminAuthLoading();
}

class AdminAuthenticated extends AdminAuthState {
  final AdminUser user;

  const AdminAuthenticated(this.user);

  @override
  List<Object?> get props => [user];
}

class AdminUnauthenticated extends AdminAuthState {
  const AdminUnauthenticated();
}

class AdminAuthError extends AdminAuthState {
  final String message;

  const AdminAuthError(this.message);

  @override
  List<Object?> get props => [message];
}
