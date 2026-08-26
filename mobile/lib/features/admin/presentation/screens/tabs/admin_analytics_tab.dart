import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../../core/theme/app_theme.dart';
import '../../../data/repositories/admin_mobile_repository.dart';

class AdminAnalyticsTab extends StatefulWidget {
  const AdminAnalyticsTab({super.key});

  @override
  State<AdminAnalyticsTab> createState() => _AdminAnalyticsTabState();
}

class _AdminAnalyticsTabState extends State<AdminAnalyticsTab> {
  final AdminMobileRepository _repository = AdminMobileRepository();
  Map<String, dynamic>? _qrData;
  Map<String, dynamic>? _dashboardData;
  Map<String, dynamic>? _schoolData;
  bool _isLoading = true;
  bool _isSendingTelegram = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final qr = await _repository.getSchoolQr();
    final dash = await _repository.getTodayDashboard();
    final school = await _repository.getSchoolSettings();
    if (mounted) {
      setState(() {
        _qrData = qr;
        _dashboardData = dash;
        _schoolData = school;
        _isLoading = false;
      });
    }
  }

  // --- EDIT SCHOOL & GEOFENCE MODAL ---
  void _showEditSchoolDialog() {
    final schoolId = _schoolData?['id'] as String? ?? _qrData?['school_id'] as String?;
    if (schoolId == null) return;

    final currentName = _schoolData?['name'] as String? ?? _qrData?['school_name'] as String? ?? '№1 Орто Мектеп';
    final currentLat = (_schoolData?['latitude'] as num?)?.toDouble() ?? 42.8746;
    final currentLng = (_schoolData?['longitude'] as num?)?.toDouble() ?? 74.5698;
    final currentRadius = (_schoolData?['allowed_radius_meters'] as num?)?.toDouble() ?? 150.0;
    final currentMaxAccuracy = (_schoolData?['max_accuracy_meters'] as num?)?.toDouble() ?? 50.0;

    final nameController = TextEditingController(text: currentName);
    final latController = TextEditingController(text: currentLat.toStringAsFixed(6));
    final lngController = TextEditingController(text: currentLng.toStringAsFixed(6));

    double selectedRadius = currentRadius;
    double selectedAccuracy = currentMaxAccuracy;
    bool isDetectingGps = false;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.edit_location_alt_rounded, color: AppTheme.primaryColor, size: 22),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Мектептин Жайгашуусу жана Геозона',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                const Text('Мектептин аталышы:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                const SizedBox(height: 6),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    hintText: 'Мис: №70 Мектеп-лицейи',
                    prefixIcon: Icon(Icons.school_rounded, color: AppTheme.primaryColor),
                  ),
                ),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Туруктуу жайы (GPS):',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: isDetectingGps
                          ? null
                          : () async {
                              setModalState(() => isDetectingGps = true);
                              try {
                                bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
                                if (!serviceEnabled) {
                                  throw Exception('GPS кызматы өчүрүлгөн');
                                }
                                LocationPermission permission = await Geolocator.checkPermission();
                                if (permission == LocationPermission.denied) {
                                  permission = await Geolocator.requestPermission();
                                }
                                if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
                                  throw Exception('Геолокацияга уруксат берилген жок');
                                }

                                Position position = await Geolocator.getCurrentPosition(
                                  locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
                                );

                                latController.text = position.latitude.toStringAsFixed(6);
                                lngController.text = position.longitude.toStringAsFixed(6);

                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(
                                      content: Text('Учурдагы GPS аныкталды! (Тактык: ±${position.accuracy.toInt()}м)'),
                                      backgroundColor: AppTheme.successColor,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (ctx.mounted) {
                                  ScaffoldMessenger.of(ctx).showSnackBar(
                                    SnackBar(content: Text('GPS катасы: $e'), backgroundColor: AppTheme.errorColor),
                                  );
                                }
                              } finally {
                                setModalState(() => isDetectingGps = false);
                              }
                            },
                      icon: isDetectingGps
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.my_location_rounded, size: 16),
                      label: const Text('Учурдагы GPS алуу', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: latController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Кеңдик (Latitude)', prefixIcon: Icon(Icons.pin_drop_outlined, size: 18)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: lngController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(labelText: 'Узундук (Longitude)', prefixIcon: Icon(Icons.pin_drop_outlined, size: 18)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Уруксат берилген радиус:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: AppTheme.primaryColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                      child: Text('${selectedRadius.toInt()} метр', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.primaryColor)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [50.0, 80.0, 100.0, 150.0, 200.0, 300.0].map((r) {
                    final isSelected = (selectedRadius - r).abs() < 1;
                    return ChoiceChip(
                      label: Text('${r.toInt()}м', style: TextStyle(fontSize: 11.5, color: isSelected ? Colors.white : AppTheme.textPrimary)),
                      selected: isSelected,
                      selectedColor: AppTheme.primaryColor,
                      onSelected: (val) {
                        if (val) setModalState(() => selectedRadius = r);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Максималдуу GPS тактыгы:', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(10)),
                      child: Text('±${selectedAccuracy.toInt()} метр', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.textSecondary)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [30.0, 50.0, 80.0, 100.0].map((acc) {
                    final isSelected = (selectedAccuracy - acc).abs() < 1;
                    return ChoiceChip(
                      label: Text('±${acc.toInt()}м', style: TextStyle(fontSize: 11.5, color: isSelected ? Colors.white : AppTheme.textPrimary)),
                      selected: isSelected,
                      selectedColor: AppTheme.secondaryColor,
                      onSelected: (val) {
                        if (val) setModalState(() => selectedAccuracy = acc);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final newName = nameController.text.trim();
                          final newLat = double.tryParse(latController.text.trim());
                          final newLng = double.tryParse(lngController.text.trim());

                          if (newName.length < 2) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Мектептин аталышын жазыңыз')));
                            return;
                          }
                          if (newLat == null || newLng == null) {
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Координаталарды туура жазыңыз')));
                            return;
                          }

                          setModalState(() => isSaving = true);
                          final messenger = ScaffoldMessenger.of(context);

                          final (success, errorMsg) = await _repository.updateSchoolSettings(
                            schoolId: schoolId,
                            name: newName,
                            latitude: newLat,
                            longitude: newLng,
                            radius: selectedRadius,
                            maxAccuracy: selectedAccuracy,
                          );

                          if (ctx.mounted) Navigator.pop(ctx);
                          if (success) {
                            _loadData();
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Мектептин жайгашуусу жана геозонасы ийгиликтүү сакталды!'),
                                backgroundColor: AppTheme.successColor,
                              ),
                            );
                          } else {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(errorMsg ?? 'Жөндөөлөрдү сактоодо ката кетти'),
                                backgroundColor: AppTheme.errorColor,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: isSaving
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text('Жөндөөлөрдү сактоо', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- TELEGRAM SETTINGS MODAL ---
  void _showTelegramSettingsModal() {
    final schoolId = _schoolData?['id'] as String? ?? _qrData?['school_id'] as String?;
    if (schoolId == null) return;

    final currentToken = _schoolData?['telegram_bot_token'] as String? ?? '';
    final currentChatId = _schoolData?['telegram_chat_id'] as String? ?? '';
    bool enabled = _schoolData?['telegram_enabled'] as bool? ?? (currentToken.isNotEmpty && currentChatId.isNotEmpty);

    // Parse initial report time
    TimeOfDay selectedReportTime = const TimeOfDay(hour: 17, minute: 30);
    final rawTime = _schoolData?['telegram_report_time'] as String?;
    if (rawTime != null && rawTime.contains(':')) {
      final parts = rawTime.split(':');
      final h = int.tryParse(parts[0]) ?? 17;
      final m = int.tryParse(parts[1]) ?? 30;
      selectedReportTime = TimeOfDay(hour: h, minute: m);
    }

    final tokenController = TextEditingController(text: currentToken);
    final chatIdController = TextEditingController(text: currentChatId);

    bool isTesting = false;
    bool isSaving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 14),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.send_rounded, color: Color(0xFF0284C7), size: 22),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Telegram Ботту жана Каналды Жөндөө',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Info Box
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F9FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFBAE6FD)),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFF0284C7)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '1. Telegram\'дан @BotFather аркылуу бот түзүп, Bot Token алыңыз.\n'
                          '2. Мектептин Telegram каналын же тайпасын ачып, ботту админ кылып кошуңуз.\n'
                          '3. Каналдын IDсин (@канал_аталышы же -100...) жазыңыз.',
                          style: TextStyle(fontSize: 11.5, color: Color(0xFF0369A1), height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Bot Token Input
                const Text('Telegram Bot Token *:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.textPrimary)),
                const SizedBox(height: 6),
                TextField(
                  controller: tokenController,
                  decoration: const InputDecoration(
                    hintText: 'Мис: 123456789:ABCdefGHIjklMNO...',
                    prefixIcon: Icon(Icons.key_rounded, color: Color(0xFF0284C7)),
                  ),
                ),
                const SizedBox(height: 14),

                // Chat ID Input
                const Text('Telegram Chat / Channel ID *:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.textPrimary)),
                const SizedBox(height: 6),
                TextField(
                  controller: chatIdController,
                  decoration: const InputDecoration(
                    hintText: 'Мис: @mektep_otchet же -1001234567890',
                    prefixIcon: Icon(Icons.tag_rounded, color: Color(0xFF0284C7)),
                  ),
                ),
                const SizedBox(height: 12),

                // Enabled Switch
                SwitchListTile(
                  title: const Text('Күндөлүк автоматтык отчетту иштетүү', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  subtitle: const Text('Директорго/каналга күн сайын белгиленген саатта жөнөтөт', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  value: enabled,
                  contentPadding: EdgeInsets.zero,
                  activeTrackColor: const Color(0xFF0284C7).withValues(alpha: 0.5),
                  activeThumbColor: const Color(0xFF0284C7),
                  onChanged: (val) => setModalState(() => enabled = val),
                ),
                const SizedBox(height: 10),

                // Report Time Picker Tile (if enabled)
                if (enabled) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F9FF),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFBAE6FD)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Row(
                            children: [
                              Icon(Icons.schedule_rounded, size: 20, color: Color(0xFF0284C7)),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Автоматтык жөнөтүү убактысы:',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.textPrimary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: selectedReportTime,
                            );
                            if (picked != null) {
                              setModalState(() => selectedReportTime = picked);
                            }
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFF0284C7)),
                            ),
                            child: Text(
                              '${selectedReportTime.hour.toString().padLeft(2, '0')}:${selectedReportTime.minute.toString().padLeft(2, '0')}',
                              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: Color(0xFF0284C7)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Test Connection Button
                OutlinedButton.icon(
                  onPressed: isTesting
                      ? null
                      : () async {
                          final token = tokenController.text.trim();
                          final chat = chatIdController.text.trim();
                          if (token.isEmpty || chat.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Bot Token жана Chat ID жазыңыз!')),
                            );
                            return;
                          }

                          setModalState(() => isTesting = true);
                          final schoolName = _schoolData?['name'] as String? ?? '№1 Орто Мектеп';
                          final (ok, msg) = await _repository.testTelegramConnection(
                            botToken: token,
                            chatId: chat,
                            schoolName: schoolName,
                          );

                          setModalState(() => isTesting = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(msg),
                                backgroundColor: ok ? AppTheme.successColor : AppTheme.errorColor,
                              ),
                            );
                          }
                        },
                  icon: isTesting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send_outlined, size: 18, color: Color(0xFF0284C7)),
                  label: const Text('Байланышты текшерүү (Тест билдирүү)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0284C7))),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 46),
                    side: const BorderSide(color: Color(0xFFBAE6FD)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 12),

                // Save Settings Button
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          final token = tokenController.text.trim();
                          final chat = chatIdController.text.trim();
                          final reportTimeStr = '${selectedReportTime.hour.toString().padLeft(2, '0')}:${selectedReportTime.minute.toString().padLeft(2, '0')}:00';

                          setModalState(() => isSaving = true);
                          final messenger = ScaffoldMessenger.of(context);

                          final (success, errorMsg) = await _repository.updateSchoolSettings(
                            schoolId: schoolId,
                            telegramBotToken: token.isNotEmpty ? token : null,
                            telegramChatId: chat.isNotEmpty ? chat : null,
                            telegramEnabled: enabled,
                            telegramReportTime: reportTimeStr,
                          );

                          if (ctx.mounted) Navigator.pop(ctx);
                          if (success) {
                            _loadData();
                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text('Telegram орнотуулары ийгиликтүү сакталды!'),
                                backgroundColor: AppTheme.successColor,
                              ),
                            );
                          } else {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(errorMsg ?? 'Сактоодо ката кетти'),
                                backgroundColor: AppTheme.errorColor,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: isSaving
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                      : const Text('Орнотууларды сактоо', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- SEND TELEGRAM REPORT ACTION ---
  Future<void> _sendTelegramReport({DateTime? date}) async {
    if (_isSendingTelegram) return;
    setState(() => _isSendingTelegram = true);

    final dateStr = date != null ? DateFormat('yyyy-MM-dd').format(date) : null;
    final messenger = ScaffoldMessenger.of(context);

    final (ok, msg, reportText) = await _repository.sendTelegramReport(targetDate: dateStr);

    if (mounted) {
      setState(() => _isSendingTelegram = false);

      if (ok) {
        showDialog(
          context: context,
          builder: (dialogCtx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: AppTheme.successColor, size: 26),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Отчет жөнөтүлдү!', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(msg, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  if (reportText != null) ...[
                    const SizedBox(height: 12),
                    const Text('Жөнөтүлгөн отчеттун тексти:', style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: Text(
                        reportText.replaceAll('<b>', '').replaceAll('</b>', '').replaceAll('<i>', '').replaceAll('</i>', ''),
                        style: const TextStyle(fontSize: 11, color: AppTheme.textPrimary, height: 1.3),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Жабуу'),
              ),
            ],
          ),
        );
      } else {
        messenger.showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: AppTheme.errorColor,
            action: SnackBarAction(
              label: 'Ботту жөндөө',
              textColor: Colors.white,
              onPressed: _showTelegramSettingsModal,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final schoolName = _schoolData?['name'] as String? ?? _qrData?['school_name'] as String? ?? '№1 Орто Мектеп';
    final schoolId = _schoolData?['id'] as String? ?? _qrData?['school_id'] as String? ?? '';
    final lat = (_schoolData?['latitude'] as num?)?.toDouble() ?? 42.8746;
    final lng = (_schoolData?['longitude'] as num?)?.toDouble() ?? 74.5698;
    final radius = (_schoolData?['allowed_radius_meters'] as num?)?.toDouble() ?? 150.0;
    final qrToken = _qrData?['qr_token'] as String? ?? 'school-qr-demo-token-12345';

    final total = _dashboardData?['total_teachers'] ?? 0;
    final checkedIn = _dashboardData?['checked_in_count'] ?? 0;
    final onTime = _dashboardData?['on_time_count'] ?? 0;
    final lateCount = _dashboardData?['late_count'] ?? 0;

    final attendanceRate = total > 0 ? ((checkedIn / total) * 100).toStringAsFixed(0) : '0';
    final onTimeRate = total > 0 ? ((onTime / total) * 100).toStringAsFixed(0) : '0';

    final tgToken = _schoolData?['telegram_bot_token'] as String? ?? '';
    final tgChatId = _schoolData?['telegram_chat_id'] as String? ?? '';
    final tgEnabled = _schoolData?['telegram_enabled'] as bool? ?? false;
    final isTgConfigured = tgToken.isNotEmpty && tgChatId.isNotEmpty;
    final rawReportTime = _schoolData?['telegram_report_time'] as String? ?? '17:30';
    final reportTimeFormatted = rawReportTime.length >= 5 ? rawReportTime.substring(0, 5) : rawReportTime;

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        children: [
          // 1. School Geofence Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppTheme.borderColor),
              boxShadow: const [
                BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 3)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.location_on_rounded, size: 20, color: AppTheme.primaryColor),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Мектептин Жайгашуусу',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5, color: AppTheme.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _showEditSchoolDialog,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_rounded, size: 14, color: AppTheme.primaryColor),
                            SizedBox(width: 4),
                            Text('Өзгөртүү', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  schoolName,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.successColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.radar_rounded, size: 14, color: AppTheme.successColor),
                          SizedBox(width: 4),
                          Text('Радиус: ${radius.toInt()}м', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.successColor)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.place_rounded, size: 14, color: AppTheme.secondaryColor),
                          SizedBox(width: 4),
                          Text('${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}', style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Telegram Reports Card (NEW)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppTheme.borderColor),
              boxShadow: const [
                BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 3)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.send_rounded, size: 20, color: Color(0xFF0284C7)),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Telegram Отчеттору',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5, color: AppTheme.textPrimary),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _showTelegramSettingsModal,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.borderColor),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.settings_outlined, size: 14, color: AppTheme.textSecondary),
                            SizedBox(width: 4),
                            Text('Жөндөө', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Status Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: isTgConfigured && tgEnabled ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isTgConfigured && tgEnabled ? const Color(0xFFBBF7D0) : AppTheme.borderColor),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isTgConfigured && tgEnabled ? Icons.check_circle_rounded : Icons.pending_rounded,
                        size: 16,
                        color: isTgConfigured && tgEnabled ? AppTheme.successColor : AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isTgConfigured && tgEnabled
                              ? 'Канал: $tgChatId • ⏰ Саат $reportTimeFormatted'
                              : (isTgConfigured ? 'Бот жөндөлгөн, бирок өчүрүлгөн' : 'Бот туташтырыла элек (Жөндөө басыңыз)'),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: isTgConfigured && tgEnabled ? const Color(0xFF166534) : AppTheme.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Send Today's Report Button (Primary)
                ElevatedButton.icon(
                  onPressed: _isSendingTelegram ? null : () => _sendTelegramReport(),
                  icon: _isSendingTelegram
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send_rounded, size: 18),
                  label: const Text(
                    'Бүгүнкү күндөлүк отчетту жөнөтүү',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 46),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 8),

                // Send Custom Date Report Button
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2025),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      _sendTelegramReport(date: picked);
                    }
                  },
                  icon: const Icon(Icons.calendar_month_rounded, size: 16, color: Color(0xFF0284C7)),
                  label: const Text(
                    'Башка күндүн отчетун тандап жөнөтүү',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5, color: Color(0xFF0284C7)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 40),
                    side: const BorderSide(color: Color(0xFFBAE6FD)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. Analytics Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppTheme.borderColor),
              boxShadow: const [
                BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 3)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.insights_rounded, size: 20, color: AppTheme.primaryColor),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Катышуу Аналитикасы',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5, color: AppTheme.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Expanded(child: _buildMetric('Катышуу', '$attendanceRate%', AppTheme.primaryColor)),
                    Container(height: 32, width: 1, color: AppTheme.borderColor),
                    Expanded(child: _buildMetric('Өз уб.', '$onTimeRate%', AppTheme.successColor)),
                    Container(height: 32, width: 1, color: AppTheme.borderColor),
                    Expanded(child: _buildMetric('Кечиккен', '$lateCount', Colors.orange)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4. School QR Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppTheme.borderColor),
              boxShadow: const [
                BoxShadow(color: Color(0x06000000), blurRadius: 10, offset: Offset(0, 3)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.qr_code_2_rounded, size: 20, color: AppTheme.secondaryColor),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Мектептин QR-коду',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5, color: AppTheme.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Мугалимдер келгенде/кеткенде ушул QR-кодду сканерлешет:',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.borderColor),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Токен: $qrToken',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppTheme.textPrimary),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 18, color: AppTheme.primaryColor),
                            tooltip: 'Көчүрүү',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: qrToken));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Токен көчүрүлдү!'), duration: Duration(seconds: 1)),
                              );
                            },
                          ),
                        ],
                      ),
                      Text('Мектеп ID: $schoolId', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: () => context.push('/admin/qr-code'),
                  icon: const Icon(Icons.qr_code_rounded, size: 18),
                  label: const Text('QR-кодду ачуу жана көрсөтүү', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    minimumSize: const Size(double.infinity, 44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 5. System Info Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppTheme.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 18, color: AppTheme.successColor),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Коопсуздук жана Эрежелер',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: AppTheme.textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildSystemTile('Убакыт алкагы', 'Asia/Bishkek (Сервердик так убакыт)'),
                const Divider(height: 14),
                _buildSystemTile('GPS Текшерүү', 'Haversine Geofencing (Радиус: ${radius.toInt()}м)'),
                const Divider(height: 14),
                _buildSystemTile('Купуялуулук', 'Координаталар базага сакталбайт'),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 10.5, color: AppTheme.textSecondary), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }

  Widget _buildSystemTile(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}
