import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'services/visit_service.dart';

enum _DateFilter {
  today,
  yesterday,
  custom,
}

class VisitRecordsPage extends StatefulWidget {
  const VisitRecordsPage({super.key});

  @override
  State<VisitRecordsPage> createState() {
    return _VisitRecordsPageState();
  }
}

class _VisitRecordsPageState extends State<VisitRecordsPage> {
  final VisitService visitService = VisitService();

  _DateFilter selectedFilter = _DateFilter.today;

  DateTime selectedDate = DateTime.now();

  String searchQuery = '';

  late Future<List<Map<String, dynamic>>> recordsFuture;

  @override
  void initState() {
    super.initState();

    recordsFuture = visitService.getVisitRecordsForDate(selectedDate);
  }

  void _refresh() {
    setState(() {
      recordsFuture = visitService.getVisitRecordsForDate(selectedDate);
    });
  }

  void _selectToday() {
    setState(() {
      selectedFilter = _DateFilter.today;
      selectedDate = DateTime.now();
    });

    _refresh();
  }

  void _selectYesterday() {
    setState(() {
      selectedFilter = _DateFilter.yesterday;
      selectedDate = DateTime.now().subtract(
        const Duration(days: 1),
      );
    });

    _refresh();
  }

  Future<void> _pickCustomDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: AppColors.ratpGreen,
              secondary: AppColors.ratpGreenDark,
              surface: AppColors.surface,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) {
      return;
    }

    setState(() {
      selectedFilter = _DateFilter.custom;
      selectedDate = picked;
    });

    _refresh();
  }

  String _dateLabel() {
    switch (selectedFilter) {
      case _DateFilter.today:
        return 'Today';
      case _DateFilter.yesterday:
        return 'Yesterday';
      case _DateFilter.custom:
        return '${selectedDate.year}-'
            '${selectedDate.month.toString().padLeft(2, '0')}-'
            '${selectedDate.day.toString().padLeft(2, '0')}';
    }
  }

  String _formatTime(String? isoString) {
    if (isoString == null) {
      return '—';
    }

    final dt = DateTime.parse(isoString).toLocal();

    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');

    return '$hour:$minute';
  }

  String _displayValue(dynamic value) {
    final text = value?.toString().trim();

    if (text == null || text.isEmpty) {
      return '-';
    }

    return text;
  }

  bool _isInvalidRecord(Map<String, dynamic> record) {
    return record['invalid_time'] != null || record['status'] == 'invalid';
  }

  List<Map<String, dynamic>> _applySearch(
      List<Map<String, dynamic>> records,
      ) {
    if (searchQuery.trim().isEmpty) {
      return records;
    }

    final query = searchQuery.trim().toLowerCase();

    return records.where(
          (record) {
        final name = (record['full_name'] ?? '').toString().toLowerCase();
        final nationalId =
        (record['national_id'] ?? '').toString().toLowerCase();
        final reason =
        (record['invalid_reason'] ?? '').toString().toLowerCase();

        return name.contains(query) ||
            nationalId.contains(query) ||
            reason.contains(query);
      },
    ).toList();
  }

  void _showRecordDetails(Map<String, dynamic> record) {
    final isInvalid = _isInvalidRecord(record);

    showModalBottomSheet(
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
          initialChildSize: 0.66,
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
                              _displayValue(record['full_name']),
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
                                _displayValue(record['full_name']),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -.3,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                isInvalid
                                    ? 'Invalid visit record · ${_dateLabel()}'
                                    : 'Visit record · ${_dateLabel()}',
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
                            color: isInvalid
                                ? AppColors.danger.withOpacity(.26)
                                : Colors.white.withOpacity(.16),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: Colors.white.withOpacity(.2),
                            ),
                          ),
                          child: Text(
                            isInvalid ? 'Invalid' : 'Record',
                            style: const TextStyle(
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
                    record['national_id'],
                  ),
                  _detailRow(
                    'Phone',
                    record['phone'],
                  ),
                  const SizedBox(height: 18),
                  const _DetailsSectionTitle(
                    icon: Icons.business_center_outlined,
                    text: 'Visit information',
                  ),
                  _detailRow(
                    'Visiting',
                    record['host_name'],
                  ),
                  _detailRow(
                    'Purpose',
                    record['purpose'],
                  ),
                  const SizedBox(height: 18),
                  _DetailsSectionTitle(
                    icon: isInvalid
                        ? Icons.block_rounded
                        : Icons.schedule_rounded,
                    text: isInvalid ? 'Invalid record' : 'Check-in / Check-out',
                  ),
                  if (isInvalid) ...[
                    _timeRow(
                      icon: Icons.block_rounded,
                      label: 'Marked invalid',
                      value: _formatTime(record['invalid_time']),
                      color: AppColors.danger,
                    ),
                    _detailRow(
                      'Reason',
                      record['invalid_reason'],
                    ),
                  ] else ...[
                    _timeRow(
                      icon: Icons.login_rounded,
                      label: 'Checked in',
                      value: _formatTime(record['check_in_time']),
                      color: AppColors.success,
                    ),
                    _timeRow(
                      icon: Icons.logout_rounded,
                      label: 'Checked out',
                      value: _formatTime(record['check_out_time']),
                      color: AppColors.warning,
                    ),
                  ],
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

  Widget _timeRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.line,
        ),
      ),
      child: Row(
        children: [
          AppIconBadge(
            icon: icon,
            color: color,
            size: 42,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(
      String label,
      bool selected,
      VoidCallback onTap,
      IconData icon,
      ) {
    return ChoiceChip(
      avatar: Icon(
        icon,
        color: selected ? Colors.white : AppColors.ratpGreenDark,
        size: 18,
      ),
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        onTap();
      },
    );
  }

  Widget _recordCard(Map<String, dynamic> record) {
    final visitorName = _displayValue(record['full_name']);
    final isInvalid = _isInvalidRecord(record);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isInvalid ? AppColors.danger.withOpacity(.35) : AppColors.line,
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
          _showRecordDetails(record);
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor:
                isInvalid ? AppColors.danger.withOpacity(.12) : AppColors.softGreen,
                child: Text(
                  initialsFromName(visitorName),
                  style: TextStyle(
                    color: isInvalid
                        ? AppColors.danger
                        : AppColors.ratpGreenDark,
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
                          Icons.credit_card_rounded,
                          size: 16,
                          color: AppColors.ratpGreenDark,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            'National ID: ${_displayValue(record['national_id'])}',
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
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.business_center_outlined,
                          size: 16,
                          color: AppColors.ratpGreenDark,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            'Visiting ${_displayValue(record['host_name'])}',
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
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        if (isInvalid) ...[
                          _timePill(
                            icon: Icons.block_rounded,
                            label: 'Invalid ${_formatTime(record['invalid_time'])}',
                            color: AppColors.danger,
                          ),
                        ] else ...[
                          _timePill(
                            icon: Icons.login_rounded,
                            label: _formatTime(record['check_in_time']),
                            color: AppColors.success,
                          ),
                          _timePill(
                            icon: Icons.logout_rounded,
                            label: _formatTime(record['check_out_time']),
                            color: AppColors.warning,
                          ),
                        ],
                      ],
                    ),
                    if (isInvalid &&
                        _displayValue(record['invalid_reason']) != '-') ...[
                      const SizedBox(height: 8),
                      Text(
                        'Reason: ${_displayValue(record['invalid_reason'])}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          height: 1.3,
                        ),
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

  Widget _timePill({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(.11),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: color.withOpacity(.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 70),
        const Center(
          child: AppIconBadge(
            icon: Icons.history_toggle_off_rounded,
            size: 70,
          ),
        ),
        const SizedBox(height: 18),
        Center(
          child: Text(
            'No records for ${_dateLabel()}.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(height: 7),
        const Center(
          child: Text(
            'Try another date or search with a different visitor name.',
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

  Widget _filtersHeader() {
    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          PageHeader(
            title: 'Visit Records',
            subtitle:
            'Review check-in, check-out, and invalid visitor records for ${_dateLabel().toLowerCase()}.',
            icon: Icons.manage_history_rounded,
          ),
          const SizedBox(height: 16),
          SectionCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    AppIconBadge(
                      icon: Icons.filter_alt_outlined,
                      size: 38,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Filter records',
                      style: TextStyle(
                        color: AppColors.navy,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _filterChip(
                      'Today',
                      selectedFilter == _DateFilter.today,
                      _selectToday,
                      Icons.today_rounded,
                    ),
                    _filterChip(
                      'Yesterday',
                      selectedFilter == _DateFilter.yesterday,
                      _selectYesterday,
                      Icons.history_rounded,
                    ),
                    _filterChip(
                      selectedFilter == _DateFilter.custom
                          ? _dateLabel()
                          : 'Pick date',
                      selectedFilter == _DateFilter.custom,
                      _pickCustomDate,
                      Icons.calendar_month_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search by name, national ID, or invalid reason',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value;
                    });
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _recordsBody() {
    return RefreshIndicator(
        color: AppColors.ratpGreen,
        onRefresh: () async {
          _refresh();
        },
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: recordsFuture,
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

            final records = _applySearch(snapshot.data ?? []);

            if (records.isEmpty) {
              return _emptyState();
            }

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: records.length,
              itemBuilder: (context, index) {
                return _recordCard(records[index]);
              },
            );
          },
        ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Visit Records'),
      ),
      body: RefreshIndicator(
        color: AppColors.ratpGreen,
        onRefresh: () async {
          _refresh();
        },
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: recordsFuture,
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

            final records = _applySearch(snapshot.data ?? []);

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _filtersHeader(),
                const SizedBox(height: 8),

                if (records.isEmpty)
                  ...[
                    const SizedBox(height: 40),
                    _emptyState(),
                  ]
                else
                  ...records.map((record) => _recordCard(record)),
              ],
            );
          },
        ),
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