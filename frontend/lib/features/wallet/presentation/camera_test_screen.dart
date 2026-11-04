import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:digital_wallet_app/core/constants/app_colors.dart';
class CameraTestScreen extends StatefulWidget {
  CameraTestScreen({super.key});

  @override
  State<CameraTestScreen> createState() => _CameraTestScreenState();
}

class _CameraTestScreenState extends State<CameraTestScreen> {
  late final MobileScannerController controller;

  String status = 'Starting camera...';
  bool isStarting = true;

  @override
  void initState() {
    super.initState();

    controller = MobileScannerController(
      autoStart: false,
      detectionSpeed: DetectionSpeed.noDuplicates,
    );

    _startCamera();
  }

  Future<void> _startCamera() async {
    try {
      await controller.start();

      if (!mounted) return;

      setState(() {
        isStarting = false;
        status = 'Camera started successfully';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isStarting = false;
        status = 'CAMERA ERROR:\n$e';
      });
    }
  }

  Future<void> _restartCamera() async {
    setState(() {
      isStarting = true;
      status = 'Restarting camera...';
    });

    try {
      await controller.stop();
      await controller.start();

      if (!mounted) return;

      setState(() {
        isStarting = false;
        status = 'Camera started successfully';
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isStarting = false;
        status = 'CAMERA ERROR:\n$e';
      });
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    AppColors.dependOnTheme(context);
    return Scaffold(
      backgroundColor: AppColors.adaptiveSurfaceAlt,
      appBar: AppBar(
        backgroundColor: AppColors.adaptiveSurfaceAlt,
        foregroundColor: AppColors.themeText,
        elevation: 0,
        title: Text(
          'Camera Test',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                decoration: BoxDecoration(
                  color: AppColors.adaptiveSurface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.blue.withValues(alpha: 0.8),
                    width: 2,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    MobileScanner(
                      controller: controller,
                      onDetect: (capture) {
                        for (final barcode in capture.barcodes) {
                          final value = barcode.rawValue;

                          if (value != null && value.trim().isNotEmpty) {
                            debugPrint('QR DETECTED: $value');

                            if (!mounted) return;

                            setState(() {
                              status = 'QR DETECTED:\n$value';
                            });
                          }
                        }
                      },
                    ),

                    if (isStarting)
                      Container(
                        color: AppColors.adaptiveSurfaceAlt.withValues(alpha: 0.75),
                        child: Center(child: CircularProgressIndicator()),
                      ),

                    IgnorePointer(
                      child: Center(
                        child: Container(
                          width: 230,
                          height: 230,
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.themeText, width: 2),
                            borderRadius: BorderRadius.circular(24),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.adaptiveSurface,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  status,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.themeText,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: isStarting ? null : _restartCamera,
                  icon: Icon(Icons.refresh),
                  label: Text(
                    'Restart Camera',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF2563EB),
                    foregroundColor: AppColors.themeText,
                    disabledBackgroundColor: Colors.grey.shade800,
                    disabledForegroundColor: Colors.grey.shade500,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
