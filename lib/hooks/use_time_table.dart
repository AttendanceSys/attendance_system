import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Lightweight helper for persisting timetable rows into the `time_table`
/// table. This file contains guarded helpers used by the UI to insert,
/// update, query and delete timetable data scoped to the current admin's
/// faculty. It purposely accepts plain maps (not UI classes) so it doesn't
/// depend on widget files.
class UseTimeTable {
  final SupabaseClient _supabase = Supabase.instance.client;

  int _toInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    final s = v.toString();
    return int.tryParse(s) ?? 0;
  }

  Future<String?> _resolveAdminFacultyId() async {
    try {
      var current = _supabase.auth.currentUser;
      if (current == null) {
        try {
          final u = await _supabase.auth.getUser();
          current = u.user;
        } catch (_) {}
      }
      if (current == null) return null;
      final authUid = current.id;

      Map<String, dynamic>? uh;
      try {
        final res = await _supabase
            .from('user_handling')
            .select('id, username, role')
            .eq('auth_uid', authUid)
            .maybeSingle();
        if (res != null) {
          uh = Map<String, dynamic>.from(res as Map);
        }
      } catch (e) {
        debugPrint('user_handling lookup failed: $e');
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
            .select('faculty_id, faculty_name, user_handling_id, username')
            .eq('user_handling_id', uhId)
            .maybeSingle();
        if (ar != null) adminRow = ar;
      }
      if (adminRow == null && username.isNotEmpty) {
        final ar2 = await _supabase
            .from('admins')
            .select('faculty_id, faculty_name, user_handling_id, username')
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
    } catch (e) {
      debugPrint('resolveAdminFacultyId error: $e');
      return null;
    }
  }

  Future<String?> _findDepartmentId(String facultyId, String dept) async {
    try {
      // try several strategies: code, exact name, case-insensitive name
      final byCode = await _supabase
          .from('departments')
          .select('id')
          .eq('faculty_id', facultyId)
          .eq('department_code', dept)
          .maybeSingle();
      if (byCode != null && byCode['id'] != null) {
        return byCode['id'].toString();
      }

      final byName = await _supabase
          .from('departments')
          .select('id')
          .eq('faculty_id', facultyId)
          .eq('department_name', dept)
          .maybeSingle();
      if (byName != null && byName['id'] != null) {
        return byName['id'].toString();
      }

      // last resort: ilike (case-insensitive)
      try {
        final il = await _supabase
            .from('departments')
            .select('id')
            .eq('faculty_id', facultyId)
            .ilike('department_name', dept)
            .maybeSingle();
        if (il != null && il['id'] != null) return il['id'].toString();
      } catch (_) {}

      return null;
    } catch (e) {
      debugPrint('findDepartmentId error: $e');
      return null;
    }
  }

  Future<String?> _findClassId(String facultyId, String className) async {
    try {
      final r = await _supabase
          .from('classes')
          .select('id')
          .eq('faculty_id', facultyId)
          .eq('class_name', className)
          .maybeSingle();
      if (r != null && r['id'] != null) return r['id'].toString();
      try {
        final il = await _supabase
            .from('classes')
            .select('id')
            .eq('faculty_id', facultyId)
            .ilike('class_name', className)
            .maybeSingle();
        if (il != null && il['id'] != null) return il['id'].toString();
      } catch (_) {}
      return null;
    } catch (e) {
      debugPrint('findClassId error: $e');
      return null;
    }
  }

  Future<String?> _findTeacherIdByName(String name, String facultyId) async {
    try {
      if (name.trim().isEmpty) return null;
      final r = await _supabase
          .from('teachers')
          .select('id')
          .eq('faculty_id', facultyId)
          .eq('teacher_name', name)
          .maybeSingle();
      if (r != null && r['id'] != null) return r['id'].toString();
      try {
        final il = await _supabase
            .from('teachers')
            .select('id')
            .eq('faculty_id', facultyId)
            .ilike('teacher_name', name)
            .maybeSingle();
        if (il != null && il['id'] != null) return il['id'].toString();
      } catch (_) {}
      return null;
    } catch (e) {
      debugPrint('findTeacherId error: $e');
      return null;
    }
  }

  Future<String?> _findCourseIdByName(String name, String facultyId) async {
    try {
      if (name.trim().isEmpty) return null;
      final r = await _supabase
          .from('courses')
          .select('id')
          .eq('faculty_id', facultyId)
          .eq('course_name', name)
          .maybeSingle();
      if (r != null && r['id'] != null) return r['id'].toString();
      try {
        final il = await _supabase
            .from('courses')
            .select('id')
            .eq('faculty_id', facultyId)
            .ilike('course_name', name)
            .maybeSingle();
        if (il != null && il['id'] != null) return il['id'].toString();
      } catch (_) {}
      return null;
    } catch (e) {
      debugPrint('findCourseId error: $e');
      return null;
    }
  }

  /// Save a list of session maps into time_table.
  /// Each session map must contain keys:
  /// - department (String), classKey (String), section (String), dayIndex (int),
  /// - startMinutes (int), endMinutes (int), cellText (String)
  /// The method will resolve faculty id from the current admin and then
  /// group sessions by department+class. Where possible it resolves FK ids
  /// and stores those; otherwise it leaves the FK columns null but still
  /// persists the session data inside the `sessions` jsonb column.
  Future<void> saveSessions(List<Map<String, dynamic>> sessions) async {
    if (sessions.isEmpty) return;
    final facultyId = await _resolveAdminFacultyId();
    if (facultyId == null) {
      throw Exception('No faculty assigned to current admin');
    }

    // Group sessions by department + class
    final Map<String, List<Map<String, dynamic>>> groups = {};
    for (final s in sessions) {
      final dep = (s['department'] ?? '').toString();
      final cls = (s['classKey'] ?? '').toString();
      final key = '${dep.trim().toLowerCase()}:::${cls.trim().toLowerCase()}';
      groups.putIfAbsent(key, () => []).add(s);
    }

    for (final entry in groups.entries) {
      final first = entry.value.first;
      final depName = (first['department'] ?? '').toString();
      final className = (first['classKey'] ?? '').toString();

      final deptId = await _findDepartmentId(facultyId, depName);
      final classId = await _findClassId(facultyId, className);

      // Try to find an existing time_table row for this faculty + dept + class
      dynamic existing;
      try {
        var q = _supabase
            .from('time_table')
            .select()
            .eq('faculty_id', facultyId);
        if (deptId != null) q = (q as dynamic).eq('department', deptId);
        if (classId != null) q = (q as dynamic).eq('class', classId);
        // Limit to one row — if multiple exist we'll pick the first
        final res = await q.limit(1).maybeSingle();
        existing = res;
      } catch (e) {
        debugPrint('find existing time_table failed: $e');
      }

      final List<Map<String, dynamic>> existingSessions = [];
      String? timeTableId;
      if (existing != null) {
        timeTableId = (existing['id'] ?? '').toString();
        try {
          final raw = existing['sessions'];
          if (raw is List) {
            for (final r in raw) {
              if (r is Map<String, dynamic>) {
                existingSessions.add(r);
              } else if (r is Map)
                existingSessions.add(Map<String, dynamic>.from(r));
            }
          }
        } catch (_) {}
      }

      // Convert new sessions to canonical objects and attempt to resolve teacher/course ids
      final List<Map<String, dynamic>> toAppend = [];
      for (final s in entry.value) {
        final cell = (s['cellText'] ?? '').toString();
        final parts = cell.split('\n');
        final lecturerName = parts.length > 1
            ? parts.sublist(1).join(' ').trim()
            : '';
        final courseName = parts.isNotEmpty ? parts.first.trim() : '';
        final teacherId = lecturerName.isNotEmpty
            ? await _findTeacherIdByName(lecturerName, facultyId)
            : null;
        final courseId = courseName.isNotEmpty
            ? await _findCourseIdByName(courseName, facultyId)
            : null;

        toAppend.add({
          'department': depName,
          'department_id': deptId,
          'class': className,
          'class_id': classId,
          'section': (s['section'] ?? '').toString(),
          'day_index': _toInt(s['dayIndex'] ?? s['day_index']),
          'start_minutes': _toInt(s['startMinutes'] ?? s['start_minutes']),
          'end_minutes': _toInt(s['endMinutes'] ?? s['end_minutes']),
          'course_name': courseName,
          'course_id': courseId,
          'lecturer_name': lecturerName,
          'teacher_id': teacherId,
        });
      }

      // Merge existing sessions with toAppend — avoid exact duplicates (same day,start,end,section)
      for (final a in toAppend) {
        final duplicate = existingSessions.any(
          (e) =>
              e['day_index'] == a['day_index'] &&
              e['start_minutes'] == a['start_minutes'] &&
              e['end_minutes'] == a['end_minutes'] &&
              (e['section'] ?? '') == (a['section'] ?? ''),
        );
        if (!duplicate) existingSessions.add(a);
      }

      final payload = {
        'faculty_id': facultyId,
        'department': deptId,
        'class': classId,
        'sessions': existingSessions,
        'updated_at': DateTime.now().toIso8601String(),
      }..removeWhere((k, v) => v == null);

      try {
        if (timeTableId != null && timeTableId.isNotEmpty) {
          await _supabase
              .from('time_table')
              .update(payload)
              .eq('id', timeTableId)
              .select();
        } else {
          // create a new row
          await _supabase.from('time_table').insert(payload).select();
        }
      } catch (e) {
        debugPrint('save time_table row failed: $e');
        rethrow;
      }
    }
  }

  /// Fetch sessions for a particular department + class + optional section
  /// scoped to current admin faculty. Returns an array of session objects
  /// (the JSON stored in the `sessions` column) or empty list if nothing.
  Future<List<Map<String, dynamic>>> fetchSessions({
    required String department,
    required String classKey,
    String? section,
  }) async {
    final facultyId = await _resolveAdminFacultyId();
    if (facultyId == null) return [];
    final deptId = await _findDepartmentId(facultyId, department);
    final classId = await _findClassId(facultyId, classKey);
    try {
      var q = _supabase
          .from('time_table')
          .select('id, sessions')
          .eq('faculty_id', facultyId);
      if (deptId != null) q = (q as dynamic).eq('department', deptId);
      if (classId != null) q = (q as dynamic).eq('class', classId);
      final res = await q;
      final rows = (res as List);
      if (rows.isEmpty) return [];
      // Collect sessions from all matching rows and filter by section if provided
      final List<Map<String, dynamic>> out = [];
      for (final r in rows) {
        final sess = r['sessions'];
        if (sess is List) {
          for (final s in sess) {
            if (s is Map) {
              final m = Map<String, dynamic>.from(s);
              if (section != null && section.isNotEmpty) {
                if ((m['section'] ?? '') == section) out.add(m);
              } else {
                out.add(m);
              }
            }
          }
        }
      }
      return out;
    } catch (e) {
      debugPrint('fetchSessions failed: $e');
      return [];
    }
  }

  /// Delete sessions that match the given department/class/section conditions.
  /// If [deleteStructure] is true the whole time_table row(s) will be removed
  /// (including period structure). Otherwise only sessions for the matching
  /// section are removed (rows kept).
  Future<void> deleteTimetable({
    required String department,
    required String classKey,
    String? section,
    bool deleteStructure = false,
  }) async {
    final facultyId = await _resolveAdminFacultyId();
    if (facultyId == null) {
      throw Exception('No faculty assigned to current admin');
    }
    final deptId = await _findDepartmentId(facultyId, department);
    final classId = await _findClassId(facultyId, classKey);

    if (deleteStructure) {
      try {
        var q = _supabase
            .from('time_table')
            .delete()
            .eq('faculty_id', facultyId);
        if (deptId != null) q = (q as dynamic).eq('department', deptId);
        if (classId != null) q = (q as dynamic).eq('class', classId);
        await q;
        return;
      } catch (e) {
        debugPrint('delete time_table rows failed: $e');
        rethrow;
      }
    }

    // Otherwise remove only sessions matching the section (or all sessions if section omitted)
    try {
      var q = _supabase
          .from('time_table')
          .select('id, sessions')
          .eq('faculty_id', facultyId);
      if (deptId != null) q = (q as dynamic).eq('department', deptId);
      if (classId != null) q = (q as dynamic).eq('class', classId);
      final rows = await q;
      for (final r in (rows as List)) {
        final id = r['id'];
        final sess = r['sessions'];
        List<Map<String, dynamic>> kept = [];
        if (sess is List) {
          for (final s in sess) {
            if (s is Map) {
              final m = Map<String, dynamic>.from(s);
              if (section != null && section.isNotEmpty) {
                if ((m['section'] ?? '') != section) kept.add(m);
              } else {
                // no section specified => remove all sessions (but keep the row)
              }
            }
          }
        }
        if (section != null && section.isNotEmpty) {
          await _supabase
              .from('time_table')
              .update({
                'sessions': kept,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', id)
              .select();
        } else {
          // clear sessions
          await _supabase
              .from('time_table')
              .update({
                'sessions': [],
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', id)
              .select();
        }
      }
    } catch (e) {
      debugPrint('deleteTimetable failed: $e');
      rethrow;
    }
  }
}
