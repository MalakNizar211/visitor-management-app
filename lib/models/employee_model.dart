class Employee {
  final String? id;
  final String fullName;
  final String department;

  Employee({
    this.id,
    required this.fullName,
    required this.department,
  });

  factory Employee.fromMap(Map<String, dynamic> map) {
    return Employee(
      id: map['id'],
      fullName: map['full_name'],
      department: map['department'],
    );
  }
}