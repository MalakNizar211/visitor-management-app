import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/visitor_model.dart';

class VisitorService {
  final supabase = Supabase.instance.client;

  // Fetch a single visitor by their id - needed to show name/national ID/phone on the verification screen
  Future<Visitor?> getVisitorById(String id) async {
    final response = await supabase
        .from('visitors')
        .select()
        .eq('id', id)
        .maybeSingle();

    if (response == null) return null;
    return Visitor.fromMap(response);
  }

  // Fetches all registered visitors - powers the dropdown in the New Visitor form
  Future<List<Visitor>> getAllVisitors() async {
    final response = await supabase
        .from('visitors')
        .select()
        .order('full_name', ascending: true);

    return (response as List).map((v) => Visitor.fromMap(v)).toList();
  }

  // Creates a brand new visitor - used when HR picks "New Visitor" instead of an existing one
  Future<Visitor> createVisitor(Visitor visitor) async {
    final userId = supabase.auth.currentUser!.id;
    final data = visitor.toMap();
    data['created_by'] = userId;

    final response = await supabase
        .from('visitors')
        .insert(data)
        .select()
        .single();

    return Visitor.fromMap(response);
  }

}