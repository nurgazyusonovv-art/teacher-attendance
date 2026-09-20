/// How a leave request stands.
enum LeaveStatus {
  pending,
  approved,
  rejected;

  static LeaveStatus parse(String? raw) => switch (raw) {
    'APPROVED' => LeaveStatus.approved,
    'REJECTED' => LeaveStatus.rejected,
    _ => LeaveStatus.pending,
  };

  String get wireName => switch (this) {
    LeaveStatus.pending => 'PENDING',
    LeaveStatus.approved => 'APPROVED',
    LeaveStatus.rejected => 'REJECTED',
  };

  /// Wording for a teacher or an administrator.
  String get label => switch (this) {
    LeaveStatus.pending => 'Каралууда',
    LeaveStatus.approved => 'Уруксат берилди',
    LeaveStatus.rejected => 'Четке кагылды',
  };
}

/// A teacher's request to be excused for a day.
///
/// Both screens used to pass raw maps around and read the same keys by hand
/// in several places.
class LeaveRequest {
  const LeaveRequest({
    required this.id,
    required this.targetDate,
    required this.reason,
    required this.status,
    this.teacherName,
    this.decisionReason,
    this.reviewedAt,
    this.createdAt,
  });

  final String id;

  /// `YYYY-MM-DD` in the school's timezone.
  final String targetDate;
  final String reason;
  final LeaveStatus status;
  final String? teacherName;
  final String? decisionReason;
  final String? reviewedAt;
  final String? createdAt;

  bool get isPending => status == LeaveStatus.pending;

  factory LeaveRequest.fromJson(Map<String, dynamic> json) {
    return LeaveRequest(
      id: json['id'] as String,
      targetDate: json['target_date'] as String? ?? '',
      reason: json['reason'] as String? ?? '',
      status: LeaveStatus.parse(json['status'] as String?),
      teacherName: json['teacher_name'] as String?,
      decisionReason: json['decision_reason'] as String?,
      reviewedAt: json['reviewed_at'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }
}
