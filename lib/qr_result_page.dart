import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

import 'app_theme.dart';
import 'models/visit_schedule_model.dart';

class QrResultPage extends StatefulWidget {
  final String visitId;
  final String visitorName;

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
  State<QrResultPage> createState() {
    return _QrResultPageState();
  }
}

class _QrResultPageState extends State<QrResultPage> {
  final GlobalKey qrKey = GlobalKey();

  bool isSharing = false;

  static const List<String> _weekdayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const List<String> _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  String _formatDate(DateTime date) {
    final weekday = _weekdayNames[date.weekday - 1];
    final month = _monthNames[date.month - 1];

    return '$weekday, ${date.day} $month ${date.year}';
  }

  String _formatTime(DateTime date) {
    final hour24 = date.hour;
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final minute = date.minute.toString().padLeft(2, '0');

    return '$hour12:$minute $period';
  }

  String _value(String? value) {
    final text = value?.trim();

    if (text == null || text.isEmpty) {
      return '-';
    }

    return text;
  }

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
        ..sort(
              (a, b) {
            return a.scheduledStart.compareTo(b.scheduledStart);
          },
        );

      if (sorted.length == 1) {
        final schedule = sorted.first;

        buffer.writeln('Date: ${_formatDate(schedule.scheduledStart)}');
        buffer.writeln(
          'Time: ${_formatTime(schedule.scheduledStart)} – ${_formatTime(schedule.scheduledEnd)}',
        );
      } else {
        buffer.writeln('Scheduled visits:');

        const maxLines = 6;

        final linesToShow = sorted.length > maxLines ? maxLines : sorted.length;

        for (var i = 0; i < linesToShow; i++) {
          final schedule = sorted[i];

          buffer.writeln(
            '  • ${_formatDate(schedule.scheduledStart)}, '
                '${_formatTime(schedule.scheduledStart)} – '
                '${_formatTime(schedule.scheduledEnd)}',
          );
        }

        if (sorted.length > maxLines) {
          final remaining = sorted.length - maxLines;

          buffer.writeln(
            '  ...and $remaining more scheduled visit${remaining == 1 ? '' : 's'}.',
          );
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
    setState(() {
      isSharing = true;
    });

    try {
      final boundary =
      qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;

      final image = await boundary.toImage(pixelRatio: 3.0);

      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      final pngBytes = byteData!.buffer.asUint8List();

      final tempDir = await getTemporaryDirectory();

      final file = await File('${tempDir.path}/visit_qr.png').create();

      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: _buildShareMessage(),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          content: Text(
            'Failed to share: ${error.toString()}',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSharing = false;
        });
      }
    }
  }

  List<VisitSchedule> get _sortedSchedules {
    final schedules = [...(widget.schedules ?? <VisitSchedule>[])];

    schedules.sort(
          (a, b) {
        return a.scheduledStart.compareTo(b.scheduledStart);
      },
    );

    return schedules;
  }

  Widget _infoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    if (value.trim().isEmpty || value == '-') {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.line,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppIconBadge(
            icon: icon,
            size: 38,
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 84,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w800,
                fontSize: 14,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _visitorHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppGradients.header,
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: [
          BoxShadow(
            color: AppColors.ratpGreen.withOpacity(.22),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.17),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: Colors.white.withOpacity(.22),
              ),
            ),
            child: const Icon(
              Icons.verified_user_outlined,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Visitor Pass',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              letterSpacing: -.5,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            'Present this QR code at the security gate.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(.84),
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _visitorNameCard() {
    return SectionCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.softGreen,
            child: Text(
              initialsFromName(widget.visitorName),
              style: const TextStyle(
                color: AppColors.ratpGreenDark,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Visitor',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.visitorName,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _qrCard() {
    return SectionCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          const Row(
            children: [
              AppIconBadge(
                icon: Icons.qr_code_2_rounded,
                size: 42,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Access QR Code',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          RepaintBoundary(
            key: qrKey,
            child: Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: AppColors.line,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(.05),
                    blurRadius: 22,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: QrImageView(
                data: widget.visitId,
                version: QrVersions.auto,
                size: 235,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: AppColors.navy,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: AppColors.navy,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'This QR code is unique for this visit and should be presented upon arrival.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailsCard() {
    final hasAnyDetails = widget.hostName != null ||
        widget.department != null ||
        widget.purpose != null ||
        widget.floor != null ||
        widget.room != null ||
        _sortedSchedules.isNotEmpty;

    if (!hasAnyDetails) {
      return const SizedBox.shrink();
    }

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              AppIconBadge(
                icon: Icons.description_outlined,
                size: 42,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Visit details',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_sortedSchedules.isNotEmpty) _scheduleList(),
          _infoRow(
            icon: Icons.business_center_outlined,
            label: 'Host',
            value:
            '${_value(widget.hostName)}${widget.department != null ? ' (${widget.department})' : ''}',
          ),
          _infoRow(
            icon: Icons.description_outlined,
            label: 'Purpose',
            value: _value(widget.purpose),
          ),
          _infoRow(
            icon: Icons.meeting_room_outlined,
            label: 'Location',
            value: widget.floor != null || widget.room != null
                ? 'Floor ${_value(widget.floor)}, Room ${_value(widget.room)}'
                : '-',
          ),
        ],
      ),
    );
  }

  Widget _scheduleList() {
    final schedules = _sortedSchedules;

    final visibleSchedules = schedules.length > 4
        ? schedules.take(4).toList()
        : schedules;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...visibleSchedules.map(
              (schedule) {
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.line,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppIconBadge(
                    icon: Icons.event_available_outlined,
                    size: 38,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Scheduled visit',
                          style: TextStyle(
                            color: AppColors.muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(schedule.scheduledStart),
                          style: const TextStyle(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_formatTime(schedule.scheduledStart)} – ${_formatTime(schedule.scheduledEnd)}',
                          style: const TextStyle(
                            color: AppColors.ratpGreenDark,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        if (schedules.length > 4)
          Padding(
            padding: const EdgeInsets.only(
              bottom: 10,
              left: 4,
            ),
            child: Text(
              '+ ${schedules.length - 4} more scheduled visit${schedules.length - 4 == 1 ? '' : 's'}',
              style: const TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }

  Widget _shareButton() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(
          top: BorderSide(
            color: AppColors.line,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 24,
            offset: const Offset(0, -10),
          ),
        ],
      ),
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
            : const Icon(Icons.ios_share_rounded),
        label: Text(
          isSharing ? 'Preparing...' : 'Share Visitor Pass',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Visitor Pass'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 480,
              ),
              child: Column(
                children: [
                  _visitorHeader(),
                  const SizedBox(height: 18),
                  _visitorNameCard(),
                  const SizedBox(height: 18),
                  _qrCard(),
                  const SizedBox(height: 18),
                  _detailsCard(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _shareButton(),
    );
  }
}