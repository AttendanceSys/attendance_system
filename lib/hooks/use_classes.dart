import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/classes.dart';

class UseClasses {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<SchoolClass>> fetchClasses({int? limit, int? page}) async {
    try {
      var query = _supabase
          .from('classes')
          .select('id, class_name, department, status, created_at')
          .order('created_at', ascending: false);

      if (limit != null) {
        final int offset = (page ?? 0) * limit;
        query = query.range(offset, offset + limit - 1);
      }

      final response = await query;
      return (response as List)
          .map(
            (e) => SchoolClass(
              id: (e['id'] ?? '') as String,
              name: (e['class_name'] ?? '') as String,
              department: (e['department'] ?? '') as String,
              section: (e['section'] ?? '') as String,
              isActive: ((e['status'] ?? 'active') as String) == 'active',
            ),
          )
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch classes: $e');
    }
  }

  Future<void> addClass(SchoolClass schoolClass) async {
    try {
      await _supabase.from('classes').insert({
        'class_name': schoolClass.name,
        'department': schoolClass.department,
        'status': schoolClass.isActive ? 'active' : 'inactive',
      });
    } catch (e) {
      throw Exception('Failed to add class: $e');
    }
  }

  Future<void> updateClass(String name, SchoolClass schoolClass) async {
    try {
      await _supabase
          .from('classes')
          .update({
            'department': schoolClass.department,
            'status': schoolClass.isActive ? 'active' : 'inactive',
            'class_name': schoolClass.name,
          })
          .eq('class_name', name);
    } catch (e) {
      throw Exception('Failed to update class: $e');
    }
  }

  Future<void> deleteClass(String name) async {
    try {
      await _supabase.from('classes').delete().eq('class_name', name);
    } catch (e) {
      throw Exception('Failed to delete class: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> subscribeClasses() {
    return _supabase
        .from('classes')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }
}
