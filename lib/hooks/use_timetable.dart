// UseTimetable service: Supabase-backed replacements for Firestore helpers used by TimetablePage
//
// Usage:
//   final svc = UseTimetable.instance; // ensure supabase is initialized in your app
//   await svc.loadDepartments(); // populates svc.departments
//   await svc.loadTeachers(); // populates svc.teachers
//   await svc.loadClassesForDepartment(depIdOrRef);
//   await svc.loadCoursesForClass(classIdOrName);
//   await svc.loadTimetable(docId or dept/class combo) ...
//
// This file is intended to be used together with timetable_page.dart which calls into
// UseTimetable singleton instead of using Firebase directly.
//
// Requirements:
//   supabase_flutter: ^0.0.1  (or appropriate version)
//
// Note: adapt imports and supabase initialization to your app (Supabase.initialize).
import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'use_departments.dart';

// Small wrapper used to normalize Supabase/Postgrest responses so callers can
// access `.data` and `.error` uniformly.
class _Resp {
  final dynamic data;
  final dynamic error;
  _Resp(this.data, this.error);
}

class UseTimetable {
  UseTimetable._private();
  static final UseTimetable instance = UseTimetable._private();

  final SupabaseClient supabase = Supabase.instance.client;

  // Simple UUID detection used to avoid sending a string name into a
  // Postgres UUID column which causes "invalid input syntax for type uuid".
  // Correct UUID regex: use end-anchor `$` inside raw string (no backslash)
  final RegExp _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  // in-memory caches
  List<Map<String, dynamic>> departments = []; // {id, name}
  List<Map<String, dynamic>> classes = []; // {id, name, raw}
  List<Map<String, dynamic>> teachers = []; // {id, name}
  List<Map<String, dynamic>> courses = []; // for loaded class
  // When true, skip strict faculty scoping checks and allow unscoped queries.
  // This is useful for local development/debugging. It defaults to true in
  // `kDebugMode` to make development easier but stays false in release.
  bool allowUnscoped = kDebugMode;

  // Timetable "documents" cache keyed by sanitized '<dept>_<class>'
  final Map<String, Map<String, dynamic>> _timetableDocs = {};

  /// Debug helper: return currently cached timetable doc keys.
  List<String> debugTimetableDocKeys() => _timetableDocs.keys.toList();

  // ----------------- Departments -----------------
  Future<void> loadDepartments() async {
    try {
      // Try to resolve the current admin's faculty and scope departments to it.
      final depSvc = UseDepartments();
      String? resolvedFaculty;
      try {
        resolvedFaculty = await depSvc.resolveAdminFacultyId();
      } catch (_) {
        resolvedFaculty = null;
      }

      // If we couldn't resolve a faculty, return empty list to avoid
      // exposing other faculties' departments in the UI. When running in
      // dev/debug mode `allowUnscoped` may be enabled to bypass this
      // restriction for local testing.
      if ((resolvedFaculty == null || resolvedFaculty.isEmpty) &&
          !allowUnscoped) {
        departments = [];
        return;
      }

      final res = await _run(
        supabase
            .from('departments')
            .select()
            .eq('faculty_id', resolvedFaculty ?? '')
            .order('created_at', ascending: false),
      );
      if (res.error != null) throw res.error!;
      final rows = _asListOfMaps(res.data);

      // Diagnostic logging to confirm scoping
      try {
        final sample = rows
            .take(5)
            .map((r) => r['department_name'] ?? r['department_code'] ?? r['id'])
            .toList();
        debugPrint(
          '[UseTimetable.loadDepartments] faculty=$resolvedFaculty -> rows=${rows.length} sample=$sample',
        );
      } catch (_) {}
      departments = rows.map((r) {
        final name =
            (r['department_name'] ??
                    r['name'] ??
                    r['displayName'] ??
                    r['title'] ??
                    '')
                .toString();
        return {'id': r['id'].toString(), 'name': name, 'raw': r};
      }).toList();
      departments.sort(
        (a, b) => a['name'].toString().compareTo(b['name'].toString()),
      );
    } catch (e) {
      // swallow - allow caller to handle
      rethrow;
    }
  }

  /// Find timetables that reference the given teacher (UUID or display name).
  /// Returns a list of matching rows (may be empty).
  Future<List<Map<String, dynamic>>> findTimetablesByTeacher(
    String teacherIdOrName,
  ) async {
    try {
      debugPrint(
        '[UseTimetable.findTimetablesByTeacher] search="$teacherIdOrName"',
      );
      final List<Map<String, dynamic>> out = [];

      // Resolve current admin faculty to scope results.
      String? resolvedFaculty;
      try {
        final depSvc = UseDepartments();
        resolvedFaculty = await depSvc.resolveAdminFacultyId();
      } catch (_) {
        resolvedFaculty = null;
      }

      // If we don't have a resolved faculty, do not search across faculties
      // unless `allowUnscoped` is enabled for debugging.
      if ((resolvedFaculty == null || resolvedFaculty.isEmpty) &&
          !allowUnscoped) {
        debugPrint(
          '[UseTimetable.findTimetablesByTeacher] no resolved faculty -> returning empty list to avoid cross-faculty reads',
        );
        return <Map<String, dynamic>>[];
      }

      // Prefer exact UUID match on top-level `teacher` column.
      if (_uuidRegex.hasMatch(teacherIdOrName)) {
        var q = supabase
            .from('time_table')
            .select('*, classes(*), departments(*), courses(*)')
            .eq('teacher', teacherIdOrName);
        q = _applyFacultyFilter(q, resolvedFaculty);
        var res = await _run(q);
        debugPrint(
          '[UseTimetable.findTimetablesByTeacher] UUID branch query result error=${res.error}',
        );
        if (res.error != null && _isMissingTableError(res.error)) {
          // try alternate table
          var q2 = supabase
              .from('timetables')
              .select('*, classes(*), departments(*), courses(*)')
              .eq('teacher', teacherIdOrName);
          q2 = _applyFacultyFilter(q2, resolvedFaculty);
          res = await _run(q2);
          debugPrint(
            '[UseTimetable.findTimetablesByTeacher] tried alternate table, error=${res.error}',
          );
        }
        if (res.error == null) {
          final rows = _asListOfMaps(res.data);
          debugPrint(
            '[UseTimetable.findTimetablesByTeacher] UUID query rows=${rows.length} sample=${rows.take(3).toList()}',
          );
          out.addAll(rows);
        }
        // Also try matching inside sessions jsonb (best-effort string search)
        // Note: filter by faculty if column exists; if not, we'll filter later.
        var q3 = supabase
            .from('time_table')
            .select('*, classes(*), departments(*), courses(*)')
            .ilike('sessions', '%$teacherIdOrName%');
        q3 = _applyFacultyFilter(q3, resolvedFaculty);
        var res2 = await _run(q3);
        if (res2.error != null && _isMissingTableError(res2.error)) {
          var q4 = supabase
              .from('timetables')
              .select('*, classes(*), departments(*), courses(*)')
              .ilike('sessions', '%$teacherIdOrName%');
          q4 = _applyFacultyFilter(q4, resolvedFaculty);
          res2 = await _run(q4);
        }
        debugPrint(
          '[UseTimetable.findTimetablesByTeacher] sessions ilike error=${res2.error}',
        );
        if (res2.error == null) {
          final rows = _asListOfMaps(res2.data);
          debugPrint(
            '[UseTimetable.findTimetablesByTeacher] sessions ilike rows=${rows.length}',
          );
          out.addAll(rows);
        }
        // dedupe by id and filter by faculty (defensive)
        final deduped = await _dedupeAndFilterByFaculty(out, resolvedFaculty);
        return deduped;
      }

      // If not a UUID, try matching display name fields on teachers table first
      try {
        debugPrint(
          '[UseTimetable.findTimetablesByTeacher] non-UUID name branch, resolving teacher id for "$teacherIdOrName"',
        );
        // Normalize search term and try to find a teacher id by matching
        // several possible name columns. Use a wildcard pattern.
        final q = '%${teacherIdOrName.replaceAll('%', '').trim()}%';
        var tres = await _run(
          supabase
              .from('teachers')
              .select('id')
              .or(
                "teacher_name.ilike.$q,name.ilike.$q,full_name.ilike.$q,username.ilike.$q",
              )
              .limit(1),
        );
        debugPrint(
          '[UseTimetable.findTimetablesByTeacher] teacher lookup result error=${tres.error}',
        );
        // If that failed (missing column/table or driver mismatch), fall back
        // to a simple query and client-side filtering of returned rows.
        if (tres.error != null) {
          final all = await _run(supabase.from('teachers').select());
          if (all.error == null) {
            final list = _asListOfMaps(all.data);
            for (final r in list) {
              try {
                final name =
                    (r['teacher_name'] ??
                            r['name'] ??
                            r['full_name'] ??
                            r['username'] ??
                            '')
                        .toString()
                        .toLowerCase();
                if (name.contains(teacherIdOrName.toLowerCase().trim())) {
                  final tid = r['id']?.toString();
                  if (tid != null && tid.isNotEmpty) {
                    return await findTimetablesByTeacher(tid);
                  }
                }
              } catch (_) {}
            }
          }
        } else {
          final tr = _asListOfMaps(tres.data);
          if (tr.isNotEmpty) {
            final tid = tr.first['id']?.toString();
            if (tid != null && tid.isNotEmpty) {
              return await findTimetablesByTeacher(tid);
            }
          }
        }
      } catch (_) {}

      // As a fallback, try searching sessions JSON text for the display name.
      // Note: scope by faculty_id where possible.
      try {
        var qF = supabase
            .from('time_table')
            .select('*, classes(*), departments(*), courses(*)')
            .ilike('sessions', '%$teacherIdOrName%');
        qF = _applyFacultyFilter(qF, resolvedFaculty);
        var fres = await _run(qF);
        if (fres.error != null && _isMissingTableError(fres.error)) {
          var qF2 = supabase
              .from('timetables')
              .select('*, classes(*), departments(*), courses(*)')
              .ilike('sessions', '%$teacherIdOrName%');
          qF2 = _applyFacultyFilter(qF2, resolvedFaculty);
          fres = await _run(qF2);
        }
        debugPrint(
          '[UseTimetable.findTimetablesByTeacher] sessions final ilike error=${fres.error}',
        );
        if (fres.error == null) {
          final rows = _asListOfMaps(fres.data);
          debugPrint(
            '[UseTimetable.findTimetablesByTeacher] final sessions ilike rows=${rows.length}',
          );
          out.addAll(rows);
        }
      } catch (_) {}
      // Final fallback: fetch all timetable rows for this faculty and scan client-side for
      // matches inside `sessions` JSON or top-level teacher/class fields.
      try {
        if (out.isEmpty) {
          debugPrint(
            '[UseTimetable.findTimetablesByTeacher] fallback scanning timetables for faculty=$resolvedFaculty (client-side)',
          );
          var qAll = supabase
              .from('time_table')
              .select('*, classes(*), departments(*), courses(*)');
          qAll = _applyFacultyFilter(qAll, resolvedFaculty);
          var all = await _run(qAll);
          if (all.error != null && _isMissingTableError(all.error)) {
            var qAll2 = supabase
                .from('timetables')
                .select('*, classes(*), departments(*), courses(*)');
            qAll2 = _applyFacultyFilter(qAll2, resolvedFaculty);
            all = await _run(qAll2);
          }
          if (all.error == null) {
            final rows = _asListOfMaps(all.data);
            int scanned = 0;
            int matchedCount = 0;
            for (final r in rows) {
              scanned++;
              try {
                var matched = false;
                // check top-level teacher column (could be uuid or name)
                final tval = (r['teacher'] ?? '').toString();
                if (tval.isNotEmpty) {
                  if (_uuidRegex.hasMatch(teacherIdOrName)) {
                    if (tval == teacherIdOrName) matched = true;
                  } else {
                    if (tval.toLowerCase().contains(
                      teacherIdOrName.toLowerCase(),
                    )) {
                      matched = true;
                    }
                  }
                }

                // inspect sessions JSON/Map/text
                if (!matched && r.containsKey('sessions')) {
                  try {
                    final s = r['sessions'];
                    final txt = jsonEncode(s).toString().toLowerCase();
                    if (txt.contains(teacherIdOrName.toLowerCase())) {
                      matched = true;
                    }
                  } catch (_) {}
                }

                if (matched) {
                  matchedCount++;
                  out.add(r);
                }
              } catch (_) {}
            }
            debugPrint(
              '[UseTimetable.findTimetablesByTeacher] fallback scanned=$scanned matched=$matchedCount',
            );
          }
        }
      } catch (_) {}
      // dedupe + faculty-filter
      final deduped = await _dedupeAndFilterByFaculty(out, resolvedFaculty);
      return deduped;
    } catch (e) {
      rethrow;
    }
  }

