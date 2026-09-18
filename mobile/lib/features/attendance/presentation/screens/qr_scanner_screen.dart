import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:teacher_mobile/core/services/location_service.dart';
import 'package:teacher_mobile/core/theme/app_theme.dart';
import 'package:teacher_mobile/features/attendance/domain/attendance_qr_payload.dart';
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
      final qrPayload = AttendanceQrPayload.tryParse(rawValue);
      if (qrPayload == null) {
        throw Exception('QR_INVALID');
      }

      // 1. Fetch current GPS location
      final location = await LocationService.getCurrentLocation();

      if (!mounted) return;

      // 2. Call Check-in or Check-out
      final cubit = context.read<AttendanceCubit>();
      if (widget.isCheckOut) {
        await cubit.checkOut(
          schoolId: qrPayload.schoolId,
          qrToken: qrPayload.token,
          latitude: location.latitude,
          longitude: location.longitude,
          accuracy: location.accuracy,
          deviceInfo: 'teacher_mobile/${Platform.operatingSystem}',
        );
      } else {
        await cubit.checkIn(
          schoolId: qrPayload.schoolId,
          qrToken: qrPayload.token,
          latitude: location.latitude,
          longitude: location.longitude,
          accuracy: location.accuracy,
          deviceInfo: 'teacher_mobile/${Platform.operatingSystem}',
        );
      }
    } catch (e) {
      if (!mounted) return;
      String errorMsg = e.toString().replaceFirst('Exception: ', '');
      if (errorMsg == 'LOCATION_SERVICES_DISABLED') {
        errorMsg =
            'GPS геолокация кызматы өчүк. Сураныч, жөндөөлөрдөн GPSти күйгүзүңүз.';
      } else if (errorMsg == 'LOCATION_PERMISSION_DENIED') {
        errorMsg = 'Жайгашкан жерге (GPS) уруксат берилген жок.';
      } else if (errorMsg == 'LOCATION_PERMISSION_PERMANENTLY_DENIED') {
        errorMsg =
            'GPS уруксаты өчүрүлгөн. Телефондун жөндөөлөрүнөн колдонмого геолокация уруксатын бериңиз.';
      } else if (errorMsg == 'QR_INVALID') {
        errorMsg = 'Бул мектептин жарактуу QR-коду эмес.';
      } else {
        errorMsg =
            'Жайгашкан жерди аныктоо мүмкүн болгон жок. Интернетти жана GPSти текшерип, кайра аракет кылыңыз.';
      }

      final canOpenSettings = e.toString().contains(
        'LOCATION_PERMISSION_PERMANENTLY_DENIED',
      );

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
            if (canOpenSettings)
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  setState(() => _isProcessing = false);
                  await openAppSettings();
                  if (mounted) await _scannerController.start();
                },
                child: const Text('Жөндөөлөрдү ачуу'),
              ),
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

  Widget _buildScannerError(
    BuildContext context,
    MobileScannerException error,
  ) {
    final permissionDenied =
        error.errorCode == MobileScannerErrorCode.permissionDenied;
    final message = permissionDenied
        ? 'QR сканерлөө үчүн камерага уруксат бериңиз.'
        : error.errorCode == MobileScannerErrorCode.unsupported
        ? 'Бул түзмөктө камера аркылуу QR сканерлөө жеткиликсиз.'
        : 'Камераны ачууда ката кетти. Колдонмону кайра иштетип көрүңүз.';

    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.no_photography_outlined,
                color: Colors.white,
                size: 54,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              if (permissionDenied) ...[
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () async => openAppSettings(),
                  child: const Text('Жөндөөлөрдү ачуу'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
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
                  const Icon(
                    Icons.check_circle,
                    color: AppTheme.successColor,
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.isCheckOut ? 'Кетүү катталды' : 'Келүү катталды',
                    ),
                  ),
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
                  Icon(
                    Icons.warning_amber_rounded,
                    color: AppTheme.warningColor,
                    size: 28,
                  ),
                  SizedBox(width: 8),
                  Expanded(child: Text('Катталган жок')),
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
          title: Text(widget.isCheckOut ? 'Кетүүнү каттоо' : 'Келүүнү каттоо'),
          actions: [
            IconButton(
              tooltip: 'Жарыкты күйгүзүү / өчүрүү',
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
              errorBuilder: _buildScannerError,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
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
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 12),
                          Flexible(
                            child: Text(
                              'GPS жана QR текшерилүүдө...',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
