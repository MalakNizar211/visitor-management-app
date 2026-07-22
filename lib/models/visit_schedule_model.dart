class VisitSchedule {
  final String? id;
  final String? visitId;
  final DateTime scheduledDate;
  final String startTime; // stored as 'HH:mm:ss' string, matches Postgres 'time' type
  final String endTime;   // stored as 'HH:mm:ss' string, matches Postgres 'time' type

  VisitSchedule({
    this.id,
    this.visitId,
    required this.scheduledDate,
    required this.startTime,
    required this.endTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'visit_id': visitId,
      'scheduled_date':
      '${scheduledDate.year.toString().padLeft(4, '0')}-${scheduledDate.month.toString().padLeft(2, '0')}-${scheduledDate.day.toString().padLeft(2, '0')}',
      'start_time': startTime,
      'end_time': endTime,
    };
  }

  factory VisitSchedule.fromMap(Map<String, dynamic> map) {
    return VisitSchedule(
      id: map['id'],
      visitId: map['visit_id'],
      scheduledDate: DateTime.parse(map['scheduled_date']),
      startTime: map['start_time'],
      endTime: map['end_time'],
    );
  }

  // Combines scheduledDate with startTime/endTime into full DateTime objects -
  // useful for comparisons (e.g. "has this window started/ended yet").
  DateTime get scheduledStart => _combine(startTime);
  DateTime get scheduledEnd => _combine(endTime);

  DateTime _combine(String timeStr) {
    final parts = timeStr.split(':'); // e.g. "15:30:00" -> ["15","30","00"]
    return DateTime(
      scheduledDate.year,
      scheduledDate.month,
      scheduledDate.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }
}