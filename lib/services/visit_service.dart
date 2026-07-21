import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/visit_model.dart';

class VisitService {
  final supabase = Supabase.instance.client;

  Future<Visit> createVisit(Visit visit) async {
    final response = await supabase
        .from('visits')
        .insert(visit.toMap())
        .select()
        .single();

    return Visit.fromMap(response);
  }

  Future<List<Visit>> getMyVisits({int page = 0, int pageSize = 20}) async {
    final userId = supabase.auth.currentUser!.id;
    final from = page * pageSize;
    final to = from + pageSize - 1;

    final response = await supabase
        .from('visits')
        .select()
        .eq('created_by', userId)
        .order('created_at', ascending: false)
        .range(from, to);

    return (response as List).map((v) => Visit.fromMap(v)).toList();
  }


  Future<Visit?> getVisitById(String id) async {
    final response = await supabase
        .from('visits')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return Visit.fromMap(response);
  }


  Future<Visit?> checkIn(String id) async {
    final response = await supabase
        .from('visits')
        .update({
      'status': 'checked_in',
      'checked_in_at': DateTime.now().toIso8601String(),
    })
        .eq('id', id)
        .eq('status', 'pending')
        .select()
        .maybeSingle();

    if (response == null) return null;
    return Visit.fromMap(response);
  }


  Future<Visit?> checkOut(String id) async {
    final response = await supabase
        .from('visits')
        .update({
      'status': 'checked_out',
      'checked_out_at': DateTime.now().toIso8601String(),
    })
        .eq('id', id)
        .eq('status', 'checked_in')
        .select()
        .maybeSingle();

    if (response == null) return null;
    return Visit.fromMap(response);
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

  Future<List<Visit>> getCurrentlyInBuilding() async {
    final response = await supabase
        .from('visits')
        .select()
        .eq('status', 'checked_in')
        .order('checked_in_at', ascending: false);

    return (response as List).map((v) => Visit.fromMap(v)).toList();
  }
}