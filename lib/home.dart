import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/visit_service.dart';
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