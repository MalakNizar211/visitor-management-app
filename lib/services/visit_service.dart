import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/visit_model.dart';
import '../models/visit_schedule_model.dart';

class VisitService {
  final supabase = Supabase.instance.client;

  // Creates one visit (one QR) plus all its scheduled dates in one go
  Future<Visit> createVisitWithSchedules(
      Visit visit,
      List<VisitSchedule> schedules,
      ) async {
    final userId = supabase.auth.currentUser!.id;
    final visitData = visit.toMap();
    visitData['created_by'] = userId;

    final visitResponse = await supabase
        .from('visits')
        .insert(visitData)
        .select()
        .single();

    final createdVisit = Visit.fromMap(visitResponse);

    final scheduleRows = schedules.map((s) {
      final map = s.toMap();
      map['visit_id'] = createdVisit.id;
      return map;
    }).toList();

    await supabase.from('visit_schedules').insert(scheduleRows);

    return createdVisit;
  }

  // Fetch a single visit by id - used right after scanning a QR
  Future<Visit?> getVisitById(String id) async {
    final response = await supabase
        .from('visits')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return Visit.fromMap(response);
  }

  // Updates editable fields on a visit (purpose, floor, room, host_id, etc.)
  // Pass only the fields that changed, e.g. {'purpose': 'Meeting', 'floor': '3'}
  Future<Visit?> updateVisit(String id, Map<String, dynamic> updates) async {
    final response = await supabase
        .from('visits')
        .update(updates)
        .eq('id', id)
        .select()
        .maybeSingle();

    if (response == null) return null;
    return Visit.fromMap(response);
  }

  // Updates a single schedule row (date, start_time, end_time) by its own id.
  // Use this when HR edits an existing scheduled date from the edit modal.
  Future<VisitSchedule?> updateSchedule(
      String scheduleId, Map<String, dynamic> updates) async {
    final response = await supabase
        .from('visit_schedules')
        .update(updates)
        .eq('id', scheduleId)
        .select()
        .maybeSingle();

    if (response == null) return null;
    return VisitSchedule.fromMap(response);
  }

  // Creates an additional schedule row while HR edits a visit.
  Future<VisitSchedule> createSchedule(
      String visitId,
      Map<String, dynamic> scheduleData,
      ) async {
    final data = Map<String, dynamic>.from(scheduleData);
    data['visit_id'] = visitId;

    final response = await supabase
        .from('visit_schedules')
        .insert(data)
        .select()
        .single();

    return VisitSchedule.fromMap(response);
  }

  // Removes a schedule row when HR deletes it from the edit screen.
  Future<void> deleteSchedule(String scheduleId) async {
    await supabase
        .from('visit_schedules')
        .delete()
        .eq('id', scheduleId);
  }

  // Fetch all scheduled dates for a given visit
  Future<List<VisitSchedule>> getSchedulesForVisit(String visitId) async {
    final response = await supabase
        .from('visit_schedules')
        .select()
        .eq('visit_id', visitId)
        .order('scheduled_date', ascending: true);

    return (response as List).map((s) => VisitSchedule.fromMap(s)).toList();
  }

  // Checks whether today matches one of this visit's scheduled dates
  Future<VisitSchedule?> getTodaysSchedule(String visitId) async {
    final today = DateTime.now();
    final todayStr =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    final response = await supabase
        .from('visit_schedules')
        .select()
        .eq('visit_id', visitId)
        .eq('scheduled_date', todayStr)
        .maybeSingle();

    if (response == null) return null;
    return VisitSchedule.fromMap(response);
  }

  // Looks at TODAY's most recent log entry only. This matters because the
  // same QR/visit can be reused on a later scheduled day - if we looked at
  // the all-time last log, a visit that ended (checked out) on day 1 would
  // look identical to one that hasn't started yet on day 2.
  Future<String?> getTodaysLatestLogAction(String visitId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day).toUtc();
    final startOfNextDay = startOfDay.add(const Duration(days: 1));

    final response = await supabase
        .from('visit_logs')
        .select()
        .eq('visit_id', visitId)
        .gte('scanned_at', startOfDay.toIso8601String())
        .lt('scanned_at', startOfNextDay.toIso8601String())
        .order('scanned_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response == null) return null;
    return response['action'];
  }

  // Single source of truth for "what should scanning this QR do right now".
  // Returns one of: 'check_in', 'check_out', 'completed'.
  // 'completed' means both check-in AND check-out already happened today -
  // no further action allowed until the next scheduled day.
  Future<String> getTodaysStatus(String visitId) async {
    final lastAction = await getTodaysLatestLogAction(visitId);

    if (lastAction == null) return 'check_in';
    if (lastAction == 'check_in') return 'check_out';
    return 'completed';
  }

