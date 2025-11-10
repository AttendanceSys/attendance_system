import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
// local resolver used to scope queries to current admin's faculty
import '../models/classes.dart';

class UseClasses {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<String?> _resolveAdminFacultyId() async {
    try {
      var current = _supabase.auth.currentUser;
      // On web/hot-reload currentUser can be null briefly; try to hydrate
      // using getUser() before giving up.
      if (current == null) {
        try {
          final ur = await _supabase.auth.getUser();
          current = ur.user;
        } catch (_) {}
      }
      if (current == null) return null;
      final authUid = current.id;

      Map<String, dynamic>? uh;
      try {
        // `user_handling` uses `username` (singular) in this project/schema.
        final res = await _supabase
            .from('user_handling')
            .select('id, username, role')
            .eq('auth_uid', authUid)
            .maybeSingle();
        if (res != null) uh = res as Map<String, dynamic>?;
      } catch (e) {
        debugPrint('user_handling auth_uid lookup failed in classes: $e');
      }
      if (uh == null) return null;
      final role = (uh['role'] ?? '').toString().trim().toLowerCase();
      if (role != 'admin') return null;

      final uhId = (uh['id'] ?? '').toString();
      final username = (uh['username'] ?? '').toString();

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

      // Enforce strict faculty scoping: if we cannot resolve a faculty id,
      // return an empty list rather than performing an un-scoped query.
      if (resolvedFacultyId == null || resolvedFacultyId.isEmpty) {
        return <SchoolClass>[];
      }

      // Request the FK `department` (id) and the nested department object
      // so the client can immediately show the human-readable department_name
      // instead of a raw uuid. PostgREST supports nested selects using the
      // `column:table(...)` syntax.
      // We'll attempt a select that requests the FK column as `department_id`
      // (the newer schema). If the DB still uses `department` as the FK name
      // the PostgREST call will error with a "column ... does not exist"
      // message; in that case we retry the select requesting `department`
      // instead. This makes the client tolerant to either schema.
      String selectWithDeptId =
          'id, class_name, department_id, department:departments(id,department_name,department_code), status, created_at';
      String selectWithDept =
          'id, class_name, department, department:departments(id,department_name,department_code), status, created_at';

      dynamic response;
      bool usedDeptId = true;

      try {
        var q = _supabase
            .from('classes')
            .select(selectWithDeptId)
            .eq('faculty_id', resolvedFacultyId)
            .order('created_at', ascending: false);
        if (limit != null) {
          final int offset = (page ?? 0) * limit;
          q = q.range(offset, offset + limit - 1);
        }
        response = await q;
      } catch (e) {
        // If the error indicates the column doesn't exist, retry with the
        // legacy `department` column name. Otherwise rethrow.
        final msg = e.toString() ?? '';
        // Some PostgREST/Postgres error messages differ between versions.
        // Accept either the 'does not exist' text or the newer
        // 'Could not find the "department_id" column' (PGRST204) message.
        if (msg.contains('department_id') &&
            (msg.contains('does not exist') ||
                msg.contains('Could not find') ||
                msg.contains('PGRST204'))) {
          usedDeptId = false;
          var q = _supabase
              .from('classes')
              .select(selectWithDept)
              .eq('faculty_id', resolvedFacultyId)
              .order('created_at', ascending: false);
          if (limit != null) {
            final int offset = (page ?? 0) * limit;
            q = q.range(offset, offset + limit - 1);
          }
          response = await q;
        } else {
          // unknown error, bubble up
          throw Exception('Failed to fetch classes: $e');
        }
      }

      return (response as List).map((e) {
        // Extract basic fields first
        final id = (e['id'] ?? '') as String;
        final name = (e['class_name'] ?? '') as String;

        // Prefer the nested department alias (human readable name). If that
        // isn't present, fall back to whichever FK column is present on the
        // row (`department_id` or `department`).
        // Prefer to store the canonical department id (UUID) in the model.
        String deptDisplay = '';
        try {
          final nested =
              e['department:departments'] ?? e['department_departments'];
          if (nested is Map) {
            // Use nested id when available so callers can compare by id.
            deptDisplay =
                (nested['id'] ??
                        nested['department_code'] ??
                        nested['department_name'] ??
                        '')
                    .toString();
          } else {
            final deptId = usedDeptId ? e['department_id'] : e['department'];
            if (deptId != null) deptDisplay = deptId.toString();
          }
        } catch (_) {
          deptDisplay = '';
        }

        return SchoolClass(
          id: id,
          name: name,
          department: deptDisplay,
          section: (e['section'] ?? '') as String,
          isActive: ((e['status'] ?? 'active') as String) == 'active',
        );
      }).toList();
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

      // Require faculty_id when creating a class to avoid global rows
      if (resolvedFacultyId == null || resolvedFacultyId.isEmpty) {
        throw Exception(
          'Cannot add class: no faculty assigned to current admin',
        );
      }

      // Try inserting into `department_id` (newer schema). If the DB
      // actually uses `department` as the column name, PostgREST will return
      // an error and we'll retry with the legacy key.
      try {
        await _supabase.from('classes').insert({
          'class_name': schoolClass.name,
          'department_id': schoolClass.department,
          'status': schoolClass.isActive ? 'active' : 'inactive',
          'faculty_id': resolvedFacultyId,
        });
      } catch (e) {
        final msg = e.toString();
        if (msg.contains('department_id') &&
            (msg.contains('does not exist') ||
                msg.contains('Could not find') ||
                msg.contains('PGRST204'))) {
          await _supabase.from('classes').insert({
            'class_name': schoolClass.name,
            'department': schoolClass.department,
            'status': schoolClass.isActive ? 'active' : 'inactive',
            'faculty_id': resolvedFacultyId,
          });
        } else {
          rethrow;
        }
      }
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
        'department_id': schoolClass.department,
        'status': schoolClass.isActive ? 'active' : 'inactive',
        'class_name': schoolClass.name,
        if (resolvedFacultyId != null && resolvedFacultyId.isNotEmpty)
          'faculty_id': resolvedFacultyId,
      };

