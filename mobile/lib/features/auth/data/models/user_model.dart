import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.email,
    required super.username,
    required super.fullName,
    required super.role,
    required super.isActive,
    required super.isDemo,
    super.schoolId,
    super.teacherId,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      username: json['username'] as String,
      fullName: json['full_name'] as String,
      role: json['role'] as String,
      isActive: json['is_active'] as bool? ?? true,
      isDemo: json['is_demo'] as bool? ?? false,
      schoolId: json['school_id'] as String?,
      teacherId: json['teacher_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'full_name': fullName,
      'role': role,
      'is_active': isActive,
      'is_demo': isDemo,
      'school_id': schoolId,
      'teacher_id': teacherId,
    };
  }
}
