import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

Future<TimeOfDay?> showIosTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
  required String title,
}) async {
  final now = DateTime.now();
  DateTime selectedDateTime = DateTime(
    now.year,
    now.month,
    now.day,
    initialTime.hour,
    initialTime.minute,
  );

  return await showCupertinoModalPopup<TimeOfDay>(
    context: context,
    builder: (BuildContext ctx) => Container(
      height: 310,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // iOS style Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFFF8FAFC),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 0.8)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text(
                      'Жокко чыгаруу',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 15),
                    ),
                  ),
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5, color: AppTheme.textPrimary),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      Navigator.of(ctx).pop(
                        TimeOfDay(
                          hour: selectedDateTime.hour,
                          minute: selectedDateTime.minute,
                        ),
                      );
                    },
                    child: const Text(
                      'Даяр',
                      style: TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
            // Cupertino 24-hour Time Wheel
            Expanded(
              child: CupertinoDatePicker(
                mode: CupertinoDatePickerMode.time,
                use24hFormat: true,
                initialDateTime: selectedDateTime,
                onDateTimeChanged: (DateTime newDateTime) {
                  selectedDateTime = newDateTime;
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
