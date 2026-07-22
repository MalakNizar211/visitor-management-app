import 'package:flutter/material.dart';
import 'services/visit_service.dart';

enum _DateFilter { today, yesterday, custom }

class VisitRecordsPage extends StatefulWidget {
  const VisitRecordsPage({super.key});

  @override
  State<VisitRecordsPage> createState() => _VisitRecordsPageState();
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
      selectedDate = DateTime.now().subtract(const Duration(days: 1));
    });
    _refresh();
  }

  Future<void> _pickCustomDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked == null) return;

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
        return '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';
    }
  }

  String _formatTime(String? isoString) {
    if (isoString == null) return '—';
    final dt = DateTime.parse(isoString).toLocal();
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  List<Map<String, dynamic>> _applySearch(List<Map<String, dynamic>> records) {
    if (searchQuery.trim().isEmpty) return records;

    final query = searchQuery.trim().toLowerCase();
    return records.where((r) {
      final name = (r['full_name'] ?? '').toString().toLowerCase();
      final nationalId = (r['national_id'] ?? '').toString().toLowerCase();
      return name.contains(query) || nationalId.contains(query);
    }).toList();
  }

  void _showRecordDetails(Map<String, dynamic> record) {
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
                record['full_name'] ?? 'Unknown',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text('National ID: ${record['national_id'] ?? '-'}'),
              const SizedBox(height: 8),
              Text('Phone: ${record['phone'] ?? '-'}'),
              const SizedBox(height: 8),
              Text('Visiting: ${record['host_name'] ?? '-'}'),
              const SizedBox(height: 8),
              Text('Purpose: ${record['purpose'] ?? '-'}'),
              const SizedBox(height: 8),
              Text('Checked in: ${_formatTime(record['check_in_time'])}'),
              const SizedBox(height: 8),
              Text('Checked out: ${_formatTime(record['check_out_time'])}'),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: Colors.lightBlue,
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.black87,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.lightBlue,
        title: const Text('Visit Records'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    _filterChip('Today', selectedFilter == _DateFilter.today, _selectToday),
                    const SizedBox(width: 8),
                    _filterChip('Yesterday', selectedFilter == _DateFilter.yesterday, _selectYesterday),
                    const SizedBox(width: 8),
                    _filterChip(
                      selectedFilter == _DateFilter.custom ? _dateLabel() : 'Pick date',
                      selectedFilter == _DateFilter.custom,
                      _pickCustomDate,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search by name or national ID',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                  ),
                  onChanged: (value) => setState(() => searchQuery = value),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _refresh(),
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: recordsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }

                  final records = _applySearch(snapshot.data ?? []);

                  if (records.isEmpty) {
                    return ListView(
                      children: [
                        const SizedBox(height: 80),
                        Center(
                          child: Text(
                            'No records for ${_dateLabel()}.',
                            style: const TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        ),
                      ],
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: records.length,
                    itemBuilder: (context, index) {
                      final record = records[index];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () => _showRecordDetails(record),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  record['full_name'] ?? 'Unknown',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text('National ID: ${record['national_id'] ?? '-'}'),
                                Text('Visiting: ${record['host_name'] ?? '-'}'),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Icon(Icons.login, size: 16, color: Colors.green[700]),
                                    const SizedBox(width: 4),
                                    Text(_formatTime(record['check_in_time'])),
                                    const SizedBox(width: 16),
                                    Icon(Icons.logout, size: 16, color: Colors.orange[700]),
                                    const SizedBox(width: 4),
                                    Text(_formatTime(record['check_out_time'])),
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
          ),
        ],
      ),
    );
  }
}