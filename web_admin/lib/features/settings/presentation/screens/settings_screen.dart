import 'package:flutter/material.dart';
import 'package:teacher_admin/core/theme/admin_theme.dart';
import 'package:teacher_admin/features/settings/data/repositories/settings_repository.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final SettingsRepository _repository = SettingsRepository();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _latController = TextEditingController();
  final TextEditingController _lngController = TextEditingController();
  final TextEditingController _radiusController = TextEditingController();
  final TextEditingController _accuracyController = TextEditingController();
  final TextEditingController _graceController = TextEditingController();
  final TextEditingController _timezoneController = TextEditingController();

  SchoolSettingsData? _school;
  QrPayloadData? _qrData;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _saveMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final school = await _repository.getSchoolSettings();
    final qr = await _repository.getSchoolQr();

    if (mounted && school != null) {
      _school = school;
      _qrData = qr;
      _nameController.text = school.name;
      _latController.text = school.latitude.toString();
      _lngController.text = school.longitude.toString();
      _radiusController.text = school.allowedRadiusMeters.toString();
      _accuracyController.text = school.maxAccuracyMeters.toString();
      _graceController.text = school.graceMinutes.toString();
      _timezoneController.text = school.timezone;
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    if (_school == null) return;
    setState(() {
      _isSaving = true;
      _saveMessage = null;
    });

    final success = await _repository.updateSchoolSettings(
      schoolId: _school!.id,
      name: _nameController.text.trim(),
      latitude: double.tryParse(_latController.text.trim()),
      longitude: double.tryParse(_lngController.text.trim()),
      allowedRadiusMeters: double.tryParse(_radiusController.text.trim()),
      maxAccuracyMeters: double.tryParse(_accuracyController.text.trim()),
      graceMinutes: int.tryParse(_graceController.text.trim()),
      timezone: _timezoneController.text.trim(),
    );

    if (mounted) {
      setState(() {
        _isSaving = false;
        _saveMessage = success
            ? 'Жөндөөлөр ийгиликтүү сакталды!'
            : 'Ката кетти, кайра текшериңиз.';
      });
      if (success) {
        _loadData();
      }
    }
  }

  Future<void> _rotateQr() async {
    if (_school == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('QR-кодду алмаштыруу'),
        content: const Text(
          'Эски QR-код дароо жараксыз болуп калат. Мектептин эшигиндеги QR-кодду кайра басып чыгаруу талап кылынат. Улантасызбы?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Жокко чыгаруу'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[800]),
            child: const Text('Ооба, алмаштыруу'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final updatedQr = await _repository.rotateSchoolQr(_school!.id);
      if (mounted && updatedQr != null) {
        setState(() => _qrData = updatedQr);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Жаңы QR-код генерацияланды!')),
        );
      }
    }
  }

  void _showPrintQrDialog() {
    if (_qrData == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${_qrData!.schoolName} — Басып чыгаруу (A4)'),
        content: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFCBD5E1), width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.school, size: 40, color: AdminTheme.accentColor),
                    const SizedBox(height: 8),
                    Text(
                      _qrData!.schoolName,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      height: 180,
                      width: 180,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        border: Border.all(color: const Color(0xFF0F172A), width: 2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Icon(Icons.qr_code_2, size: 140, color: Color(0xFF0F172A)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Teacher Mobile тиркемеси менен сканерлеңиз',
                      style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Токен: ${_qrData!.qrToken.substring(0, 16)}...',
                      style: const TextStyle(fontSize: 10, fontFamily: 'monospace', color: Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Жабуу'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('A4 басып чыгаруу режимине жөнөтүлдү')),
              );
            },
            icon: const Icon(Icons.print, size: 18),
            label: const Text('Басып чыгаруу (Print)'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  const Text(
                    'Мектеп Настройкалары',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'GPS координаталар, радиус, убакыт чектөөлөрү жана туруктуу QR-код',
                    style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 24),

                  if (_saveMessage != null)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _saveMessage!.contains('ийгиликтүү')
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _saveMessage!,
                        style: TextStyle(
                          color: _saveMessage!.contains('ийгиликтүү') ? Colors.green[800] : Colors.red[800],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Form Section (Left)
                      Expanded(
                        flex: 3,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Геолокация жана Иш Параметрлери',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 16),
                                TextField(
                                  controller: _nameController,
                                  decoration: const InputDecoration(labelText: 'Мектептин аталышы'),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _latController,
                                        decoration: const InputDecoration(labelText: 'GPS Кеңдик (Latitude)'),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: TextField(
                                        controller: _lngController,
                                        decoration: const InputDecoration(labelText: 'GPS Узундук (Longitude)'),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _radiusController,
                                        decoration: const InputDecoration(
                                          labelText: 'Уруксат берилген радиус (метр)',
                                          helperText: 'Стандарт: 80 метр',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: TextField(
                                        controller: _accuracyController,
                                        decoration: const InputDecoration(
                                          labelText: 'GPS тактыгынын чеги (метр)',
                                          helperText: 'Стандарт: 50 метр',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _graceController,
                                        decoration: const InputDecoration(
                                          labelText: 'Кечигүүгө жеңилдик (мүнөт)',
                                          helperText: 'Мисалы: 5 мүнөт',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: TextField(
                                        controller: _timezoneController,
                                        decoration: const InputDecoration(
                                          labelText: 'Убакыт алкагы (Timezone)',
                                          helperText: 'Asia/Bishkek',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  onPressed: _isSaving ? null : _saveSettings,
                                  icon: _isSaving
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Icon(Icons.save, size: 18),
                                  label: const Text('Жөндөөлөрдү сактоо'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AdminTheme.accentColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 20),

                      // QR Code Section (Right)
                      Expanded(
                        flex: 2,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Мектептин Туруктуу QR-Коду',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Container(
                                  height: 160,
                                  width: 160,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    border: Border.all(color: const Color(0xFFCBD5E1), width: 2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.qr_code_2, size: 120, color: Color(0xFF0F172A)),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (_qrData != null)
                                  Text(
                                    'QR Токен: ${_qrData!.qrToken.substring(0, 18)}...',
                                    style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Color(0xFF64748B)),
                                  ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    OutlinedButton.icon(
                                      onPressed: _showPrintQrDialog,
                                      icon: const Icon(Icons.print, size: 16),
                                      label: const Text('Басып чыгаруу'),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton.icon(
                                      onPressed: _rotateQr,
                                      icon: const Icon(Icons.refresh, size: 16, color: Colors.amber),
                                      label: const Text('Жаңылоо', style: TextStyle(color: Colors.amber)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }
}
