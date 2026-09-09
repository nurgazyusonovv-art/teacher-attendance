import 'package:flutter/material.dart';
import '../../data/repositories/admin_attendance_repository.dart';

enum AttendanceGroup { all, checkedIn, onTime, late, absent }

bool matchesGroup(AdminDailyAttendanceItem r, AttendanceGroup group) {
  final checkedIn = r.checkInTime != null;
  final onTime = r.status == 'ON_TIME';
  return switch (group) {
    AttendanceGroup.all => true,
    AttendanceGroup.checkedIn => checkedIn,
    AttendanceGroup.onTime => checkedIn && onTime,
    AttendanceGroup.late => checkedIn && r.status == 'LATE',
    AttendanceGroup.absent => !checkedIn && r.status == 'ABSENT',
  };
}

String attendanceStatus(String status) => switch (status) {
  'PENDING' => 'Азырынча каттала элек',
  'ON_TIME' => 'Өз убагында',
  'LATE' => 'Кечиккен',
  'ABSENT' => 'Келген жок',
  'EXCUSED' => 'Себептүү',
  'DAY_OFF' => 'Эс алуу күнү',
  'NO_SCHEDULE' => 'Жадыбал жок',
  _ => status,
};

String attendanceTime(String? value) {
  if (value == null || value.isEmpty) return '—';
  // Preserve the school-local wall time supplied by the API, not browser TZ.
  final match = RegExp(r'T(\d{2}:\d{2})').firstMatch(value);
  return match?.group(1) ?? value;
}

class AttendanceDetails extends StatelessWidget {
  const AttendanceDetails({super.key, required this.records});
  final List<AdminDailyAttendanceItem> records;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const Center(child: Text('Тандалган чыпка боюнча маалымат жок'));
    }
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('Күнү')),
            DataColumn(label: Text('Мугалим')),
            DataColumn(label: Text('Табель номери')),
            DataColumn(label: Text('Келүү')),
            DataColumn(label: Text('Кетүү')),
            DataColumn(label: Text('Статус')),
            DataColumn(label: Text('Жалпы кечигүү')),
            DataColumn(label: Text('Иштеген')),
            DataColumn(label: Text('Оңдоонун себеби')),
          ],
          rows: records
              .map(
                (r) => DataRow(
                  cells: [
                    DataCell(Text(r.date)),
                    DataCell(Text(r.teacherName ?? '—')),
                    DataCell(Text(r.employeeCode ?? '—')),
                    DataCell(Text(attendanceTime(r.checkInTime))),
                    DataCell(Text(attendanceTime(r.checkOutTime))),
                    DataCell(Text(attendanceStatus(r.status))),
                    DataCell(
                      Text('${r.lateMinutes + r.lessonLateMinutes} мүн'),
                    ),
                    DataCell(Text('${r.workedMinutes} мүн')),
                    DataCell(Text(r.correctionReason ?? '—')),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
