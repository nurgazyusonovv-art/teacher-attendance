import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final String id;
  final String email;
  final String username;
  final String fullName;
  final String role;
  final bool isActive;
  final bool isDemo;
  final String? schoolId;
  final String? teacherId;

  const UserEntity({
    required this.id,
    required this.email,
    required this.username,
    required this.fullName,
    required this.role,
    required this.isActive,
    required this.isDemo,
    this.schoolId,
    this.teacherId,
  });

  bool get isTeacher => role == 'TEACHER';
  bool get isAdmin => role == 'ADMIN' || role == 'SUPER_ADMIN';

  @override
  List<Object?> get props => [
        id,
        email,
        username,
        fullName,
        role,
        isActive,
        isDemo,
        schoolId,
        teacherId,
      ];
}