      try {
        var query = _supabase
            .from('classes')
            .update(updatePayload)
            .eq('class_name', name);
        if (resolvedFacultyId != null && resolvedFacultyId.isNotEmpty) {
          query = (query as dynamic).eq('faculty_id', resolvedFacultyId);
        }
        await query;
      } catch (e) {
        final msg = e.toString();
        if (msg.contains('department_id') &&
            (msg.contains('does not exist') ||
                msg.contains('Could not find') ||
                msg.contains('PGRST204'))) {
          // Retry using legacy `department` column name
          final altPayload = {
            'department': schoolClass.department,
            'status': schoolClass.isActive ? 'active' : 'inactive',
            'class_name': schoolClass.name,
            if (resolvedFacultyId != null && resolvedFacultyId.isNotEmpty)
              'faculty_id': resolvedFacultyId,
          };
          var q = _supabase
              .from('classes')
              .update(altPayload)
              .eq('class_name', name);
          if (resolvedFacultyId != null && resolvedFacultyId.isNotEmpty) {
            q = (q as dynamic).eq('faculty_id', resolvedFacultyId);
          }
          await q;
        } else {
          rethrow;
        }
      }
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

      var query = _supabase.from('classes').delete().eq('class_name', name);
      if (resolvedFacultyId != null && resolvedFacultyId.isNotEmpty) {
        query = (query as dynamic).eq('faculty_id', resolvedFacultyId);
      }
      await query;
    } catch (e) {
      throw Exception('Failed to delete class: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> subscribeClasses() {
    // Return an empty stream unless caller provides a facultyId to scope by.
    // Callers should pass the resolved faculty id from login/navigation.
    return Stream<List<Map<String, dynamic>>>.value(<Map<String, dynamic>>[]);
  }

  /// Fetch classes belonging to a specific department id (UUID or string).
  /// This performs a scoped query by faculty (resolved from the current admin)
  /// and will try both `department_id` and legacy `department` column names.
  Future<List<SchoolClass>> fetchClassesByDepartmentId(
    String departmentId, {
    int? limit,
    int? page,
    String? facultyId,
  }) async {
    try {
      String? resolvedFacultyId = facultyId;
      if (resolvedFacultyId == null || resolvedFacultyId.isEmpty) {
        try {
          resolvedFacultyId = await _resolveAdminFacultyId();
        } catch (_) {}
      }

      if (resolvedFacultyId == null || resolvedFacultyId.isEmpty) {
        return <SchoolClass>[];
      }

      String selectWithDeptId =
          'id, class_name, department_id, department:departments(id,department_name,department_code), status, created_at';
      String selectWithDept =
          'id, class_name, department, department:departments(id,department_name,department_code), status, created_at';

      dynamic response;
      bool usedDeptId = true;
      try {
        var q = _supabase
            .from('classes')
            .select(selectWithDeptId)
            .eq('department_id', departmentId)
            .eq('faculty_id', resolvedFacultyId)
            .order('created_at', ascending: false);
        debugPrint(
          '[UseClasses.fetchClassesByDepartmentId] Querying classes by department_id=$departmentId faculty_id=$resolvedFacultyId',
        );
        if (limit != null) {
          final int offset = (page ?? 0) * limit;
          q = q.range(offset, offset + limit - 1);
        }
        response = await q;
        debugPrint(
          '[UseClasses.fetchClassesByDepartmentId] raw response length: ${response is List ? (response).length : 0}',
        );
      } catch (e) {
        final msg = e.toString();
        if (msg.contains('does not exist') && msg.contains('department_id')) {
          usedDeptId = false;
          var q = _supabase
              .from('classes')
              .select(selectWithDept)
              .eq('department', departmentId)
              .eq('faculty_id', resolvedFacultyId)
              .order('created_at', ascending: false);
          debugPrint(
            '[UseClasses.fetchClassesByDepartmentId] department_id not present, retrying with legacy column department=$departmentId faculty_id=$resolvedFacultyId',
          );
          if (limit != null) {
            final int offset = (page ?? 0) * limit;
            q = q.range(offset, offset + limit - 1);
          }
          response = await q;
          debugPrint(
            '[UseClasses.fetchClassesByDepartmentId] legacy response length: ${response is List ? (response).length : 0}',
          );
        } else {
          throw Exception('Failed to fetch classes by department: $e');
        }
      }

      return (response as List).map((e) {
        final id = (e['id'] ?? '') as String;
        final name = (e['class_name'] ?? '') as String;

        // Prefer to store the canonical department id (UUID) in the model.
        String deptDisplay = '';
        try {
          final nested =
              e['department:departments'] ?? e['department_departments'];
          if (nested is Map) {
            deptDisplay =
                (nested['id'] ??
                        nested['department_code'] ??
                        nested['department_name'] ??
                        '')
                    .toString();
          } else {
            final deptId = usedDeptId ? e['department_id'] : e['department'];
            if (deptId != null) deptDisplay = deptId.toString();
          }
        } catch (_) {
          deptDisplay = '';
        }

        return SchoolClass(
          id: id,
          name: name,
          department: deptDisplay,
          section: (e['section'] ?? '') as String,
          isActive: ((e['status'] ?? 'active') as String) == 'active',
        );
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch classes by department: $e');
    }
  }
}