  // For the security "records" search page: everyone with any check-in or
  // check-out activity on a given calendar day (local day, converted to UTC
  // for the query), with check-in AND check-out time shown side by side.
  Future<List<Map<String, dynamic>>> getVisitRecordsForDate(DateTime date) async {
    final startOfDay = DateTime(date.year, date.month, date.day).toUtc();
    final startOfNextDay = startOfDay.add(const Duration(days: 1));

    final logsResponse = await supabase
        .from('visit_logs')
        .select()
        .gte('scanned_at', startOfDay.toIso8601String())
        .lt('scanned_at', startOfNextDay.toIso8601String())
        .order('scanned_at', ascending: true);

    final logs = (logsResponse as List).cast<Map<String, dynamic>>();
    if (logs.isEmpty) return [];

    final visitIds = logs.map((l) => l['visit_id'] as String).toSet().toList();

    final visitsResponse = await supabase
        .from('visits')
        .select('*, visitors(*), employees(*)')
        .inFilter('id', visitIds);

    final visits = (visitsResponse as List).cast<Map<String, dynamic>>();
    final Map<String, Map<String, dynamic>> visitById = {
      for (final v in visits) v['id'] as String: v,
    };

    // Group logs by visit_id, picking out check-in and check-out times.
    // If a visit somehow has more than one check-in/check-out on the same
    // day, this keeps the first check-in and the last check-out.
    final Map<String, Map<String, dynamic>> recordsByVisit = {};
    for (final log in logs) {
      final visitId = log['visit_id'] as String;
      final record = recordsByVisit.putIfAbsent(visitId, () => {
        'visit_id': visitId,
        'check_in_time': null,
        'check_out_time': null,
      });

      if (log['action'] == 'check_in' && record['check_in_time'] == null) {
        record['check_in_time'] = log['scanned_at'];
      } else if (log['action'] == 'check_out') {
        record['check_out_time'] = log['scanned_at'];
      }
    }

    final records = <Map<String, dynamic>>[];
    for (final entry in recordsByVisit.entries) {
      final visit = visitById[entry.key];
      if (visit == null) continue;

      final visitorInfo = visit['visitors'] as Map<String, dynamic>?;
      final employeeInfo = visit['employees'] as Map<String, dynamic>?;

      records.add({
        'visit_id': entry.key,
        'full_name': visitorInfo?['full_name'],
        'national_id': visitorInfo?['national_id'],
        'phone': visitorInfo?['phone'],
        'host_name': employeeInfo?['full_name'],
        'purpose': visit['purpose'],
        'check_in_time': entry.value['check_in_time'],
        'check_out_time': entry.value['check_out_time'],
      });
    }

    records.sort((a, b) {
      final aTime = a['check_in_time'] as String? ?? '';
      final bTime = b['check_in_time'] as String? ?? '';
      return aTime.compareTo(bTime);
    });

    return records;
  }

  Future<void> checkIn(String visitId) async {
    await supabase.from('visit_logs').insert({
      'visit_id': visitId,
      'action': 'check_in',
    });
  }

  Future<void> checkOut(String visitId) async {
    await supabase.from('visit_logs').insert({
      'visit_id': visitId,
      'action': 'check_out',
    });
  }

  Future<Visit?> markInvalid(String id, String reason) async {
    final response = await supabase
        .from('visits')
        .update({
      'status': 'invalid',
      'invalid_reason': reason,
    })
        .eq('id', id)
        .neq('status', 'invalid')
        .select()
        .maybeSingle();

    if (response == null) return null;
    return Visit.fromMap(response);
  }

  // For the HR dashboard: visits created by this HR user, with visitor + employee info joined in
  Future<List<Map<String, dynamic>>> getMyVisitsWithVisitors() async {
    final userId = supabase.auth.currentUser!.id;

    final response = await supabase
        .from('visits')
        .select('*, visitors(*), employees(*), visit_schedules(*)')
        .eq('created_by', userId)
        .order('created_at', ascending: false);

    return (response as List).cast<Map<String, dynamic>>();
  }

  // For the security dashboard: everyone currently inside the building
  Future<List<Map<String, dynamic>>> getCurrentlyInBuilding() async {
    final visitsResponse = await supabase
        .from('visits')
        .select('*, visitors(*), employees(*)')
        .eq('status', 'active');

    final visits = (visitsResponse as List).cast<Map<String, dynamic>>();

    if (visits.isEmpty) return [];

    final visitIds = visits.map((v) => v['id'] as String).toList();

    final logsResponse = await supabase
        .from('visit_logs')
        .select()
        .inFilter('visit_id', visitIds)
        .order('scanned_at', ascending: false);

    final logs = (logsResponse as List).cast<Map<String, dynamic>>();

    final Map<String, Map<String, dynamic>> latestLogByVisit = {};
    for (final log in logs) {
      final visitId = log['visit_id'] as String;
      if (!latestLogByVisit.containsKey(visitId)) {
        latestLogByVisit[visitId] = log;
      }
    }

    final currentlyIn = <Map<String, dynamic>>[];
    for (final visit in visits) {
      final visitId = visit['id'] as String;
      final latestLog = latestLogByVisit[visitId];

      if (latestLog != null && latestLog['action'] == 'check_in') {
        final visitorInfo = visit['visitors'] as Map<String, dynamic>?;
        final employeeInfo = visit['employees'] as Map<String, dynamic>?;
        currentlyIn.add({
          'visit_id': visit['id'],
          'visitor_id': visitorInfo?['id'],
          'full_name': visitorInfo?['full_name'],
          'national_id': visitorInfo?['national_id'],
          'phone': visitorInfo?['phone'],
          'host_name': employeeInfo?['full_name'],
          'purpose': visit['purpose'],
          'last_check_in': latestLog['scanned_at'],
        });
      }
    }

    return currentlyIn;
  }
}