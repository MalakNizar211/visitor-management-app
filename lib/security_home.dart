import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_theme.dart';
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
  int _selectedIndex = 0;

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

  String _displayValue(dynamic value) {
    final text = value?.toString().trim();

    if (text == null || text.isEmpty) {
      return '-';
    }

    return text;
  }

  void _showVisitDetails(
      BuildContext context,
      Map<String, dynamic> visit,
      ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      builder: (_) {
        return DraggableScrollableSheet(
          initialChildSize: 0.62,
          minChildSize: 0.35,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(
                20,
                12,
                20,
                28,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 18),
                      decoration: BoxDecoration(
                        color: AppColors.line,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: AppGradients.header,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Colors.white.withOpacity(.18),
                          child: Text(
                            initialsFromName(
                              _displayValue(visit['full_name']),
                            ),
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
                                _displayValue(visit['full_name']),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -.3,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Currently inside the building',
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
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(.16),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withOpacity(.2),
                            ),
                          ),
                          child: const Text(
                            'Inside',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  const _DetailsSectionTitle(
                    icon: Icons.person_outline_rounded,
                    text: 'Visitor information',
                  ),
                  _detailRow(
                    'National ID',
                    visit['national_id'],
                  ),
                  _detailRow(
                    'Phone',
                    visit['phone'],
                  ),
                  const SizedBox(height: 18),
                  const _DetailsSectionTitle(
                    icon: Icons.business_center_outlined,
                    text: 'Visit information',
                  ),
                  _detailRow(
                    'Visiting',
                    visit['host_name'],
                  ),
                  _detailRow(
                    'Purpose',
                    visit['purpose'],
                  ),
                  if (visit['last_check_in'] != null)
                    _detailRow(
                      'Checked in at',
                      visit['last_check_in'],
                    ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Close details'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _detailRow(String label, dynamic value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 13,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.line,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              _displayValue(value),
              style: const TextStyle(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _visitorCard(Map<String, dynamic> visit) {
    final visitorName = _displayValue(visit['full_name']);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.line,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.035),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          _showVisitDetails(context, visit);
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: AppColors.softGreen,
                child: Text(
                  initialsFromName(visitorName),
                  style: const TextStyle(
                    color: AppColors.ratpGreenDark,
                    fontWeight: FontWeight.w900,
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
                        color: AppColors.ink,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -.1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(
                          Icons.meeting_room_outlined,
                          size: 16,
                          color: AppColors.ratpGreenDark,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            'Visiting ${_displayValue(visit['host_name'])}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (visit['last_check_in'] != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.login_rounded,
                            size: 16,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              'Checked in: ${visit['last_check_in']}',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: const [
        SizedBox(height: 70),
        Center(
          child: AppIconBadge(
            icon: Icons.sensor_occupied_outlined,
            size: 70,
          ),
        ),
        SizedBox(height: 18),
        Center(
          child: Text(
            'No one is currently in the building.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        SizedBox(height: 7),
        Center(
          child: Text(
            'Scanned visitors will appear here after check-in.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _errorState(Object error) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 70),
        const Center(
          child: AppIconBadge(
            icon: Icons.error_outline_rounded,
            color: AppColors.danger,
            size: 70,
          ),
        ),
        const SizedBox(height: 18),
        const Center(
          child: Text(
            'Something went wrong',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 7),
        Center(
          child: Text(
            error.toString(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _visitorsList(List<Map<String, dynamic>> visits) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: visits.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: PageHeader(
              title: 'Currently In Building',
              subtitle:
              '${visits.length} visitor${visits.length == 1 ? '' : 's'} checked in and being monitored by security.',
              icon: Icons.security_rounded,
            ),
          );
        }

        return _visitorCard(visits[index - 1]);
      },
    );
  }

  Widget _securityHomeBody() {
    return Stack(
      children: [
        BluetoothScannerReceiver(
          onScan: _handleBluetoothScan,
        ),
        RefreshIndicator(
          color: AppColors.ratpGreen,
          onRefresh: () async {
            _refresh();
          },
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: visitsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.ratpGreen,
                  ),
                );
              }

              if (snapshot.hasError) {
                return _errorState(snapshot.error!);
              }

              final visits = snapshot.data ?? [];

              if (visits.isEmpty) {
                return _emptyState();
              }

              return _visitorsList(visits);
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isHomeTab = _selectedIndex == 0;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: isHomeTab
          ? AppBar(
        title: const Text('Security Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: _logout,
          ),
        ],
      )
          : null,
      body: isHomeTab ? _securityHomeBody() : const VisitRecordsPage(),
      floatingActionButton: isHomeTab
          ? FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const QrScannerPage(),
            ),
          );

          _refresh();
        },
        icon: const Icon(Icons.qr_code_scanner_rounded),
        label: const Text('Scan QR'),
      )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });

          if (index == 0) {
            _refresh();
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history_rounded),
            label: 'History',
          ),
        ],
      ),
    );
  }
}

class _DetailsSectionTitle extends StatelessWidget {
  final IconData icon;
  final String text;

  const _DetailsSectionTitle({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          AppIconBadge(
            icon: icon,
            size: 34,
          ),
          const SizedBox(width: 10),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}