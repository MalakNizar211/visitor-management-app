import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'verification_page.dart';

class QrScannerPage extends StatefulWidget {
  const QrScannerPage({super.key});

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  final MobileScannerController controller = MobileScannerController();
  bool hasScanned = false;

  void _onDetect(BarcodeCapture capture) async {
    if (hasScanned) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? scannedValue = barcodes.first.rawValue;
    if (scannedValue == null) return;

    setState(() => hasScanned = true);

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VerificationPage(scannedId: scannedValue),
      ),
    );

    if (!mounted) return;
    Navigator.pop(context); // close the scanner screen once verification is done
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.lightBlue,
        title: const Text('Scan Visitor QR'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => controller.toggleTorch(),
          ),
        ],
      ),
      body: MobileScanner(
        controller: controller,
        onDetect: _onDetect,
      ),
    );
  }
}