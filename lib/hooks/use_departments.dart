import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/department.dart';

class UseDepartments {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Department>> fetchDepartments({int? limit, int? page}) async {
    try {
      var query = _supabase
          .from('departments')
          .select(
            'id, department_name, department_code, head_of_department, status, created_at',
          )
          .order('created_at', ascending: false);

      if (limit != null) {
        final int offset = (page ?? 0) * limit;
        query = query.range(offset, offset + limit - 1);
      }

      final response = await query;
      return (response as List)
          .map(
            (e) => Department(
              id: (e['id'] ?? '') as String,
              code: (e['department_code'] ?? '') as String,
              name: (e['department_name'] ?? '') as String,
              head: (e['head_of_department'] ?? '') as String,
              status: (e['status'] ?? '') as String,
            ),
          )
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch departments: $e');
    }
  }

  /// Returns the Department where [teacherId] is head, or null if none.
  Future<Department?> findDepartmentByHead(String teacherId) async {
    try {
      if (teacherId.isEmpty) return null;
      final response = await _supabase
          .from('departments')
          .select(
            'id, department_name, department_code, head_of_department, status, created_at',
          )
          .eq('head_of_department', teacherId)
          .maybeSingle();

      if (response == null) return null;

      final e = response as Map<String, dynamic>;
      return Department(
        id: (e['id'] ?? '') as String,
        code: (e['department_code'] ?? '') as String,
        name: (e['department_name'] ?? '') as String,
        head: (e['head_of_department'] ?? '') as String,
        status: (e['status'] ?? '') as String,
      );
    } catch (e) {
      throw Exception('Failed to query department by head: $e');
    }
  }

  Future<void> addDepartment(Department department) async {
    try {
      // server-side guard: ensure teacher isn't already head elsewhere
      if (department.head.isNotEmpty) {
        final existing = await findDepartmentByHead(department.head);
        if (existing != null) {
          throw Exception(
              'Teacher is already head of department: ${existing.name} (${existing.code})');
        }
      }

      await _supabase.from('departments').insert({
        'department_name': department.name,
        'department_code': department.code,
        'head_of_department': department.head,
        'status': department.status,
      });
    } catch (e) {
      throw Exception('Failed to add department: $e');
    }
  }

  Future<void> updateDepartment(String code, Department department) async {
    try {
      // server-side guard: if teacher is assigned as a head to another department, disallow
      if (department.head.isNotEmpty) {
        final existing = await findDepartmentByHead(department.head);
        if (existing != null && existing.code != code) {
          throw Exception(
              'Teacher is already head of department: ${existing.name} (${existing.code})');
        }
      }

      await _supabase
          .from('departments')
          .update({
            'department_name': department.name,
            'head_of_department': department.head,
            'status': department.status,
            'department_code': department.code,
          })
          .eq('department_code', code);
    } catch (e) {
      throw Exception('Failed to update department: $e');
    }
  }

  Future<void> deleteDepartment(String code) async {
    try {
      await _supabase.from('departments').delete().eq('department_code', code);
    } catch (e) {
      throw Exception('Failed to delete department: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> subscribeDepartments() {
    return _supabase
        .from('departments')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }
}