import 'package:flutter/material.dart';
import 'models/visit_model.dart';
import 'services/visit_service.dart';

class VerificationPage extends StatefulWidget {
  final String scannedId;

  const VerificationPage({super.key, required this.scannedId});

  @override
  State<VerificationPage> createState() => _VerificationPageState();
}

class _VerificationPageState extends State<VerificationPage> {
  final VisitService visitService = VisitService();
  late Future<Visit?> visitFuture;
  bool isProcessing = false;

  @override
  void initState() {
    super.initState();
    visitFuture = visitService.getVisitById(widget.scannedId);
  }

  Future<void> _handleYes(Visit visit) async {
    setState(() => isProcessing = true);

    Visit? result;
    if (visit.status == 'pending') {
      result = await visitService.checkIn(visit.id!);
    } else if (visit.status == 'checked_in') {
      result = await visitService.checkOut(visit.id!);
    }

    if (!mounted) return;
    setState(() => isProcessing = false);

    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Action failed - this QR may have already been used.')),
      );
      return;
    }

    final message = visit.status == 'pending' ? 'Visitor admitted' : 'Visitor checked out';
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.lightBlue,
        title: const Text('Verify Visitor'),
      ),
      body: FutureBuilder<Visit?>(
        future: visitFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final visit = snapshot.data;

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

          if (visit.status == 'checked_out' || visit.status == 'invalid') {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.block, color: Colors.red[700], size: 64),
                    const SizedBox(height: 16),
                    Text(
                      visit.status == 'invalid'
                          ? 'This QR was flagged invalid.\n${visit.invalidReason ?? ''}'
                          : 'This visitor has already checked out.\nThis QR is no longer valid.',
                      style: const TextStyle(fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          final isEntryScan = visit.status == 'pending';

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
                Text(
                  visit.visitorName,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text('National ID: ${visit.nationalId}', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                Text('Phone: ${visit.phone}', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                Text('Visiting: ${visit.hostName}', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                Text('Purpose: ${visit.purpose}', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                Text('Scheduled time: ${visit.visitTime}', style: const TextStyle(fontSize: 16)),
                const Spacer(),
                if (isProcessing)
                  const Center(child: CircularProgressIndicator())
                else
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _handleYes(visit),
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