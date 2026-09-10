// OWNER: A5. Full-screen camera scanner (Android, iOS, macOS, Web).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../l10n/l10n.dart';
import '../../../theme/spacing.dart';
import '../../../widgets/empty_state.dart';
import 'keyboard_wedge_dialog.dart';
import 'stable_code_detector.dart';

/// The barcode symbologies a shop actually uses. Restricting the list makes
/// detection faster and stops the scanner reading stray QR codes as products.
const kShelfWiseBarcodeFormats = <BarcodeFormat>[
  BarcodeFormat.ean13,
  BarcodeFormat.ean8,
  BarcodeFormat.upcA,
  BarcodeFormat.upcE,
  BarcodeFormat.code128,
  BarcodeFormat.qrCode,
];

/// Full-screen scanner. Pops the scanned code, or null when cancelled.
class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final _controller = MobileScannerController(
    formats: kShelfWiseBarcodeFormats,
    detectionSpeed: DetectionSpeed.normal,
  );
  final _detector = StableCodeDetector();
  bool _handled = false;

  @override
  void dispose() {
    unawaited(_controller.dispose());
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    for (final barcode in capture.barcodes) {
      final code = _detector.offer(barcode.rawValue);
      if (code != null) {
        unawaited(_accept(code));
        return;
      }
    }
  }

  Future<void> _accept(String code) async {
    if (_handled) return;
    _handled = true;
    unawaited(SystemSound.play(SystemSoundType.click));
    unawaited(HapticFeedback.mediumImpact());
    await _controller.stop().onError((_, _) {});
    if (mounted) Navigator.of(context).pop(code);
  }

  Future<void> _enterManually() async {
    final code = await showKeyboardWedgeDialog(context);
    if (code == null || !mounted) return;
    _handled = true;
    await _controller.stop().onError((_, _) {});
    if (mounted) Navigator.of(context).pop(code);
  }

  Future<void> _toggleTorch() async {
    try {
      await _controller.toggleTorch();
    } on MobileScannerException {
      // No torch on this camera — nothing to report to the user.
    }
  }

  Future<void> _switchCamera() async {
    try {
      await _controller.switchCamera();
    } on MobileScannerException {
      // Only one camera; leave the preview as it is.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(l10n.platform_scanTitle),
        actions: [
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, _) {
              if (state.torchState == TorchState.unavailable) return const SizedBox.shrink();
              final on = state.torchState == TorchState.on;
              return IconButton(
                tooltip: l10n.platform_scanTorch,
                icon: Icon(on ? Icons.flash_on : Icons.flash_off),
                onPressed: _toggleTorch,
              );
            },
          ),
          IconButton(
            tooltip: l10n.platform_scanSwitchCamera,
            icon: const Icon(Icons.cameraswitch_outlined),
            onPressed: _switchCamera,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.biggest;
          final width = size.shortestSide * 0.8;
          final scanWindow = Rect.fromCenter(
            center: size.center(Offset.zero),
            width: width,
            height: width * 0.6,
          );
          return Stack(
            fit: StackFit.expand,
            children: [
              MobileScanner(
                controller: _controller,
                onDetect: _onDetect,
                scanWindow: scanWindow,
                errorBuilder: (context, error) => _ScanError(
                  error: error,
                  onEnterManually: _enterManually,
                ),
              ),
              ScanWindowOverlay(
                controller: _controller,
                scanWindow: scanWindow,
                borderColor: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(AppRadii.lg),
                borderWidth: 3,
              ),
              PositionedDirectional(
                bottom: 0,
                start: 0,
                end: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.platform_scanHint,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextButton.icon(
                          style: TextButton.styleFrom(foregroundColor: Colors.white),
                          onPressed: _enterManually,
                          icon: const Icon(Icons.keyboard_outlined),
                          label: Text(l10n.platform_scanEnterManually),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Camera permission refused, no camera, or the camera failed to start.
class _ScanError extends StatelessWidget {
  const _ScanError({required this.error, required this.onEnterManually});

  final MobileScannerException error;
  final VoidCallback onEnterManually;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (title, message) = switch (error.errorCode) {
      MobileScannerErrorCode.permissionDenied => (
          l10n.platform_cameraDeniedTitle,
          l10n.platform_cameraDeniedBody,
        ),
      MobileScannerErrorCode.unsupported => (
          l10n.platform_cameraUnsupportedTitle,
          l10n.platform_cameraUnsupportedBody,
        ),
      _ => (l10n.platform_cameraErrorTitle, l10n.platform_cameraErrorBody),
    };
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: EmptyState(
        icon: Icons.no_photography_outlined,
        title: title,
        message: message,
        action: FilledButton.icon(
          onPressed: onEnterManually,
          icon: const Icon(Icons.keyboard_outlined),
          label: Text(l10n.platform_scanEnterManually),
        ),
      ),
    );
  }
}
