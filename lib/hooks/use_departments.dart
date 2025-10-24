import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
// ...existing code...
import '../models/department.dart';

class UseDepartments {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<String?> _resolveAdminFacultyId() async {
    try {
      final current = _supabase.auth.currentUser;
      if (current == null) return null;
      final authUid = current.id;

      Map<String, dynamic>? uh;
      try {
        final res = await _supabase
            .from('user_handling')
            .select('id, usernames, role')
            .eq('auth_uid', authUid)
            .maybeSingle();
        if (res != null) uh = res as Map<String, dynamic>?;
      } catch (e) {
        debugPrint('user_handling auth_uid lookup failed in departments: $e');
      }
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

  Future<List<Department>> fetchDepartments({
    int? limit,
    int? page,
    String? facultyId,
  }) async {
    try {
      // If facultyId not provided, try to resolve current admin's faculty
      String? resolvedFacultyId = facultyId;
      if (resolvedFacultyId == null || resolvedFacultyId.isEmpty) {
        try {
          resolvedFacultyId = await _resolveAdminFacultyId();
        } catch (_) {}
      }

      var query = _supabase
          .from('departments')
          .select(
            'id, department_name, department_code, head_of_department, status, created_at, faculty_id, faculty:faculties(id,faculty_name)',
          )
          .order('created_at', ascending: false);

      // allow calling .eq/.range on the transform builder dynamically
      final dynamic builder = query;
      if (resolvedFacultyId != null && resolvedFacultyId.isNotEmpty) {
        // include departments specifically for the faculty OR global (faculty_id IS NULL)
        // PostgREST 'or' clause: (faculty_id.eq.<id>,faculty_id.is.null)
        try {
          query = _supabase
              .from('departments')
              .select(
                'id, department_name, department_code, head_of_department, status, created_at',
              )
              .or('faculty_id.eq.${resolvedFacultyId},faculty_id.is.null')
              .order('created_at', ascending: false);
        } catch (_) {
          // fallback to simple eq if 'or' isn't supported in this environment
          builder.eq('faculty_id', resolvedFacultyId);
        }
      }

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
            'id, department_name, department_code, head_of_department, status, created_at, faculty_id, faculty:faculties(id,faculty_name)',
          )
          .eq('head_of_department', teacherId)
          .maybeSingle();

      if (response == null) return null;

      final e = response;
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

  Future<void> addDepartment(Department department, {String? facultyId}) async {
    try {
      // server-side guard: ensure teacher isn't already head elsewhere
      if (department.head.isNotEmpty) {
        final existing = await findDepartmentByHead(department.head);
        if (existing != null) {
          throw Exception(
            'Teacher is already head of department: ${existing.name} (${existing.code})',
          );
        }
      }

      String? resolvedFacultyId = facultyId;
      if (resolvedFacultyId == null || resolvedFacultyId.isEmpty) {
        try {
          resolvedFacultyId = await _resolveAdminFacultyId();
        } catch (_) {}
      }

      await _supabase.from('departments').insert({
        'department_name': department.name,
        'department_code': department.code,
        'head_of_department': department.head,
        'status': department.status,
        if (resolvedFacultyId != null && resolvedFacultyId.isNotEmpty)
          'faculty_id': resolvedFacultyId,
      });
    } catch (e) {
      throw Exception('Failed to add department: $e');
    }
  }

  Future<void> updateDepartment(
    String code,
    Department department, {
    String? facultyId,
  }) async {
    try {
      // server-side guard: if teacher is assigned as a head to another department, disallow
      if (department.head.isNotEmpty) {
        final existing = await findDepartmentByHead(department.head);
        if (existing != null && existing.code != code) {
          throw Exception(
            'Teacher is already head of department: ${existing.name} (${existing.code})',
          );
        }
      }

      String? resolvedFacultyId = facultyId;
      if (resolvedFacultyId == null || resolvedFacultyId.isEmpty) {
        try {
          resolvedFacultyId = await _resolveAdminFacultyId();
        } catch (_) {}
      }

      final Map<String, dynamic> updatePayload = {
        'department_name': department.name,
        'head_of_department': department.head,
        'status': department.status,
        'department_code': department.code,
        if (resolvedFacultyId != null && resolvedFacultyId.isNotEmpty)
          'faculty_id': resolvedFacultyId,
      };

      await _supabase
          .from('departments')
          .update(updatePayload)
          .eq('department_code', code);
    } catch (e) {
      throw Exception('Failed to update department: $e');
    }
  }

  Future<void> deleteDepartment(String code) async {
    try {
      // If possible, scope deletion to the current admin's faculty to avoid cross-faculty deletes
      String? resolvedFacultyId;
      try {
        resolvedFacultyId = await _resolveAdminFacultyId();
      } catch (_) {}

      final builder = _supabase
          .from('departments')
          .delete()
          .eq('department_code', code);
      if (resolvedFacultyId != null && resolvedFacultyId.isNotEmpty) {
        builder.eq('faculty_id', resolvedFacultyId);
      }
      await builder;
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
