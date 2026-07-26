import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_theme.dart';
import 'loginpage.dart';
import 'new_visitor_page.dart';
import 'qr_result_page.dart';
import 'services/visit_service.dart';

class Home extends StatefulWidget {
  const Home({super.key});

  @override
  State<Home> createState() {
    return _HomeState();
  }
}

class _HomeState extends State<Home> {
  final VisitService visitService = VisitService();

  late Future<List<Map<String, dynamic>>> visitsFuture;
  String? _employeeName;

  @override
  void initState() {
    super.initState();

    visitsFuture = visitService.getMyVisitsWithVisitors();
    _loadEmployeeName();
  }

  void _refreshVisits() {
    setState(() {
      visitsFuture = visitService.getMyVisitsWithVisitors();
    });
  }

  // Fetches the logged-in HR user's own name from the employees table.
  // Queried directly here (not via VisitService) since it's dashboard-only
  // display data, not shared visit logic.
  Future<void> _loadEmployeeName() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;

    if (userId == null) return;

    try {
      final response = await Supabase.instance.client
          .from('employees')
          .select('full_name')
          .eq('auth_user_id', userId)
          .maybeSingle();

      if (mounted && response != null) {
        setState(() {
          _employeeName = response['full_name'] as String?;
        });
      }
    } catch (_) {
      // Silently fall back to a generic greeting if this fails.
    }
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const LoginPage(),
      ),
    );
  }

  void _showVisitDetails(Map<String, dynamic> visit) {
    final visitorInfo =
    visit['visitors'] as Map<String, dynamic>?;

    final employeeInfo =
    visit['employees'] as Map<String, dynamic>?;

    final schedules = List<Map<String, dynamic>>.from(
      (visit['visit_schedules'] as List?) ?? const [],
    )..sort(
          (a, b) => '${a['scheduled_date']} ${a['start_time']}'
          .compareTo(
        '${b['scheduled_date']} ${b['start_time']}',
      ),
    );

    final isInvalid = visit['status'] == 'invalid';

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.95,
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
                      margin: const EdgeInsets.only(
                        bottom: 18,
                      ),
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
                          radius: 27,
                          backgroundColor:
                          Colors.white.withOpacity(.18),
                          child: Text(
                            initialsFromName(
                              visitorInfo?['full_name'] ??
                                  'Unknown visitor',
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
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Text(
                                visitorInfo?['full_name'] ??
                                    'Unknown visitor',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -.3,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                employeeInfo?['full_name'] == null
                                    ? 'Visitor profile'
                                    : 'Visiting ${employeeInfo?['full_name']}',
                                style: TextStyle(
                                  color:
                                  Colors.white.withOpacity(.82),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _statusBadge(isInvalid),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  const _SectionTitle(
                    icon: Icons.person_outline_rounded,
                    text: 'Visitor information',
                  ),
                  _detailRow(
                    'National ID',
                    visitorInfo?['national_id'],
                  ),
                  _detailRow(
                    'Phone',
                    visitorInfo?['phone'],
                  ),
                  const SizedBox(height: 18),
                  const _SectionTitle(
                    icon: Icons.business_center_outlined,
                    text: 'Visit information',
                  ),
                  _detailRow(
                    'Host',
                    employeeInfo?['full_name'],
                  ),
                  _detailRow(
                    'Department',
                    employeeInfo?['department'],
                  ),
                  _detailRow(
                    'Purpose',
                    visit['purpose'],
                  ),
                  _detailRow(
                    'Floor',
                    visit['floor'],
                  ),
                  _detailRow(
                    'Room',
                    visit['room'],
                  ),
                  _detailRow(
                    'Status',
                    isInvalid ? 'Invalid' : 'Active',
                  ),
                  if (isInvalid)
                    _detailRow(
                      'Invalid reason',
                      visit['invalid_reason'],
                    ),
                  const SizedBox(height: 18),
                  const _SectionTitle(
                    icon: Icons.event_available_outlined,
                    text: 'Scheduled dates',
                  ),
                  if (schedules.isEmpty)
                    const Text(
                      'No schedules found.',
                      style: TextStyle(
                        color: AppColors.muted,
                      ),
                    )
                  else
                    ...schedules.map(
                          (schedule) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius:
                            BorderRadius.circular(18),
                            border: Border.all(
                              color: AppColors.line,
                            ),
                          ),
                          child: Row(
                            children: [
                              const AppIconBadge(
                                icon: Icons.calendar_month_rounded,
                                size: 42,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _displayDate(
                                        schedule['scheduled_date']
                                            ?.toString(),
                                      ),
                                      style: const TextStyle(
                                        color: AppColors.ink,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_displayTime(schedule['start_time']?.toString())} - '
                                          '${_displayTime(schedule['end_time']?.toString())}',
                                      style: const TextStyle(
                                        color: AppColors.muted,
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
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _statusBadge(bool isInvalid) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: isInvalid
            ? AppColors.danger.withOpacity(.12)
            : Colors.white.withOpacity(.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isInvalid
              ? AppColors.danger.withOpacity(.25)
              : Colors.white.withOpacity(.2),
        ),
      ),
      child: Text(
        isInvalid ? 'Invalid' : 'Active',
        style: TextStyle(
          color: isInvalid ? AppColors.danger : Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _detailRow(String label, dynamic value) {
    final displayValue = value?.toString().trim();

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
              displayValue == null || displayValue.isEmpty
                  ? '-'
                  : displayValue,
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

  Future<void> _openEditPage(
      Map<String, dynamic> visit,
      ) async {
    final wasUpdated = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => NewVisitorPage(
          visitToEdit: visit,
        ),
      ),
    );

    if (wasUpdated == true && mounted) {
      _refreshVisits();
    }
  }

  Widget _emptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: const [
        SizedBox(height: 80),
        AppIconBadge(
          icon: Icons.people_outline_rounded,
          size: 68,
        ),
        SizedBox(height: 18),
        Center(
          child: Text(
            'No visitors registered yet.',
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        SizedBox(height: 6),
        Center(
          child: Text(
            'Create a new visitor request to see it here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.muted,
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
        const SizedBox(height: 80),
        const AppIconBadge(
          icon: Icons.error_outline_rounded,
          color: AppColors.danger,
          size: 68,
        ),
        const SizedBox(height: 18),
        const Center(
          child: Text(
            'Something went wrong',
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            error.toString(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.muted,
            ),
          ),
        ),
      ],
    );
  }

  Widget _visitorCard(
      Map<String, dynamic> visit,
      ) {
    final visitorInfo =
    visit['visitors'] as Map<String, dynamic>?;

    final visitorName =
        visitorInfo?['full_name']?.toString() ?? 'Unknown visitor';

    final isInvalid = visit['status'] == 'invalid';

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
          _showVisitDetails(visit);
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            16,
            10,
            8,
            10,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
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
                  mainAxisSize: MainAxisSize.min,
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
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isInvalid
                                ? Icons.block_rounded
                                : Icons.verified_outlined,
                            size: 16,
                            color: isInvalid
                                ? AppColors.danger
                                : AppColors.success,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            isInvalid ? 'Invalid visit' : 'Active visit',
                            style: TextStyle(
                              color: isInvalid
                                  ? AppColors.danger
                                  : AppColors.muted,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.edit_note_rounded,
                      color: AppColors.warning,
                    ),
                    tooltip: 'Edit all details',
                    onPressed: () {
                      _openEditPage(visit);
                    },
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.qr_code_2_rounded,
                      color: AppColors.ratpGreenDark,
                    ),
                    tooltip: 'View QR code',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) {
                            return QrResultPage(
                              visitId: visit['id'],
                              visitorName: visitorName,
                            );
                          },
                        ),
                      );
                    },
                  ),
                ],
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

  Widget _visitorsList(
      List<Map<String, dynamic>> visits,
      ) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        16,
        16,
        16,
        100,
      ),
      itemCount: visits.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: PageHeader(
              title: 'Hello, ${_employeeName ?? 'there'}',
              subtitle:
              "Manage today's visits and registered visitors.",
              icon: Icons.groups_2_rounded,
            ),
          );
        }

        return _visitorCard(
          visits[index - 1],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Visitor Management'),
        actions: [
          IconButton(
            icon: const Icon(
              Icons.logout_rounded,
            ),
            tooltip: 'Log out',
            onPressed: _logout,
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.ratpGreen,
        onRefresh: () async {
          _refreshVisits();
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
              return _errorState(
                snapshot.error!,
              );
            }

            final visits = snapshot.data ?? [];

            if (visits.isEmpty) {
              return _emptyState();
            }

            return _visitorsList(visits);
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const NewVisitorPage(),
            ),
          );

          _refreshVisits();
        },
        icon: const Icon(
          Icons.person_add_alt_1_rounded,
        ),
        label: const Text(
          'New Visitor',
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SectionTitle({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: 12,
      ),
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

String _displayTime(String? rawTime) {
  final parts = (rawTime ?? '').split(':');

  if (parts.length < 2) {
    return rawTime ?? '-';
  }

  return '${parts[0]}:${parts[1]}';
}

String _displayDate(String? rawDate) {
  if (rawDate == null || rawDate.isEmpty) {
    return '-';
  }

  final date = DateTime.tryParse(rawDate);

  if (date == null) {
    return rawDate;
  }

  return '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';
}