import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shopdesk/features/scanner/domain/scan_result.dart';

/// Full-screen camera scanner. Stays open so a whole basket or delivery can
/// be scanned; the caller decides what each code means via [onCode].
class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({super.key, required this.onCode});
  final ScanResult Function(String code) onCode;

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  static const _repeatDelay = Duration(milliseconds: 1800);

  final _controller = MobileScannerController();
  final _lastSeen = <String, DateTime>{};
  String _message = 'Point the camera at a barcode';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue;
      if (code == null || code.isEmpty) continue;
      final now = DateTime.now();
      final last = _lastSeen[code];
      if (last != null && now.difference(last) < _repeatDelay) continue;
      _lastSeen[code] = now;
      final result = widget.onCode(code);
      HapticFeedback.lightImpact();
      setState(() => _message = result.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan items'),
        actions: [
          IconButton(
            tooltip: 'Torch',
            icon: const Icon(Icons.flashlight_on_outlined),
            onPressed: () => _controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'The camera is not available. Check the camera permission and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(_message, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Done')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
