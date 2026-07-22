class Visit {
  final String? id;
  final String? visitorId;
  final String? hostId;
  final String purpose;
  final String? floor;
  final String? room;
  final String status;
  final String? invalidReason;
  final String? createdBy;

  Visit({
    this.id,
    this.visitorId,
    this.hostId,
    required this.purpose,
    this.floor,
    this.room,
    this.status = 'active',
    this.invalidReason,
    this.createdBy,
  });

  Map<String, dynamic> toMap() {
    return {
      'visitor_id': visitorId,
      'host_id': hostId,
      'purpose': purpose,
      'floor': floor,
      'room': room,
      'created_by': createdBy,
    };
  }

  factory Visit.fromMap(Map<String, dynamic> map) {
    return Visit(
      id: map['id'],
      visitorId: map['visitor_id'],
      hostId: map['host_id'],
      purpose: map['purpose'],
      floor: map['floor'],
      room: map['room'],
      status: map['status'],
      invalidReason: map['invalid_reason'],
      createdBy: map['created_by'],
    );
  }
}