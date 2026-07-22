import 'package:flutter/material.dart';
import 'models/visit_model.dart';
import 'models/visitor_model.dart';
import 'models/employee_model.dart';
import 'models/visit_schedule_model.dart';
import 'services/visit_service.dart';
import 'services/visitor_service.dart';
import 'services/employee_service.dart';

class VerificationPage extends StatefulWidget {
  final String scannedId;

  const VerificationPage({super.key, required this.scannedId});

  @override
  State<VerificationPage> createState() => _VerificationPageState();
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

  Future<void> _handleYes(Visit visit, bool isEntryScan) async {
    setState(() => isProcessing = true);

    try {
      if (isEntryScan) {
        await visitService.checkIn(visit.id!);
      } else {
        await visitService.checkOut(visit.id!);
      }

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEntryScan ? 'Visitor admitted' : 'Visitor checked out')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => isProcessing = false);
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
          title: const Text('Reason for rejection'),
          content: TextField(
            controller: reasonController,
            decoration: const InputDecoration(
              hintText: 'e.g. National ID does not match',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (reasonController.text.trim().isEmpty) return;
                Navigator.pop(context, reasonController.text.trim());
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );

    if (reason == null || reason.isEmpty) return;

    setState(() => isProcessing = true);
    final result = await visitService.markInvalid(visit.id!, reason);
    if (!mounted) return;
    setState(() => isProcessing = false);

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update - please try again.')),
      );
      return;
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('QR marked as invalid')),
    );
  }

  String _formatTime(DateTime d) {
    final hour24 = d.hour;
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final minute = d.minute.toString().padLeft(2, '0');
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

  // Shared visitor/host/visit details block, reused across the entry/exit
  // screen, the "not scheduled today" screen, and the "completed" screen.
  Widget _visitorDetailsBlock(Visitor? visitor, Employee? host, Visit visit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          visitor?.fullName ?? 'Unknown',
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Text('National ID: ${visitor?.nationalId ?? '-'}', style: const TextStyle(fontSize: 15)),
        const SizedBox(height: 6),
        Text('Phone: ${visitor?.phone ?? '-'}', style: const TextStyle(fontSize: 15)),
        const SizedBox(height: 6),
        Text(
          'Visiting: ${host?.fullName ?? '-'}${host?.department != null ? ' (${host?.department})' : ''}',
          style: const TextStyle(fontSize: 15),
        ),
        const SizedBox(height: 6),
        Text('Purpose: ${visit.purpose}', style: const TextStyle(fontSize: 15)),
        const SizedBox(height: 6),
        Text('Location: Floor ${visit.floor ?? '-'}, Room ${visit.room ?? '-'}',
            style: const TextStyle(fontSize: 15)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.lightBlue,
        title: const Text('Verify Visitor'),
      ),
      body: FutureBuilder<_VerificationData>(
        future: dataFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data;
          final visit = data?.visit;
          final visitor = data?.visitor;
          final host = data?.host;

          if (visit == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Invalid QR code - no matching visit found.',
                  style: TextStyle(fontSize: 18, color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          if (visit.status == 'invalid') {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.block, color: Colors.red[700], size: 64),
                    const SizedBox(height: 16),
                    Text(
                      'This QR was flagged invalid.\n${visit.invalidReason ?? ''}',
                      style: const TextStyle(fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          if (data!.todaysSchedule == null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.event_busy, color: Colors.orange[800], size: 64),
                    const SizedBox(height: 16),
                    const Text(
                      'Not scheduled for today.',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    _visitorDetailsBlock(visitor, host, visit),
                  ],
                ),
              ),
            );
          }

          final status = data.latestLogAction ?? 'check_in';

          if (status == 'completed') {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_circle_outline, color: Colors.blueGrey[700], size: 64),
                    const SizedBox(height: 16),
                    const Text(
                      'Already checked in and out today.',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    _visitorDetailsBlock(visitor, host, visit),
                  ],
                ),
              ),
            );
          }

          final isEntryScan = status == 'check_in';
          final schedule = data.todaysSchedule!;

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEntryScan ? 'ENTRY REQUEST' : 'EXIT REQUEST',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isEntryScan ? Colors.green[800] : Colors.orange[800],
                  ),
                ),
                const SizedBox(height: 16),
                _visitorDetailsBlock(visitor, host, visit),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _scheduleStatusMessage(schedule),
                    style: TextStyle(color: Colors.blue[900], fontWeight: FontWeight.w600),
                  ),
                ),
                const Spacer(),
                if (isProcessing)
                  const Center(child: CircularProgressIndicator())
                else
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _handleYes(visit, isEntryScan),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Yes'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _handleNo,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.grey,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('No'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _handleNotValid(visit),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Not Valid'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}