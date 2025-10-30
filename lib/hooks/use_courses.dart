import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/course.dart';
import 'use_faculty_scope.dart';

class UseCourses {
  final SupabaseClient _supabase = Supabase.instance.client;
  final FacultyScope _facultyScope = FacultyScope();

  bool _looksLikeUuid(String s) {
    final uuidReg = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    return uuidReg.hasMatch(s);
  }

  Future<String?> _resolveTeacherId(String display) async {
    final val = display.trim();
    if (val.isEmpty) return null;
    if (_looksLikeUuid(val)) return val;

    final resp = await _supabase
        .from('teachers')
        .select('id')
        .or('username.eq.$val,teacher_name.eq.$val')
        .maybeSingle();

    if (resp == null) return null;
    if (resp['id'] != null) return resp['id'].toString();
    return null;
  }

  Future<String?> _resolveClassId(String display) async {
    final val = display.trim();
    if (val.isEmpty) return null;
    if (_looksLikeUuid(val)) return val;

    // Try exact match first, then fall back to case-insensitive match
    try {
      var resp = await _supabase
          .from('classes')
          .select('id')
          .eq('class_name', val)
          .maybeSingle();
      if (resp != null && resp['id'] != null) return resp['id'].toString();

      // Case-insensitive match (ILIKE). Some DB rows may differ in case or
      // have small variations; try a direct ilike and then a contains-style
      // ilike if needed.
      resp = await _supabase
          .from('classes')
          .select('id')
          .ilike('class_name', val)
          .maybeSingle();
      if (resp != null && resp['id'] != null) return resp['id'].toString();

      resp = await _supabase
          .from('classes')
          .select('id')
          .ilike('class_name', '%$val%')
          .maybeSingle();
      if (resp != null && resp['id'] != null) return resp['id'].toString();
      return null;
    } catch (e) {
      // If any error occurs during lookup, return null so caller knows no id
      // could be resolved and can handle the empty result gracefully.
      return null;
    }
  }

  Future<String?> _resolveDepartmentId(String display) async {
    final val = display.trim();
    if (val.isEmpty) return null;
    if (_looksLikeUuid(val)) return val;

    // Try to find by department_name or department_code
    try {
      // debug: log resolution attempt
      // ignore: avoid_print
      print('[resolveDepartmentId] resolving "$val"');

      final resp = await _supabase
          .from('departments')
          .select('id, department_name, department_code')
          .or('department_name.eq.$val,department_code.eq.$val')
          .maybeSingle();

      // debug: log response from departments lookup
      // ignore: avoid_print
      print('[resolveDepartmentId] response for "$val": $resp');

      if (resp == null) return null;
      if (resp['id'] != null) return resp['id'].toString();
      return null;
    } catch (e) {
      // ignore: avoid_print
      print('[resolveDepartmentId] error resolving "$val": $e');
      return null;
    }
  }

