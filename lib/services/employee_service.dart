import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/employee_model.dart';

class EmployeeService {
  final supabase = Supabase.instance.client;

  Future<List<Employee>> getAllEmployees() async {
    final response = await supabase
        .from('employees')
        .select()
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
}