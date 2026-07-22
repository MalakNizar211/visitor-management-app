import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'models/visitor_model.dart';
import 'models/visit_model.dart';
import 'models/visit_schedule_model.dart';
import 'models/employee_model.dart';
import 'services/visitor_service.dart';
import 'services/visit_service.dart';
import 'services/employee_service.dart';
import 'qr_result_page.dart';

// A period: a set of individually-picked calendar days, sharing one time range.
// (Also covers what used to be a "one-time" visit: just pick a single day.)
class _PeriodBlock {
  final Set<DateTime> days;
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  _PeriodBlock({
    required this.days,
    required this.startTime,
    required this.endTime,
  });
}

/// A text field that shows its matching results as a floating dropdown
/// overlay (like a browser address bar autocomplete) instead of a
/// permanently-visible list underneath. The overlay only appears while
/// the field has focus, and closes automatically on selection or when
/// focus moves away.
class _SearchDropdownField<T> extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final List<T> Function() itemsBuilder;
  final String Function(T item) itemLabelBuilder;
  final String Function(T item)? itemSubtitleBuilder;
  final ValueChanged<T> onSelected;

  const _SearchDropdownField({
    super.key,
    required this.controller,
    required this.labelText,
    required this.itemsBuilder,
    required this.itemLabelBuilder,
    this.itemSubtitleBuilder,
    required this.onSelected,
  });

  @override
  State<_SearchDropdownField<T>> createState() => _SearchDropdownFieldState<T>();
}

