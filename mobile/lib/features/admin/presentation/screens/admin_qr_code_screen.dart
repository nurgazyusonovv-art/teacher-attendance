import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/repositories/admin_mobile_repository.dart';

class AdminQrCodeScreen extends StatefulWidget {
  const AdminQrCodeScreen({super.key});

  @override
  State<AdminQrCodeScreen> createState() => _AdminQrCodeScreenState();
}

class _AdminQrCodeScreenState extends State<AdminQrCodeScreen> {
  final AdminMobileRepository _repository = AdminMobileRepository();
  Map<String, dynamic>? _qrData;
  bool _isLoading = true;
  bool _isRotating = false;

  @override
  void initState() {
    super.initState();
    _loadQrCode();
  }

  Future<void> _loadQrCode() async {
    setState(() => _isLoading = true);
    final data = await _repository.getSchoolQr();
    if (mounted) {
      setState(() {
        _qrData = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _rotateQr() async {
    final schoolId = _qrData?['school_id'] as String?;
    if (schoolId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'QR-кодду жаңыртуу',
                style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Text(
          'Эски басып чыгарылган QR-коддор жараксыз болуп калат. Жаңы QR-кодду кайра басып чыгаруу керек болот. Улантасызбы?',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Жокко чыгаруу'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ооба, жаңыртуу'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _isRotating = true);
      final messenger = ScaffoldMessenger.of(context);
      final newData = await _repository.rotateSchoolQr(schoolId);
      if (mounted) {
        setState(() {
          if (newData != null) _qrData = newData;
          _isRotating = false;
        });
        messenger.showSnackBar(
          SnackBar(
            content: Text(newData != null ? 'QR-код ийгиликтүү жаңыланды!' : 'Ката кетти, кайра аракет кылыңыз'),
            backgroundColor: newData != null ? AppTheme.successColor : AppTheme.errorColor,
          ),
        );
      }
    }
  }

  void _showFullscreenQr(String qrString, String schoolName) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                schoolName,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: AppTheme.textPrimary),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              const Text(
                'Келүү/кетүү каттоо үчүн сканерлеңиз',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderColor),
                ),
                child: QrImageView(
                  data: qrString,
                  version: QrVersions.auto,
                  size: 220.0,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: AppTheme.primaryColor,
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  minimumSize: const Size(double.infinity, 46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Жабуу', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final schoolName = _qrData?['school_name'] as String? ?? '№1 Орто Мектеп';
    final token = _qrData?['qr_token'] as String? ?? 'school-qr-secret-token-001';
    final rawPayload = _qrData?['qr_payload'];
    final qrString = rawPayload is String
        ? rawPayload
        : jsonEncode(rawPayload ?? {'type': 'school_attendance', 'token': token});

    final screenWidth = MediaQuery.of(context).size.width;
    final qrDisplaySize = (screenWidth * 0.52).clamp(160.0, 210.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Мектептин QR-Коду'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Жаңылоо',
            onPressed: _loadQrCode,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 14.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Main QR Poster Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppTheme.borderColor),
                        boxShadow: const [
                          BoxShadow(color: Color(0x0A000000), blurRadius: 16, offset: Offset(0, 4)),
                        ],
                      ),
                      child: Column(
                        children: [
                          // Header Badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified_rounded, size: 13, color: AppTheme.primaryColor),
                                SizedBox(width: 5),
                                Flexible(
                                  child: Text(
                                    'Расмий Каттоо Коду',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            schoolName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.3,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          const Text(
                            'Мугалимдердин келүү/кетүүсүн каттоо',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 16),

                          // QR Code Container
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: QrImageView(
                              data: qrString,
                              version: QrVersions.auto,
                              size: qrDisplaySize,
                              eyeStyle: const QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: AppTheme.primaryColor,
                              ),
                              dataModuleStyle: const QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Geofence info badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.location_on_rounded, size: 13, color: AppTheme.primaryLight),
                                SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Радиус: 150м • Asia/Bishkek',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Instruction Card
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFBFDBFE)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline_rounded, size: 18, color: AppTheme.primaryLight),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Бул QR-кодду мектептин башкы эшигине чаптап койсоңуз болот. Мугалимдер тиркемеден сканерлеп катталышат.',
                              style: TextStyle(fontSize: 11.5, color: Color(0xFF1E40AF), height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Fullscreen View Button
                    ElevatedButton(
                      onPressed: () => _showFullscreenQr(qrString, schoolName),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.fullscreen_rounded, size: 20),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'QR-кодду чоңойтуу',
                              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Rotate Button
                    OutlinedButton(
                      onPressed: _isRotating ? null : _rotateQr,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 46),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        side: const BorderSide(color: AppTheme.borderColor),
                      ),
                      child: _isRotating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.sync_lock_rounded, size: 17, color: AppTheme.textSecondary),
                                SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'QR-кодду жаңылоо (Ротация)',
                                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }
}
