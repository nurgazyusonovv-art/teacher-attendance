import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/repositories/admin_mobile_repository.dart';

class AdminQrCodeScreen extends StatefulWidget {
  const AdminQrCodeScreen({super.key});

  @override
  State<AdminQrCodeScreen> createState() => _AdminQrCodeScreenState();
}

class _AdminQrCodeScreenState extends State<AdminQrCodeScreen> {
  final AdminMobileRepository _repository = AdminMobileRepository();
  final GlobalKey _qrPosterKey = GlobalKey();
  Map<String, dynamic>? _qrData;
  bool _isLoading = true;
  bool _isRotating = false;
  bool _isExporting = false;

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

  Future<void> _exportAndSaveQrImage() async {
    if (_isExporting) return;
    setState(() => _isExporting = true);

    try {
      // Find the render boundary
      final boundary = _qrPosterKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        throw Exception('QR сүрөтүн даярдоодо ката кетти');
      }

      // Render image at 3.0x pixel ratio for crisp print quality
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw Exception('PNG байттары алынган жок');
      }
      final pngBytes = byteData.buffer.asUint8List();

      // Write to temp file
      final tempDir = await getTemporaryDirectory();
      final schoolNameClean = (_qrData?['school_name'] as String? ?? 'mektep')
          .replaceAll(RegExp(r'[^\w\sа-яА-ЯөӨүҮңҢ]'), '')
          .replaceAll(' ', '_');
      final filePath = '${tempDir.path}/qr_${schoolNameClean}_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes);

      if (!mounted) return;

      final schoolName = _qrData?['school_name'] as String? ?? '№1 Орто Мектеп';

      // Open native save / share sheet (Allows saving to Photos, Files, AirDrop, Print, WhatsApp)
      final box = context.findRenderObject() as RenderBox?;
      await Share.shareXFiles(
        [XFile(filePath, mimeType: 'image/png', name: 'school_qr.png')],
        text: '$schoolName - Мугалимдердин катышуусун каттоочу расмий QR-коду',
        sharePositionOrigin: box != null ? box.localToGlobal(Offset.zero) & box.size : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('QR-код сүрөт катары даярдалды! Сактап же басып чыгарыңыз.'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Сүрөттү сактоодо ката: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
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
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Сүрөттү жүктөө / бөлүшүү',
            onPressed: _isLoading ? null : _exportAndSaveQrImage,
          ),
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
                    // Main QR Poster Card (Captured by RepaintBoundary for PNG export)
                    RepaintBoundary(
                      key: _qrPosterKey,
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: AppTheme.borderColor),
                          boxShadow: const [
                            BoxShadow(color: Color(0x0A000000), blurRadius: 16, offset: Offset(0, 4)),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
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
                                  SizedBox(width: 4),
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
                                fontSize: 17,
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
                              style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 14),

                            // QR Code Container
                            Container(
                              padding: const EdgeInsets.all(12),
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
                            const SizedBox(height: 12),

                            // Geofence info badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                                      'Мектеп аймагы • GPS текшерүү',
                                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
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
                    ),
                    const SizedBox(height: 16),

                    // Download / Save QR Code as Image Button (Primary Action)
                    ElevatedButton(
                      onPressed: _isExporting ? null : _exportAndSaveQrImage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 52),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 3,
                      ),
                      child: _isExporting
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                                SizedBox(width: 10),
                                Text('Сүрөт даярдалууда...', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold)),
                              ],
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.file_download_rounded, size: 22),
                                SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'QR-кодду сүрөт кылып жүктөп алуу',
                                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.bold),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    const SizedBox(height: 10),

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
                              'Бул QR-кодду жүктөп алып, кагазга басып чыгарып, мектептин башкы эшигине чаптап койсоңуз болот.',
                              style: TextStyle(fontSize: 11.5, color: Color(0xFF1E40AF), height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Fullscreen View Button
                    OutlinedButton(
                      onPressed: () => _showFullscreenQr(qrString, schoolName),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 46),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        side: const BorderSide(color: AppTheme.borderColor),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.fullscreen_rounded, size: 20, color: AppTheme.primaryColor),
                          SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Экранга чоңойтуп чыгаруу',
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
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
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
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