class _SearchDropdownFieldState<T> extends State<_SearchDropdownField<T>> {
  final _focusNode = FocusNode();
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    widget.controller.addListener(_onTextChange);
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      _showOverlay();
    } else {
      _removeOverlay();
    }
  }

  void _onTextChange() {
    _overlayEntry?.markNeedsBuild();
  }

  void _showOverlay() {
    _removeOverlay();
    _overlayEntry = _createOverlayEntry();
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  OverlayEntry _createOverlayEntry() {
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    return OverlayEntry(
      builder: (context) => Positioned(
        width: size.width,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 4),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: _buildList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildList() {
    final items = widget.itemsBuilder();
    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No matches found'),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        return InkWell(
          // canRequestFocus: false keeps the search field focused (and the
          // overlay open) long enough for the tap to register as a
          // selection, instead of the overlay closing itself first.
          canRequestFocus: false,
          onTap: () {
            widget.onSelected(item);
            _focusNode.unfocus();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.itemLabelBuilder(item),
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                if (widget.itemSubtitleBuilder != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    widget.itemSubtitleBuilder!(item),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _removeOverlay();
    _focusNode.removeListener(_onFocusChange);
    widget.controller.removeListener(_onTextChange);
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: TextField(
        controller: widget.controller,
        focusNode: _focusNode,
        decoration: InputDecoration(
          labelText: widget.labelText,
          prefixIcon: const Icon(Icons.search),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class NewVisitorPage extends StatefulWidget {
  const NewVisitorPage({super.key});

  @override
  State<NewVisitorPage> createState() => _NewVisitorPageState();
}

class _NewVisitorPageState extends State<NewVisitorPage> {
  final _formKey = GlobalKey<FormState>();

  final VisitorService visitorService = VisitorService();
  final VisitService visitService = VisitService();
  final EmployeeService employeeService = EmployeeService();

  // Visitor selection state
  List<Visitor> existingVisitors = [];
  Visitor? selectedVisitor;
  bool isRegisteringNewVisitor = false;
  final visitorSearchController = TextEditingController();
  bool isLoadingData = true;

  // Employee (host) selection state
  List<Employee> employees = [];
  Employee? selectedHost;
  String? selectedDepartmentFilter; // null = All
  final hostSearchController = TextEditingController();

  // New visitor fields (only used if selectedVisitor stays null)
  final newNameController = TextEditingController();
  final newNationalIdController = TextEditingController();
  final newPhoneController = TextEditingController();

  // Visit details
  final purposeController = TextEditingController();
  final floorController = TextEditingController();
  final roomController = TextEditingController();

  // Scheduling state
  List<_PeriodBlock> periodBlocks = [];

  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final visitors = await visitorService.getAllVisitors();
    final employeesList = await employeeService.getAllEmployees();
    setState(() {
      existingVisitors = visitors;
      employees = employeesList;
      isLoadingData = false;
    });
  }

  // --- Visitor search ---

  List<Visitor> get _filteredVisitors {
    final query = visitorSearchController.text.trim().toLowerCase();
    if (query.isEmpty) return existingVisitors;
    return existingVisitors.where((v) {
      return v.fullName.toLowerCase().contains(query) ||
          v.nationalId.toLowerCase().contains(query);
    }).toList();
  }

  // --- Host search + department filter ---

  List<String> get _departments {
    final set = employees.map((e) => e.department).toSet().toList();
    set.sort();
    return set;
  }

  List<Employee> get _filteredEmployees {
    final query = hostSearchController.text.trim().toLowerCase();
    return employees.where((e) {
      final matchesDept =
          selectedDepartmentFilter == null || e.department == selectedDepartmentFilter;
      final matchesQuery = query.isEmpty || e.fullName.toLowerCase().contains(query);
      return matchesDept && matchesQuery;
    }).toList();
  }

  // --- Period / visit-day scheduling ---

  Future<void> _addPeriod() async {
    final selectedDays = await Navigator.push<Set<DateTime>>(
      context,
      MaterialPageRoute(builder: (context) => const _PeriodCalendarPicker()),
    );
    if (selectedDays == null || selectedDays.isEmpty || !mounted) return;

    final start = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (start == null || !mounted) return;

    final end = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (end == null) return;

    setState(() {
      periodBlocks.add(_PeriodBlock(days: selectedDays, startTime: start, endTime: end));
    });
  }

  void _removePeriod(int index) {
    setState(() => periodBlocks.removeAt(index));
  }

  String _timeOfDayToDbString(TimeOfDay t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';
  }

  String _formatDateOnly(DateTime d) {
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  // --- Submit ---

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (!isRegisteringNewVisitor && selectedVisitor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an existing visitor or switch to "New visitor"')),
      );
      return;
    }

    if (isRegisteringNewVisitor &&
        (newNameController.text.trim().isEmpty ||
            newNationalIdController.text.trim().isEmpty ||
            newPhoneController.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all new visitor details')),
      );
      return;
    }

    if (selectedHost == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select who they are visiting')),
      );
      return;
    }

    if (periodBlocks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one visit date')),
      );
      return;
    }

    final List<VisitSchedule> schedules = [];

    for (final block in periodBlocks) {
      for (final day in block.days) {
        schedules.add(VisitSchedule(
          scheduledDate: day,
          startTime: _timeOfDayToDbString(block.startTime),
          endTime: _timeOfDayToDbString(block.endTime),
        ));
      }
    }

    setState(() => isSaving = true);

    try {
      Visitor visitor;
      if (!isRegisteringNewVisitor && selectedVisitor != null) {
        visitor = selectedVisitor!;
      } else {
        visitor = await visitorService.createVisitor(
          Visitor(
            fullName: newNameController.text.trim(),
            nationalId: newNationalIdController.text.trim(),
            phone: newPhoneController.text.trim(),
          ),
        );
      }

      final visit = Visit(
        visitorId: visitor.id,
        hostId: selectedHost!.id,
        purpose: purposeController.text.trim(),
        floor: floorController.text.trim(),
        room: roomController.text.trim(),
      );

      final createdVisit = await visitService.createVisitWithSchedules(visit, schedules);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => QrResultPage(
            visitId: createdVisit.id!,
            visitorName: visitor.fullName,
            hostName: selectedHost!.fullName,
            department: selectedHost!.department,
            purpose: purposeController.text.trim(),
            floor: floorController.text.trim(),
            room: roomController.text.trim(),
            // Full schedule objects, so the share message can show real
            // start-end ranges instead of just a single time per day.
            schedules: schedules,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => isSaving = false);
    }
  }

  @override
  void dispose() {
    visitorSearchController.dispose();
    hostSearchController.dispose();
    newNameController.dispose();
    newNationalIdController.dispose();
    newPhoneController.dispose();
    purposeController.dispose();
    floorController.dispose();
    roomController.dispose();
    super.dispose();
  }

  // --- UI pieces ---

  Widget _visitorSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Select Visitor', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Row(
          children: [
            ChoiceChip(
              label: const Text('Existing visitor'),
              selected: !isRegisteringNewVisitor,
              onSelected: (_) => setState(() {
                isRegisteringNewVisitor = false;
              }),
            ),
            const SizedBox(width: 8),
            ChoiceChip(
              label: const Text('New visitor'),
              selected: isRegisteringNewVisitor,
              onSelected: (_) => setState(() {
                isRegisteringNewVisitor = true;
                selectedVisitor = null;
              }),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (!isRegisteringNewVisitor) ...[
          if (selectedVisitor != null)
            Card(
              child: ListTile(
                title: Text(selectedVisitor!.fullName),
                subtitle: Text('National ID: ${selectedVisitor!.nationalId}'),
                trailing: TextButton(
                  onPressed: () => setState(() {
                    selectedVisitor = null;
                    visitorSearchController.clear();
                  }),
                  child: const Text('Change'),
                ),
              ),
            )
          else
            _SearchDropdownField<Visitor>(
              controller: visitorSearchController,
              labelText: 'Search by name or national ID',
              itemsBuilder: () => _filteredVisitors,
              itemLabelBuilder: (v) => v.fullName,
              itemSubtitleBuilder: (v) => 'National ID: ${v.nationalId}',
              onSelected: (v) => setState(() => selectedVisitor = v),
            ),
        ] else ...[
          TextFormField(
            controller: newNameController,
            decoration: const InputDecoration(labelText: 'Visitor Name', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: newNationalIdController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'National ID', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: newPhoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder()),
          ),
        ],
      ],
    );
  }

  Widget _hostSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Person They Are Visiting', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (selectedHost != null)
          Card(
            child: ListTile(
              title: Text(selectedHost!.fullName),
              subtitle: Text(selectedHost!.department),
              trailing: TextButton(
                onPressed: () => setState(() {
                  selectedHost = null;
                  hostSearchController.clear();
                  selectedDepartmentFilter = null;
                }),
                child: const Text('Change'),
              ),
            ),
          )
        else ...[
          DropdownButtonFormField<String?>(
            initialValue: selectedDepartmentFilter,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
            hint: const Text('Select department'),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('All departments'),
              ),
              ..._departments.map(
                    (d) => DropdownMenuItem<String?>(value: d, child: Text(d)),
              ),
            ],
            onChanged: (value) => setState(() => selectedDepartmentFilter = value),
          ),
          const SizedBox(height: 12),
          _SearchDropdownField<Employee>(
            controller: hostSearchController,
            labelText: 'Search by name',
            itemsBuilder: () => _filteredEmployees,
            itemLabelBuilder: (e) => e.fullName,
            itemSubtitleBuilder: (e) => e.department,
            onSelected: (e) => setState(() => selectedHost = e),
          ),
        ],
      ],
    );
  }

  Widget _scheduleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...periodBlocks.asMap().entries.map((entry) {
          final index = entry.key;
          final block = entry.value;
          final sortedDays = block.days.toList()..sort();
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              title: Text('${block.days.length} day(s) selected'),
              subtitle: Text(
                '${sortedDays.map(_formatDateOnly).join(", ")}\n'
                    '${block.startTime.format(context)} – ${block.endTime.format(context)}',
              ),
              isThreeLine: true,
              trailing: IconButton(
                icon: const Icon(Icons.remove_circle, color: Colors.red),
                onPressed: () => _removePeriod(index),
              ),
            ),
          );
        }),
        TextButton.icon(
          onPressed: _addPeriod,
          icon: const Icon(Icons.add),
          label: const Text('Add Visit Date(s)'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.lightBlue,
        title: const Text('New Visitor'),
      ),
      body: isLoadingData
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _visitorSection(),
              const SizedBox(height: 24),
              _hostSection(),
              const SizedBox(height: 24),
              TextFormField(
                controller: purposeController,
                decoration: const InputDecoration(labelText: 'Purpose of Visit', border: OutlineInputBorder()),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: floorController,
                      decoration: const InputDecoration(labelText: 'Floor', border: OutlineInputBorder()),
                      validator: (value) => (value == null || value.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: roomController,
                      decoration: const InputDecoration(labelText: 'Room', border: OutlineInputBorder()),
                      validator: (value) => (value == null || value.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text('Visit Date(s)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _scheduleSection(),
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lightBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                  ),
                  child: isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Register Visit', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Full-screen calendar for picking a scattered set of individual days for a period.
class _PeriodCalendarPicker extends StatefulWidget {
  const _PeriodCalendarPicker();

  @override
  State<_PeriodCalendarPicker> createState() => _PeriodCalendarPickerState();
}

class _PeriodCalendarPickerState extends State<_PeriodCalendarPicker> {
  final Set<DateTime> selectedDays = {};
  DateTime focusedDay = DateTime.now();

  bool _isSelected(DateTime day) {
    return selectedDays.any((d) => isSameDay(d, day));
  }

  void _toggleDay(DateTime day) {
    final normalized = DateTime(day.year, day.month, day.day);
    setState(() {
      if (_isSelected(normalized)) {
        selectedDays.removeWhere((d) => isSameDay(d, normalized));
      } else {
        selectedDays.add(normalized);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.lightBlue,
        title: const Text('Select period days'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, selectedDays),
            child: const Text('Done', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.now().subtract(const Duration(days: 1)),
            lastDay: DateTime.now().add(const Duration(days: 365)),
            focusedDay: focusedDay,
            selectedDayPredicate: _isSelected,
            // The weekday-names row (Sun, Mon, Tue...) was getting visually
            // clipped/overlapped by the calendar grid below it because the
            // default row height (16px) is shorter than its own text plus
            // padding. Giving it explicit room fixes the overlap.
            daysOfWeekHeight: 40,
            rowHeight: 48,
            // Keeps every month rendered at a fixed 6-row height so the
            // calendar doesn't resize (and re-trigger the overlap) when
            // paging between months with different week counts.
            sixWeekMonthsEnforced: true,
            onDaySelected: (selected, focused) {
              setState(() => focusedDay = focused);
              _toggleDay(selected);
            },
            onPageChanged: (focused) => focusedDay = focused,
            calendarStyle: CalendarStyle(
              selectedDecoration: BoxDecoration(color: Colors.lightBlue.shade700, shape: BoxShape.circle),
              todayDecoration: BoxDecoration(color: Colors.lightBlue.shade100, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${selectedDays.length} day(s) selected',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Tap any day to select or deselect it. Selected days don\'t need to be in a row.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}