import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'models/visit_model.dart';
import 'models/visitor_model.dart';
import 'models/employee_model.dart';
import 'models/visit_schedule_model.dart';
import 'services/visit_service.dart';
import 'services/visitor_service.dart';
import 'services/employee_service.dart';

class VerificationPage extends StatefulWidget {
  final String scannedId;

  const VerificationPage({
    super.key,
    required this.scannedId,
  });

  @override
  State<VerificationPage> createState() {
    return _VerificationPageState();
  }
}

class _VerificationData {
  final Visit? visit;
  final Visitor? visitor;
  final Employee? host;
  final VisitSchedule? todaysSchedule;
  final String? latestLogAction;

  _VerificationData({
    this.visit,
    this.visitor,
    this.host,
    this.todaysSchedule,
    this.latestLogAction,
  });
}

class _VerificationPageState extends State<VerificationPage> {
  final VisitService visitService = VisitService();
  final VisitorService visitorService = VisitorService();
  final EmployeeService employeeService = EmployeeService();

  late Future<_VerificationData> dataFuture;

  bool isProcessing = false;

  @override
  void initState() {
    super.initState();

    dataFuture = _loadData();
  }

  Future<_VerificationData> _loadData() async {
    final visit = await visitService.getVisitById(widget.scannedId);

    if (visit == null) {
      return _VerificationData();
    }

    final visitor = visit.visitorId != null
        ? await visitorService.getVisitorById(visit.visitorId!)
        : null;

    final host = visit.hostId != null
        ? await employeeService.getEmployeeById(visit.hostId!)
        : null;

    VisitSchedule? todaysSchedule;
    String? latestLogAction;

    if (visit.status == 'active') {
      todaysSchedule = await visitService.getTodaysSchedule(visit.id!);

      if (todaysSchedule != null) {
        latestLogAction = await visitService.getTodaysStatus(visit.id!);
      }
    }

    return _VerificationData(
      visit: visit,
      visitor: visitor,
      host: host,
      todaysSchedule: todaysSchedule,
      latestLogAction: latestLogAction,
    );
  }

