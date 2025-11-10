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

  // Timetable "documents" cache keyed by sanitized '<dept>_<class>'
  final Map<String, Map<String, dynamic>> _timetableDocs = {};

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
      // exposing other faculties' departments in the UI.
      if (resolvedFaculty == null || resolvedFaculty.isEmpty) {
        departments = [];
        return;
      }

      final res = await _run(
        supabase
            .from('departments')
            .select()
            .eq('faculty_id', resolvedFaculty)
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

      // Prefer exact UUID match on top-level `teacher` column.
      if (_uuidRegex.hasMatch(teacherIdOrName)) {
        var res = await _run(
          supabase.from('time_table').select().eq('teacher', teacherIdOrName),
        );
        debugPrint(
          '[UseTimetable.findTimetablesByTeacher] UUID branch query result error=${res.error}',
        );
        if (res.error != null && _isMissingTableError(res.error)) {
          // try alternate table
          res = await _run(
            supabase.from('timetables').select().eq('teacher', teacherIdOrName),
          );
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
        final res2 = await _run(
          supabase
              .from('time_table')
              .select()
              .ilike('sessions', '%$teacherIdOrName%'),
        );
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
        // dedupe by id
        final seen = <String>{};
        return out.where((r) {
          final id = (r['id']?.toString() ?? '');
          if (id.isEmpty) return false;
          if (seen.contains(id)) return false;
          seen.add(id);
          return true;
        }).toList();
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
                  if (tid != null && tid.isNotEmpty)
                    return await findTimetablesByTeacher(tid);
                }
              } catch (_) {}
            }
          }
        } else {
          final tr = _asListOfMaps(tres.data);
          if (tr.isNotEmpty) {
            final tid = tr.first['id']?.toString();
            if (tid != null && tid.isNotEmpty)
              return await findTimetablesByTeacher(tid);
          }
        }
      } catch (_) {}

      // As a fallback, try searching sessions JSON text for the display name.
      // Note: some schemas store `sessions` as JSON/JSONB; ilike directly
      // against JSONB often doesn't match. Attempt the query but guard errors.
      try {
        final fres = await _run(
          supabase
              .from('time_table')
              .select()
              .ilike('sessions', '%$teacherIdOrName%'),
        );
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
      // Final fallback: fetch all timetable rows and scan client-side for
      // matches inside `sessions` JSON or top-level teacher/class fields.
      // This is heavier but helps when the DB schema stores `sessions` as
      // jsonb (where ilike may not match) or when column names differ.
      try {
        if (out.isEmpty) {
          debugPrint(
            '[UseTimetable.findTimetablesByTeacher] fallback scanning all timetables (client-side)',
          );
          var all = await _run(supabase.from('time_table').select());
          if (all.error != null && _isMissingTableError(all.error)) {
            all = await _run(supabase.from('timetables').select());
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
                    ))
                      matched = true;
                  }
                }

                // inspect sessions JSON/Map/text
                if (!matched && r.containsKey('sessions')) {
                  try {
                    final s = r['sessions'];
                    final txt = jsonEncode(s).toString().toLowerCase();
                    if (txt.contains(teacherIdOrName.toLowerCase()))
                      matched = true;
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
      return out;
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

      // If looks like UUID, try matching `class` FK on time_table
      if (_uuidRegex.hasMatch(classIdOrName)) {
        var res = await _run(
          supabase.from('time_table').select().eq('class', classIdOrName),
        );
        if (res.error != null && _isMissingTableError(res.error)) {
          res = await _run(
            supabase.from('timetables').select().eq('class', classIdOrName),
          );
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
              var res2 = await _run(
                supabase.from('time_table').select().eq('class', cid),
              );
              if (res2.error != null && _isMissingTableError(res2.error)) {
                res2 = await _run(
                  supabase.from('timetables').select().eq('class', cid),
                );
              }
              if (res2.error == null) return _asListOfMaps(res2.data);
            }
          }
        }
      } catch (_) {}

      // Try matching class_id/className fields
      var res2 = await _run(
        supabase.from('time_table').select().eq('classKey', classIdOrName),
      );
      if (res2.error != null && _isMissingTableError(res2.error)) {
        res2 = await _run(
          supabase.from('timetables').select().eq('classKey', classIdOrName),
        );
      }
      if (res2.error == null) {
        final rows = _asListOfMaps(res2.data);
        debugPrint(
          '[UseTimetable.findTimetablesByClass] classKey lookup rows=${rows.length}',
        );
        out.addAll(rows);
      }

      // Try ilike on class_name/className
      final res3 = await _run(
        supabase
            .from('time_table')
            .select()
            .ilike('className', '%$classIdOrName%'),
      );
      if (res3.error == null) {
        final rows = _asListOfMaps(res3.data);
        debugPrint(
          '[UseTimetable.findTimetablesByClass] ilike className rows=${rows.length}',
        );
        out.addAll(rows);
      }

      // Final fallback: if no rows found yet, fetch all timetable rows and
      // perform a client-side filter by class name/classKey/class fields.
      try {
        if (out.isEmpty) {
          var all = await _run(supabase.from('time_table').select());
          if (all.error != null && _isMissingTableError(all.error)) {
            all = await _run(supabase.from('timetables').select());
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
                    if (cid.toLowerCase().contains(classIdOrName.toLowerCase()))
                      matched = true;
                  }
                }
                // inspect sessions or other text fields
                if (!matched) {
                  try {
                    final txt = jsonEncode(
                      r['sessions'],
                    ).toString().toLowerCase();
                    if (txt.contains(classIdOrName.toLowerCase()))
                      matched = true;
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

      // dedupe
      final seen = <String>{};
      return out.where((r) {
        final id = (r['id']?.toString() ?? '');
        if (id.isEmpty) return false;
        if (seen.contains(id)) return false;
        seen.add(id);
        return true;
      }).toList();
    } catch (e) {
      rethrow;
    }
  }

  // Helper: normalize different supabase shapes into a List<Map<String,dynamic>>
  // Accepts List, Map (single row), JSArray-like, or Postgrest response data.
  List<Map<String, dynamic>> _asListOfMaps(dynamic data) {
    if (data == null) return <Map<String, dynamic>>[];
    try {
      if (data is List)
        return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      if (data is Map)
        return <Map<String, dynamic>>[Map<String, dynamic>.from(data)];
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
      teachers = rows.map((r) {
        final name =
            (r['teacher_name'] ??
                    r['name'] ??
                    r['full_name'] ??
                    r['username'] ??
                    '')
                .toString();
        return {'id': r['id'].toString(), 'name': name, 'raw': r};
      }).toList();
      teachers.sort(
        (a, b) => a['name'].toString().compareTo(b['name'].toString()),
      );
    } catch (e) {
      rethrow;
    }
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
      // faculties' classes.
      String? resolvedFaculty;
      try {
        final depSvc = UseDepartments();
        resolvedFaculty = await depSvc.resolveAdminFacultyId();
      } catch (_) {
        resolvedFaculty = null;
      }
      if (resolvedFaculty == null || resolvedFaculty.isEmpty) {
        classes = [];
        return;
      }

      // Try by department id or name. Avoid querying a UUID column with a
      // plain display name (Postgres will return an error). If the input
      // looks like a UUID we try matching the `department` FK column first.
      if (depIdOrName is String) {
        if (_uuidRegex.hasMatch(depIdOrName)) {
          final res = await _run(
            supabase
                .from('classes')
                .select()
                .eq('department', depIdOrName)
                .eq('faculty_id', resolvedFaculty),
          );
          if (res.error == null) rows = _asListOfMaps(res.data);
        }

        // If we didn't find rows yet, try department_id or search by display
        // name. Always scope by faculty_id.
        if (rows.isEmpty) {
          final res = await _run(
            supabase
                .from('classes')
                .select()
                .eq('department_id', depIdOrName)
                .eq('faculty_id', resolvedFaculty),
          );
          if (res.error == null) rows = _asListOfMaps(res.data);
        }

        if (rows.isEmpty) {
          final depRes = await _run(
            supabase
                .from('departments')
                .select()
                .ilike('department_name', depIdOrName)
                .eq('faculty_id', resolvedFaculty),
          );
          if (depRes.error == null) {
            final depRows = _asListOfMaps(depRes.data);
            if (depRows.isNotEmpty) {
              final dep = depRows.first;
              final res2 = await _run(
                supabase
                    .from('classes')
                    .select()
                    .eq('department', dep['id'])
                    .eq('faculty_id', resolvedFaculty),
              );
              if (res2.error == null) rows = _asListOfMaps(res2.data);
            }
          }
        }
      }

      // Fallback: select all classes for this faculty only
      if (rows.isEmpty) {
        final res = await _run(
          supabase.from('classes').select().eq('faculty_id', resolvedFaculty),
        );
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
      // courses.
      String? resolvedFaculty;
      try {
        final depSvc = UseDepartments();
        resolvedFaculty = await depSvc.resolveAdminFacultyId();
      } catch (_) {
        resolvedFaculty = null;
      }
      if (resolvedFaculty == null || resolvedFaculty.isEmpty) {
        courses = [];
        return;
      }

      if (classIdOrName is String) {
        // If this looks like a UUID, try matching the `class` UUID FK first.
        if (_uuidRegex.hasMatch(classIdOrName)) {
          final res = await _run(
            supabase
                .from('courses')
                .select()
                .eq('class', classIdOrName)
                .eq('faculty_id', resolvedFaculty),
          );
          if (res.error == null) rows = _asListOfMaps(res.data);
        }

        if (rows.isEmpty) {
          final res = await _run(
            supabase
                .from('courses')
                .select()
                .eq('class_id', classIdOrName)
                .eq('faculty_id', resolvedFaculty),
          );
          if (res.error == null) rows = _asListOfMaps(res.data);
        }

        if (rows.isEmpty) {
          // some schemas use class name stored
          final res2 = await _run(
            supabase
                .from('courses')
                .select()
                .ilike('class_name', classIdOrName)
                .eq('faculty_id', resolvedFaculty),
          );
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

      var res = await _run(
        supabase.from('timetables').select().eq('id', docId).limit(1),
      );
      // If table not found, try alternate table name used in some schemas
      if (res.error != null && _isMissingTableError(res.error)) {
        res = await _run(
          supabase.from('time_table').select().eq('id', docId).limit(1),
        );
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
        res = await _run(
          supabase
              .from('timetables')
              .select()
              .eq('department', department)
              .eq('className', className)
              .limit(1),
        );
        if (res.error != null &&
            (_isMissingTableError(res.error) ||
                _isMissingColumnError(res.error))) {
          if (preResolvedDeptId != null && preResolvedClassId != null) {
            res = await _run(
              supabase
                  .from('time_table')
                  .select()
                  .eq('department', preResolvedDeptId)
                  .eq('class', preResolvedClassId)
                  .limit(1),
            );
          } else {
            res = await _run(
              supabase
                  .from('time_table')
                  .select()
                  .ilike('department', department)
                  .limit(1),
            );
          }
        }
      } else {
        res = await _run(
          supabase
              .from('timetables')
              .select()
              .ilike('department', department)
              .eq('className', className)
              .limit(1),
        );
        if (res.error != null &&
            (_isMissingTableError(res.error) ||
                _isMissingColumnError(res.error))) {
          if (preResolvedDeptId != null && preResolvedClassId != null) {
            res = await _run(
              supabase
                  .from('time_table')
                  .select()
                  .eq('department', preResolvedDeptId)
                  .eq('class', preResolvedClassId)
                  .limit(1),
            );
          } else {
            res = await _run(
              supabase
                  .from('time_table')
                  .select()
                  .ilike('department', department)
                  .limit(1),
            );
          }
        }
      }
      if (res.error == null) {
        final rows = _asListOfMaps(res.data);
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
                if (dr.isNotEmpty)
                  deptDisp =
                      (dr.first['department_name'] ??
                              dr.first['name'] ??
                              deptDisp)
                          .toString();
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
                if (cr.isNotEmpty)
                  classDisp =
                      (cr.first['class_name'] ?? cr.first['name'] ?? classDisp)
                          .toString();
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

      // try by department_id & classKey
      if (departmentId != null && classKey != null) {
        res = await _run(
          supabase
              .from('timetables')
              .select()
              .eq('department_id', departmentId)
              .eq('classKey', classKey)
              .limit(1),
        );
        if (res.error != null && _isMissingTableError(res.error)) {
          res = await _run(
            supabase
                .from('time_table')
                .select()
                .eq('department_id', departmentId)
                .eq('classKey', classKey)
                .limit(1),
          );
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
                  if (dr.isNotEmpty)
                    deptDisp =
                        (dr.first['department_name'] ??
                                dr.first['name'] ??
                                deptDisp)
                            .toString();
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
                  if (cr.isNotEmpty)
                    classDisp =
                        (cr.first['class_name'] ??
                                cr.first['name'] ??
                                classDisp)
                            .toString();
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

      // last resort: any timetable with department or className match
      res = await _run(
        supabase
            .from('timetables')
            .select()
            .ilike('department', department)
            .limit(1),
      );
      if (res.error != null && _isMissingTableError(res.error)) {
        res = await _run(
          supabase
              .from('time_table')
              .select()
              .ilike('department', department)
              .limit(1),
        );
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
                if (dr.isNotEmpty)
                  deptDisp =
                      (dr.first['department_name'] ??
                              dr.first['name'] ??
                              deptDisp)
                          .toString();
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
                if (cr.isNotEmpty)
                  classDisp =
                      (cr.first['class_name'] ?? cr.first['name'] ?? classDisp)
                          .toString();
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
        if (_uuidRegex.hasMatch(classIdOrName))
          preResolvedClassId = classIdOrName;
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
                final dr = _asListOfMaps(res.data);
                if (dr.isNotEmpty) resolvedDeptId = dr.first['id']?.toString();
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
                final cr = _asListOfMaps(res.data);
                if (cr.isNotEmpty) resolvedClassId = cr.first['id']?.toString();
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
                      if (parts.length > 1)
                        teacherVal = parts.sublist(1).join(' ').trim();
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
                            final cres = await _run(
                              supabase
                                  .from('courses')
                                  .select('id')
                                  .ilike('course_name', courseVal)
                                  .limit(1),
                            );
                            if (cres.error == null) {
                              final cr = _asListOfMaps(cres.data);
                              if (cr.isNotEmpty)
                                courseIdResolved = cr.first['id']?.toString();
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
                              if (tr.isNotEmpty)
                                teacherIdResolved = tr.first['id']?.toString();
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
                      if (courseIdResolved == null &&
                          courseVal != null &&
                          courseVal.isNotEmpty)
                        'course': courseVal,
                      if (teacherIdResolved != null)
                        'teacher': teacherIdResolved,
                      if (teacherIdResolved == null &&
                          teacherVal != null &&
                          teacherVal.isNotEmpty)
                        'teacher': teacherVal,
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
                      if (_uuidRegex.hasMatch(v))
                        topCourse = v;
                      else
                        topCourse ??= v;
                    }
                  }
                  if (topTeacher == null && s.containsKey('teacher')) {
                    final v = s['teacher']?.toString();
                    if (v != null && v.isNotEmpty) {
                      if (_uuidRegex.hasMatch(v))
                        topTeacher = v;
                      else
                        topTeacher ??= v;
                    }
                  }
                } catch (_) {}
                if (topCourse != null && topTeacher != null) break;
              }
              if (topCourse != null && _uuidRegex.hasMatch(topCourse))
                tt['course'] = topCourse;
              if (topTeacher != null && _uuidRegex.hasMatch(topTeacher))
                tt['teacher'] = topTeacher;
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
                final cres = await _run(
                  supabase
                      .from('courses')
                      .select('id')
                      .or("course_name.ilike.$cval,course_code.ilike.$cval")
                      .limit(1),
                );
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
        if (_uuidRegex.hasMatch(classIdOrName))
          preResolvedClassId = classIdOrName;
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
      if (qrows.isEmpty)
        throw Exception('No timetable found for the selected class');
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
    if (found != null && found.isNotEmpty)
      return (found['name'] ?? s).toString();
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
    if (found != null && found.isNotEmpty)
      return (found['name'] ?? s).toString();
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

  // Compatibility helper to call the supabase query builder in a way that
  // works across supabase client versions. Some client versions expose an
  // `execute()` method on the builder, others return a Future that resolves
  // to either a Postgrest-like response object or directly to a List of rows
  // (especially on web). This helper normalizes those into an `_Resp`.
  Future<_Resp> _run(dynamic builder) async {
    dynamic raw;
    // Try builder.execute() first (older API)
    try {
      raw = await (builder as dynamic).execute();
    } catch (_) {
      // If that fails, try awaiting the builder itself (some versions return
      // a Future from the builder)
      try {
        raw = await builder;
      } catch (e) {
        // If both attempts fail, return the exception as an error payload
        // instead of rethrowing so callers can handle PostgrestExceptions
        // (for example when a queried column doesn't exist on the table).
        return _Resp(null, e);
      }
    }

    // Normalize `raw` into an object exposing `.data` and `.error`.
    try {
      // If raw is a Postgrest-like response (has .data/.error), prefer those.
      final data = (raw as dynamic).data;
      final error = (raw as dynamic).error;
      return _Resp(data, error);
    } catch (_) {
      // If `.data` isn't available, raw might already be a List of rows.
      if (raw is List) return _Resp(raw, null);
      // If it's a Map with 'data' key, use that.
      if (raw is Map && raw.containsKey('data'))
        return _Resp(raw['data'], raw['error']);
      // Fallback: return raw as data with no error.
      return _Resp(raw, null);
    }
  }

  String _sanitizeForId(String input) {
    var s = input.trim().toLowerCase();
    s = s.replaceAll(RegExp(r'\s+'), '_');
    s = s.replaceAll(RegExp(r'[^\w\-]'), '');
    return s;
  }

  String _sanitizedKey(String deptDisplay, String classDisplay) {
    final d = _sanitizeForId(deptDisplay);
    final c = _sanitizeForId(classDisplay);
    return '${d}_$c';
  }

  // Helper: detect Postgrest "table not found" errors so callers can retry
  // with alternate table names. We check common fields on the exception.
  bool _isMissingTableError(dynamic err) {
    try {
      final msg = (err as dynamic).message?.toString() ?? '';
      final code = (err as dynamic).code?.toString() ?? '';
      if (code == 'PGRST205') return true;
      if (msg.toLowerCase().contains('could not find the table')) return true;
    } catch (_) {}
    return false;
  }

  // Helper: detect "column does not exist" Postgres errors (undefined column)
  bool _isMissingColumnError(dynamic err) {
    try {
      final msg = (err as dynamic).message?.toString() ?? '';
      final code = (err as dynamic).code?.toString() ?? '';
      // Postgres undefined_column code is 42703
      if (code == '42703') return true;
      if (msg.toLowerCase().contains('does not exist')) return true;
    } catch (_) {}
    return false;
  }
}
