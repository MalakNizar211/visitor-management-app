import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'models/visit_model.dart';
import 'services/visit_service.dart';
import 'qr_result_page.dart';

class NewVisitorPage extends StatefulWidget {
  const NewVisitorPage({super.key});

  @override
  State<NewVisitorPage> createState() => _NewVisitorPageState();
}

class _NewVisitorPageState extends State<NewVisitorPage> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final nationalIdController = TextEditingController();
  final phoneController = TextEditingController();
  final hostController = TextEditingController();
  final purposeController = TextEditingController();

  DateTime? selectedDateTime;
  bool isSaving = false;

  final VisitService visitService = VisitService();

  Future<void> _pickDateTime() async {
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
      selectedDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (selectedDateTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a visit date and time')),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;

      final visit = Visit(
        visitorName: nameController.text.trim(),
        nationalId: nationalIdController.text.trim(),
        phone: phoneController.text.trim(),
        visitTime: selectedDateTime!,
        hostName: hostController.text.trim(),
        purpose: purposeController.text.trim(),
        createdBy: userId,
      );

      final createdVisit = await visitService.createVisit(visit);

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => QrResultPage(
            visitId: createdVisit.id!,
            visitorName: createdVisit.visitorName,
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
    nameController.dispose();
    nationalIdController.dispose();
    phoneController.dispose();
    hostController.dispose();
    purposeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.lightBlue,
        title: const Text('New Visitor'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Visitor Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                (value == null || value.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: nationalIdController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'National ID',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                (value == null || value.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                (value == null || value.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: hostController,
                decoration: const InputDecoration(
                  labelText: 'Person They Are Visiting',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                (value == null || value.trim().isEmpty) ? 'Required' : null,
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
              InkWell(
                onTap: _pickDateTime,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Visit Date & Time',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    selectedDateTime == null
                        ? 'Tap to select'
                        : selectedDateTime.toString(),
                  ),
                ),
              ),
              const SizedBox(height: 32),
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
                      : const Text('Register Visitor', style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}