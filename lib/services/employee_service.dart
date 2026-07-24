import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/employee_model.dart';

class EmployeeService {
  final supabase = Supabase.instance.client;

  // Fetches all employees EXCEPT the Security department - powers the host
  // dropdown in the New Visitor form. Security shouldn't be selectable as
  // someone a visitor is coming to see.
  Future<List<Employee>> getAllEmployees() async {
    final response = await supabase
        .from('employees')
        .select()
        .neq('department', 'Security')
        .order('full_name', ascending: true);

    return (response as List).map((e) => Employee.fromMap(e)).toList();
  }

  // Fetch a single employee by their id - needed to show host name on the verification screen
  Future<Employee?> getEmployeeById(String id) async {
    final response = await supabase
        .from('employees')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return Employee.fromMap(response);
  }

  // Fetch the employee record linked to the currently logged-in auth user.
  // Returns null if this logged-in user has no matching employee record at all.
  Future<Employee?> getMyEmployeeRecord() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return null;

    final response = await supabase
        .from('employees')
        .select()
        .eq('auth_user_id', userId)
        .maybeSingle();

    if (response == null) return null;
    return Employee.fromMap(response);
  }

  // Updates an existing employee's info (e.g. name).
  // Used if HR needs to correct a host's details directly from the edit modal.
  Future<Employee?> updateEmployee(String id, Map<String, dynamic> updates) async {
    final response = await supabase
        .from('employees')
        .update(updates)
        .eq('id', id)
        .select()
        .maybeSingle();

    if (response == null) return null;
    return Employee.fromMap(response);
  }
}