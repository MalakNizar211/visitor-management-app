import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/visit_service.dart';
import 'services/visitor_service.dart';
import 'new_visitor_page.dart';
import 'qr_result_page.dart';
import 'loginpage.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> {
  final VisitService visitService = VisitService();
  final VisitorService visitorService = VisitorService();
  late Future<List<Map<String, dynamic>>> visitsFuture;

  @override
  void initState() {
    super.initState();
    visitsFuture = visitService.getMyVisitsWithVisitors();
  }

  void _refreshVisits() {
    setState(() {
      visitsFuture = visitService.getMyVisitsWithVisitors();
    });
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
  }

  // Shows all visit details in a bottom sheet when a card is tapped
  void _showVisitDetails(Map<String, dynamic> visit) {
    final visitorInfo = visit['visitors'] as Map<String, dynamic>?;
    final employeeInfo = visit['employees'] as Map<String, dynamic>?;
    final schedules = (visit['visit_schedules'] as List?) ?? [];
    final isInvalid = visit['status'] == 'invalid';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Text(
                    visitorInfo?['full_name'] ?? 'Unknown',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isInvalid ? Colors.red[100] : Colors.green[100],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isInvalid ? 'Invalid' : 'Active',
                      style: TextStyle(
                        color: isInvalid ? Colors.red[800] : Colors.green[800],
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _detailRow('National ID', visitorInfo?['national_id']),
                  _detailRow('Phone', visitorInfo?['phone']),
                  _detailRow('Host', employeeInfo?['full_name']),
                  _detailRow('Department', employeeInfo?['department']),
                  _detailRow('Purpose', visit['purpose']),
                  _detailRow('Floor', visit['floor']),
                  _detailRow('Room', visit['room']),
                  if (isInvalid) _detailRow('Invalid Reason', visit['invalid_reason']),
                  const SizedBox(height: 16),
                  const Text(
                    'Scheduled Dates',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  if (schedules.isEmpty)
                    const Text('No schedules found.')
                  else
                    ...schedules.map((s) {
                      final map = s as Map<String, dynamic>;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '${map['scheduled_date']}  •  ${map['start_time']} - ${map['end_time']}',
                        ),
                      );
                    }),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _detailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: Colors.black54)),
          ),
          Expanded(child: Text(value?.toString() ?? '-')),
        ],
      ),
    );
  }

  // Opens an edit form for the visit + visitor fields, saves on submit
  void _showEditDialog(Map<String, dynamic> visit) {
    final visitorInfo = visit['visitors'] as Map<String, dynamic>?;

    final nameController = TextEditingController(text: visitorInfo?['full_name'] ?? '');
    final nationalIdController = TextEditingController(text: visitorInfo?['national_id'] ?? '');
    final phoneController = TextEditingController(text: visitorInfo?['phone'] ?? '');
    final purposeController = TextEditingController(text: visit['purpose'] ?? '');
    final floorController = TextEditingController(text: visit['floor'] ?? '');
    final roomController = TextEditingController(text: visit['room'] ?? '');

    showDialog(
      context: context,
      builder: (context) {
        bool isSaving = false;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Visit'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: 'Full Name'),
                    ),
                    TextField(
                      controller: nationalIdController,
                      decoration: const InputDecoration(labelText: 'National ID'),
                    ),
                    TextField(
                      controller: phoneController,
                      decoration: const InputDecoration(labelText: 'Phone'),
                    ),
                    const Divider(height: 24),
                    TextField(
                      controller: purposeController,
                      decoration: const InputDecoration(labelText: 'Purpose'),
                    ),
                    TextField(
                      controller: floorController,
                      decoration: const InputDecoration(labelText: 'Floor'),
                    ),
                    TextField(
                      controller: roomController,
                      decoration: const InputDecoration(labelText: 'Room'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                    setDialogState(() => isSaving = true);
                    try {
                      if (visitorInfo?['id'] != null) {
                        await visitorService.updateVisitor(
                          visitorInfo!['id'],
                          {
                            'full_name': nameController.text.trim(),
                            'national_id': nationalIdController.text.trim(),
                            'phone': phoneController.text.trim(),
                          },
                        );
                      }

                      await visitService.updateVisit(
                        visit['id'],
                        {
                          'purpose': purposeController.text.trim(),
                          'floor': floorController.text.trim(),
                          'room': roomController.text.trim(),
                        },
                      );

                      if (!mounted) return;
                      Navigator.pop(context);
                      _refreshVisits();
                    } catch (e) {
                      setDialogState(() => isSaving = false);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to save: $e')),
                      );
                    }
                  },
                  child: isSaving
                      ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                      : const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.lightBlue,
        title: const Text("HR Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _refreshVisits();
        },
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: visitsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }

            final visits = snapshot.data ?? [];

            if (visits.isEmpty) {
              return const Center(
                child: Text(
                  'No visitors registered yet.',
                  style: TextStyle(fontSize: 18),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: visits.length,
              itemBuilder: (context, index) {
                final visit = visits[index];
                final visitorInfo = visit['visitors'] as Map<String, dynamic>?;
                final employeeInfo = visit['employees'] as Map<String, dynamic>?;
                final isInvalid = visit['status'] == 'invalid';

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _showVisitDetails(visit),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  visitorInfo?['full_name'] ?? 'Unknown',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text('National ID: ${visitorInfo?['national_id'] ?? '-'}'),
                                Text('Phone: ${visitorInfo?['phone'] ?? '-'}'),
                                Text('Visiting: ${employeeInfo?['full_name'] ?? '-'}${employeeInfo?['department'] != null ? ' (${employeeInfo?['department']})' : ''}'),
                                Text('Purpose: ${visit['purpose']}'),
                                Text('Location: Floor ${visit['floor'] ?? '-'}, Room ${visit['room'] ?? '-'}'),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isInvalid ? Colors.red[100] : Colors.green[100],
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    isInvalid ? 'Invalid' : 'Active',
                                    style: TextStyle(
                                      color: isInvalid ? Colors.red[800] : Colors.green[800],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                if (isInvalid && visit['invalid_reason'] != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Reason: ${visit['invalid_reason']}',
                                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit, color: Colors.orange, size: 28),
                                tooltip: 'Edit Visit',
                                onPressed: () => _showEditDialog(visit),
                              ),
                              IconButton(
                                icon: const Icon(Icons.qr_code, color: Colors.lightBlue, size: 32),
                                tooltip: 'View QR Code',
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => QrResultPage(
                                        visitId: visit['id'],
                                        visitorName: visitorInfo?['full_name'] ?? 'Visitor',
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.lightBlue,
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NewVisitorPage()),
          );
          _refreshVisits();
        },
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('New Visitor', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}