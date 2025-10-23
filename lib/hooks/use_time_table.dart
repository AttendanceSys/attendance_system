import 'package:supabase_flutter/supabase_flutter.dart';

/// CRUD helper for the `time_table` table.
class UseTimeTable {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Create a time_table row. `sessions` should be a JSON-serializable object.
  Future<Map<String, dynamic>> createTimeTable({
    required String facultyId,
    String? departmentId,
    String? classId,
    String? teacherId,
    String? courseId,
    required Map<String, dynamic> sessions,
  }) async {
    try {
      final row = await _supabase
          .from('time_table')
          .insert({
            'faculty_id': facultyId,
            if (departmentId != null) 'department_id': departmentId,
            if (classId != null) 'class_id': classId,
            if (teacherId != null) 'teacher_id': teacherId,
            if (courseId != null) 'course_id': courseId,
            'sessions': sessions,
          })
          .select()
          .maybeSingle();

      if (row == null) throw Exception('Insert returned null');
      return Map<String, dynamic>.from(row as Map);
    } catch (e) {
      throw Exception('Failed to create time_table row: $e');
    }
  }

  /// Fetch time_table rows with optional filters
  Future<List<Map<String, dynamic>>> fetchTimeTables({
    String? facultyId,
    String? departmentId,
    String? classId,
    String? teacherId,
    String? courseId,
    int? limit,
    int? page,
  }) async {
    try {
      var query = _supabase
          .from('time_table')
          .select(
            'id, faculty_id, department_id, class_id, teacher_id, course_id, sessions, created_at',
          );

      final dynamic q = query;
      if (facultyId != null && facultyId.isNotEmpty)
        q.eq('faculty_id', facultyId);
      if (departmentId != null && departmentId.isNotEmpty)
        q.eq('department_id', departmentId);
      if (classId != null && classId.isNotEmpty) q.eq('class_id', classId);
      if (teacherId != null && teacherId.isNotEmpty)
        q.eq('teacher_id', teacherId);
      if (courseId != null && courseId.isNotEmpty) q.eq('course_id', courseId);

      var request = query.order('created_at', ascending: false);
      if (limit != null) {
        final offset = (page ?? 0) * limit;
        request = request.range(offset, offset + limit - 1);
      }

      final resp = await request;
      final rows = resp as List? ?? [];
      return rows
          .map<Map<String, dynamic>>((r) => Map<String, dynamic>.from(r as Map))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch time_table rows: $e');
    }
  }

  /// Update a time_table row by id. Returns the updated row map.
  Future<Map<String, dynamic>> updateTimeTable({
    required String id,
    Map<String, dynamic>? sessions,
    String? facultyId,
    String? departmentId,
    String? classId,
    String? teacherId,
    String? courseId,
  }) async {
    try {
      final updateData = <String, dynamic>{
        if (sessions != null) 'sessions': sessions,
        if (facultyId != null) 'faculty_id': facultyId,
        if (departmentId != null) 'department_id': departmentId,
        if (classId != null) 'class_id': classId,
        if (teacherId != null) 'teacher_id': teacherId,
        if (courseId != null) 'course_id': courseId,
      };

      final row = await _supabase
          .from('time_table')
          .update(updateData)
          .eq('id', id)
          .select()
          .maybeSingle();

      if (row == null) throw Exception('Update returned null');
      return Map<String, dynamic>.from(row as Map);
    } catch (e) {
      throw Exception('Failed to update time_table row: $e');
    }
  }

  /// Delete a time_table row by id. Returns true on success.
  Future<bool> deleteTimeTable(String id) async {
    try {
      final resp = await _supabase.from('time_table').delete().eq('id', id);
      if (resp == null) return false;
      if (resp is List && resp.isEmpty) return false;
      return true;
    } catch (e) {
      throw Exception('Failed to delete time_table row: $e');
    }
  }
}
