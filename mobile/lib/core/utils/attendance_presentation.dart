import 'package:flutter/material.dart';

String attendanceLabel(String status) => switch (status) {
  'ON_TIME' => 'Өз убагында келди',
  'LATE' => 'Кечигип келди',
  'ABSENT' => 'Келген жок',
  'EXCUSED' => 'Себептүү',
  'DAY_OFF' => 'Дем алыш',
  'NO_SCHEDULE' => 'Иш графиги жок',
  'PENDING' => 'Азырынча каттала элек',
  _ => 'Статус жеткиликсиз. Маалыматты жаңыртыңыз.',
};
Color attendanceColor(String status) => switch (status) {
  'ON_TIME' => Colors.green,
  'LATE' => Colors.orange,
  'ABSENT' => Colors.red,
  'EXCUSED' => Colors.blue,
  _ => Colors.grey,
};
