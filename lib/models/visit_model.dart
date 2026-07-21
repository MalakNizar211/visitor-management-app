class Visit {
  final String? id;
  final String visitorName;
  final String nationalId;
  final String phone;
  final DateTime visitTime;
  final String hostName;
  final String purpose;
  final String status;
  final String? createdBy;
  final DateTime? checkedInAt;
  final DateTime? checkedOutAt;
  final String? invalidReason;

  Visit({
    this.id,
    required this.visitorName,
    required this.nationalId,
    required this.phone,
    required this.visitTime,
    required this.hostName,
    required this.purpose,
    this.status = 'pending',
    this.createdBy,
    this.checkedInAt,
    this.checkedOutAt,
    this.invalidReason,
  });

  Map<String, dynamic> toMap() {
    return {
      'visitor_name': visitorName,
      'national_id': nationalId,
      'phone': phone,
      'visit_time': visitTime.toIso8601String(),
      'host_name': hostName,
      'purpose': purpose,
      'created_by': createdBy,
    };
  }

  factory Visit.fromMap(Map<String, dynamic> map) {
    return Visit(
      id: map['id'],
      visitorName: map['visitor_name'],
      nationalId: map['national_id'],
      phone: map['phone'],
      visitTime: DateTime.parse(map['visit_time']),
      hostName: map['host_name'],
      purpose: map['purpose'],
      status: map['status'],
      createdBy: map['created_by'],
      checkedInAt: map['checked_in_at'] != null
          ? DateTime.parse(map['checked_in_at'])
          : null,
      checkedOutAt: map['checked_out_at'] != null
          ? DateTime.parse(map['checked_out_at'])
          : null,
      invalidReason: map['invalid_reason'],
    );
  }
}