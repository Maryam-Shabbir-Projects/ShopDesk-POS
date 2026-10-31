import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shopdesk/features/scanner/domain/scan_result.dart';
import 'package:shopdesk/features/scanner/presentation/barcode_scanner_page.dart';

/// Text field for USB / Bluetooth scanners (they type the code and press
/// Enter) plus a button that opens the camera scanner.
class ScanInputBar extends StatefulWidget {
  const ScanInputBar({super.key, required this.onCode, this.onUnknown});

  final ScanResult Function(String code) onCode;
  final void Function(String code)? onUnknown;

  @override
  State<ScanInputBar> createState() => _ScanInputBarState();
}

class _ScanInputBarState extends State<ScanInputBar> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit(String value) {
    final code = value.trim();
    _controller.clear();
    _focus.requestFocus();
    if (code.isEmpty) return;
    final result = widget.onCode(code);
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(result.message), duration: const Duration(milliseconds: 1400)));
    if (result.outcome == ScanOutcome.unknown) widget.onUnknown?.call(code);
  }

  void _openCamera() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => BarcodeScannerPage(onCode: widget.onCode)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            focusNode: _focus,
            textInputAction: TextInputAction.done,
            onSubmitted: _submit,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.qr_code_scanner),
              hintText: 'Scan or type barcode, press Enter',
            ),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          tooltip: 'Scan with camera',
          onPressed: _openCamera,
          icon: const Icon(Icons.photo_camera_outlined),
        ),
      ],
    );
  }
}
