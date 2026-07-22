class Visitor {
  final String? id;
  final String fullName;
  final String nationalId;
  final String phone;
  final String? createdBy;

  Visitor({
    this.id,
    required this.fullName,
    required this.nationalId,
    required this.phone,
    this.createdBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'full_name': fullName,
      'national_id': nationalId,
      'phone': phone,
      'created_by': createdBy,
    };
  }

  factory Visitor.fromMap(Map<String, dynamic> map) {
    return Visitor(
      id: map['id'],
      fullName: map['full_name'],
      nationalId: map['national_id'],
      phone: map['phone'],
      createdBy: map['created_by'],
    );
  }
}