  Future<void> _handleYes(
      Visit visit,
      bool isEntryScan,
      ) async {
    setState(() {
      isProcessing = true;
    });

    try {
      if (isEntryScan) {
        await visitService.checkIn(visit.id!);
      } else {
        await visitService.checkOut(visit.id!);
      }

      if (!mounted) return;

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEntryScan ? 'Visitor admitted' : 'Visitor checked out',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed: ${error.toString()}',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isProcessing = false;
        });
      }
    }
  }

  void _handleNo() {
    Navigator.pop(context);
  }

  Future<void> _handleNotValid(Visit visit) async {
    final reasonController = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          surfaceTintColor: AppColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
          title: const Row(
            children: [
              AppIconBadge(
                icon: Icons.report_problem_outlined,
                color: AppColors.danger,
                size: 42,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Reason for rejection',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          content: TextField(
            controller: reasonController,
            decoration: const InputDecoration(
              hintText: 'e.g. National ID does not match',
              prefixIcon: Icon(Icons.edit_note_rounded),
            ),
            autofocus: true,
            maxLines: 3,
            minLines: 1,
          ),
          actionsPadding: const EdgeInsets.fromLTRB(
            18,
            0,
            18,
            18,
          ),
          actions: [
            OutlinedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (reasonController.text.trim().isEmpty) {
                  return;
                }

                Navigator.pop(
                  context,
                  reasonController.text.trim(),
                );
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    reasonController.dispose();

    if (reason == null || reason.isEmpty) {
      return;
    }

    setState(() {
      isProcessing = true;
    });

    final result = await visitService.markInvalid(
      visit.id!,
      reason,
    );

    if (!mounted) return;

    setState(() {
      isProcessing = false;
    });

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Failed to update - please try again.',
          ),
        ),
      );

      return;
    }

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('QR marked as invalid'),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final hour24 = dateTime.hour;
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');

    return '$hour12:$minute $period';
  }

  String _scheduleStatusMessage(VisitSchedule schedule) {
    final now = DateTime.now();
    final start = schedule.scheduledStart;
    final end = schedule.scheduledEnd;
    final range = '${_formatTime(start)} – ${_formatTime(end)}';

    if (now.isBefore(start)) {
      final diff = start.difference(now);

      final untilStart = diff.inMinutes < 60
          ? 'Starts in ${diff.inMinutes} minutes'
          : 'Starts in ${diff.inHours} hours';

      return '$range · $untilStart';
    }

    if (now.isAfter(end)) {
      final diff = now.difference(end);

      final sinceEnd = diff.inMinutes < 60
          ? 'Scheduled window ended ${diff.inMinutes} minutes ago'
          : 'Scheduled window ended ${diff.inHours} hours ago';

      return '$range · $sinceEnd';
    }

    return '$range · Within scheduled window';
  }

  String _value(String? value) {
    final text = value?.trim();

    if (text == null || text.isEmpty) {
      return '-';
    }

    return text;
  }

  Widget _detailRow({
    required String label,
    required String value,
    required IconData icon,
  }) {
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
            width: 100,
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

  Widget _visitorHeader({
    required Visitor? visitor,
    required Employee? host,
    required Visit visit,
    required IconData icon,
    required Color badgeColor,
    required String badgeText,
  }) {
    final visitorName = visitor?.fullName ?? 'Unknown';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.white.withOpacity(.18),
            child: Text(
              initialsFromName(visitorName),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  visitorName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -.3,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  host?.fullName == null
                      ? 'Visitor verification'
                      : 'Visiting ${host!.fullName}',
                  style: TextStyle(
                    color: Colors.white.withOpacity(.82),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(.18),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: Colors.white.withOpacity(.22),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 5),
                Text(
                  badgeText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _visitorDetailsBlock(
      Visitor? visitor,
      Employee? host,
      Visit visit,
      ) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: Icons.badge_outlined,
            title: 'Visitor details',
            subtitle: 'Confirm the visitor identity and visit information.',
          ),
          const SizedBox(height: 16),
          _detailRow(
            label: 'National ID',
            value: _value(visitor?.nationalId),
            icon: Icons.credit_card_rounded,
          ),
          _detailRow(
            label: 'Phone',
            value: _value(visitor?.phone),
            icon: Icons.phone_outlined,
          ),
          _detailRow(
            label: 'Visiting',
            value:
            '${_value(host?.fullName)}${host?.department != null ? ' (${host?.department})' : ''}',
            icon: Icons.business_center_outlined,
          ),
          _detailRow(
            label: 'Purpose',
            value: _value(visit.purpose),
            icon: Icons.description_outlined,
          ),
          _detailRow(
            label: 'Location',
            value:
            'Floor ${_value(visit.floor)}, Room ${_value(visit.room)}',
            icon: Icons.meeting_room_outlined,
          ),
        ],
      ),
    );
  }

  Widget _messageState({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    Widget? details,
  }) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 38),
        Center(
          child: AppIconBadge(
            icon: icon,
            color: color,
            size: 76,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: -.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
        ),
        if (details != null) ...[
          const SizedBox(height: 22),
          details,
        ],
      ],
    );
  }

  Widget _verificationContent({
    required bool isEntryScan,
    required Visit visit,
    required Visitor? visitor,
    required Employee? host,
    required VisitSchedule schedule,
  }) {
    final actionColor =
    isEntryScan ? AppColors.success : AppColors.warning;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              _visitorHeader(
                visitor: visitor,
                host: host,
                visit: visit,
                icon: isEntryScan
                    ? Icons.login_rounded
                    : Icons.logout_rounded,
                badgeColor: actionColor,
                badgeText: isEntryScan ? 'ENTRY' : 'EXIT',
              ),
              const SizedBox(height: 18),
              _visitorDetailsBlock(
                visitor,
                host,
                visit,
              ),
              const SizedBox(height: 16),
              SectionCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppIconBadge(
                      icon: Icons.schedule_rounded,
                      color: actionColor,
                      size: 46,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Schedule window',
                            style: TextStyle(
                              color: AppColors.navy,
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _scheduleStatusMessage(schedule),
                            style: TextStyle(
                              color: actionColor,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        _actionBar(
          visit: visit,
          isEntryScan: isEntryScan,
        ),
      ],
    );
  }

  Widget _actionBar({
    required Visit visit,
    required bool isEntryScan,
  }) {
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
      child: isProcessing
          ? const Center(
        child: Padding(
          padding: EdgeInsets.all(10),
          child: CircularProgressIndicator(
            color: AppColors.ratpGreen,
          ),
        ),
      )
          : Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                _handleYes(
                  visit,
                  isEntryScan,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 54),
              ),
              icon: Icon(
                isEntryScan
                    ? Icons.login_rounded
                    : Icons.logout_rounded,
              ),
              label: Text(
                isEntryScan ? 'Admit' : 'Check Out',
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _handleNo,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 54),
              ),
              icon: const Icon(
                Icons.close_rounded,
              ),
              label: const Text('No'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                _handleNotValid(visit);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 54),
              ),
              icon: const Icon(
                Icons.block_rounded,
              ),
              label: const Text('Invalid'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Verify Visitor'),
      ),
      body: FutureBuilder<_VerificationData>(
        future: dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.ratpGreen,
              ),
            );
          }

          if (snapshot.hasError) {
            return _messageState(
              icon: Icons.error_outline_rounded,
              color: AppColors.danger,
              title: 'Verification failed',
              subtitle: snapshot.error.toString(),
            );
          }

          final data = snapshot.data;
          final visit = data?.visit;
          final visitor = data?.visitor;
          final host = data?.host;

          if (visit == null) {
            return _messageState(
              icon: Icons.qr_code_2_rounded,
              color: AppColors.danger,
              title: 'Invalid QR code',
              subtitle: 'No matching visit was found for this QR code.',
            );
          }

          if (visit.status == 'invalid') {
            return _messageState(
              icon: Icons.block_rounded,
              color: AppColors.danger,
              title: 'QR flagged invalid',
              subtitle: visit.invalidReason == null ||
                  visit.invalidReason!.trim().isEmpty
                  ? 'This QR code was previously marked as invalid.'
                  : visit.invalidReason!,
              details: _visitorDetailsBlock(
                visitor,
                host,
                visit,
              ),
            );
          }

          if (data!.todaysSchedule == null) {
            return _messageState(
              icon: Icons.event_busy_rounded,
              color: AppColors.warning,
              title: 'Not scheduled for today',
              subtitle:
              'This visitor has a valid profile, but there is no scheduled visit window for today.',
              details: _visitorDetailsBlock(
                visitor,
                host,
                visit,
              ),
            );
          }

          final status = data.latestLogAction ?? 'check_in';

          if (status == 'completed') {
            return _messageState(
              icon: Icons.verified_rounded,
              color: AppColors.ratpGreen,
              title: 'Visit already completed',
              subtitle:
              'This visitor has already checked in and checked out today.',
              details: _visitorDetailsBlock(
                visitor,
                host,
                visit,
              ),
            );
          }

          final isEntryScan = status == 'check_in';
          final schedule = data.todaysSchedule!;

          return _verificationContent(
            isEntryScan: isEntryScan,
            visit: visit,
            visitor: visitor,
            host: host,
            schedule: schedule,
          );
        },
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppIconBadge(
          icon: icon,
          size: 42,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}