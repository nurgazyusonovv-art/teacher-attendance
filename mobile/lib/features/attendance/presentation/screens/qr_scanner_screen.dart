import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:teacher_mobile/core/services/location_service.dart';
import 'package:teacher_mobile/core/theme/app_theme.dart';
import '../cubit/attendance_cubit.dart';
import '../cubit/attendance_state.dart';

class QrScannerScreen extends StatefulWidget {
  final bool isCheckOut;

  const QrScannerScreen({super.key, this.isCheckOut = false});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _isProcessing = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _handleBarcode(BarcodeCapture capture) async {
    if (_isProcessing) return;
    final barcode = capture.barcodes.firstOrNull;
    final rawValue = barcode?.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    setState(() => _isProcessing = true);
    await _scannerController.stop();

    try {
      String schoolId = '';
      String qrToken = '';

      try {
        final decoded = jsonDecode(rawValue) as Map<String, dynamic>;
        schoolId = decoded['school_id'] as String? ?? '';
        qrToken = decoded['qr_token'] as String? ?? decoded['token'] as String? ?? '';
      } catch (_) {
        // Fallback for direct token string or standard payload
        qrToken = rawValue.trim();
      }

      // 1. Fetch current GPS location
      final location = await LocationService.getCurrentLocation();

      if (!mounted) return;

      // 2. Call Check-in or Check-out
      final cubit = context.read<AttendanceCubit>();
      if (widget.isCheckOut) {
        await cubit.checkOut(
          schoolId: schoolId,
          qrToken: qrToken,
          latitude: location.latitude,
          longitude: location.longitude,
          accuracy: location.accuracy,
          deviceInfo: 'iOS Mobile App',
        );
      } else {
        await cubit.checkIn(
          schoolId: schoolId,
          qrToken: qrToken,
          latitude: location.latitude,
          longitude: location.longitude,
          accuracy: location.accuracy,
          deviceInfo: 'iOS Mobile App',
        );
      }
    } catch (e) {
      if (!mounted) return;
      String errorMsg = e.toString().replaceFirst('Exception: ', '');
      if (errorMsg == 'LOCATION_SERVICES_DISABLED') {
        errorMsg = 'GPS геолокация кызматы өчүк. Сураныч, жөндөөлөрдөн GPSти күйгүзүңүз.';
      } else if (errorMsg == 'LOCATION_PERMISSION_DENIED') {
        errorMsg = 'Жайгашкан жерге (GPS) уруксат берилген жок.';
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.error_outline, color: AppTheme.errorColor),
              SizedBox(width: 8),
              Text('Ката кетти'),
            ],
          ),
          content: Text(errorMsg),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() => _isProcessing = false);
                _scannerController.start();
              },
              child: const Text('Кайра аракет кылуу'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AttendanceCubit, AttendanceState>(
      listener: (context, state) {
        if (state is AttendanceActionSuccess) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.check_circle, color: AppTheme.successColor, size: 28),
                  const SizedBox(width: 8),
                  Text(widget.isCheckOut ? 'Кетүү катталды' : 'Келүү катталды'),
                ],
              ),
              content: Text(state.message),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    context.pop(true);
                  },
                  child: const Text('Жакшы'),
                ),
              ],
            ),
          );
        } else if (state is AttendanceError) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: AppTheme.warningColor, size: 28),
                  SizedBox(width: 8),
                  Text('Катталган жок'),
                ],
              ),
              content: Text(state.message),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    setState(() => _isProcessing = false);
                    _scannerController.start();
                  },
                  child: const Text('Кайра сканерлөө'),
                ),
              ],
            ),
          );
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(widget.isCheckOut ? 'Кетүү (Check-out) QR' : 'Келүү (Check-in) QR'),
          actions: [
            IconButton(
              icon: const Icon(Icons.flash_on),
              onPressed: () => _scannerController.toggleTorch(),
            ),
          ],
        ),
        body: Stack(
          children: [
            MobileScanner(
              controller: _scannerController,
              onDetect: _handleBarcode,
            ),

            // Viewfinder cutout overlay
            Center(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.primaryColor, width: 3),
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),

            // Bottom guidance prompt
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.75),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isProcessing)
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          ),
                          SizedBox(width: 12),
                          Text(
                            'GPS жана QR текшерилүүдө...',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      )
                    else
                      const Text(
                        'Мектептин эшигиндеги же дубалындагы QR-кодду алкактын ортосуна багыттаңыз',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 13),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
