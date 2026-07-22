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
        builder: (context) => VerificationPage(
          scannedId: scannedValue,
        ),
      ),
    );

    if (!mounted) return;

    Navigator.pop(context);
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
        title: const Text("Scan Visitor QR"),
        actions: [
          IconButton(
            tooltip: "Toggle Flashlight",
            icon: const Icon(Icons.flashlight_on_outlined),
            onPressed: () => controller.toggleTorch(),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: controller,
            onDetect: _onDetect,
          ),

          Container(
            color: Colors.black.withOpacity(0.30),
          ),

          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white,
                  width: 3,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),

          Positioned(
            top: 40,
            left: 24,
            right: 24,
            child: Column(
              children: const [
                Text(
                  "Scan Visitor QR Code",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  "Position the QR code inside the frame.\nScanning starts automatically.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),

          Positioned(
            bottom: 50,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.92),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                    ),
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      "Scanning...",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}