  /// Find timetables for a given class id or display name. Returns matching rows.
  Future<List<Map<String, dynamic>>> findTimetablesByClass(
    String classIdOrName,
  ) async {
    try {
      final List<Map<String, dynamic>> out = [];

      // Resolve current admin faculty to scope results. Allow unscoped
      // operation during local debugging when `allowUnscoped` is true.
      String? resolvedFaculty;
      try {
        final depSvc = UseDepartments();
        resolvedFaculty = await depSvc.resolveAdminFacultyId();
      } catch (_) {
        resolvedFaculty = null;
      }
      if ((resolvedFaculty == null || resolvedFaculty.isEmpty) &&
          !allowUnscoped) {
        debugPrint(
          '[UseTimetable.findTimetablesByClass] no resolved faculty -> returning empty list',
        );
        return <Map<String, dynamic>>[];
      }

      // If looks like UUID, try matching `class` FK on time_table
      if (_uuidRegex.hasMatch(classIdOrName)) {
        var qClass = supabase
            .from('time_table')
            .select()
            .eq('class', classIdOrName);
        qClass = _applyFacultyFilter(qClass, resolvedFaculty);
        var res = await _run(qClass);
        if (res.error != null && _isMissingTableError(res.error)) {
          var qClass2 = supabase
              .from('timetables')
              .select()
              .eq('class', classIdOrName);
          qClass2 = _applyFacultyFilter(qClass2, resolvedFaculty);
          res = await _run(qClass2);
        }
        if (res.error == null) return _asListOfMaps(res.data);
      }

      // If not a UUID, try resolving class display name to id first (search common columns)
      try {
        final q = '%${classIdOrName.replaceAll('%', '').trim()}%';
        var cres = await _run(
          supabase
              .from('classes')
              .select('id')
              .or('class_name.ilike.$q,name.ilike.$q')
              .limit(1),
        );
        if (cres.error == null) {
          final cr = _asListOfMaps(cres.data);
          if (cr.isNotEmpty) {
            final cid = cr.first['id']?.toString();
            if (cid != null && cid.isNotEmpty) {
              // Found an id — try UUID branch using class FK
              var qTime = supabase.from('time_table').select().eq('class', cid);
              qTime = _applyFacultyFilter(qTime, resolvedFaculty);
              var res2 = await _run(qTime);
              if (res2.error != null && _isMissingTableError(res2.error)) {
                var qTime2 = supabase
                    .from('timetables')
                    .select()
                    .eq('class', cid);
                qTime2 = _applyFacultyFilter(qTime2, resolvedFaculty);
                res2 = await _run(qTime2);
              }
              if (res2.error == null) return _asListOfMaps(res2.data);
            }
          }
        }
      } catch (_) {}

      // Try matching class_id/className fields
      var qCK = supabase
          .from('time_table')
          .select()
          .eq('classKey', classIdOrName);
      qCK = _applyFacultyFilter(qCK, resolvedFaculty);
      var res2 = await _run(qCK);
      if (res2.error != null && _isMissingTableError(res2.error)) {
        var qCK2 = supabase
            .from('timetables')
            .select()
            .eq('classKey', classIdOrName);
        qCK2 = _applyFacultyFilter(qCK2, resolvedFaculty);
        res2 = await _run(qCK2);
      }
      if (res2.error == null) {
        final rows = _asListOfMaps(res2.data);
        debugPrint(
          '[UseTimetable.findTimetablesByClass] classKey lookup rows=${rows.length}',
        );
        out.addAll(rows);
      }

      // Try ilike on class_name/className, scoping to faculty where possible
      var qCN = supabase
          .from('time_table')
          .select()
          .ilike('className', '%$classIdOrName%');
      qCN = _applyFacultyFilter(qCN, resolvedFaculty);
      final res3 = await _run(qCN);
      if (res3.error == null) {
        final rows = _asListOfMaps(res3.data);
        debugPrint(
          '[UseTimetable.findTimetablesByClass] ilike className rows=${rows.length}',
        );
        out.addAll(rows);
      }

      // Final fallback: if no rows found yet, fetch all timetable rows for this faculty and
      // perform a client-side filter by class name/classKey/class fields.
      try {
        if (out.isEmpty) {
          var qAll = supabase.from('time_table').select();
          qAll = _applyFacultyFilter(qAll, resolvedFaculty);
          var all = await _run(qAll);
          if (all.error != null && _isMissingTableError(all.error)) {
            var qAll2 = supabase.from('timetables').select();
            qAll2 = _applyFacultyFilter(qAll2, resolvedFaculty);
            all = await _run(qAll2);
          }
          if (all.error == null) {
            final rows = _asListOfMaps(all.data);
            int scanned = 0;
            int matchedCount = 0;
            for (final r in rows) {
              scanned++;
              try {
                var matched = false;
                final cid =
                    (r['class'] ?? r['className'] ?? r['classKey'] ?? '')
                        .toString();
                if (cid.isNotEmpty) {
                  if (_uuidRegex.hasMatch(classIdOrName)) {
                    if (cid == classIdOrName) matched = true;
                  } else {
                    if (cid.toLowerCase().contains(
                      classIdOrName.toLowerCase(),
                    )) {
                      matched = true;
                    }
                  }
                }
                // inspect sessions or other text fields
                if (!matched) {
                  try {
                    final txt = jsonEncode(
                      r['sessions'],
                    ).toString().toLowerCase();
                    if (txt.contains(classIdOrName.toLowerCase())) {
                      matched = true;
                    }
                  } catch (_) {}
                }
                if (matched) {
                  matchedCount++;
                  out.add(r);
                }
              } catch (_) {}
            }
            debugPrint(
              '[UseTimetable.findTimetablesByClass] fallback scanned=$scanned matched=$matchedCount',
            );
          }
        }
      } catch (_) {}

      // dedupe & filter by faculty
      final deduped = await _dedupeAndFilterByFaculty(out, resolvedFaculty);
      return deduped;
    } catch (e) {
      rethrow;
    }
  }

