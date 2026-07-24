class Employee {
  final String? id;
  final String fullName;
  final String department;
  final String? authUserId;
  final bool canBookForOthers;

  Employee({
    this.id,
    required this.fullName,
    required this.department,
    this.authUserId,
    this.canBookForOthers = false,
  });

  factory Employee.fromMap(Map<String, dynamic> map) {
    return Employee(
      id: map['id'],
      fullName: map['full_name'],
      department: map['department'],
      authUserId: map['auth_user_id'],
      canBookForOthers: map['can_book_for_others'] ?? false,
    );
  }
}