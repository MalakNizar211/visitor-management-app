import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'models/visit_schedule_model.dart';

class QrResultPage extends StatefulWidget {
  final String visitId;
  final String visitorName;

  // Optional extra details used to build the formal share message.
  // Pass whatever you have available - anything left null is simply
  // skipped in the message instead of showing as "null" or a blank line.
  // schedules carries full start/end time ranges per day, not just a
  // single timestamp - this is what lets the message show real ranges
  // like "2:00 PM - 4:00 PM" instead of only a start time.
  final String? hostName;
  final String? department;
  final String? purpose;
  final String? floor;
  final String? room;
  final List<VisitSchedule>? schedules;
  final String? companyName;

  const QrResultPage({
    super.key,
    required this.visitId,
    required this.visitorName,
    this.hostName,
    this.department,
    this.purpose,
    this.floor,
    this.room,
    this.schedules,
    this.companyName,
  });

  @override
  State<QrResultPage> createState() => _QrResultPageState();
}

class _QrResultPageState extends State<QrResultPage> {
  final GlobalKey qrKey = GlobalKey();

  bool isSharing = false;

  static const Color primaryBlue = Color(0xFF003B71);

  static const List<String> _weekdayNames = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];
  static const List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  String _formatDate(DateTime d) {
    final weekday = _weekdayNames[d.weekday - 1];
    final month = _monthNames[d.month - 1];
    return '$weekday, ${d.day} $month ${d.year}';
  }

  String _formatTime(DateTime d) {
    final hour24 = d.hour;
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final minute = d.minute.toString().padLeft(2, '0');
    return '$hour12:$minute $period';
  }

  // Builds the full formal, welcoming message sent alongside the QR image.
  String _buildShareMessage() {
    final buffer = StringBuffer();

    buffer.writeln('Dear ${widget.visitorName},');
    buffer.writeln();
    buffer.writeln(
      'You are cordially invited to visit ${widget.companyName ?? 'our office'}. '
          'We are pleased to confirm the details of your visit below.',
    );
    buffer.writeln();

    if (widget.schedules != null && widget.schedules!.isNotEmpty) {
      final sorted = [...widget.schedules!]
        ..sort((a, b) => a.scheduledStart.compareTo(b.scheduledStart));

      if (sorted.length == 1) {
        final s = sorted.first;
        buffer.writeln('Date: ${_formatDate(s.scheduledStart)}');
        buffer.writeln('Time: ${_formatTime(s.scheduledStart)} – ${_formatTime(s.scheduledEnd)}');
      } else {
        buffer.writeln('Scheduled visits:');
        const maxLines = 6;
        final linesToShow = sorted.length > maxLines ? maxLines : sorted.length;

        for (var i = 0; i < linesToShow; i++) {
          final s = sorted[i];
          buffer.writeln(
            '  • ${_formatDate(s.scheduledStart)}, ${_formatTime(s.scheduledStart)} – ${_formatTime(s.scheduledEnd)}',
          );
        }

        if (sorted.length > maxLines) {
          final remaining = sorted.length - maxLines;
          buffer.writeln('  ...and $remaining more scheduled visit${remaining == 1 ? '' : 's'}.');
        }
      }
    }

    if (widget.hostName != null) {
      final dept = widget.department != null ? ' (${widget.department})' : '';
      buffer.writeln('Host: ${widget.hostName}$dept');
    }

    if (widget.purpose != null) {
      buffer.writeln('Purpose of visit: ${widget.purpose}');
    }

    if (widget.floor != null || widget.room != null) {
      buffer.writeln(
        'Location: Floor ${widget.floor ?? '-'}, Room ${widget.room ?? '-'}',
      );
    }

    buffer.writeln();
    buffer.writeln(
      'Please present the attached QR code at the security gate upon your arrival. '
          'This code is unique to your visit and will be used to check you in and out.',
    );
    buffer.writeln();
    buffer.writeln('We look forward to welcoming you.');

    return buffer.toString();
  }

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
        text: _buildShareMessage(),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade700,
          content: Text(
            'Failed to share: ${e.toString()}',
            style: const TextStyle(color: Colors.white),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => isSharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Visitor Pass"),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    children: [
                      const CircleAvatar(
                        radius: 38,
                        backgroundColor: Color(0xFFEAF2F8),
                        child: Icon(
                          Icons.verified_user_outlined,
                          color: primaryBlue,
                          size: 40,
                        ),
                      ),

                      const SizedBox(height: 20),

                      const Text(
                        "Visitor Pass",
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: primaryBlue,
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        "Present this QR code at the security gate.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),

                      const SizedBox(height: 28),

                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F7FA),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              "Visitor",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.visitorName,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: primaryBlue,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      RepaintBoundary(
                        key: qrKey,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.grey.shade300,
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Colors.black12,
                                blurRadius: 8,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: QrImageView(
                            data: widget.visitId,
                            version: QrVersions.auto,
                            size: 240,
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton.icon(
                          onPressed: isSharing ? null : _shareQr,
                          icon: isSharing
                              ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: Colors.white,
                            ),
                          )
                              : const Icon(Icons.share),

                          label: Text(
                            isSharing
                                ? "Preparing..."
                                : "Share Visitor Pass",
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      const Text(
                        "This QR code is unique for this visit and should be presented upon arrival.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}