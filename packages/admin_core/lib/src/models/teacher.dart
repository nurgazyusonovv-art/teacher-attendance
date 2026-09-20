/// One teacher, as the API's `TeacherRead` schema returns them.
///
/// The two admin surfaces each used to carry their own mapping of this shape,
/// under different field names — `phone` on the phone, `phoneNumber` in the
/// browser — so a field added to the API had to be mirrored twice. Names here
/// follow the API.
class Teacher {
  const Teacher({
    required this.id,
    required this.userId,
    required this.schoolId,
    required this.employeeCode,
    required this.fullName,
    required this.username,
    this.email = '',
    this.phoneNumber,
    this.subject,
    this.isActive = true,
    this.isDemo = false,
  });

  final String id;
  final String userId;
  final String schoolId;
  final String employeeCode;
  final String fullName;
  final String username;
  final String email;
  final String? phoneNumber;
  final String? subject;
  final bool isActive;
  final bool isDemo;

  factory Teacher.fromJson(Map<String, dynamic> json) {
    return Teacher(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      schoolId: json['school_id'] as String? ?? '',
      employeeCode: json['employee_code'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      username: json['username'] as String? ?? '',
      email: json['email'] as String? ?? '',
      // The phone has been sent under both names over the API's lifetime.
      phoneNumber: json['phone_number'] as String? ?? json['phone'] as String?,
      subject: json['subject'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      isDemo: json['is_demo'] as bool? ?? false,
    );
  }

  Teacher copyWith({
    String? id,
    String? userId,
    String? schoolId,
    String? employeeCode,
    String? fullName,
    String? username,
    String? email,
    String? phoneNumber,
    String? subject,
    bool? isActive,
    bool? isDemo,
  }) {
    return Teacher(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      schoolId: schoolId ?? this.schoolId,
      employeeCode: employeeCode ?? this.employeeCode,
      fullName: fullName ?? this.fullName,
      username: username ?? this.username,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      subject: subject ?? this.subject,
      isActive: isActive ?? this.isActive,
      isDemo: isDemo ?? this.isDemo,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Teacher &&
      other.id == id &&
      other.userId == userId &&
      other.schoolId == schoolId &&
      other.employeeCode == employeeCode &&
      other.fullName == fullName &&
      other.username == username &&
      other.email == email &&
      other.phoneNumber == phoneNumber &&
      other.subject == subject &&
      other.isActive == isActive &&
      other.isDemo == isDemo;

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    schoolId,
    employeeCode,
    fullName,
    username,
    email,
    phoneNumber,
    subject,
    isActive,
    isDemo,
  );
}

/// A page of teachers, as `TeacherListResponse` returns it.
class TeacherPage {
  const TeacherPage({required this.items, required this.total});

  final List<Teacher> items;
  final int total;

  factory TeacherPage.fromJson(Map<String, dynamic> json) {
    final rows = json['items'] as List<dynamic>? ?? const [];
    return TeacherPage(
      items: rows
          .map((row) => Teacher.fromJson(row as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int? ?? rows.length,
    );
  }
}
