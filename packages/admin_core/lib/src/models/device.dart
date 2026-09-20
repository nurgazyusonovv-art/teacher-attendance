/// Where a registered device sits in the approval flow.
///
/// A teacher's first device is approved on registration — otherwise nobody
/// could ever record attendance — and every later one waits for an
/// administrator (PROJECT.md §10).
enum DeviceStatus {
  pending,
  approved,
  revoked;

  static DeviceStatus parse(String? raw) {
    return switch (raw) {
      'APPROVED' => DeviceStatus.approved,
      'REVOKED' => DeviceStatus.revoked,
      _ => DeviceStatus.pending,
    };
  }

  /// The value the API uses.
  String get wireName => switch (this) {
    DeviceStatus.pending => 'PENDING',
    DeviceStatus.approved => 'APPROVED',
    DeviceStatus.revoked => 'REVOKED',
  };

  /// Wording for an administrator.
  String get label => switch (this) {
    DeviceStatus.pending => 'Күтүүдө',
    DeviceStatus.approved => 'Ырасталган',
    DeviceStatus.revoked => 'Жокко чыгарылган',
  };
}

/// One teacher's registered device, as the API's `AdminDeviceRead` returns it.
class TeacherDevice {
  const TeacherDevice({
    required this.id,
    required this.deviceId,
    required this.platform,
    required this.status,
    required this.teacherName,
    this.username,
    this.lastSeenAt,
    this.approvedAt,
    this.revokedAt,
  });

  final String id;

  /// The identifier the device itself reports; stable per install.
  final String deviceId;
  final String platform;
  final DeviceStatus status;
  final String teacherName;
  final String? username;
  final DateTime? lastSeenAt;
  final DateTime? approvedAt;
  final DateTime? revokedAt;

  bool get isPending => status == DeviceStatus.pending;
  bool get isApproved => status == DeviceStatus.approved;

  /// Enough of the identifier to tell two devices apart, without filling a
  /// phone screen with an opaque token.
  String get shortDeviceId =>
      deviceId.length <= 14 ? deviceId : '${deviceId.substring(0, 12)}…';

  factory TeacherDevice.fromJson(Map<String, dynamic> json) {
    DateTime? at(String key) {
      final raw = json[key] as String?;
      return raw == null ? null : DateTime.tryParse(raw);
    }

    return TeacherDevice(
      id: json['id'] as String,
      deviceId: json['device_id'] as String? ?? '',
      platform: json['platform'] as String? ?? '',
      status: DeviceStatus.parse(json['status'] as String?),
      teacherName: json['teacher_name'] as String? ?? 'Белгисиз',
      username: json['username'] as String?,
      lastSeenAt: at('last_seen_at'),
      approvedAt: at('approved_at'),
      revokedAt: at('revoked_at'),
    );
  }
}
