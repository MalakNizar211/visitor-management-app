import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/visit_model.dart';
import 'services/visit_service.dart';
import 'loginpage.dart';
import 'qr_scanner_page.dart';

class SecurityHome extends StatefulWidget {
  const SecurityHome({super.key});

  @override
  State<SecurityHome> createState() => _SecurityHomeState();
}

class _SecurityHomeState extends State<SecurityHome> {
  final VisitService visitService = VisitService();
  late Future<List<Visit>> visitsFuture;

  @override
  void initState() {
    super.initState();
    visitsFuture = visitService.getCurrentlyInBuilding();
  }

  void _refresh() {
    setState(() {
      visitsFuture = visitService.getCurrentlyInBuilding();
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
  void _showVisitDetails(BuildContext context, Visit visit) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                visit.visitorName,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text('National ID: ${visit.nationalId}'),
              const SizedBox(height: 8),
              Text('Phone: ${visit.phone}'),
              const SizedBox(height: 8),
              Text('Visiting: ${visit.hostName}'),
              const SizedBox(height: 8),
              Text('Purpose: ${visit.purpose}'),
              const SizedBox(height: 8),
              Text('Scheduled visit time: ${visit.visitTime}'),
              if (visit.checkedInAt != null) ...[
                const SizedBox(height: 8),
                Text('Checked in at: ${visit.checkedInAt}'),
              ],
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.lightBlue,
        title: const Text('Currently In Building'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _refresh();
        },
        child: FutureBuilder<List<Visit>>(
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
                  'No one is currently in the building.',
                  style: TextStyle(fontSize: 18),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: visits.length,
              itemBuilder: (context, index) {
                final visit = visits[index];

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () => _showVisitDetails(context, visit),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            visit.visitorName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text('National ID: ${visit.nationalId}'),
                          Text('Visiting: ${visit.hostName}'),
                          if (visit.checkedInAt != null)
                            Text('Checked in: ${visit.checkedInAt}'),
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
            MaterialPageRoute(builder: (context) => const QrScannerPage()),
          );
          _refresh();
        },
        icon: const Icon(Icons.qr_code_scanner, color: Colors.white),
        label: const Text('Scan QR', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}