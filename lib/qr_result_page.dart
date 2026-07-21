import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class QrResultPage extends StatefulWidget {
  final String visitId;
  final String visitorName;

  const QrResultPage({
    super.key,
    required this.visitId,
    required this.visitorName,
  });

  @override
  State<QrResultPage> createState() => _QrResultPageState();
}

class _QrResultPageState extends State<QrResultPage> {
  final GlobalKey qrKey = GlobalKey();
  bool isSharing = false;

  Future<void> _shareQr() async {
    setState(() => isSharing = true);
    try {
      RenderRepaintBoundary boundary =
      qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData =
      await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/visit_qr.png').create();
      await file.writeAsBytes(pngBytes);


      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Visitor pass for ${widget.visitorName}. Please present this QR code at the gate.',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.lightBlue,
        title: const Text('Visitor QR Code'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              widget.visitorName,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            RepaintBoundary(
              key: qrKey,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: QrImageView(
                  data: widget.visitId,
                  version: QrVersions.auto,
                  size: 250,
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: isSharing ? null : _shareQr,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
                icon: const Icon(Icons.share),
                label: isSharing
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Share via WhatsApp', style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}