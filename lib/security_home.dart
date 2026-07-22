import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'services/visit_service.dart';
import 'loginpage.dart';
import 'qr_scanner_page.dart';
import 'visit_records_page.dart';
import 'verification_page.dart';
import 'widgets/bluetooth_scanner_receiver.dart';

class SecurityHome extends StatefulWidget {
  const SecurityHome({super.key});

  @override
  State<SecurityHome> createState() => _SecurityHomeState();
}

class _SecurityHomeState extends State<SecurityHome> {
  final VisitService visitService = VisitService();

  late Future<List<Map<String, dynamic>>> visitsFuture;

  bool _processingBluetoothScan = false;

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
      MaterialPageRoute(
        builder: (_) => const LoginPage(),
      ),
    );
  }

  Future<void> _handleBluetoothScan(String scannedId) async {
    if (_processingBluetoothScan) return;

    _processingBluetoothScan = true;

    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VerificationPage(
            scannedId: scannedId,
          ),
        ),
      );

      _refresh();
    } finally {
      _processingBluetoothScan = false;
    }
  }

  void _showVisitDetails(
      BuildContext context,
      Map<String, dynamic> visit,
      ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                visit['full_name'] ?? 'Unknown',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 16),

              Text(
                'National ID: ${visit['national_id'] ?? '-'}',
              ),

              const SizedBox(height: 8),

              Text(
                'Phone: ${visit['phone'] ?? '-'}',
              ),

              const SizedBox(height: 8),

              Text(
                'Visiting: ${visit['host_name'] ?? '-'}',
              ),

              const SizedBox(height: 8),

              Text(
                'Purpose: ${visit['purpose'] ?? '-'}',
              ),

              if (visit['last_check_in'] != null) ...[
                const SizedBox(height: 8),

                Text(
                  'Checked in at: ${visit['last_check_in']}',
                ),
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
        title: const Text(
          'Currently In Building',
        ),
        actions: [
          IconButton(
            tooltip: 'Visit Records',
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const VisitRecordsPage(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),

      body: Stack(
        children: [
          BluetoothScannerReceiver(
            onScan: _handleBluetoothScan,
          ),

          RefreshIndicator(
            onRefresh: () async {
              _refresh();
            },
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: visitsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                    ),
                  );
                }

                final visits = snapshot.data ?? [];

                if (visits.isEmpty) {
                  return const Center(
                    child: Text(
                      'No one is currently in the building.',
                      style: TextStyle(
                        fontSize: 18,
                      ),
                    ),
                  );
                }

                return Stack(
                  children: [
                    // SizedBox(
                    //   width: 0,
                    //   height: 0,
                    //   child: TextField(
                    //     controller: _controller,
                    //     // focusNode: _focusNode,
                    //     autofocus: true,
                    //     // showCursor: false,
                    //     // enableInteractiveSelection: false,
                    //     // enableSuggestions: false,
                    //     // autocorrect: false,
                    //     keyboardType: TextInputType.none,
                    //     // textInputAction: TextInputAction.done,
                    //     decoration: const InputDecoration(
                    //       isCollapsed: true,
                    //       border: InputBorder.none,
                    //     ),
                    //     // onTap: _requestFocus,
                    //     // onSubmitted: _handleScan,
                    //   ),
                    // ),
                    ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: visits.length,
                      itemBuilder: (context, index) {
                        final visit = visits[index];

                        return Card(
                          margin: const EdgeInsets.only(
                            bottom: 12,
                          ),
                          child: InkWell(
                            onTap: () => _showVisitDetails(
                              context,
                              visit,
                            ),
                            child: Padding(
                              padding:
                              const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    visit['full_name'] ??
                                        'Unknown',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight:
                                      FontWeight.bold,
                                    ),
                                  ),

                                  const SizedBox(height: 6),

                                  Text(
                                    'National ID: ${visit['national_id'] ?? '-'}',
                                  ),

                                  Text(
                                    'Visiting: ${visit['host_name'] ?? '-'}',
                                  ),

                                  if (visit[
                                  'last_check_in'] !=
                                      null)
                                    Text(
                                      'Checked in: ${visit['last_check_in']}',
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),

      floatingActionButton:
      FloatingActionButton.extended(
        backgroundColor: Colors.lightBlue,
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
              const QrScannerPage(),
            ),
          );

          _refresh();
        },
        icon: const Icon(
          Icons.qr_code_scanner,
          color: Colors.white,
        ),
        label: const Text(
          'Scan QR',
          style: TextStyle(
            color: Colors.white,
          ),
        ),
      ),
    );

  }
  final _controller = TextEditingController();
}