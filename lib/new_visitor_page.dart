import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import 'app_theme.dart';
import 'custom_time_picker.dart';
import 'models/employee_model.dart';
import 'models/visit_model.dart';
import 'models/visit_schedule_model.dart';
import 'models/visitor_model.dart';
import 'qr_result_page.dart';
import 'services/employee_service.dart';
import 'services/visit_service.dart';
import 'services/visitor_service.dart';

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

class _SearchDropdownField<T> extends StatefulWidget {
  final TextEditingController controller;
  final String labelText;
  final List<T> Function() itemsBuilder;
  final String Function(T item) itemLabelBuilder;
  final String Function(T item)? itemSubtitleBuilder;
  final ValueChanged<T> onSelected;
  final IconData icon;

  const _SearchDropdownField({
    super.key,
    required this.controller,
    required this.labelText,
    required this.itemsBuilder,
    required this.itemLabelBuilder,
    this.itemSubtitleBuilder,
    required this.onSelected,
    this.icon = Icons.search_rounded,
  });

  @override
  State<_SearchDropdownField<T>> createState() {
    return _SearchDropdownFieldState<T>();
  }
}

class _SearchDropdownFieldState<T> extends State<_SearchDropdownField<T>> {
  final FocusNode _focusNode = FocusNode();
  final LayerLink _layerLink = LayerLink();

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
      Future.delayed(const Duration(milliseconds: 160), _removeOverlay);
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
      builder: (context) {
        return Positioned(
          width: size.width,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            offset: Offset(0, size.height + 8),
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 250),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                  border: Border.all(color: AppColors.line),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(.08),
                      blurRadius: 24,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                  child: _buildList(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildList() {
    final items = widget.itemsBuilder();

    if (items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(
              Icons.search_off_rounded,
              color: AppColors.muted,
            ),
            SizedBox(width: 10),
            Text(
              'No matches found',
              style: TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: items.length,
      separatorBuilder: (_, __) {
        return const Divider(
          height: 1,
          color: AppColors.line,
        );
      },
      itemBuilder: (context, index) {
        final item = items[index];

        return InkWell(
          canRequestFocus: false,
          onTap: () {
            widget.onSelected(item);
            _focusNode.unfocus();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            child: Row(
              children: [
                const AppIconBadge(
                  icon: Icons.person_outline_rounded,
                  size: 38,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.itemLabelBuilder(item),
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      if (widget.itemSubtitleBuilder != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          widget.itemSubtitleBuilder!(item),
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
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
          prefixIcon: Icon(widget.icon),
        ),
      ),
    );
  }
}

class NewVisitorPage extends StatefulWidget {
  final Map<String, dynamic>? visitToEdit;

  const NewVisitorPage({
    super.key,
    this.visitToEdit,
  });

  bool get isEditMode {
    return visitToEdit != null;
  }

  @override
  State<NewVisitorPage> createState() {
    return _NewVisitorPageState();
  }
}

class _NewVisitorPageState extends State<NewVisitorPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  final VisitorService visitorService = VisitorService();
  final VisitService visitService = VisitService();
  final EmployeeService employeeService = EmployeeService();

  List<Visitor> existingVisitors = [];
  Visitor? selectedVisitor;

  bool isRegisteringNewVisitor = false;

  final TextEditingController visitorSearchController =
  TextEditingController();

  List<Employee> employees = [];
  Employee? selectedHost;
  Employee? myEmployeeRecord; // the logged-in user's own employee row
  bool isBookingForSomeoneElse = false;

  String? selectedDepartmentFilter;

  final TextEditingController hostSearchController = TextEditingController();

  final TextEditingController newNameController = TextEditingController();
  final TextEditingController newNationalIdController =
  TextEditingController();
  final TextEditingController newPhoneController = TextEditingController();

  final TextEditingController purposeController = TextEditingController();
  final TextEditingController floorController = TextEditingController();
  final TextEditingController roomController = TextEditingController();
  final TextEditingController invalidReasonController =
  TextEditingController();

  String selectedStatus = 'active';

  List<_PeriodBlock> periodBlocks = [];

  bool isLoadingData = true;
  bool isSaving = false;

  bool get isEditMode {
    return widget.isEditMode;
  }

  @override
  void initState() {
    super.initState();

    if (isEditMode) {
      _prefillEditControllers();
    }

    _loadData();
  }

  void _prefillEditControllers() {
    final visit = widget.visitToEdit!;

    final visitorInfo = visit['visitors'] as Map<String, dynamic>?;

    newNameController.text = visitorInfo?['full_name']?.toString() ?? '';

    newNationalIdController.text =
        visitorInfo?['national_id']?.toString() ?? '';

    newPhoneController.text = visitorInfo?['phone']?.toString() ?? '';

    purposeController.text = visit['purpose']?.toString() ?? '';
    floorController.text = visit['floor']?.toString() ?? '';
    roomController.text = visit['room']?.toString() ?? '';

    selectedStatus = visit['status']?.toString() ?? 'active';

    invalidReasonController.text =
        visit['invalid_reason']?.toString() ?? '';
  }

  Future<void> _loadData() async {
    try {
      final visitors = await visitorService.getAllVisitors();
      final employeesList = await employeeService.getAllEmployees();
      final myRecord = await employeeService.getMyEmployeeRecord();

      Employee? host;

      List<_PeriodBlock> loadedPeriods = [];

      if (isEditMode) {
        final visit = widget.visitToEdit!;

        final employeeInfo = visit['employees'] as Map<String, dynamic>?;

        final hostId =
            visit['host_id']?.toString() ?? employeeInfo?['id']?.toString();

        for (final employee in employeesList) {
          if (employee.id?.toString() == hostId) {
            host = employee;
            break;
          }
        }

        final scheduleMaps = (visit['visit_schedules'] as List?) ?? [];

        loadedPeriods = _periodBlocksFromScheduleMaps(scheduleMaps);
      } else {
        // Not editing - default the host to the logged-in user themselves
        host = myRecord;
      }

      if (!mounted) return;

      setState(() {
        existingVisitors = visitors;
        employees = employeesList;
        myEmployeeRecord = myRecord;
        selectedHost = host;
        periodBlocks = loadedPeriods;
        isLoadingData = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoadingData = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load page data: $error'),
        ),
      );
    }
  }

  List<_PeriodBlock> _periodBlocksFromScheduleMaps(List<dynamic> schedules) {
    final groupedDays = <String, Set<DateTime>>{};

    for (final item in schedules) {
      final schedule = item as Map<String, dynamic>;

      final dateValue = schedule['scheduled_date']?.toString();

      final startValue = schedule['start_time']?.toString() ?? '00:00:00';
      final endValue = schedule['end_time']?.toString() ?? '00:00:00';

      if (dateValue == null) {
        continue;
      }

      final date = DateTime.tryParse(dateValue);

      if (date == null) {
        continue;
      }

      final key = '$startValue|$endValue';

      groupedDays
          .putIfAbsent(
        key,
            () => <DateTime>{},
      )
          .add(
        DateTime(
          date.year,
          date.month,
          date.day,
        ),
      );
    }

    final blocks = groupedDays.entries.map(
          (entry) {
        final parts = entry.key.split('|');

        return _PeriodBlock(
          days: entry.value,
          startTime: _databaseTimeToTimeOfDay(parts[0]),
          endTime: _databaseTimeToTimeOfDay(parts[1]),
        );
      },
    ).toList();

    blocks.sort(
          (first, second) {
        final firstDays = first.days.toList()..sort();
        final secondDays = second.days.toList()..sort();

        return firstDays.first.compareTo(secondDays.first);
      },
    );

    return blocks;
  }

  TimeOfDay _databaseTimeToTimeOfDay(String value) {
    final parts = value.split(':');

    return TimeOfDay(
      hour: parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0,
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
  }

  List<Visitor> get filteredVisitors {
    final query = visitorSearchController.text.trim().toLowerCase();

    if (query.isEmpty) {
      return existingVisitors;
    }

    return existingVisitors.where(
          (visitor) {
        return visitor.fullName.toLowerCase().contains(query) ||
            visitor.nationalId.toLowerCase().contains(query);
      },
    ).toList();
  }

  List<String> get departments {
    final departmentList = employees
        .map(
          (employee) => employee.department,
    )
        .toSet()
        .toList();

    departmentList.sort();

    return departmentList;
  }

  List<Employee> get filteredEmployees {
    final query = hostSearchController.text.trim().toLowerCase();

    return employees.where(
          (employee) {
        final matchesDepartment = selectedDepartmentFilter == null ||
            employee.department == selectedDepartmentFilter;

        final matchesSearch =
            query.isEmpty || employee.fullName.toLowerCase().contains(query);

        return matchesDepartment && matchesSearch;
      },
    ).toList();
  }

  Future<void> _addPeriod() async {
    final selectedDays = await Navigator.push<Set<DateTime>>(
      context,
      MaterialPageRoute(
        builder: (context) {
          return const _PeriodCalendarPicker();
        },
      ),
    );

    if (selectedDays == null || selectedDays.isEmpty || !mounted) {
      return;
    }

    final range = await _pickValidTimeRange(
      selectedDays: selectedDays,
    );

    if (range == null || !mounted) {
      return;
    }


    setState(() {
      periodBlocks.add(
        _PeriodBlock(
          days: selectedDays,
          startTime: range.start,
          endTime: range.end,
        ),
      );
    });
  }

  Future<void> _editPeriod(int index) async {
    final currentBlock = periodBlocks[index];

    final selectedDays = await Navigator.push<Set<DateTime>>(
      context,
      MaterialPageRoute(
        builder: (context) {
          return _PeriodCalendarPicker(
            initialSelectedDays: currentBlock.days,
          );
        },
      ),
    );

    if (selectedDays == null || selectedDays.isEmpty || !mounted) {
      return;
    }

    final range = await _pickValidTimeRange(
      selectedDays: selectedDays,
      initialStart: currentBlock.startTime,
      initialEnd: currentBlock.endTime,
    );

    if (range == null || !mounted) {
      return;
    }

    setState(() {
      periodBlocks[index] = _PeriodBlock(
        days: selectedDays,
        startTime: range.start,
        endTime: range.end,
      );
    });
  }

  /// Opens a single time-range picker dialog that walks the user through
  /// choosing a start time and then an end time, without closing and
  /// reopening a separate [Dialog] for each step. The dialog itself only
  /// ever surfaces reachable (valid) times - there is nothing left to
  /// validate afterwards, so no error SnackBars are needed here.
  Future<({TimeOfDay start, TimeOfDay end})?> _pickValidTimeRange({
    required Set<DateTime> selectedDays,
    TimeOfDay? initialStart,
    TimeOfDay? initialEnd,
  }) async {
    final today = DateTime.now();

    final includesToday = selectedDays.any(
          (day) =>
      day.year == today.year &&
          day.month == today.month &&
          day.day == today.day,
    );

    // Start time can't be before "now" when one of the selected days is
    // today. Otherwise there's no lower bound.
    final startMinTime = includesToday ? TimeOfDay.now() : null;

    final range = await showCustomTimeRangePicker(
      context: context,
      initialStart: initialStart,
      initialEnd: initialEnd,
      minStartTime: startMinTime,
    );

    if (range == null || !mounted) return null;

    return range;
  }

  void _removePeriod(int index) {
    setState(() {
      periodBlocks.removeAt(index);
    });
  }

  String _timeOfDayToDatabaseString(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}:00';
  }

  String _formatDateOnly(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!isEditMode &&
        !isRegisteringNewVisitor &&
        selectedVisitor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select an existing visitor or switch to "New visitor"',
          ),
        ),
      );

      return;
    }

    if ((isEditMode || isRegisteringNewVisitor) &&
        (newNameController.text.trim().isEmpty ||
            newNationalIdController.text.trim().isEmpty ||
            newPhoneController.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all visitor details'),
        ),
      );

      return;
    }

    if (selectedHost == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select who they are visiting'),
        ),
      );

      return;
    }

    if (periodBlocks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one visit date'),
        ),
      );

