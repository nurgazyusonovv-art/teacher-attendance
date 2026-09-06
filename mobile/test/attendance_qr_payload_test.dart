import 'package:flutter_test/flutter_test.dart';
import 'package:teacher_mobile/features/attendance/domain/attendance_qr_payload.dart';

void main() {
  group('AttendanceQrPayload', () {
    test('accepts a typed school attendance payload', () {
      final payload = AttendanceQrPayload.tryParse(
        '{"type":"school_attendance","school_id":"school-1",'
        '"qr_token":"token-1"}',
      );

      expect(payload?.schoolId, 'school-1');
      expect(payload?.token, 'token-1');
    });

    test('rejects a payload without the attendance type', () {
      final payload = AttendanceQrPayload.tryParse(
        '{"school_id":"school-1","qr_token":"token-1"}',
      );

      expect(payload, isNull);
    });

    test('rejects legacy token aliases and malformed input', () {
      expect(
        AttendanceQrPayload.tryParse(
          '{"type":"school_attendance","school_id":"school-1",'
          '"token":"legacy-token"}',
        ),
        isNull,
      );
      expect(AttendanceQrPayload.tryParse('not-json'), isNull);
    });
  });
}
