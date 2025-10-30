import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
// ...existing code...
import '../models/department.dart';

class UseDepartments {
  final SupabaseClient _supabase = Supabase.instance.client;
  // Cache the last-resolved faculty id when fetchDepartments is called with
  // an explicit facultyId. This helps pages that attempt to resolve the
  // faculty id later (e.g., ClassesPage) avoid races by using the cached
  // value if available.
  static String? _cachedFacultyId;

  Future<String?> _resolveAdminFacultyId() async {
    try {
      var current = _supabase.auth.currentUser;
      // If currentUser is null (web init/race), try the async getter as a fallback.
      if (current == null) {
        try {
          final userResp = await _supabase.auth.getUser();
          current = userResp.user;
        } catch (_) {
          // ignore - fallback to null
        }
      }
      if (current == null) return null;
      final authUid = current.id;

      Map<String, dynamic>? uh;
      try {
        // 1) Try lookup by auth_uid (older schema)
        final res = await _supabase
            .from('user_handling')
            .select('id, username, role, faculty_id')
            .eq('auth_uid', authUid)
            .maybeSingle();
        if (res != null) uh = res as Map<String, dynamic>?;
      } catch (e) {
        debugPrint('user_handling auth_uid lookup failed in departments: $e');
      }

      // 2) Fallbacks: some schemas store the login identity in `username`.
      // Try matching by current.email or current.id if we didn't find a row above.
      if (uh == null) {
        try {
          if (current.email != null && current.email!.isNotEmpty) {
            final res2 = await _supabase
                .from('user_handling')
                .select('id, username, role, faculty_id')
                .eq('username', current.email!)
                .maybeSingle();
            if (res2 != null) uh = res2 as Map<String, dynamic>?;
          }
        } catch (e) {
          debugPrint('user_handling username (email) lookup failed: $e');
        }
      }
      if (uh == null) {
        try {
          // try using auth uid as username (some setups store auth id in username)
          final res3 = await _supabase
              .from('user_handling')
              .select('id, username, role, faculty_id')
              .eq('username', authUid)
              .maybeSingle();
          if (res3 != null) uh = res3 as Map<String, dynamic>?;
        } catch (e) {
          debugPrint('user_handling username (authUid) lookup failed: $e');
        }
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

  /// Public wrapper to resolve the current admin's faculty id.
  /// Returns null if it cannot be resolved.
  /// Public wrapper to resolve the current admin's faculty id.
  /// This will retry a few times with a short delay to accommodate cases
  /// where auth/user state isn't immediately available (web hot-reload/startup).
  Future<String?> resolveAdminFacultyId({
    int attempts = 5,
    Duration delay = const Duration(milliseconds: 300),
  }) async {
    // Prefer a previously-cached faculty id if present.
    if (_cachedFacultyId != null && _cachedFacultyId!.isNotEmpty) {
      debugPrint(
        '[UseDepartments.resolveAdminFacultyId] returning cached facultyId=$_cachedFacultyId',
      );
      return _cachedFacultyId;
    }
    for (int i = 0; i < attempts; i++) {
      try {
        final res = await _resolveAdminFacultyId();
        debugPrint(
          '[UseDepartments.resolveAdminFacultyId] attempt ${i + 1}/$attempts -> ${res ?? 'null'}',
        );
        if (res != null && res.isNotEmpty) return res;
      } catch (e) {
        debugPrint(
          '[UseDepartments.resolveAdminFacultyId] attempt ${i + 1} failed: $e',
        );
      }
      if (i < attempts - 1) await Future.delayed(delay);
    }
    return null;
  }

  Future<List<Department>> fetchDepartments({
    int? limit,
    int? page,
    String? facultyId,

    /// If true, ignore faculty scoping and return all departments across faculties.
    /// Default false to preserve security boundaries.
    bool includeAll = false,
  }) async {
    try {
      // If we're not explicitly requesting all departments, attempt to
      // resolve the current admin's faculty so we can scope results.
      String? resolvedFacultyId = facultyId;
      if (!includeAll &&
          (resolvedFacultyId == null || resolvedFacultyId.isEmpty)) {
        try {
          resolvedFacultyId = await _resolveAdminFacultyId();
        } catch (_) {}
      }

      // Cache explicit faculty id for other consumers to use (reduces races)
      if (facultyId != null && facultyId.isNotEmpty) {
        _cachedFacultyId = facultyId;
      }
      if (resolvedFacultyId != null && resolvedFacultyId.isNotEmpty) {
        _cachedFacultyId = resolvedFacultyId;
      }

      // If includeAll is requested, do not add the faculty_id filter.
      dynamic query = _supabase
          .from('departments')
          .select(
            'id, department_name, department_code, head_of_department, status, created_at, faculty_id, faculty:faculties(id,faculty_name)',
          );
      if (!includeAll) {
        // Enforce strict faculty scoping: only return rows for the resolved
        // faculty_id. Do not include global rows where faculty_id IS NULL.
        if (resolvedFacultyId == null || resolvedFacultyId.isEmpty) {
          // If we cannot resolve a faculty id for the current user, return an
          // empty list to avoid exposing other faculties' data.
          return <Department>[];
        }
        query = query
            .eq('faculty_id', resolvedFacultyId)
            .order('created_at', ascending: false);
      } else {
        query = query.order('created_at', ascending: false);
      }

      if (limit != null) {
        final int offset = (page ?? 0) * limit;
        query = query.range(offset, offset + limit - 1);
      }

      final response = await query;
      try {
        final rows = (response as List<dynamic>);
        debugPrint(
          'fetchDepartments: facultyId=$resolvedFacultyId -> returned ${rows.length} rows',
        );
        // Log a small sample (up to 5) so logs aren't noisy
        final sample = rows
            .take(5)
            .map((r) => r['department_name'] ?? r['department_code'] ?? r['id'])
            .toList();
        debugPrint('fetchDepartments sample names/codes: $sample');
      } catch (_) {
        debugPrint('fetchDepartments: unexpected response shape: $response');
      }

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

      // Require faculty_id to be present for created departments. If we
      // couldn't resolve a faculty id, abort the insert to prevent creating
      // a department with a null faculty_id.
      if (resolvedFacultyId == null || resolvedFacultyId.isEmpty) {
        throw Exception(
          'Cannot add department: no faculty assigned to current admin',
        );
      }

      await _supabase.from('departments').insert({
        'department_name': department.name,
        'department_code': department.code,
        'head_of_department': department.head,
        'status': department.status,
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

  Future<void> deleteDepartment(String code, {String? facultyId}) async {
    try {
      // Scope deletion to the provided facultyId or resolve from current admin
      String? resolvedFacultyId = facultyId;
      if (resolvedFacultyId == null || resolvedFacultyId.isEmpty) {
        try {
          resolvedFacultyId = await _resolveAdminFacultyId();
        } catch (_) {}
      }

      var query = _supabase
          .from('departments')
          .delete()
          .eq('department_code', code);
      if (resolvedFacultyId != null && resolvedFacultyId.isNotEmpty) {
        query = (query as dynamic).eq('faculty_id', resolvedFacultyId);
      }
      await query;
    } catch (e) {
      throw Exception('Failed to delete department: $e');
    }
  }

  /// Subscribe to department changes scoped to a faculty.
  /// If [facultyId] is omitted, the current admin's faculty will be resolved.
  /// If no faculty can be resolved, an empty stream is returned.
  Stream<List<Map<String, dynamic>>> subscribeDepartments({String? facultyId}) {
    // If a facultyId isn't provided, attempt to resolve it synchronously
    // by kicking off an async resolve and returning an empty stream for
    // now. Callers that need a live subscription should pass the resolved
    // facultyId obtained from the login/navigation flow or by calling
    // `resolveAdminFacultyId()`.
    if (facultyId == null || facultyId.isEmpty) {
      // Return an empty stream so UI can handle empty state consistently.
      return Stream<List<Map<String, dynamic>>>.value(<Map<String, dynamic>>[]);
    }

    return _supabase
        .from('departments')
        .stream(primaryKey: ['id'])
        .eq('faculty_id', facultyId)
        .order('created_at', ascending: false);
  }
}
