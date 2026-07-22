import 'package:flutter/material.dart';
import 'models/visitor_model.dart';
import 'models/visit_model.dart';
import 'models/visit_schedule_model.dart';
import 'models/employee_model.dart';
import 'services/visitor_service.dart';
import 'services/visit_service.dart';
import 'services/employee_service.dart';
import 'qr_result_page.dart';

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
  bool isLoadingData = true;

  // Employee (host) selection state
  List<Employee> employees = [];
  Employee? selectedHost;

  // New visitor fields (only used if selectedVisitor stays null)
  final newNameController = TextEditingController();
  final newNationalIdController = TextEditingController();
  final newPhoneController = TextEditingController();

  // Visit details
  final purposeController = TextEditingController();
  final floorController = TextEditingController();
  final roomController = TextEditingController();

  // Scheduled dates - starts with one empty slot
  List<DateTime?> scheduledDateTimes = [null];

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

  Future<void> _pickDateTimeFor(int index) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null) return;

    setState(() {
      scheduledDateTimes[index] = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _addDateSlot() {
    setState(() {
      scheduledDateTimes.add(null);
    });
  }

  void _removeDateSlot(int index) {
    setState(() {
      scheduledDateTimes.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (selectedVisitor == null) {
      if (newNameController.text.trim().isEmpty ||
          newNationalIdController.text.trim().isEmpty ||
          newPhoneController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a visitor or fill in new visitor details')),
        );
        return;
      }
    }

    if (selectedHost == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select who they are visiting')),
      );
      return;
    }

    if (scheduledDateTimes.any((d) => d == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set a date and time for every visit slot')),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      Visitor visitor;
      if (selectedVisitor != null) {
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

      final schedules = scheduledDateTimes.map((dt) {
        final timeStr =
            '${dt!.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:00';
        return VisitSchedule(
          scheduledDate: DateTime(dt.year, dt.month, dt.day),
          scheduledTime: timeStr,
        );
      }).toList();

      final createdVisit = await visitService.createVisitWithSchedules(visit, schedules);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => QrResultPage(
            visitId: createdVisit.id!,
            visitorName: visitor.fullName,
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
    newNameController.dispose();
    newNationalIdController.dispose();
    newPhoneController.dispose();
    purposeController.dispose();
    floorController.dispose();
    roomController.dispose();
    super.dispose();
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
              const Text(
                'Select Visitor',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<Visitor?>(
                initialValue: selectedVisitor,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Choose an existing visitor',
                ),
                items: [
                  const DropdownMenuItem<Visitor?>(
                    value: null,
                    child: Text('+ Register a new visitor'),
                  ),
                  ...existingVisitors.map((v) => DropdownMenuItem<Visitor?>(
                    value: v,
                    child: Text('${v.fullName} (${v.nationalId})'),
                  )),
                ],
                onChanged: (value) {
                  setState(() => selectedVisitor = value);
                },
              ),
              const SizedBox(height: 16),

              if (selectedVisitor == null) ...[
                TextFormField(
                  controller: newNameController,
                  decoration: const InputDecoration(
                    labelText: 'Visitor Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: newNationalIdController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'National ID',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: newPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone Number',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              DropdownButtonFormField<Employee>(
                initialValue: selectedHost,
                decoration: const InputDecoration(
                  labelText: 'Person They Are Visiting',
                  border: OutlineInputBorder(),
                ),
                items: employees.map((e) => DropdownMenuItem<Employee>(
                  value: e,
                  child: Text('${e.fullName} - ${e.department}'),
                )).toList(),
                onChanged: (value) {
                  setState(() => selectedHost = value);
                },
                validator: (value) => value == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: purposeController,
                decoration: const InputDecoration(
                  labelText: 'Purpose of Visit',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                (value == null || value.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: floorController,
                      decoration: const InputDecoration(
                        labelText: 'Floor',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: roomController,
                      decoration: const InputDecoration(
                        labelText: 'Room',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              const Text(
                'Scheduled Visit Dates',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              ...scheduledDateTimes.asMap().entries.map((entry) {
                final index = entry.key;
                final dt = entry.value;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () => _pickDateTimeFor(index),
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                            ),
                            child: Text(dt == null ? 'Tap to select date & time' : dt.toString()),
                          ),
                        ),
                      ),
                      if (scheduledDateTimes.length > 1)
                        IconButton(
                          icon: const Icon(Icons.remove_circle, color: Colors.red),
                          onPressed: () => _removeDateSlot(index),
                        ),
                    ],
                  ),
                );
              }),

              TextButton.icon(
                onPressed: _addDateSlot,
                icon: const Icon(Icons.add),
                label: const Text('Add another date'),
              ),
              const SizedBox(height: 24),

              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.lightBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
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