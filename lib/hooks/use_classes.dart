import 'package:supabase_flutter/supabase_flutter.dart';
// local resolver used to scope queries to current admin's faculty
import '../models/classes.dart';

class UseClasses {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<String?> _resolveAdminFacultyId() async {
    try {
      final current = _supabase.auth.currentUser;
      if (current == null) return null;
      final authUid = current.id;

      final uh = await _supabase
          .from('user_handling')
          .select('id, usernames, role')
          .eq('auth_uid', authUid)
          .maybeSingle();
      if (uh == null) return null;
      final role = (uh['role'] ?? '').toString().trim().toLowerCase();
      if (role != 'admin') return null;

      final uhId = (uh['id'] ?? '').toString();
      final username = (uh['usernames'] ?? '').toString();

      Map<String, dynamic>? adminRow;
      if (uhId.isNotEmpty) {
        final ar = await _supabase
            .from('admins')
            .select(
              'faculty_id, faculty_name, user_handling_id, user_id, username',
            )
            .eq('user_handling_id', uhId)
            .maybeSingle();
        if (ar != null) adminRow = ar;
      }
      if (adminRow == null && username.isNotEmpty) {
        final ar2 = await _supabase
            .from('admins')
            .select(
              'faculty_id, faculty_name, user_handling_id, user_id, username',
            )
            .eq('username', username)
            .maybeSingle();
        if (ar2 != null) adminRow = ar2;
      }
      if (adminRow == null) return null;
      final facultyId = (adminRow['faculty_id'] ?? '').toString();
      if (facultyId.isNotEmpty) return facultyId;
      final facultyName = (adminRow['faculty_name'] ?? '').toString();
      if (facultyName.isNotEmpty) {
        final f = await _supabase
            .from('faculties')
            .select('id')
            .eq('faculty_name', facultyName)
            .maybeSingle();
        if (f != null && f['id'] != null) return f['id'].toString();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<List<SchoolClass>> fetchClasses({
    int? limit,
    int? page,
    String? facultyId,
  }) async {
    try {
      // resolve faculty id from current admin if not provided
      String? resolvedFacultyId = facultyId;
      if (resolvedFacultyId == null || resolvedFacultyId.isEmpty) {
        try {
          resolvedFacultyId = await _resolveAdminFacultyId();
        } catch (_) {}
      }

      var query = _supabase
          .from('classes')
          .select('id, class_name, department, status, created_at')
          .order('created_at', ascending: false);

      final dynamic builder = query;
      if (resolvedFacultyId != null && resolvedFacultyId.isNotEmpty) {
        builder.eq('faculty_id', resolvedFacultyId);
      }

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

  Future<void> addClass(SchoolClass schoolClass, {String? facultyId}) async {
    try {
      String? resolvedFacultyId = facultyId;
      if (resolvedFacultyId == null || resolvedFacultyId.isEmpty) {
        try {
          resolvedFacultyId = await _resolveAdminFacultyId();
        } catch (_) {}
      }

      await _supabase.from('classes').insert({
        'class_name': schoolClass.name,
        'department': schoolClass.department,
        'status': schoolClass.isActive ? 'active' : 'inactive',
        if (resolvedFacultyId != null && resolvedFacultyId.isNotEmpty)
          'faculty_id': resolvedFacultyId,
      });
    } catch (e) {
      throw Exception('Failed to add class: $e');
    }
  }

  Future<void> updateClass(
    String name,
    SchoolClass schoolClass, {
    String? facultyId,
  }) async {
    try {
      String? resolvedFacultyId = facultyId;
      if (resolvedFacultyId == null || resolvedFacultyId.isEmpty) {
        try {
          resolvedFacultyId = await _resolveAdminFacultyId();
        } catch (_) {}
      }

      final updatePayload = {
        'department': schoolClass.department,
        'status': schoolClass.isActive ? 'active' : 'inactive',
        'class_name': schoolClass.name,
        if (resolvedFacultyId != null && resolvedFacultyId.isNotEmpty)
          'faculty_id': resolvedFacultyId,
      };

      final builder = _supabase
          .from('classes')
          .update(updatePayload)
          .eq('class_name', name);
      if (resolvedFacultyId != null && resolvedFacultyId.isNotEmpty)
        builder.eq('faculty_id', resolvedFacultyId);
      await builder;
    } catch (e) {
      throw Exception('Failed to update class: $e');
    }
  }

  Future<void> deleteClass(String name) async {
    try {
      String? resolvedFacultyId;
      try {
        resolvedFacultyId = await _resolveAdminFacultyId();
      } catch (_) {}

      final builder = _supabase.from('classes').delete().eq('class_name', name);
      if (resolvedFacultyId != null && resolvedFacultyId.isNotEmpty)
        builder.eq('faculty_id', resolvedFacultyId);
      await builder;
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