  Future<List<Course>> fetchCourses({
    int? limit,
    int? page,
    String? facultyId,
  }) async {
    try {
      // Resolve faculty scope when not provided by caller
      String? resolvedFacultyId = facultyId;
      if (resolvedFacultyId == null || resolvedFacultyId.isEmpty) {
        try {
          resolvedFacultyId = await _facultyScope.resolveCurrentFacultyId();
        } catch (_) {
          resolvedFacultyId = null;
        }
      }

      // If no faculty resolved for current admin, return empty to avoid
      // exposing other faculties' courses.
      if (resolvedFacultyId == null || resolvedFacultyId.isEmpty) {
        return <Course>[];
      }

      // NOTE: do NOT select a plain 'department' column — it does not exist on
      // the courses table and will cause PostgREST to error (it would look for
      // courses.department). Instead, request the FK `department_id` and the
      // related nested department object via `department:departments(...)`.
      dynamic query = _supabase
          .from('courses')
          .select(
            'id, course_code, course_name, teacher_assigned, class, department_id, semester, created_at, faculty_id, faculty:faculties(id,faculty_name), teacher_assigned:teachers(id, teacher_name, username), class:classes(id, class_name), department:departments(id, department_name, department_code)',
          );

      query = (query as dynamic).eq('faculty_id', resolvedFacultyId);
      query = query.order('created_at', ascending: false);

      if (limit != null) {
        final int offset = (page ?? 0) * limit;
        query = query.range(offset, offset + limit - 1);
      }

      final response = await query;
      final rows = response as List<dynamic>;

      // collect teacher and class ids when API returned plain uuids
      final Set<String> teacherIds = {};
      final Set<String> classIds = {};
      final Set<String> deptIds = {};

      for (final r in rows) {
        if (r is Map) {
          final t = r['teacher_assigned'];
          if (t is String && t.isNotEmpty) teacherIds.add(t);
          final c = r['class'];
          if (c is String && c.isNotEmpty) classIds.add(c);
          final d1 = r['department_id'];
          if (d1 is String && d1.isNotEmpty) deptIds.add(d1);
          final d2 = r['department'];
          if (d2 is String && d2.isNotEmpty) deptIds.add(d2);
          // if API returned nested department object with id, capture it
          if (d2 is Map && d2['id'] != null) {
            final idVal = (d2['id'] ?? '').toString();
            if (idVal.isNotEmpty) deptIds.add(idVal);
          }
        }
      }

      // batch fetch teacher names and class names if needed
      Map<String, String> teacherNameById = {};
      Map<String, String> classNameById = {};
      Map<String, String> deptNameById = {};

      if (teacherIds.isNotEmpty) {
        final tResp = await _supabase
            .from('teachers')
            .select('id, teacher_name, username')
            .filter('id', 'in', teacherIds.toList());
        for (final t in tResp as List) {
          try {
            final id = (t['id'] ?? '').toString();
            final name = (t['teacher_name'] ?? t['username'] ?? '').toString();
            if (id.isNotEmpty && name.isNotEmpty) teacherNameById[id] = name;
          } catch (_) {}
        }
      }

      if (classIds.isNotEmpty) {
        final cResp = await _supabase
            .from('classes')
            .select('id, class_name')
            .filter('id', 'in', classIds.toList());
        for (final c in cResp as List) {
          try {
            final id = (c['id'] ?? '').toString();
            final name = (c['class_name'] ?? '').toString();
            if (id.isNotEmpty && name.isNotEmpty) classNameById[id] = name;
          } catch (_) {}
        }
      }

      // department name lookup already done above via deptIds and fetching departments

      if (deptIds.isNotEmpty) {
        try {
          final dResp = await _supabase
              .from('departments')
              .select('id, department_name, department_code')
              .filter('id', 'in', deptIds.toList());
          for (final d in dResp as List) {
            try {
              final id = (d['id'] ?? '').toString();
              final name = (d['department_name'] ?? d['department_code'] ?? '')
                  .toString();
              if (id.isNotEmpty && name.isNotEmpty) deptNameById[id] = name;
            } catch (_) {}
          }
        } catch (_) {}
      }

      return rows.map((e) {
        final map = e as Map<String, dynamic>;
        // if teacher_name/class_name not present but ids map exists, patch them
        if ((map['teacher_name'] == null ||
                (map['teacher_name'] as String).isEmpty) &&
            map['teacher_assigned'] != null) {
          final tval = map['teacher_assigned'];
          if (tval is String && teacherNameById.containsKey(tval)) {
            map['teacher_name'] = teacherNameById[tval];
          }
        }
        if ((map['class_name'] == null ||
                (map['class_name'] as String).isEmpty) &&
            map['class'] != null) {
          final cval = map['class'];
          if (cval is String && classNameById.containsKey(cval)) {
            map['class_name'] = classNameById[cval];
          }
        }
        // patch department id -> name when API returned plain uuid in map['department_id'] or map['department']
        if ((map['department_name'] == null ||
            (map['department_name'] is String &&
                (map['department_name'] as String).isEmpty))) {
          // try department_id first
          final dval = map['department_id'] ?? map['department'];
          if (dval is String && deptNameById.containsKey(dval)) {
            map['department_name'] = deptNameById[dval];
          } else if (dval is Map && dval['department_name'] != null) {
            map['department_name'] = dval['department_name'].toString();
          }
        }

        return Course.fromMap(map);
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch courses: $e');
    }
  }

  /// Fetch courses that belong to a specific class (by class id or display).
  /// `classDisplay` can be either a UUID or a class_name. The method will
  /// resolve the class to an id when necessary and then query courses where
  /// `class` = the resolved id. Results are scoped by faculty like
  /// `fetchCourses`.
  Future<List<Course>> fetchCoursesByClass(
    String classDisplay, {
    int? limit,
    int? page,
    String? facultyId,
  }) async {
    try {
      // ignore: avoid_print
      print(
        '[UseCourses.fetchCoursesByClass] called with classDisplay="$classDisplay" facultyId=$facultyId',
      );
      // resolve class id if display provided
      String? classId = classDisplay.trim();
      if (classId.isEmpty) return <Course>[];
      if (!_looksLikeUuid(classId)) {
        final resolved = await _resolveClassId(classId);
        // ignore: avoid_print
        print(
          '[UseCourses.fetchCoursesByClass] resolved class id for "$classDisplay" => $resolved',
        );
        if (resolved == null) return <Course>[];
        classId = resolved;
      }

      // resolve faculty scope when not provided by caller
      String? resolvedFacultyId = facultyId;
      if (resolvedFacultyId == null || resolvedFacultyId.isEmpty) {
        try {
          resolvedFacultyId = await _facultyScope.resolveCurrentFacultyId();
        } catch (_) {
          resolvedFacultyId = null;
        }
      }
      if (resolvedFacultyId == null || resolvedFacultyId.isEmpty) {
        return <Course>[];
      }

      // ignore: avoid_print
      print(
        '[UseCourses.fetchCoursesByClass] querying courses for classId=$classId faculty_id=$resolvedFacultyId limit=$limit page=$page',
      );
      dynamic query = _supabase
          .from('courses')
          .select(
            'id, course_code, course_name, teacher_assigned, class, department_id, semester, created_at, faculty_id, faculty:faculties(id,faculty_name), teacher_assigned:teachers(id, teacher_name, username), class:classes(id, class_name), department:departments(id, department_name, department_code)',
          )
          .eq('class', classId)
          .eq('faculty_id', resolvedFacultyId)
          .order('created_at', ascending: false);

      if (limit != null) {
        final int offset = (page ?? 0) * limit;
        query = query.range(offset, offset + limit - 1);
      }

      final response = await query;
      final rows = response as List<dynamic>;
      // ignore: avoid_print
      print(
        '[UseCourses.fetchCoursesByClass] query returned ${rows.length} rows',
      );
      try {
        final sample = rows
            .take(5)
            .map(
              (r) => (r is Map
                  ? {
                      'id': r['id'],
                      'course_name': r['course_name'],
                      'class': r['class'],
                    }
                  : r),
            )
            .toList();
        // ignore: avoid_print
        print('[UseCourses.fetchCoursesByClass] sample rows: $sample');
      } catch (_) {}
      // collect teacher and class ids when API returned plain uuids
      final Set<String> teacherIds = {};
      final Set<String> classIds = {};
      final Set<String> deptIds = {};

      for (final r in rows) {
        if (r is Map) {
          final t = r['teacher_assigned'];
          if (t is String && t.isNotEmpty) teacherIds.add(t);
          final c = r['class'];
          if (c is String && c.isNotEmpty) classIds.add(c);
          final d1 = r['department_id'];
          if (d1 is String && d1.isNotEmpty) deptIds.add(d1);
          final d2 = r['department'];
          if (d2 is String && d2.isNotEmpty) deptIds.add(d2);
          if (d2 is Map && d2['id'] != null) {
            final idVal = (d2['id'] ?? '').toString();
            if (idVal.isNotEmpty) deptIds.add(idVal);
          }
        }
      }

      Map<String, String> teacherNameById = {};
      Map<String, String> classNameById = {};
      Map<String, String> deptNameById = {};

      if (teacherIds.isNotEmpty) {
        final tResp = await _supabase
            .from('teachers')
            .select('id, teacher_name, username')
            .filter('id', 'in', teacherIds.toList());
        for (final t in tResp as List) {
          try {
            final id = (t['id'] ?? '').toString();
            final name = (t['teacher_name'] ?? t['username'] ?? '').toString();
            if (id.isNotEmpty && name.isNotEmpty) teacherNameById[id] = name;
          } catch (_) {}
        }
      }

      if (classIds.isNotEmpty) {
        final cResp = await _supabase
            .from('classes')
            .select('id, class_name')
            .filter('id', 'in', classIds.toList());
        for (final c in cResp as List) {
          try {
            final id = (c['id'] ?? '').toString();
            final name = (c['class_name'] ?? '').toString();
            if (id.isNotEmpty && name.isNotEmpty) classNameById[id] = name;
          } catch (_) {}
        }
      }

      if (deptIds.isNotEmpty) {
        try {
          final dResp = await _supabase
              .from('departments')
              .select('id, department_name, department_code')
              .filter('id', 'in', deptIds.toList());
          for (final d in dResp as List) {
            try {
              final id = (d['id'] ?? '').toString();
              final name = (d['department_name'] ?? d['department_code'] ?? '')
                  .toString();
              if (id.isNotEmpty && name.isNotEmpty) deptNameById[id] = name;
            } catch (_) {}
          }
        } catch (_) {}
      }

      return rows.map((e) {
        final map = e as Map<String, dynamic>;
        if ((map['teacher_name'] == null ||
                (map['teacher_name'] as String).isEmpty) &&
            map['teacher_assigned'] != null) {
          final tval = map['teacher_assigned'];
          if (tval is String && teacherNameById.containsKey(tval)) {
            map['teacher_name'] = teacherNameById[tval];
          }
        }
        if ((map['class_name'] == null ||
                (map['class_name'] as String).isEmpty) &&
            map['class'] != null) {
          final cval = map['class'];
          if (cval is String && classNameById.containsKey(cval)) {
            map['class_name'] = classNameById[cval];
          }
        }
        if ((map['department_name'] == null ||
            (map['department_name'] is String &&
                (map['department_name'] as String).isEmpty))) {
          final dval = map['department_id'] ?? map['department'];
          if (dval is String && deptNameById.containsKey(dval)) {
            map['department_name'] = deptNameById[dval];
          } else if (dval is Map && dval['department_name'] != null) {
            map['department_name'] = dval['department_name'].toString();
          }
        }
        return Course.fromMap(map);
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch courses by class: $e');
    }
  }

  Future<Course?> fetchCourseById(String id) async {
    try {
      // When fetching by id, also ensure scope if current user is a faculty admin
      final resolvedFacultyId = await _facultyScope.resolveCurrentFacultyId();
      // Include department relation and department_id when fetching a single
      // course so the UI can show and edit the department selection.
      var query = _supabase
          .from('courses')
          .select(
            'id, course_code, course_name, teacher_assigned, class, department_id, semester, created_at, faculty_id, faculty:faculties(id,faculty_name), teacher_assigned:teachers(id, teacher_name, username), class:classes(id, class_name), department:departments(id, department_name, department_code)',
          )
          .eq('id', id);
      if (resolvedFacultyId != null && resolvedFacultyId.isNotEmpty) {
        query = (query as dynamic).eq('faculty_id', resolvedFacultyId);
      }
      final dynamic response = await query.maybeSingle();

      if (response == null) return null;
      return Course.fromMap(response);
    } catch (e) {
      throw Exception('Failed to fetch course by id: $e');
    }
  }

  Future<void> addCourse(Course course, {String? facultyId}) async {
    try {
      // resolve teacher/class display values to IDs when possible
      final Map<String, dynamic> data = {
        'course_code': course.code,
        'course_name': course.name,
        'semester': course.semester.toString(),
      };

      final teacherDisplay = course.teacher;
      if (teacherDisplay.isNotEmpty) {
        final tId = await _resolveTeacherId(teacherDisplay);
        if (tId == null) {
          throw Exception('Teacher not found: $teacherDisplay');
        }
        data['teacher_assigned'] = tId;
      }

      final classDisplay = course.className;
      final cId = await _resolveClassId(classDisplay);
      if (classDisplay.isNotEmpty && cId == null) {
        throw Exception('Class not found: $classDisplay');
      }
      if (cId != null) data['class'] = cId;

      // Resolve department display -> id when possible. If the UI sent a
      // non-empty department but we can't resolve it to an id, fail fast so
      // we don't silently insert a null FK.
      final deptDisplay = course.department;
      if (deptDisplay.isNotEmpty) {
        // debug: log the department display before resolving
        // ignore: avoid_print
        print('[addCourse] deptDisplay: "$deptDisplay"');
        final dId = await _resolveDepartmentId(deptDisplay);
        // debug: log resolved id (or null)
        // ignore: avoid_print
        print('[addCourse] resolved department id for "$deptDisplay": $dId');
        if (dId == null) {
          throw Exception('Department not found: $deptDisplay');
        }
        data['department_id'] = dId;
      }

      // debug: log outgoing payload to help diagnose insertion issues
      // ignore: avoid_print
      print('Inserting course: $data');

      String? resolvedFacultyId = facultyId;
      if (resolvedFacultyId == null || resolvedFacultyId.isEmpty) {
        try {
          resolvedFacultyId = await _facultyScope.resolveCurrentFacultyId();
        } catch (_) {
          resolvedFacultyId = null;
        }
      }
      if (resolvedFacultyId != null && resolvedFacultyId.isNotEmpty) {
        data['faculty_id'] = resolvedFacultyId;
      }
      // Request the inserted row back so we can inspect what the server persisted.
      final resp = await _supabase
          .from('courses')
          .insert(data)
          .select()
          .maybeSingle();
      // debug: print full response for inspection
      // ignore: avoid_print
      print('[addCourse] Insert response (returned row): $resp');
    } catch (e) {
      // ignore: avoid_print
      print('[addCourse] Failed to add course: $e');
      rethrow;
    }
  }

  Future<void> updateCourse(
    String id,
    Course course, {
    String? facultyId,
  }) async {
    try {
      final Map<String, dynamic> data = {
        'course_code': course.code,
        'course_name': course.name,
        'semester': course.semester.toString(),
      };

      final teacherDisplay = course.teacher;
      if (teacherDisplay.isNotEmpty) {
        final tId = await _resolveTeacherId(teacherDisplay);
        if (tId == null) {
          throw Exception('Teacher not found: $teacherDisplay');
        }
        data['teacher_assigned'] = tId;
      } else {
        // clear the teacher assignment if empty
        data['teacher_assigned'] = null;
      }

      final classDisplay = course.className;
      if (classDisplay.isNotEmpty) {
        final cId = await _resolveClassId(classDisplay);
        if (cId == null) throw Exception('Class not found: $classDisplay');
        data['class'] = cId;
      } else {
        data['class'] = null;
      }

      // resolve department name -> id for updates as well
      final deptDisplay = course.department;
      if (deptDisplay.isNotEmpty) {
        final dId = await _resolveDepartmentId(deptDisplay);
        if (dId == null) throw Exception('Department not found: $deptDisplay');
        data['department_id'] = dId;
      }

      // debug
      // ignore: avoid_print
      print('Updating course $id with $data');
      String? resolvedFacultyId = facultyId;
      if (resolvedFacultyId == null || resolvedFacultyId.isEmpty) {
        try {
          resolvedFacultyId = await _facultyScope.resolveCurrentFacultyId();
        } catch (_) {
          resolvedFacultyId = null;
        }
      }
      if (resolvedFacultyId != null && resolvedFacultyId.isNotEmpty) {
        data['faculty_id'] = resolvedFacultyId;
      }
      // scope the update by faculty if resolved to avoid cross-faculty modification
      var query = _supabase.from('courses').update(data).eq('id', id);
      if (resolvedFacultyId != null && resolvedFacultyId.isNotEmpty) {
        query = (query as dynamic).eq('faculty_id', resolvedFacultyId);
      }
      // request the updated row back for introspection
      final resp = await (query as dynamic).select().maybeSingle();
      // ignore: avoid_print
      print('[updateCourse] Update response (returned row): $resp');
    } catch (e) {
      // ignore: avoid_print
      print('Failed to update course: $e');
      throw Exception('Failed to update course: $e');
    }
  }

  Future<void> deleteCourse(String id) async {
    try {
      final resolvedFacultyId = await _facultyScope.resolveCurrentFacultyId();
      var query = _supabase.from('courses').delete().eq('id', id);
      if (resolvedFacultyId != null && resolvedFacultyId.isNotEmpty) {
        query = (query as dynamic).eq('faculty_id', resolvedFacultyId);
      }
      await query;
    } catch (e) {
      throw Exception('Failed to delete course: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> subscribeCourses() {
    return _supabase
        .from('courses')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }
}