      return;
    }

    if (selectedStatus == 'invalid' &&
        invalidReasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the invalid reason'),
        ),
      );

      return;
    }

    final schedules = <VisitSchedule>[];

    for (final block in periodBlocks) {
      final startMinutes = block.startTime.hour * 60 + block.startTime.minute;
      final endMinutes = block.endTime.hour * 60 + block.endTime.minute;

      if (endMinutes <= startMinutes) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Every end time must be after its start time'),
          ),
        );

        return;
      }

      for (final day in block.days) {
        schedules.add(
          VisitSchedule(
            scheduledDate: day,
            startTime: _timeOfDayToDatabaseString(block.startTime),
            endTime: _timeOfDayToDatabaseString(block.endTime),
          ),
        );
      }
    }

    setState(() {
      isSaving = true;
    });

    try {
      if (isEditMode) {
        await _saveEditedVisitor(schedules);
        return;
      }

      await _createNewVisit(schedules);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${error.toString()}'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  Future<void> _saveEditedVisitor(List<VisitSchedule> schedules) async {
    final existingVisit = widget.visitToEdit!;

    final visitorInfo = existingVisit['visitors'] as Map<String, dynamic>?;

    final visitorId =
        visitorInfo?['id']?.toString() ?? existingVisit['visitor_id']?.toString();

    final visitId = existingVisit['id']?.toString();

    if (visitorId == null || visitId == null) {
      throw Exception('The visitor or visit ID is missing.');
    }

    await visitorService.updateVisitor(
      visitorId,
      {
        'full_name': newNameController.text.trim(),
        'national_id': newNationalIdController.text.trim(),
        'phone': newPhoneController.text.trim(),
      },
    );

    await visitService.updateVisit(
      visitId,
      {
        'host_id': selectedHost!.id,
        'purpose': purposeController.text.trim(),
        'floor': floorController.text.trim(),
        'room': roomController.text.trim(),
        'status': selectedStatus,
        'invalid_reason': selectedStatus == 'invalid'
            ? invalidReasonController.text.trim()
            : null,
      },
    );

    await visitService.supabase
        .from('visit_schedules')
        .delete()
        .eq('visit_id', visitId);

    final scheduleRows = schedules.map(
          (schedule) {
        final map = schedule.toMap();

        map['visit_id'] = visitId;

        return map;
      },
    ).toList();

    await visitService.supabase.from('visit_schedules').insert(scheduleRows);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Visitor updated successfully'),
      ),
    );

    Navigator.pop(context, true);
  }

  Future<void> _createNewVisit(List<VisitSchedule> schedules) async {
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

    final createdVisit = await visitService.createVisitWithSchedules(
      visit,
      schedules,
    );

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) {
          return QrResultPage(
            visitId: createdVisit.id!,
            visitorName: visitor.fullName,
            hostName: selectedHost!.fullName,
            department: selectedHost!.department,
            purpose: purposeController.text.trim(),
            floor: floorController.text.trim(),
            room: roomController.text.trim(),
            schedules: schedules,
          );
        },
      ),
    );
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
    invalidReasonController.dispose();

    super.dispose();
  }

  Widget _sectionTitle({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppIconBadge(
          icon: icon,
          size: 42,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.navy,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _visitorSection() {
    if (isEditMode) {
      return SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(
              icon: Icons.badge_outlined,
              title: 'Visitor Details',
              subtitle: 'Update the visitor profile information.',
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: newNameController,
              decoration: const InputDecoration(
                labelText: 'Visitor Name',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Required';
                }

                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: newNationalIdController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'National ID',
                prefixIcon: Icon(Icons.credit_card_rounded),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Required';
                }

                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: newPhoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Required';
                }

                return null;
              },
            ),
          ],
        ),
      );
    }

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            icon: Icons.person_search_rounded,
            title: 'Select Visitor',
            subtitle: 'Select a registered visitor or create a new one.',
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ChoiceChip(
                avatar: Icon(
                  Icons.people_alt_outlined,
                  color: !isRegisteringNewVisitor
                      ? Colors.white
                      : AppColors.ratpGreenDark,
                  size: 18,
                ),
                label: const Text('Registered Visitor'),
                selected: !isRegisteringNewVisitor,
                onSelected: (_) {
                  setState(() {
                    isRegisteringNewVisitor = false;
                  });
                },
              ),
              ChoiceChip(
                avatar: Icon(
                  Icons.person_add_alt_1_rounded,
                  color: isRegisteringNewVisitor
                      ? Colors.white
                      : AppColors.ratpGreenDark,
                  size: 18,
                ),
                label: const Text('New Visitor'),
                selected: isRegisteringNewVisitor,
                onSelected: (_) {
                  setState(() {
                    isRegisteringNewVisitor = true;
                    selectedVisitor = null;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (!isRegisteringNewVisitor) ...[
            if (selectedVisitor != null)
              _selectedPersonCard(
                icon: Icons.person_outline_rounded,
                title: selectedVisitor!.fullName,
                subtitle: 'National ID: ${selectedVisitor!.nationalId}',
                onChange: () {
                  setState(() {
                    selectedVisitor = null;
                    visitorSearchController.clear();
                  });
                },
              )
            else
              _SearchDropdownField<Visitor>(
                controller: visitorSearchController,
                labelText: 'Search by name or national ID',
                icon: Icons.search_rounded,
                itemsBuilder: () {
                  return filteredVisitors;
                },
                itemLabelBuilder: (visitor) {
                  return visitor.fullName;
                },
                itemSubtitleBuilder: (visitor) {
                  return 'National ID: ${visitor.nationalId}';
                },
                onSelected: (visitor) {
                  setState(() {
                    selectedVisitor = visitor;
                  });
                },
              ),
          ] else ...[
            TextFormField(
              controller: newNameController,
              decoration: const InputDecoration(
                labelText: 'Visitor Name',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Required';
                }

                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: newNationalIdController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'National ID',
                prefixIcon: Icon(Icons.credit_card_rounded),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Required';
                }

                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: newPhoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Required';
                }

                return null;
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _selectedPersonCard({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onChange,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        children: [
          AppIconBadge(
            icon: icon,
            size: 44,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (onChange != null)
            TextButton.icon(
              onPressed: onChange,
              icon: const Icon(
                Icons.swap_horiz_rounded,
                size: 18,
              ),
              label: const Text('Change'),
            ),
        ],
      ),
    );
  }

  Widget _hostSection() {
    // Edit mode keeps the existing full dropdown behavior, unchanged.
    if (isEditMode) {
      return _hostSectionDropdownMode();
    }

    // Not edit mode, and this logged-in user has no employee record at all -
    // fall back to the full dropdown (shouldn't normally happen, but safe).
    if (myEmployeeRecord == null) {
      return _hostSectionDropdownMode();
    }

    // Booking for someone else was toggled on - show the searchable dropdown.
    if (isBookingForSomeoneElse) {
      return _hostSectionDropdownMode(showCancelDelegation: true);
    }

    // Default case: locked to the logged-in user's own name/department.
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            icon: Icons.business_center_outlined,
            title: 'Person They Are Visiting',
            subtitle: "You're the assigned host.",
          ),
          const SizedBox(height: 18),
          _selectedPersonCard(
            icon: Icons.work_outline_rounded,
            title: myEmployeeRecord!.fullName,
            subtitle: myEmployeeRecord!.department,
            onChange: myEmployeeRecord!.canBookForOthers
                ? () {
              setState(() {
                isBookingForSomeoneElse = true;
                selectedHost = null;
                hostSearchController.clear();
                selectedDepartmentFilter = null;
              });
            }
                : null,
          ),
        ],
      ),
    );
  }

  Widget _hostSectionDropdownMode({bool showCancelDelegation = false}) {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            icon: Icons.business_center_outlined,
            title: 'Person They Are Visiting',
            subtitle: showCancelDelegation
                ? 'Choose the employee to visit.'
                : 'Select the host employee.',
          ),
          const SizedBox(height: 18),
          if (selectedHost != null)
            _selectedPersonCard(
              icon: Icons.work_outline_rounded,
              title: selectedHost!.fullName,
              subtitle: selectedHost!.department,
              onChange: () {
                setState(() {
                  selectedHost = null;
                  hostSearchController.clear();
                  selectedDepartmentFilter = null;
                });
              },
            )
          else ...[
            DropdownButtonFormField<String?>(
              initialValue: selectedDepartmentFilter,
              decoration: const InputDecoration(
                labelText: 'Department',
                prefixIcon: Icon(Icons.apartment_rounded),
              ),
              hint: const Text('Select department'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All departments'),
                ),
                ...departments.map(
                      (department) {
                    return DropdownMenuItem<String?>(
                      value: department,
                      child: Text(department),
                    );
                  },
                ),
              ],
              onChanged: (value) {
                setState(() {
                  selectedDepartmentFilter = value;
                });
              },
            ),
            const SizedBox(height: 14),
            _SearchDropdownField<Employee>(
              controller: hostSearchController,
              labelText: 'Search host by name',
              icon: Icons.manage_search_rounded,
              itemsBuilder: () {
                return filteredEmployees;
              },
              itemLabelBuilder: (employee) {
                return employee.fullName;
              },
              itemSubtitleBuilder: (employee) {
                return employee.department;
              },
              onSelected: (employee) {
                setState(() {
                  selectedHost = employee;
                });
              },
            ),
          ],
          if (showCancelDelegation) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    isBookingForSomeoneElse = false;
                    selectedHost = myEmployeeRecord;
                    hostSearchController.clear();
                    selectedDepartmentFilter = null;
                  });
                },
                icon: const Icon(Icons.undo_rounded),
                label: const Text('Book for myself instead'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _visitInformationSection() {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            icon: Icons.route_rounded,
            title: 'Visit Information',
            subtitle: 'Enter the visit details.',
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: purposeController,
            decoration: const InputDecoration(
              labelText: 'Purpose of Visit',
              prefixIcon: Icon(Icons.description_outlined),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Required';
              }

              return null;
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: floorController,
                  decoration: const InputDecoration(
                    labelText: 'Floor',
                    prefixIcon: Icon(Icons.layers_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Required';
                    }

                    return null;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: roomController,
                  decoration: const InputDecoration(
                    labelText: 'Room',
                    prefixIcon: Icon(Icons.meeting_room_outlined),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Required';
                    }

                    return null;
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _scheduleSection() {
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            icon: Icons.event_available_outlined,
            title: 'Visit Date(s)',
            subtitle: 'Select the visit date and time.',
          ),
          const SizedBox(height: 18),
          if (periodBlocks.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(AppRadius.medium),
                border: Border.all(color: AppColors.line),
              ),
              child: const Column(
                children: [
                  AppIconBadge(
                    icon: Icons.calendar_month_rounded,
                    size: 54,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'No visit dates added yet',
                    style: TextStyle(
                      color: AppColors.navy,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Add at least one date before saving.',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            )
          else
            ...periodBlocks.asMap().entries.map(
                  (entry) {
                final index = entry.key;
                final block = entry.value;

                final sortedDays = block.days.toList()..sort();

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppIconBadge(
                        icon: Icons.calendar_today_rounded,
                        size: 44,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${block.days.length} day(s) selected',
                              style: const TextStyle(
                                color: AppColors.ink,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              sortedDays.map(_formatDateOnly).join(', '),
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.softGreen,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${block.startTime.format(context)} \u2013 ${block.endTime.format(context)}',
                                style: const TextStyle(
                                  color: AppColors.ratpGreenDark,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          IconButton(
                            tooltip: 'Edit schedule',
                            icon: const Icon(
                              Icons.edit_note_rounded,
                              color: AppColors.warning,
                            ),
                            onPressed: () {
                              _editPeriod(index);
                            },
                          ),
                          IconButton(
                            tooltip: 'Remove schedule',
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: AppColors.danger,
                            ),
                            onPressed: () {
                              _removePeriod(index);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _addPeriod,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Visit Date(s)'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusSection() {
    if (!isEditMode) {
      return const SizedBox.shrink();
    }

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(
            icon: Icons.verified_user_outlined,
            title: 'Visit Status',
            subtitle: 'Update the visit status.',
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            initialValue: selectedStatus,
            decoration: const InputDecoration(
              labelText: 'Status',
              prefixIcon: Icon(Icons.fact_check_outlined),
            ),
            items: const [
              DropdownMenuItem(
                value: 'active',
                child: Text('Active'),
              ),
              DropdownMenuItem(
                value: 'invalid',
                child: Text('Invalid'),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;

              setState(() {
                selectedStatus = value;

                if (value == 'active') {
                  invalidReasonController.clear();
                }
              });
            },
          ),
          if (selectedStatus == 'invalid') ...[
            const SizedBox(height: 16),
            TextFormField(
              controller: invalidReasonController,
              decoration: const InputDecoration(
                labelText: 'Invalid Reason',
                prefixIcon: Icon(Icons.report_problem_outlined),
              ),
              validator: (value) {
                if (selectedStatus == 'invalid' &&
                    (value == null || value.trim().isEmpty)) {
                  return 'Required';
                }

                return null;
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _loadingPage() {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(isEditMode ? 'Edit Visitor' : 'New Visitor'),
      ),
      body: const Center(
        child: CircularProgressIndicator(
          color: AppColors.ratpGreen,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoadingData) {
      return _loadingPage();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          isEditMode ? 'Edit Visitor' : 'New Visitor',
        ),
      ),
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusScope.of(context).unfocus(),
          child: Form(
            key: _formKey,
            child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
          children: [
            PageHeader(
              title: isEditMode ? 'Edit visitor request' : 'Create visitor request',
              subtitle: isEditMode
                  ? 'Update visitor information and visit details.'
                  : 'Register a visitor and schedule their visit.',
              icon: isEditMode
                  ? Icons.edit_note_rounded
                  : Icons.person_add_alt_1_rounded,
            ),
            const SizedBox(height: 18),
            _visitorSection(),
            const SizedBox(height: 16),
            _hostSection(),
            const SizedBox(height: 16),
            _visitInformationSection(),
            const SizedBox(height: 16),
            _scheduleSection(),
            if (isEditMode) ...[
              const SizedBox(height: 16),
              _statusSection(),
            ],
          ],
        ),
      ),),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          16 + MediaQuery.of(context).padding.bottom,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: const Border(
            top: BorderSide(color: AppColors.line),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.05),
              blurRadius: 24,
              offset: const Offset(0, -10),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: isSaving ? null : _submit,
          icon: isSaving
              ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 3,
            ),
          )
              : Icon(
            isEditMode
                ? Icons.save_as_rounded
                : Icons.qr_code_2_rounded,
          ),
          label: Text(
            isSaving
                ? 'Saving...'
                : isEditMode
                ? 'Save Changes'
                : 'Register Visit',
          ),
        ),
      ),
    );
  }
}

class _PeriodCalendarPicker extends StatefulWidget {
  final Set<DateTime> initialSelectedDays;

  const _PeriodCalendarPicker({
    this.initialSelectedDays = const {},
  });

  @override
  State<_PeriodCalendarPicker> createState() {
    return _PeriodCalendarPickerState();
  }
}

class _PeriodCalendarPickerState extends State<_PeriodCalendarPicker> {
  late final Set<DateTime> selectedDays;
  late DateTime focusedDay;

  @override
  void initState() {
    super.initState();

    selectedDays = widget.initialSelectedDays
        .map(
          (day) => DateTime(
        day.year,
        day.month,
        day.day,
      ),
    )
        .toSet();

    if (selectedDays.isEmpty) {
      focusedDay = DateTime.now();
    } else {
      final sortedDays = selectedDays.toList()..sort();

      focusedDay = sortedDays.first;
    }
  }

  bool _isSelected(DateTime day) {
    return selectedDays.any(
          (selectedDay) {
        return isSameDay(selectedDay, day);
      },
    );
  }

  void _toggleDay(DateTime day) {
    final normalizedDay = DateTime(
      day.year,
      day.month,
      day.day,
    );

    setState(() {
      if (_isSelected(normalizedDay)) {
        selectedDays.removeWhere(
              (selectedDay) {
            return isSameDay(selectedDay, normalizedDay);
          },
        );
      } else {
        selectedDays.add(normalizedDay);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Select period days'),

      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          PageHeader(
            title: 'Choose visit days',
            subtitle:
            'Select one or more visit dates.',
            icon: Icons.calendar_month_rounded,
          ),
          const SizedBox(height: 18),
          SectionCard(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 20),
            child: TableCalendar(
              firstDay: DateTime(
                DateTime.now().year,
                DateTime.now().month,
                DateTime.now().day,
              ),
              enabledDayPredicate: (day) {
                final today = DateTime(
                  DateTime.now().year,
                  DateTime.now().month,
                  DateTime.now().day,
                );

                return !day.isBefore(today);
              },
              lastDay: DateTime.now().add(
                const Duration(days: 365),
              ),
              focusedDay: focusedDay,
              selectedDayPredicate: _isSelected,
              daysOfWeekHeight: 40,
              rowHeight: 48,
              sixWeekMonthsEnforced: true,
              onDaySelected: (
                  selectedDay,
                  newFocusedDay,
                  ) {
                setState(() {
                  focusedDay = newFocusedDay;
                });

                _toggleDay(selectedDay);
              },
              onPageChanged: (
                  newFocusedDay,
                  ) {
                focusedDay = newFocusedDay;
              },
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
                titleTextStyle: TextStyle(
                  color: AppColors.navy,
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
                leftChevronIcon: Icon(
                  Icons.chevron_left_rounded,
                  color: AppColors.ratpGreenDark,
                ),
                rightChevronIcon: Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.ratpGreenDark,
                ),
              ),
              daysOfWeekStyle: const DaysOfWeekStyle(
                weekdayStyle: TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w800,
                ),
                weekendStyle: TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w800,
                ),
              ),
              calendarStyle: CalendarStyle(
                selectedDecoration: const BoxDecoration(
                  color: AppColors.ratpGreen,
                  shape: BoxShape.circle,
                ),
                todayDecoration: BoxDecoration(
                  color: AppColors.ratpGreen.withOpacity(.16),
                  shape: BoxShape.circle,
                ),
                todayTextStyle: const TextStyle(
                  color: AppColors.ratpGreenDark,
                  fontWeight: FontWeight.w900,
                ),
                selectedTextStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
                defaultTextStyle: const TextStyle(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w700,
                ),
                weekendTextStyle: const TextStyle(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w700,
                ),
                outsideTextStyle: TextStyle(
                  color: AppColors.muted.withOpacity(.45),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          SectionCard(
            child: Row(
              children: [
                const AppIconBadge(
                  icon: Icons.check_circle_outline_rounded,
                  size: 48,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    '${selectedDays.length} ${selectedDays.length == 1 ? "day" : "days"} selected',
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: selectedDays.isEmpty
                  ? null
                  : () {
                Navigator.pop(context, selectedDays);
              },
              icon: const Icon(Icons.done_rounded),
              label: const Text('Confirm Selection'),
            ),
          ),
        ],
      ),
    );
  }
}