  // Helper: normalize different supabase shapes into a List<Map<String,dynamic>>
  // Accepts List, Map (single row), JSArray-like, or Postgrest response data.
  List<Map<String, dynamic>> _asListOfMaps(dynamic data) {
    if (data == null) return <Map<String, dynamic>>[];
    try {
      if (data is List) {
        return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      if (data is Map) {
        return <Map<String, dynamic>>[Map<String, dynamic>.from(data)];
      }
      // try to iterate (JSArray proxy etc.)
      try {
        return (data as dynamic)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList()
            as List<Map<String, dynamic>>;
      } catch (_) {
        return <Map<String, dynamic>>[];
      }
    } catch (_) {
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> loadTeachers() async {
    try {
      final res = await _run(supabase.from('teachers').select());
      if (res.error != null) throw res.error!;
      final rows = _asListOfMaps(res.data);
      // Build a map keyed by id to ensure unique ids (prevents duplicate
      // DropdownMenuItem values in the Flutter UI). Keep last-seen row.
      final Map<String, Map<String, dynamic>> byId = {};
      for (final r in rows) {
        try {
          final id = (r['id']?.toString() ?? '').trim();
          final name =
              (r['teacher_name'] ??
                      r['name'] ??
                      r['full_name'] ??
                      r['username'] ??
                      '')
                  .toString();
          if (id.isEmpty) continue;
          byId[id] = {'id': id, 'name': name, 'raw': r};
        } catch (_) {}
      }
      teachers = byId.values.toList();
      teachers.sort(
        (a, b) => a['name'].toString().compareTo(b['name'].toString()),
      );
    } catch (e) {
      rethrow;
    }
  }

  /// Return a single teacher's full raw record (best-effort) for the given
  /// id or display name. This lets UI show only the selected teacher's details
  /// without fetching or rendering unrelated timetables.
  Future<Map<String, dynamic>?> getTeacherDetails(String idOrName) async {
    final s = idOrName.toString().trim();
    if (s.isEmpty) return null;

    // check in-memory cache first (match by id or name)
    try {
      for (final t in teachers) {
        try {
          if ((t['id']?.toString() ?? '') == s) {
            return t['raw'] as Map<String, dynamic>? ?? t;
          }
          if ((t['name']?.toString().toLowerCase() ?? '') == s.toLowerCase()) {
            return t['raw'] as Map<String, dynamic>? ?? t;
          }
        } catch (_) {}
      }
    } catch (_) {}

    // If looks like a UUID, try direct id lookup in DB
    try {
      if (_uuidRegex.hasMatch(s)) {
        final res = await _run(
          supabase.from('teachers').select().eq('id', s).limit(1),
        );
        if (res.error == null) {
          final rows = _asListOfMaps(res.data);
          if (rows.isNotEmpty) return rows.first;
        }
      }
    } catch (_) {}

    // Fallback: try a name search across common columns
    try {
      final q = '%${s.replaceAll('%', '').trim()}%';
      var tres = await _run(
        supabase
            .from('teachers')
            .select()
            .or(
              "teacher_name.ilike.$q,name.ilike.$q,full_name.ilike.$q,username.ilike.$q",
            )
            .limit(1),
      );
      if (tres.error == null) {
        final tr = _asListOfMaps(tres.data);
        if (tr.isNotEmpty) return tr.first;
      }
    } catch (_) {}

    return null;
  }

  // ----------------- Classes -----------------
  /// Accepts department id string OR department display name string.
  Future<void> loadClassesForDepartment(dynamic depIdOrName) async {
    try {
      classes = [];
      if (depIdOrName == null) return;
      List<Map<String, dynamic>> rows = [];
      // Resolve current admin's faculty and enforce scoping. If we can't
      // resolve a faculty id, return empty result to avoid exposing other
      // faculties' classes. Allow bypass in debug using `allowUnscoped`.
      String? resolvedFaculty;
      try {
        final depSvc = UseDepartments();
        resolvedFaculty = await depSvc.resolveAdminFacultyId();
      } catch (_) {
        resolvedFaculty = null;
      }
      if ((resolvedFaculty == null || resolvedFaculty.isEmpty) &&
          !allowUnscoped) {
        classes = [];
        return;
      }

      // Try by department id or name. Avoid querying a UUID column with a
      // plain display name (Postgres will return an error). If the input
      // looks like a UUID we try matching the `department` FK column first.
      if (depIdOrName is String) {
        if (_uuidRegex.hasMatch(depIdOrName)) {
          var q = supabase
              .from('classes')
              .select()
              .eq('department', depIdOrName);
          q = _applyFacultyFilter(q, resolvedFaculty);
          final res = await _run(q);
          if (res.error == null) rows = _asListOfMaps(res.data);
        }

        // If we didn't find rows yet, try department_id or search by display
        // name. Always scope by faculty_id.
        if (rows.isEmpty) {
          var q2 = supabase
              .from('classes')
              .select()
              .eq('department_id', depIdOrName);
          q2 = _applyFacultyFilter(q2, resolvedFaculty);
          final res = await _run(q2);
          if (res.error == null) rows = _asListOfMaps(res.data);
        }

        if (rows.isEmpty) {
          var qdep = supabase
              .from('departments')
              .select()
              .ilike('department_name', depIdOrName);
          qdep = _applyFacultyFilter(qdep, resolvedFaculty);
          final depRes = await _run(qdep);
          if (depRes.error == null) {
            final depRows = _asListOfMaps(depRes.data);
            if (depRows.isNotEmpty) {
              final dep = depRows.first;
              var q3 = supabase
                  .from('classes')
                  .select()
                  .eq('department', dep['id']);
              q3 = _applyFacultyFilter(q3, resolvedFaculty);
              final res2 = await _run(q3);
              if (res2.error == null) rows = _asListOfMaps(res2.data);
            }
          }
        }
      }

      // Fallback: select all classes for this faculty only
      if (rows.isEmpty) {
        var qall = supabase.from('classes').select();
        qall = _applyFacultyFilter(qall, resolvedFaculty);
        final res = await _run(qall);
        if (res.error == null) rows = _asListOfMaps(res.data);
      }

      classes = rows.map((d) {
        final name = (d['class_name'] ?? d['name'] ?? d['title'] ?? d['id'])
            .toString();
        return {'id': d['id'].toString(), 'name': name, 'raw': d};
      }).toList();
      classes.sort(
        (a, b) => a['name'].toString().compareTo(b['name'].toString()),
      );
    } catch (e) {
      rethrow;
    }
  }

  // ----------------- Courses -----------------
  Future<void> loadCoursesForClass(dynamic classIdOrName) async {
    try {
      courses = [];
      if (classIdOrName == null) return;
      List<Map<String, dynamic>> rows = [];

      // Resolve current admin's faculty and enforce scoping. If we can't
      // resolve a faculty id, return empty to avoid exposing other faculties'
      // courses. Allow bypass in debug using `allowUnscoped`.
      String? resolvedFaculty;
      try {
        final depSvc = UseDepartments();
        resolvedFaculty = await depSvc.resolveAdminFacultyId();
      } catch (_) {
        resolvedFaculty = null;
      }
      if ((resolvedFaculty == null || resolvedFaculty.isEmpty) &&
          !allowUnscoped) {
        courses = [];
        return;
      }

      if (classIdOrName is String) {
        // If this looks like a UUID, try matching the `class` UUID FK first.
        if (_uuidRegex.hasMatch(classIdOrName)) {
          var q = supabase.from('courses').select().eq('class', classIdOrName);
          q = _applyFacultyFilter(q, resolvedFaculty);
          final res = await _run(q);
          if (res.error == null) rows = _asListOfMaps(res.data);
        }

        if (rows.isEmpty) {
          var q = supabase
              .from('courses')
              .select()
              .eq('class_id', classIdOrName);
          q = _applyFacultyFilter(q, resolvedFaculty);
          final res = await _run(q);
          if (res.error == null) rows = _asListOfMaps(res.data);
        }

        if (rows.isEmpty) {
          // some schemas use class name stored
          var q2 = supabase
              .from('courses')
              .select()
              .ilike('class_name', classIdOrName);
          q2 = _applyFacultyFilter(q2, resolvedFaculty);
          final res2 = await _run(q2);
          if (res2.error == null) rows = _asListOfMaps(res2.data);
        }
      }

      if (rows.isEmpty) {
        // no rows for this class in this faculty
        courses = [];
        return;
      }

      courses = rows.map((d) {
        final name =
            (d['course_name'] ?? d['title'] ?? d['course_code'] ?? d['id'])
                .toString();
        return {'id': d['id'].toString(), 'name': name, 'raw': d};
      }).toList();

      courses.sort(
        (a, b) => a['name'].toString().compareTo(b['name'].toString()),
      );
    } catch (e) {
      rethrow;
    }
  }

  // ----------------- Timetables -----------------
  // We model timetables as rows in 'timetables' table (or using time_table in SQL).
  // Attempt to find by sanitized doc id, or by department/class fields.
  Future<Map<String, dynamic>?> loadTimetableByDocId(String docId) async {
    try {
      // If the provided docId is not a UUID (for example when the UI builds a
      // sanitized key like 'computer_science_jh'), avoid querying the `id`
      // UUID column with that value — Postgres will raise "invalid input
      // syntax for type uuid". Only query the id column when the docId
      // actually looks like a UUID; otherwise return null and let callers
      // fall back to searching by department/class fields.
      if (!_uuidRegex.hasMatch(docId)) {
        return null;
      }

      // Resolve faculty to scope search
      String? resolvedFaculty;
      try {
        final depSvc = UseDepartments();
        resolvedFaculty = await depSvc.resolveAdminFacultyId();
      } catch (_) {
        resolvedFaculty = null;
      }
      debugPrint(
        '[UseTimetable.loadTimetableByDocId] docId="$docId" resolvedFaculty=$resolvedFaculty',
      );
      if ((resolvedFaculty == null || resolvedFaculty.isEmpty) &&
          !allowUnscoped) {
        // Don't attempt cross-faculty id lookup when faculty unknown
        return null;
      }

      var q = supabase.from('timetables').select().eq('id', docId).limit(1);
      q = _applyFacultyFilter(q, resolvedFaculty);
      var res = await _run(q);
      // If table not found, try alternate table name used in some schemas
      if (res.error != null && _isMissingTableError(res.error)) {
        var q2 = supabase.from('time_table').select().eq('id', docId).limit(1);
        q2 = _applyFacultyFilter(q2, resolvedFaculty);
        res = await _run(q2);
      }
      if (res.error != null) throw res.error!;
      final rows = _asListOfMaps(res.data);
      if (rows.isEmpty) return null;
      final row = rows.first;
      _timetableDocs[docId] = row;
      return row;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> findTimetableByDeptClass(
    String department,
    String className, {
    String? classKey,
    String? departmentId,
  }) async {
    try {
      // Resolve current admin faculty to scope search. Allow unscoped
      // behavior during debugging when `allowUnscoped` is true.
      String? resolvedFaculty;
      try {
        final depSvc = UseDepartments();
        resolvedFaculty = await depSvc.resolveAdminFacultyId();
      } catch (_) {
        resolvedFaculty = null;
      }
      if ((resolvedFaculty == null || resolvedFaculty.isEmpty) &&
          !allowUnscoped) {
        debugPrint(
          '[UseTimetable.findTimetableByDeptClass] no resolved faculty -> skip cross-faculty search',
        );
        return null;
      }

      debugPrint(
        '[UseTimetable.findTimetableByDeptClass] department="$department" className="$className" classKey=$classKey departmentId=$departmentId resolvedFaculty=$resolvedFaculty',
      );
      // try exact department & className. If the `time_table` schema uses
      // UUID FKs instead of text fields, fall back to querying by resolved
      // department/class ids.
      dynamic res;
      // Pre-resolve ids (best-effort) for time_table lookups
      String? preResolvedDeptId;
      String? preResolvedClassId;
      try {
        if (_uuidRegex.hasMatch(department)) preResolvedDeptId = department;
        if (preResolvedDeptId == null) {
          for (final d in departments) {
            if ((d['name']?.toString() ?? '') == department) {
              preResolvedDeptId = d['id']?.toString();
              break;
            }
          }
        }
      } catch (_) {}
      debugPrint(
        '[UseTimetable.findTimetableByDeptClass] preResolvedDeptId=$preResolvedDeptId preResolvedClassId=$preResolvedClassId',
      );
      try {
        if (_uuidRegex.hasMatch(className)) preResolvedClassId = className;
        if (preResolvedClassId == null) {
          for (final c in classes) {
            if ((c['name']?.toString() ?? '') == className) {
              preResolvedClassId = c['id']?.toString();
              break;
            }
          }
        }
      } catch (_) {}

      // try primary table name, fallback to alternate if missing or column-mismatch
      if (_uuidRegex.hasMatch(department)) {
        var q = supabase
            .from('timetables')
            .select()
            .eq('department', department)
            .eq('className', className)
            .limit(1);
        q = _applyFacultyFilter(q, resolvedFaculty);
        res = await _run(q);
        if (res.error != null &&
            (_isMissingTableError(res.error) ||
                _isMissingColumnError(res.error))) {
          if (preResolvedDeptId != null && preResolvedClassId != null) {
            var q2 = supabase
                .from('time_table')
                .select()
                .eq('department', preResolvedDeptId)
                .eq('class', preResolvedClassId)
                .limit(1);
            q2 = _applyFacultyFilter(q2, resolvedFaculty);
            res = await _run(q2);
          } else {
            var q3 = supabase
                .from('time_table')
                .select()
                .ilike('department', department)
                .limit(1);
            q3 = _applyFacultyFilter(q3, resolvedFaculty);
            res = await _run(q3);
          }
        }
      } else {
        var q = supabase
            .from('timetables')
            .select()
            .ilike('department', department)
            .eq('className', className)
            .limit(1);
        q = _applyFacultyFilter(q, resolvedFaculty);
        res = await _run(q);
        if (res.error != null &&
            (_isMissingTableError(res.error) ||
                _isMissingColumnError(res.error))) {
          if (preResolvedDeptId != null && preResolvedClassId != null) {
            var q2 = supabase
                .from('time_table')
                .select()
                .eq('department', preResolvedDeptId)
                .eq('class', preResolvedClassId)
                .limit(1);
            q2 = _applyFacultyFilter(q2, resolvedFaculty);
            res = await _run(q2);
          } else {
            var q3 = supabase
                .from('time_table')
                .select()
                .ilike('department', department)
                .limit(1);
            q3 = _applyFacultyFilter(q3, resolvedFaculty);
            res = await _run(q3);
          }
        }
      }
      if (res.error == null) {
        final rows = _asListOfMaps(res.data);
        debugPrint(
          '[UseTimetable.findTimetableByDeptClass] primary query rows=${rows.length}',
        );
        if (rows.isNotEmpty) {
          final row = rows.first;
          // Try to derive human-friendly display names for department/class.
          String deptDisp = department;
          String classDisp = className;
          try {
            final dval = row['department']?.toString();
            if (dval != null && _uuidRegex.hasMatch(dval)) {
              final dres = await _run(
                supabase
                    .from('departments')
                    .select('department_name')
                    .eq('id', dval)
                    .limit(1),
              );
              if (dres.error == null) {
                final dr = _asListOfMaps(dres.data);
                if (dr.isNotEmpty) {
                  deptDisp =
                      (dr.first['department_name'] ??
                              dr.first['name'] ??
                              deptDisp)
                          .toString();
                }
              }
            } else if (row.containsKey('department')) {
              deptDisp = row['department']?.toString() ?? deptDisp;
            }
          } catch (_) {}
          try {
            final cval = (row['className'] ?? row['class'])?.toString();
            if (cval != null && _uuidRegex.hasMatch(cval)) {
              final cres = await _run(
                supabase
                    .from('classes')
                    .select('class_name')
                    .eq('id', cval)
                    .limit(1),
              );
              if (cres.error == null) {
                final cr = _asListOfMaps(cres.data);
                if (cr.isNotEmpty) {
                  classDisp =
                      (cr.first['class_name'] ?? cr.first['name'] ?? classDisp)
                          .toString();
                }
              }
            } else if (cval != null) {
              classDisp = cval;
            }
          } catch (_) {}

          final key = _sanitizedKey(deptDisp, classDisp);
          debugPrint(
            '[UseTimetable.findTimetableByDeptClass] primary matched deptDisp="$deptDisp" classDisp="$classDisp" key="$key"',
          );
          _timetableDocs[key] = row;
          return row;
        }
      }

      // try by department_id & classKey
      if (departmentId != null && classKey != null) {
        var q = supabase
            .from('timetables')
            .select()
            .eq('department_id', departmentId)
            .eq('classKey', classKey)
            .limit(1);
        q = _applyFacultyFilter(q, resolvedFaculty);
        res = await _run(q);
        if (res.error != null && _isMissingTableError(res.error)) {
          var q2 = supabase
              .from('time_table')
              .select()
              .eq('department_id', departmentId)
              .eq('classKey', classKey)
              .limit(1);
          q2 = _applyFacultyFilter(q2, resolvedFaculty);
          res = await _run(q2);
        }
        if (res.error == null) {
          final rows2 = _asListOfMaps(res.data);
          if (rows2.isNotEmpty) {
            final row = rows2.first;
            String deptDisp = department;
            String classDisp = className;
            try {
              final dval = row['department']?.toString();
              if (dval != null && _uuidRegex.hasMatch(dval)) {
                final dres = await _run(
                  supabase
                      .from('departments')
                      .select('department_name')
                      .eq('id', dval)
                      .limit(1),
                );
                if (dres.error == null) {
                  final dr = _asListOfMaps(dres.data);
                  if (dr.isNotEmpty) {
                    deptDisp =
                        (dr.first['department_name'] ??
                                dr.first['name'] ??
                                deptDisp)
                            .toString();
                  }
                }
              } else if (row.containsKey('department')) {
                deptDisp = row['department']?.toString() ?? deptDisp;
              }
            } catch (_) {}
            try {
              final cval = (row['className'] ?? row['class'])?.toString();
              if (cval != null && _uuidRegex.hasMatch(cval)) {
                final cres = await _run(
                  supabase
                      .from('classes')
                      .select('class_name')
                      .eq('id', cval)
                      .limit(1),
                );
                if (cres.error == null) {
                  final cr = _asListOfMaps(cres.data);
                  if (cr.isNotEmpty) {
                    classDisp =
                        (cr.first['class_name'] ??
                                cr.first['name'] ??
                                classDisp)
                            .toString();
                  }
                }
              } else if (cval != null) {
                classDisp = cval;
              }
            } catch (_) {}

            final key = _sanitizedKey(deptDisp, classDisp);
            _timetableDocs[key] = row;
            return row;
          }
        }
      }

      // last resort: any timetable with department or className match restricted to faculty
      var q = supabase
          .from('timetables')
          .select()
          .ilike('department', department)
          .limit(1);
      q = _applyFacultyFilter(q, resolvedFaculty);
      res = await _run(q);
      if (res.error != null && _isMissingTableError(res.error)) {
        var q2 = supabase
            .from('time_table')
            .select()
            .ilike('department', department)
            .limit(1);
        q2 = _applyFacultyFilter(q2, resolvedFaculty);
        res = await _run(q2);
      }
      if (res.error == null) {
        final rows3 = _asListOfMaps(res.data);
        if (rows3.isNotEmpty) {
          final row = rows3.first;
          String deptDisp = department;
          String classDisp = className;
          try {
            final dval = row['department']?.toString();
            if (dval != null && _uuidRegex.hasMatch(dval)) {
              final dres = await _run(
                supabase
                    .from('departments')
                    .select('department_name')
                    .eq('id', dval)
                    .limit(1),
              );
              if (dres.error == null) {
                final dr = _asListOfMaps(dres.data);
                if (dr.isNotEmpty) {
                  deptDisp =
                      (dr.first['department_name'] ??
                              dr.first['name'] ??
                              deptDisp)
                          .toString();
                }
              }
            } else if (row.containsKey('department')) {
              deptDisp = row['department']?.toString() ?? deptDisp;
            }
          } catch (_) {}
          try {
            final cval = (row['className'] ?? row['class'])?.toString();
            if (cval != null && _uuidRegex.hasMatch(cval)) {
              final cres = await _run(
                supabase
                    .from('classes')
                    .select('class_name')
                    .eq('id', cval)
                    .limit(1),
              );
              if (cres.error == null) {
                final cr = _asListOfMaps(cres.data);
                if (cr.isNotEmpty) {
                  classDisp =
                      (cr.first['class_name'] ?? cr.first['name'] ?? classDisp)
                          .toString();
                }
              }
            } else if (cval != null) {
              classDisp = cval;
            }
          } catch (_) {}

          final key = _sanitizedKey(deptDisp, classDisp);
          _timetableDocs[key] = row;
          return row;
        }
      }

      return null;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> saveTimetable(
    String depIdOrName,
    String classIdOrName,
    Map<String, dynamic> payload,
  ) async {
    // payload should contain keys matching your table schema: department, department_id, classKey, className, periods, spans, grid
    try {
      final deptDisplay = await resolveDepartmentDisplayName(depIdOrName);
      final classDisplay = await resolveClassDisplayName(classIdOrName);
      final sanitizedDocId = _sanitizedKey(deptDisplay, classDisplay);

      // Resolve current admin's faculty to scope DB lookups (used below
      // when searching courses/teachers by faculty). Some callers expect
      // queries to be limited to the admin's faculty to avoid cross-faculty
      // leaks. If unresolved, we keep it null and the subsequent queries
      // will omit the faculty filter where appropriate.
      String? resolvedFaculty;
      try {
        final depSvc = UseDepartments();
        resolvedFaculty = await depSvc.resolveAdminFacultyId();
      } catch (_) {
        resolvedFaculty = null;
      }

      // Pre-resolve dept/class ids so we can query schemas that store UUID FKs
      String? preResolvedDeptId;
      String? preResolvedClassId;
      try {
        if (_uuidRegex.hasMatch(depIdOrName)) preResolvedDeptId = depIdOrName;
        if (preResolvedDeptId == null) {
          for (final d in departments) {
            if ((d['name']?.toString() ?? '') == deptDisplay) {
              preResolvedDeptId = d['id']?.toString();
              break;
            }
          }
        }
        if (preResolvedDeptId == null) {
          final r = await _run(
            supabase
                .from('departments')
                .select('id')
                .ilike('department_name', deptDisplay)
                .limit(1),
          );
          if (r.error == null) {
            final rr = _asListOfMaps(r.data);
            if (rr.isNotEmpty) preResolvedDeptId = rr.first['id']?.toString();
          }
        }
      } catch (_) {}
      try {
        if (_uuidRegex.hasMatch(classIdOrName)) {
          preResolvedClassId = classIdOrName;
        }
        if (preResolvedClassId == null) {
          for (final c in classes) {
            if ((c['name']?.toString() ?? '') == classDisplay) {
              preResolvedClassId = c['id']?.toString();
              break;
            }
          }
        }
        if (preResolvedClassId == null) {
          final r = await _run(
            supabase
                .from('classes')
                .select('id')
                .ilike('class_name', classDisplay)
                .limit(1),
          );
          if (r.error == null) {
            final rr = _asListOfMaps(r.data);
            if (rr.isNotEmpty) preResolvedClassId = rr.first['id']?.toString();
          }
        }
      } catch (_) {}

      // Check if an existing row exists. Try multiple strategies depending on
      // whether the DB schema uses text fields (department/className) or UUID FKs
      // (department/class). Prefer the original 'timetables' query, but if that
      // errors due to missing columns, fall back to querying 'time_table' by ids.
      var q = await _run(
        supabase
            .from('timetables')
            .select('id')
            .eq('department', deptDisplay)
            .eq('className', classDisplay)
            .limit(1),
      );
      var targetTable = 'timetables';
      if (q.error != null) {
        // If table doesn't exist, try time_table using resolved ids
        if (_isMissingTableError(q.error) || _isMissingColumnError(q.error)) {
          // attempt time_table lookup by uuid fks if we have ids
          if (preResolvedDeptId != null && preResolvedClassId != null) {
            q = await _run(
              supabase
                  .from('time_table')
                  .select('id')
                  .eq('department', preResolvedDeptId)
                  .eq('class', preResolvedClassId)
                  .limit(1),
            );
            targetTable = 'time_table';
          } else {
            // try a time_table query by department display only (best-effort)
            q = await _run(
              supabase
                  .from('time_table')
                  .select('id')
                  .ilike('department', deptDisplay)
                  .limit(1),
            );
            targetTable = 'time_table';
          }
        }
      }
      if (q.error != null) throw q.error!;
      String? id;
      final qrows = _asListOfMaps(q.data);
      if (qrows.isNotEmpty) {
        final row = qrows.first;
        id = row['id']?.toString();
      } else {
        // try by sanitized id in id column, but only if it looks like a UUID.
        var docQ = _Resp(null, null);
        if (_uuidRegex.hasMatch(sanitizedDocId)) {
          docQ = await _run(
            supabase
                .from(targetTable)
                .select('id')
                .eq('id', sanitizedDocId)
                .limit(1),
          );
          if (docQ.error != null &&
              _isMissingTableError(docQ.error) &&
              targetTable == 'timetables') {
            docQ = await _run(
              supabase
                  .from('time_table')
                  .select('id')
                  .eq('id', sanitizedDocId)
                  .limit(1),
            );
            targetTable = 'time_table';
          }
        }
        if (docQ.error == null) {
          final docRows = _asListOfMaps(docQ.data);
          if (docRows.isNotEmpty) {
            final row = docRows.first;
            id = row['id']?.toString();
          }
        }
      }

      final now = DateTime.now().toIso8601String();
      final rowPayload = {
        ...payload,
        'department': deptDisplay,
        'department_id': depIdOrName,
        'classKey': classIdOrName,
        'className': classDisplay,
        'updated_at': now,
        'created_at': now,
      };

      // If the target table is the SQL `time_table` schema, adapt payload
      // keys to the expected column names to avoid "column does not exist"
      // Postgres errors. The `time_table` schema stores UUID FKs in
      // `class` and `department` columns and expects `sessions` jsonb.
      Map<String, dynamic> payloadForTarget = Map<String, dynamic>.from(
        rowPayload,
      );
      if (targetTable == 'time_table') {
        // Resolve department id: prefer the passed depIdOrName when it's a UUID,
        // otherwise try to find the department id from cache or the DB.
        String? resolvedDeptId;
        if (_uuidRegex.hasMatch(depIdOrName)) {
          resolvedDeptId = depIdOrName;
        } else {
          try {
            for (final d in departments) {
              if ((d['name']?.toString() ?? '') == deptDisplay) {
                resolvedDeptId = d['id']?.toString();
                break;
              }
            }
            if (resolvedDeptId == null) {
              final res = await _run(
                supabase
                    .from('departments')
                    .select('id')
                    .ilike('department_name', deptDisplay)
                    .limit(1),
              );
              if (res.error == null) {
                final rr = _asListOfMaps(res.data);
                if (rr.isNotEmpty) resolvedDeptId = rr.first['id']?.toString();
              }
            }
          } catch (_) {}
        }

        // Resolve class id: prefer classIdOrName when it's a UUID, otherwise
        // search the cached classes by display name or query DB.
        String? resolvedClassId;
        if (_uuidRegex.hasMatch(classIdOrName)) {
          resolvedClassId = classIdOrName;
        } else {
          try {
            for (final c in classes) {
              if ((c['name']?.toString() ?? '') == classDisplay) {
                resolvedClassId = c['id']?.toString();
                break;
              }
            }
            if (resolvedClassId == null) {
              final res = await _run(
                supabase
                    .from('classes')
                    .select('id')
                    .ilike('class_name', classDisplay)
                    .limit(1),
              );
              if (res.error == null) {
                final rr = _asListOfMaps(res.data);
                if (rr.isNotEmpty) resolvedClassId = rr.first['id']?.toString();
              }
            }
          } catch (_) {}
        }

        // Build sessions JSON from existing payload fields if present
        dynamic sessionsObj;
        try {
          sessionsObj = {
            if (payload.containsKey('periods')) 'periods': payload['periods'],
            if (payload.containsKey('spans')) 'spans': payload['spans'],
            if (payload.containsKey('grid')) 'grid': payload['grid'],
          };
        } catch (_) {
          sessionsObj = null;
        }

        // Compose the final payload expected by time_table
        // Ensure we send UUIDs for department/class when targeting time_table.
        String? deptVal =
            resolvedDeptId ?? rowPayload['department_id']?.toString();
        String? classVal =
            resolvedClassId ??
            rowPayload['classKey']?.toString() ??
            rowPayload['className']?.toString();

        // If we still don't have uuid ids, try DB lookups by common name fields.
        try {
          if (deptVal == null || !_uuidRegex.hasMatch(deptVal)) {
            final r = await _run(
              supabase
                  .from('departments')
                  .select('id,department_name,department_code,name')
                  .ilike('department_name', deptDisplay)
                  .limit(1),
            );
            if (r.error == null) {
              final rr = _asListOfMaps(r.data);
              if (rr.isNotEmpty) {
                deptVal = rr.first['id']?.toString();
              }
            }
            // try alternative fields
            if (deptVal == null) {
              final r2 = await _run(
                supabase
                    .from('departments')
                    .select('id')
                    .ilike('name', deptDisplay)
                    .limit(1),
              );
              if (r2.error == null) {
                final rr2 = _asListOfMaps(r2.data);
                if (rr2.isNotEmpty) deptVal = rr2.first['id']?.toString();
              }
            }
            if (deptVal == null) {
              final r3 = await _run(
                supabase
                    .from('departments')
                    .select('id')
                    .ilike('department_code', deptDisplay)
                    .limit(1),
              );
              if (r3.error == null) {
                final rr3 = _asListOfMaps(r3.data);
                if (rr3.isNotEmpty) deptVal = rr3.first['id']?.toString();
              }
            }
          }
        } catch (_) {}

        try {
          if (classVal == null || !_uuidRegex.hasMatch(classVal)) {
            final r = await _run(
              supabase
                  .from('classes')
                  .select('id,class_name,name')
                  .ilike('class_name', classDisplay)
                  .limit(1),
            );
            if (r.error == null) {
              final rr = _asListOfMaps(r.data);
              if (rr.isNotEmpty) classVal = rr.first['id']?.toString();
            }
            if (classVal == null) {
              final r2 = await _run(
                supabase
                    .from('classes')
                    .select('id')
                    .ilike('name', classDisplay)
                    .limit(1),
              );
              if (r2.error == null) {
                final rr2 = _asListOfMaps(r2.data);
                if (rr2.isNotEmpty) classVal = rr2.first['id']?.toString();
              }
            }
          }
        } catch (_) {}

        // If we still don't have UUIDs, abort with a clear error rather than
        // sending a human name into a UUID column which causes Postgres 22P02.
        if (deptVal == null || !_uuidRegex.hasMatch(deptVal)) {
          throw Exception(
            'Could not resolve department id for "$deptDisplay". Resolved value: $deptVal',
          );
        }
        if (classVal == null || !_uuidRegex.hasMatch(classVal)) {
          throw Exception(
            'Could not resolve class id for "$classDisplay". Resolved value: $classVal',
          );
        }

        // Resolve faculty_id to a UUID when possible. The UI sometimes passes
        // a display name (e.g. "Computer Science") which must not be written
        // into a UUID column. Prefer an explicit UUID if provided, otherwise
        // derive it from the department row (if the department has a faculty_id).
        String? resolvedFacultyId;
        try {
          final rawFaculty = rowPayload['faculty_id'];
          if (rawFaculty != null) {
            final fstr = rawFaculty.toString();
            if (_uuidRegex.hasMatch(fstr)) {
              resolvedFacultyId = fstr;
            } else {
              // try to derive from department row (deptVal is a UUID at this point)
              try {
                final fres = await _run(
                  supabase
                      .from('departments')
                      .select('faculty_id')
                      .eq('id', deptVal)
                      .limit(1),
                );
                if (fres.error == null) {
                  final fr = _asListOfMaps(fres.data);
                  if (fr.isNotEmpty) {
                    final cand = fr.first['faculty_id']?.toString();
                    if (cand != null && _uuidRegex.hasMatch(cand)) {
                      resolvedFacultyId = cand;
                    }
                  }
                }
              } catch (_) {}
            }
          } else {
            // no explicit faculty_id provided; attempt to derive from dept
            try {
              final fres = await _run(
                supabase
                    .from('departments')
                    .select('faculty_id')
                    .eq('id', deptVal)
                    .limit(1),
              );
              if (fres.error == null) {
                final fr = _asListOfMaps(fres.data);
                if (fr.isNotEmpty) {
                  final cand = fr.first['faculty_id']?.toString();
                  if (cand != null && _uuidRegex.hasMatch(cand)) {
                    resolvedFacultyId = cand;
                  }
                }
              }
            } catch (_) {}
          }
        } catch (_) {}

        final Map<String, dynamic> tt = {
          'department': deptVal,
          'class': classVal,
          'updated_at': now,
          'created_at': now,
        };
        if (resolvedFacultyId != null &&
            _uuidRegex.hasMatch(resolvedFacultyId)) {
          tt['faculty_id'] = resolvedFacultyId;
        }
        if (sessionsObj != null && (sessionsObj as Map).isNotEmpty) {
          // Build sessions as a list of entries {day, start, end, course, teacher}
          final List<Map<String, dynamic>> sessionsEntries = [];
          try {
            final mapObj = sessionsObj as Map<String, dynamic>;
            final spansList = mapObj['spans'] as List? ?? [];
            final gridList = mapObj['grid'] as List? ?? [];

            for (final rowObj in gridList) {
              try {
                if (rowObj is Map &&
                    rowObj.containsKey('r') &&
                    rowObj['cells'] is List) {
                  final int dayIndex = (rowObj['r'] is int)
                      ? rowObj['r'] as int
                      : 0;
                  final List cells = rowObj['cells'] as List;
                  for (int col = 0; col < cells.length; col++) {
                    final cellRaw = (cells[col] ?? '').toString();
                    final text = cellRaw.trim();
                    if (text.isEmpty) continue;
                    if (text.toLowerCase().contains('break')) continue;

                    // Determine start/end minutes for this column using spans if available
                    int startMin = 0;
                    int endMin = 0;
                    try {
                      if (col < spansList.length && spansList[col] is Map) {
                        startMin =
                            (spansList[col]['start'] as num?)?.toInt() ?? 0;
                        endMin = (spansList[col]['end'] as num?)?.toInt() ?? 0;
                      }
                    } catch (_) {}

                    // Parse course and teacher from cell text (first line = course, second line = teacher)
                    String? courseVal;
                    String? teacherVal;
                    try {
                      final parts = text.split('\n');
                      if (parts.isNotEmpty) courseVal = parts[0].trim();
                      if (parts.length > 1) {
                        teacherVal = parts.sublist(1).join(' ').trim();
                      }
                    } catch (_) {}

                    // Try to resolve to UUIDs when possible (teachers/courses caches or DB)
                    String? courseIdResolved;
                    String? teacherIdResolved;
                    try {
                      if (courseVal != null && courseVal.isNotEmpty) {
                        if (_uuidRegex.hasMatch(courseVal)) {
                          courseIdResolved = courseVal;
                        } else {
                          // check cached courses
                          for (final c in courses) {
                            try {
                              final name = (c['name']?.toString() ?? '')
                                  .toLowerCase();
                              if (name == courseVal.toLowerCase()) {
                                courseIdResolved = c['id']?.toString();
                                break;
                              }
                            } catch (_) {}
                          }
                          if (courseIdResolved == null) {
                            // Build query and conditionally apply faculty filter
                            var q0 = supabase
                                .from('courses')
                                .select('id')
                                .ilike('course_name', courseVal);
                            q0 = _applyFacultyFilter(q0, resolvedFaculty);
                            final cres = await _run(q0.limit(1));
                            if (cres.error == null) {
                              final cr = _asListOfMaps(cres.data);
                              if (cr.isNotEmpty) {
                                courseIdResolved = cr.first['id']?.toString();
                              }
                            }
                          }
                        }
                      }
                    } catch (_) {}

                    try {
                      if (teacherVal != null && teacherVal.isNotEmpty) {
                        if (_uuidRegex.hasMatch(teacherVal)) {
                          teacherIdResolved = teacherVal;
                        } else {
                          for (final t in teachers) {
                            try {
                              final name = (t['name']?.toString() ?? '')
                                  .toLowerCase();
                              if (name == teacherVal.toLowerCase()) {
                                teacherIdResolved = t['id']?.toString();
                                break;
                              }
                            } catch (_) {}
                          }
                          if (teacherIdResolved == null) {
                            final tres = await _run(
                              supabase
                                  .from('teachers')
                                  .select('id')
                                  .ilike('teacher_name', teacherVal)
                                  .limit(1),
                            );
                            if (tres.error == null) {
                              final tr = _asListOfMaps(tres.data);
                              if (tr.isNotEmpty) {
                                teacherIdResolved = tr.first['id']?.toString();
                              }
                            }
                          }
                        }
                      }
                    } catch (_) {}

                    final entry = <String, dynamic>{
                      'day': dayIndex,
                      'start': startMin,
                      'end': endMin,
                      if (courseIdResolved != null) 'course': courseIdResolved,
                      // If we couldn't resolve a UUID for course, store the
                      // human-readable name under `course_name` instead of
                      // writing a display name into a column that may be a
                      // UUID in the DB. This prevents toggling between name
                      // and uuid on subsequent reads/writes.
                      if (courseIdResolved == null &&
                          courseVal != null &&
                          courseVal.isNotEmpty)
                        'course_name': courseVal,
                      if (teacherIdResolved != null)
                        'teacher': teacherIdResolved,
                      // Same for teacher: keep unresolved teacher names in a
                      // separate key so we don't accidentally write a name
                      // into a UUID column.
                      if (teacherIdResolved == null &&
                          teacherVal != null &&
                          teacherVal.isNotEmpty)
                        'teacher_name': teacherVal,
                    };
                    sessionsEntries.add(entry);
                  }
                }
              } catch (_) {}
            }
          } catch (_) {}

          if (sessionsEntries.isNotEmpty) {
            tt['sessions'] = {'sessions': sessionsEntries};

            // Promote first non-null resolved course/teacher from sessions to
            // top-level fields so the table's `course` and `teacher` UUID
            // columns are populated when available.
            try {
              String? topCourse;
              String? topTeacher;
              for (final s in sessionsEntries) {
                try {
                  if (topCourse == null && s.containsKey('course')) {
                    final v = s['course']?.toString();
                    if (v != null && v.isNotEmpty) {
                      // prefer UUIDs
                      if (_uuidRegex.hasMatch(v)) {
                        topCourse = v;
                      } else {
                        topCourse ??= v;
                      }
                    }
                  }
                  if (topTeacher == null && s.containsKey('teacher')) {
                    final v = s['teacher']?.toString();
                    if (v != null && v.isNotEmpty) {
                      if (_uuidRegex.hasMatch(v)) {
                        topTeacher = v;
                      } else {
                        topTeacher ??= v;
                      }
                    }
                  }
                } catch (_) {}
                if (topCourse != null && topTeacher != null) break;
              }
              if (topCourse != null && _uuidRegex.hasMatch(topCourse)) {
                tt['course'] = topCourse;
              }
              if (topTeacher != null && _uuidRegex.hasMatch(topTeacher)) {
                tt['teacher'] = topTeacher;
              }
            } catch (_) {}
          } else {
            // fallback: keep the original sessions object
            tt['sessions'] = sessionsObj;
          }
        }

        // compute break_time (duration in minutes) if any period contains 'break'
        try {
          int? breakTimeVal;
          final mapObj2 = sessionsObj as Map<String, dynamic>;
          final periodsList2 = mapObj2['periods'] as List? ?? [];
          final spansList2 = mapObj2['spans'] as List? ?? [];
          for (int i = 0; i < periodsList2.length; i++) {
            final p = (periodsList2[i] ?? '').toString().toLowerCase();
            if (p.contains('break')) {
              if (i < spansList2.length && spansList2[i] is Map) {
                final s = (spansList2[i]['start'] as num?)?.toInt() ?? 0;
                final e = (spansList2[i]['end'] as num?)?.toInt() ?? 0;
                breakTimeVal = (e - s).abs();
                break;
              }
            }
          }
          if (breakTimeVal != null) tt['break_time'] = breakTimeVal;
        } catch (_) {}

        // Resolve teacher/course fields to UUIDs when possible (database_schema uses UUID FKs)
        // Accept either UUIDs already provided in payload, or names that we can look up.
        try {
          // teacher: could be uuid string or display name
          if (rowPayload.containsKey('teacher') &&
              rowPayload['teacher'] != null) {
            final tval = rowPayload['teacher'].toString();
            if (_uuidRegex.hasMatch(tval)) {
              tt['teacher'] = tval;
            } else {
              // try to find teacher by name or teacher_name
              // ensure teachers cache is loaded
              if (teachers.isEmpty) await loadTeachers();
              String? teacherId;
              for (final t in teachers) {
                try {
                  final name = (t['name']?.toString() ?? '').toLowerCase();
                  if (name == tval.toLowerCase()) {
                    teacherId = t['id']?.toString();
                    break;
                  }
                } catch (_) {}
              }
              if (teacherId == null) {
                // try DB lookup
                final tres = await _run(
                  supabase
                      .from('teachers')
                      .select('id')
                      .ilike('teacher_name', tval)
                      .limit(1),
                );
                if (tres.error == null) {
                  final tr = _asListOfMaps(tres.data);
                  if (tr.isNotEmpty) teacherId = tr.first['id']?.toString();
                }
              }
              if (teacherId != null && _uuidRegex.hasMatch(teacherId)) {
                tt['teacher'] = teacherId;
              } else {
                // if we cannot resolve teacher to uuid, omit the field rather than sending a name into uuid column
                debugPrint(
                  'saveTimetable: could not resolve teacher "$tval" to uuid; omitting teacher field',
                );
              }
            }
          }

          // course: could be uuid string or course_name/course_code
          if (rowPayload.containsKey('course') &&
              rowPayload['course'] != null) {
            final cval = rowPayload['course'].toString();
            if (_uuidRegex.hasMatch(cval)) {
              tt['course'] = cval;
            } else {
              String? courseId;
              // try cached courses (if loaded)
              for (final c in courses) {
                try {
                  final name = (c['name']?.toString() ?? '').toLowerCase();
                  if (name == cval.toLowerCase()) {
                    courseId = c['id']?.toString();
                    break;
                  }
                } catch (_) {}
              }
              if (courseId == null) {
                // try DB lookup by course_name or course_code
                var q2 = supabase
                    .from('courses')
                    .select('id')
                    .or("course_name.ilike.$cval,course_code.ilike.$cval");
                q2 = _applyFacultyFilter(q2, resolvedFaculty);
                final cres = await _run(q2.limit(1));
                if (cres.error == null) {
                  final cr = _asListOfMaps(cres.data);
                  if (cr.isNotEmpty) courseId = cr.first['id']?.toString();
                }
              }
              if (courseId != null && _uuidRegex.hasMatch(courseId)) {
                tt['course'] = courseId;
              } else {
                debugPrint(
                  'saveTimetable: could not resolve course "$cval" to uuid; omitting course field',
                );
              }
            }
          }
        } catch (_) {}

        payloadForTarget = tt;
      }

      // Debug: print the final payload and target table so we can match DB schema
      try {
        debugPrint(
          '[UseTimetable.saveTimetable] targetTable=$targetTable payload=${jsonEncode(payloadForTarget)}',
        );
      } catch (_) {}

      if (id != null && id.isNotEmpty) {
        // update existing on the resolved target table
        final res = await _run(
          supabase.from(targetTable).update(payloadForTarget).eq('id', id),
        );
        if (res.error != null) throw res.error!;
        _timetableDocs[id] = payloadForTarget;
      } else {
        // insert new - use resolved targetTable
        final res = await _run(
          supabase.from(targetTable).insert(payloadForTarget),
        );
        if (res.error != null) throw res.error!;
        final insertedRows = _asListOfMaps(res.data);
        final inserted = insertedRows.isNotEmpty
            ? insertedRows.first
            : <String, dynamic>{};
        final newId = inserted['id']?.toString() ?? sanitizedDocId;
        _timetableDocs[newId] = inserted;
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteTimetableByDeptClass(
    String depIdOrName,
    String classIdOrName, {
    bool deleteEntireClass = true,
  }) async {
    try {
      final deptDisplay = await resolveDepartmentDisplayName(depIdOrName);
      final classDisplay = await resolveClassDisplayName(classIdOrName);
      debugPrint(
        '[UseTimetable.deleteTimetableByDeptClass] dep="$deptDisplay" class="$classDisplay" deleteEntireClass=$deleteEntireClass',
      );

      // find id. Try multiple lookup strategies to support different schemas
      String? preResolvedDeptId;
      String? preResolvedClassId;
      try {
        if (_uuidRegex.hasMatch(depIdOrName)) preResolvedDeptId = depIdOrName;
        if (preResolvedDeptId == null) {
          for (final d in departments) {
            if ((d['name']?.toString() ?? '') == deptDisplay) {
              preResolvedDeptId = d['id']?.toString();
              break;
            }
          }
        }
      } catch (_) {}
      try {
        if (_uuidRegex.hasMatch(classIdOrName)) {
          preResolvedClassId = classIdOrName;
        }
        if (preResolvedClassId == null) {
          for (final c in classes) {
            if ((c['name']?.toString() ?? '') == classDisplay) {
              preResolvedClassId = c['id']?.toString();
              break;
            }
          }
        }
      } catch (_) {}

      var q = await _run(
        supabase
            .from('timetables')
            .select('id')
            .eq('department', deptDisplay)
            .eq('className', classDisplay)
            .limit(1),
      );
      var targetTable = 'timetables';
      if (q.error != null &&
          (_isMissingTableError(q.error) || _isMissingColumnError(q.error))) {
        if (preResolvedDeptId != null && preResolvedClassId != null) {
          q = await _run(
            supabase
                .from('time_table')
                .select('id')
                .eq('department', preResolvedDeptId)
                .eq('class', preResolvedClassId)
                .limit(1),
          );
          targetTable = 'time_table';
        } else {
          q = await _run(
            supabase
                .from('time_table')
                .select('id')
                .ilike('department', deptDisplay)
                .limit(1),
          );
          targetTable = 'time_table';
        }
      }
      if (q.error != null) throw q.error!;
      final qrows = _asListOfMaps(q.data);
      if (qrows.isEmpty) {
        throw Exception('No timetable found for the selected class');
      }
      final id = qrows.first['id'].toString();
      if (deleteEntireClass) {
        final res = await _run(
          supabase.from(targetTable).delete().eq('id', id),
        );
        if (res.error != null) throw res.error!;
        _timetableDocs.remove(id);
      } else {
        // clear grid only
        final res = await _run(
          supabase
              .from(targetTable)
              .update({
                'grid': jsonEncode([]),
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', id),
        );
        if (res.error != null) throw res.error!;
        _timetableDocs.remove(id);
      }
    } catch (e) {
      rethrow;
    }
  }

  // ----------------- Helpers -----------------
  Future<String> resolveDepartmentDisplayName(String depIdOrName) async {
    final s = depIdOrName.toString().trim();
    if (s.isEmpty) return s;
    // Avoid `firstWhere(..., orElse: ...)` generic mismatches on DDC by
    // performing an explicit search. This sidesteps Map<String,dynamic>
    // vs Map<String,Object> covariance issues in the JS runtime.
    Map<String, dynamic>? found;
    for (final d in departments) {
      final idStr = (d['id']?.toString() ?? '');
      final nameStr = (d['name']?.toString() ?? '').toLowerCase();
      if (idStr == s || nameStr == s.toLowerCase()) {
        found = d;
        break;
      }
    }
    if (found != null && found.isNotEmpty) {
      return (found['name'] ?? s).toString();
    }
    // try lookup by id in table
    try {
      final res = await _run(
        supabase.from('departments').select().eq('id', s).limit(1),
      );
      if (res.error == null) {
        final rows = _asListOfMaps(res.data);
        if (rows.isNotEmpty) {
          final row = rows.first;
          final name =
              (row['department_name'] ??
                      row['name'] ??
                      row['displayName'] ??
                      '')
                  .toString();
          if (name.isNotEmpty) return name;
        }
      }
    } catch (_) {}
    return s;
  }

  Future<String> resolveClassDisplayName(String classIdOrName) async {
    final s = classIdOrName.toString().trim();
    if (s.isEmpty) return s;
    Map<String, dynamic>? found;
    for (final c in classes) {
      final idStr = (c['id']?.toString() ?? '');
      final nameStr = (c['name']?.toString() ?? '').toLowerCase();
      if (idStr == s || nameStr == s.toLowerCase()) {
        found = c;
        break;
      }
    }
    if (found != null && found.isNotEmpty) {
      return (found['name'] ?? s).toString();
    }
    // try lookup
    try {
      final res = await _run(
        supabase.from('classes').select().eq('id', s).limit(1),
      );
      if (res.error == null) {
        final rows = _asListOfMaps(res.data);
        if (rows.isNotEmpty) {
          final row = rows.first;
          final name = (row['class_name'] ?? row['name'] ?? '').toString();
          if (name.isNotEmpty) return name;
        }
      }
    } catch (_) {}
    return s;
  }

  /// Resolve a course display name from an id or name.
  Future<String> resolveCourseDisplayName(String courseIdOrName) async {
    final s = courseIdOrName.toString().trim();
    if (s.isEmpty) return s;
    // check cache first
    for (final c in courses) {
      final idStr = (c['id']?.toString() ?? '');
      final nameStr = (c['name']?.toString() ?? '').toLowerCase();
      if (idStr == s || nameStr == s.toLowerCase()) {
        return (c['name'] ?? s).toString();
      }
    }
    // try lookup in DB
    try {
      // if looks like uuid, try id lookup first
      if (_uuidRegex.hasMatch(s)) {
        final r = await _run(
          supabase
              .from('courses')
              .select('course_name,name,course_code')
              .eq('id', s)
              .limit(1),
        );
        if (r.error == null) {
          final rr = _asListOfMaps(r.data);
          if (rr.isNotEmpty) {
            return (rr.first['course_name'] ??
                    rr.first['name'] ??
                    rr.first['course_code'] ??
                    s)
                .toString();
          }
        }
      }

      final q = '%${s.replaceAll('%', '').trim()}%';
      final res = await _run(
        supabase
            .from('courses')
            .select('course_name,name,course_code')
            .or('course_name.ilike.$q,course_code.ilike.$q,name.ilike.$q')
            .limit(1),
      );
      if (res.error == null) {
        final rr = _asListOfMaps(res.data);
        if (rr.isNotEmpty) {
          return (rr.first['course_name'] ??
                  rr.first['name'] ??
                  rr.first['course_code'] ??
                  s)
              .toString();
        }
      }
    } catch (_) {}
    return s;
  }

  /// Return a flattened schedule list for the selected teacher (id or display name).
  /// Each entry contains: day (int), dayName, time (start-end as string), start (minutes), end (minutes), course, className, department
  Future<List<Map<String, dynamic>>> getTeacherSchedule(
    String teacherIdOrName,
  ) async {
    final List<Map<String, dynamic>> out = [];
    try {
      final rows = await findTimetablesByTeacher(teacherIdOrName);
      if (rows.isEmpty) return out;

      String dayName(int d) {
        // Align day indices with UI convention: 0=Sat,1=Sun,2=Mon,...
        const names = ['Sat', 'Sun', 'Mon', 'Tue', 'Wed', 'Thu'];
        if (d < 0 || d >= names.length) return d.toString();
        return names[d];
      }

      String minsToTime(int mins) {
        try {
          final h = (mins ~/ 60).toString();
          final m = (mins % 60).toString().padLeft(2, '0');
          return '$h:$m';
        } catch (_) {
          return mins.toString();
        }
      }

      for (final r in rows) {
        try {
          // Prefer sessions structure
          if (r.containsKey('sessions')) {
            final sess = r['sessions'];
            List<dynamic> sessList = [];
            if (sess is Map && sess.containsKey('sessions')) {
              try {
                sessList = (sess['sessions'] as List).toList();
              } catch (_) {
                sessList = [];
              }
            } else if (sess is List) {
              sessList = sess;
            }
            for (final s in sessList) {
              try {
                final rawDay = (s['day'] is int)
                    ? s['day'] as int
                    : (int.tryParse(s['day']?.toString() ?? '') ?? 0);
                // normalize day index: accept either 0-based (0..5) or 1-based (1..6)
                int day;
                if (rawDay >= 0 && rawDay <= 5) {
                  day = rawDay;
                } else if (rawDay >= 1 && rawDay <= 6) {
                  day = rawDay - 1;
                } else {
                  final m = rawDay % 7;
                  day = (m >= 0 && m <= 5) ? m : 5;
                }
                final start = (s['start'] is num)
                    ? (s['start'] as num).toInt()
                    : (int.tryParse(s['start']?.toString() ?? '') ?? 0);
                final end = (s['end'] is num)
                    ? (s['end'] as num).toInt()
                    : (int.tryParse(s['end']?.toString() ?? '') ?? 0);
                final course =
                    (s['course_name'] ?? s['course'] ?? s['title'] ?? '')
                        .toString();
                final className =
                    (r['className'] ?? r['class'] ?? r['classKey'] ?? '')
                        .toString();
                final dept = (r['department'] ?? r['department_id'] ?? '')
                    .toString();

                out.add({
                  'day': day,
                  'dayName': dayName(day),
                  'time': '${minsToTime(start)} - ${minsToTime(end)}',
                  'start': start,
                  'end': end,
                  'course': course,
                  'className': className,
                  'department': dept,
                });
              } catch (_) {}
            }
          } else if (r.containsKey('grid')) {
            // fallback: parse grid+spans if sessions not present
            try {
              final spansRaw = (r['spans'] is List) ? r['spans'] as List : [];
              final spansList = spansRaw.map((e) {
                try {
                  return {
                    'start': (e['start'] as num?)?.toInt() ?? 0,
                    'end': (e['end'] as num?)?.toInt() ?? 0,
                  };
                } catch (_) {
                  return {'start': 0, 'end': 0};
                }
              }).toList();
              final gridRaw = (r['grid'] is List) ? r['grid'] as List : [];
              for (final rowObj in gridRaw) {
                try {
                  if (rowObj is Map && rowObj['cells'] is List) {
                    final int dayIndex = (rowObj['r'] is int)
                        ? rowObj['r'] as int
                        : 0;
                    final List cells = rowObj['cells'] as List;
                    for (int col = 0; col < cells.length; col++) {
                      try {
                        final cellRaw = (cells[col] ?? '').toString().trim();
                        if (cellRaw.isEmpty) continue;
                        if (cellRaw.toLowerCase().contains('break')) continue;
                        final parts = cellRaw.split('\n');
                        final course = parts.isNotEmpty ? parts[0] : '';
                        final teacher = parts.length > 1
                            ? parts.sublist(1).join(' ')
                            : '';
                        // only add rows that reference the requested teacher
                        final tid = teacherIdOrName;
                        bool matched = false;
                        if (_uuidRegex.hasMatch(tid)) {
                          if (teacher.contains(tid)) matched = true;
                        } else {
                          if (teacher.toLowerCase().contains(
                            tid.toLowerCase(),
                          )) {
                            matched = true;
                          }
                        }
                        if (!matched) continue;
                        final span = (col < spansList.length)
                            ? spansList[col]
                            : {'start': 0, 'end': 0};
                        out.add({
                          'day': dayIndex,
                          'dayName': dayName(dayIndex),
                          'time':
                              '${minsToTime(span['start'] ?? 0)} - ${minsToTime(span['end'] ?? 0)}',
                          'start': span['start'] ?? 0,
                          'end': span['end'] ?? 0,
                          'course': course,
                          'className':
                              (r['className'] ??
                                      r['class'] ??
                                      r['classKey'] ??
                                      '')
                                  .toString(),
                          'department':
                              (r['department'] ?? r['department_id'] ?? '')
                                  .toString(),
                        });
                      } catch (_) {}
                    }
                  }
                } catch (_) {}
              }
            } catch (_) {}
          }
        } catch (_) {}
      }

      return out;
    } catch (e) {
      rethrow;
    }
  }

  // ----------------- Period config persistence -----------------
  /// Persist period configuration for a class. Will insert or update a
  /// small per-class table `class_period_configs` with columns:
  /// (id uuid, class_id uuid, department_id uuid, faculty_id uuid, periods jsonb, spans jsonb, created_at timestamptz, updated_at timestamptz)
  Future<void> createPeriodConfiguration(
    String classId,
    String departmentId,
    List<String> periods,
    List<Map<String, int>> spans,
  ) async {
    try {
      if (classId.trim().isEmpty) return;
      // try to resolve faculty id if possible
      String? resolvedFaculty;
      try {
        final depSvc = UseDepartments();
        resolvedFaculty = await depSvc.resolveAdminFacultyId();
      } catch (_) {
        resolvedFaculty = null;
      }

      final payload = {
        'class_id': classId,
        'department_id': departmentId,
        if (resolvedFaculty != null) 'faculty_id': resolvedFaculty,
        'periods': periods,
        'spans': spans,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Try update if exists
      try {
        final q = await _run(
          supabase
              .from('class_period_configs')
              .select('id')
              .eq('class_id', classId)
              .limit(1),
        );
        if (q.error == null) {
          final rows = _asListOfMaps(q.data);
          if (rows.isNotEmpty) {
            await _run(
              supabase
                  .from('class_period_configs')
                  .update(payload)
                  .eq('class_id', classId),
            );
            return;
          }
        }
      } catch (_) {}

      // insert new
      try {
        await _run(supabase.from('class_period_configs').insert(payload));
      } catch (e) {
        // if table missing, silently ignore (caller falls back to timetable row storage)
        if (!_isMissingTableError(e)) rethrow;
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Fetch saved period labels for a given class id (if any).
  Future<List<String>?> getPeriodConfiguration(String classId) async {
    try {
      if (classId.trim().isEmpty) return null;
      final res = await _run(
        supabase
            .from('class_period_configs')
            .select('periods')
            .eq('class_id', classId)
            .limit(1),
      );
      if (res.error != null) {
        if (_isMissingTableError(res.error)) return null;
        throw res.error!;
      }
      final rows = _asListOfMaps(res.data);
      if (rows.isEmpty) return null;
      final p = rows.first['periods'];
      if (p is List) return p.map((e) => e?.toString() ?? '').toList();
      return null;
    } catch (_) {
      return null;
    }
  }

  // ----------------- Auto-assign teacher -----------------
  /// Given a course id, try to fetch `teacher_assigned` from `courses` table
  /// and resolve the teacher's display name. Returns map {id,name} or null.
  Future<Map<String, String>?> autoAssignTeacher(String courseId) async {
    try {
      if (courseId.trim().isEmpty) return null;
      // fetch course row
      final res = await _run(
        supabase
            .from('courses')
            .select('teacher_assigned')
            .eq('id', courseId)
            .limit(1),
      );
      if (res.error != null) {
        if (_isMissingTableError(res.error)) return null;
        throw res.error!;
      }
      final rows = _asListOfMaps(res.data);
      if (rows.isEmpty) return null;
      final tid = rows.first['teacher_assigned']?.toString();
      if (tid == null || tid.isEmpty) return null;
      // resolve teacher name from cache or DB
      try {
        for (final t in teachers) {
          try {
            if ((t['id']?.toString() ?? '') == tid) {
              final name = (t['name'] ?? t['teacher_name'] ?? '').toString();
              return {'id': tid, 'name': name};
            }
          } catch (_) {}
        }
      } catch (_) {}
      // DB lookup
      final tres = await _run(
        supabase
            .from('teachers')
            .select('teacher_name,name')
            .eq('id', tid)
            .limit(1),
      );
      if (tres.error == null) {
        final tr = _asListOfMaps(tres.data);
        if (tr.isNotEmpty) {
          final name = (tr.first['teacher_name'] ?? tr.first['name'] ?? '')
              .toString();
          return {'id': tid, 'name': name};
        }
      }
      return {'id': tid, 'name': tid};
    } catch (_) {
      return null;
    }
  }

  // ----------------- Internal helpers for faculty filtering/dedupe -----------------

  // Deduplicate by id and ensure each row belongs to resolvedFaculty (best-effort)
  Future<List<Map<String, dynamic>>> _dedupeAndFilterByFaculty(
    List<Map<String, dynamic>> rows,
    String? resolvedFaculty,
  ) async {
    final seen = <String>{};
    final out = <Map<String, dynamic>>[];
    for (final r in rows) {
      try {
        final id = (r['id']?.toString() ?? '');
        if (id.isEmpty) continue;
        if (seen.contains(id)) continue;
        seen.add(id);
        final ok = await _rowBelongsToFaculty(r, resolvedFaculty);
        if (ok) out.add(r);
      } catch (_) {}
    }
    return out;
  }

  // Best-effort check whether a timetable row belongs to a faculty.
  // Returns true only if it's provable; otherwise false.
  Future<bool> _rowBelongsToFaculty(
    Map<String, dynamic> row,
    String? facultyId,
  ) async {
    try {
      // If no faculty id is provided, allow when in unscoped debug mode,
      // otherwise conservatively deny (to avoid cross-faculty reads).
      if (facultyId == null || facultyId.isEmpty) {
        return allowUnscoped;
      }
      // If the row itself has faculty_id and it matches -> ok
      try {
        final f = (row['faculty_id'] ?? row['faculty'])?.toString();
        if (f != null && f.isNotEmpty) {
          if (f == facultyId) return true;
        }
      } catch (_) {}

      // If row has department_id or department that looks like uuid -> check departments table
      try {
        final depCandidate = (row['department_id'] ?? row['department'])
            ?.toString();
        if (depCandidate != null &&
            depCandidate.isNotEmpty &&
            _uuidRegex.hasMatch(depCandidate)) {
          final res = await _run(
            supabase
                .from('departments')
                .select('faculty_id')
                .eq('id', depCandidate)
                .limit(1),
          );
          if (res.error == null) {
            final dr = _asListOfMaps(res.data);
            if (dr.isNotEmpty) {
              final fid = dr.first['faculty_id']?.toString();
              if (fid != null && fid == facultyId) return true;
              return false;
            }
          }
        }
      } catch (_) {}

      // If row has class id -> check classes.faculty_id
      try {
        final clsCandidate =
            (row['class'] ?? row['classKey'] ?? row['className'])?.toString();
        if (clsCandidate != null &&
            clsCandidate.isNotEmpty &&
            _uuidRegex.hasMatch(clsCandidate)) {
          final cres = await _run(
            supabase
                .from('classes')
                .select('faculty_id')
                .eq('id', clsCandidate)
                .limit(1),
          );
          if (cres.error == null) {
            final cr = _asListOfMaps(cres.data);
            if (cr.isNotEmpty) {
              final fid = cr.first['faculty_id']?.toString();
              if (fid != null && fid == facultyId) return true;
              return false;
            }
          }
        }
      } catch (_) {}

      // Conservative default: if we cannot prove membership, treat as not belonging.
      return false;
    } catch (_) {
      return false;
    }
  }

  // ----------------- Utility functions used earlier -----------------

  String _sanitizedKey(String dep, String cls) {
    String sanitize(String s) {
      var t = s.trim().toLowerCase();
      t = t.replaceAll(RegExp(r'\s+'), '_');
      t = t.replaceAll(RegExp(r'[^\w\-]'), '');
      return t;
    }

    return '${sanitize(dep)}_${sanitize(cls)}';
  }

  // -------------- _run helper and error checks --------------
  // You may already have these helpers in your environment; if not, use these.

  Future<_Resp> _run(dynamic query) async {
    try {
      final res = await query;
      // Supabase responses may have {data: ..., error: ...} or return List directly
      if (res is PostgrestResponse) {
        // Some PostgrestResponse types may not expose strongly-typed accessors
        // in all versions; use dynamic access to avoid compile-time getter
        // mismatches across package versions.
        final dyn = res as dynamic;
        return _Resp(dyn.data, dyn.error);
      }
      if (res is Map && res.containsKey('data')) {
        return _Resp(res['data'], res['error']);
      }
      return _Resp(res, null);
    } catch (e) {
      // Convert to _Resp with error
      return _Resp(null, e);
    }
  }

  bool _isMissingTableError(dynamic e) {
    try {
      final s = e.toString().toLowerCase();
      // Known patterns from Postgres/PostgREST/Supabase errors:
      // - "relation \"...\" does not exist"
      // - "could not find the table 'public.timetables' in the schema cache"
      // - PostgREST codes like PGRST205 may appear in messages
      final relMissing = s.contains('relation') && s.contains('does not exist');
      final couldNotFindTable =
          s.contains('could not find') && s.contains('table');
      final pgrstHint =
          s.contains('pgrst') || s.contains('perhaps you meant the table');
      final invalidUuid =
          s.contains('invalid input') && s.contains('uuid'); // defensive
      return relMissing || couldNotFindTable || pgrstHint || invalidUuid;
    } catch (_) {
      return false;
    }
  }

  bool _isMissingColumnError(dynamic e) {
    try {
      final s = e.toString().toLowerCase();
      return s.contains('column') && s.contains('does not exist') ||
          s.contains('undefined column');
    } catch (_) {
      return false;
    }
  }

  // Apply faculty scoping to a Postgrest query builder when a resolved
  // faculty id is available. If `allowUnscoped` is true and no faculty is
  // resolved, this function returns the query unchanged so callers can
  // perform unscoped development queries.
  dynamic _applyFacultyFilter(dynamic query, String? resolvedFaculty) {
    try {
      if (allowUnscoped) return query;
      if (resolvedFaculty != null && resolvedFaculty.isNotEmpty) {
        return query.eq('faculty_id', resolvedFaculty);
      }
      return query;
    } catch (_) {
      return query;
    }
  }
}
