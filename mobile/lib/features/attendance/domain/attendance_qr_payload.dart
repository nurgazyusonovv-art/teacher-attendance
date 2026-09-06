import 'dart:convert';

class AttendanceQrPayload {
  final String schoolId;
  final String token;

  const AttendanceQrPayload({required this.schoolId, required this.token});

  static AttendanceQrPayload? tryParse(String rawValue) {
    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is! Map<String, dynamic> ||
          decoded['type'] != 'school_attendance') {
        return null;
      }

      final schoolId = decoded['school_id'];
      final token = decoded['qr_token'];
      if (schoolId is! String ||
          schoolId.trim().isEmpty ||
          token is! String ||
          token.trim().isEmpty) {
        return null;
      }

      return AttendanceQrPayload(
        schoolId: schoolId.trim(),
        token: token.trim(),
      );
    } on FormatException {
      return null;
    }
  }
}
