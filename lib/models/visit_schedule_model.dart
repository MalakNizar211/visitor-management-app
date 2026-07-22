class VisitSchedule {
  final String? id;
  final String? visitId;
  final DateTime scheduledDate;
  final String scheduledTime; // stored as 'HH:mm:ss' string, matches Postgres 'time' type

  VisitSchedule({
    this.id,
    this.visitId,
    required this.scheduledDate,
    required this.scheduledTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'visit_id': visitId,
      'scheduled_date':
      '${scheduledDate.year.toString().padLeft(4, '0')}-${scheduledDate.month.toString().padLeft(2, '0')}-${scheduledDate.day.toString().padLeft(2, '0')}',
      'scheduled_time': scheduledTime,
    };
  }

  factory VisitSchedule.fromMap(Map<String, dynamic> map) {
    return VisitSchedule(
      id: map['id'],
      visitId: map['visit_id'],
      scheduledDate: DateTime.parse(map['scheduled_date']),
      scheduledTime: map['scheduled_time'],
    );
  }

  // Combines the date and time into one DateTime object - useful for comparisons later
  DateTime get scheduledDateTime {
    final parts = scheduledTime.split(':'); // e.g. "15:30:00" -> ["15","30","00"]
    return DateTime(
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }
}