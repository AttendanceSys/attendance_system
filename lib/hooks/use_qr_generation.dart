import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'use_timetable.dart';

class LecturerSchedule {
  final String id;
  final String className;
  final String departmentName;
  final String classId;
  final String departmentId;
  final String teacher;
  final String courseName;
  final String courseId;
  final String facultyId;
  final Map<String, dynamic> session;

  LecturerSchedule({
    required this.id,
    required this.className,
    required this.departmentName,
    required this.classId,
    required this.departmentId,
    required this.teacher,
    required this.courseName,
    required this.courseId,
    required this.facultyId,
    required this.session,
  });

  factory LecturerSchedule.fromJson(Map<String, dynamic> json) {
    String pickClass(Map<String, dynamic> j) {
      try {
        if (j.containsKey('classes') && j['classes'] is Map) {
          final c = Map<String, dynamic>.from(j['classes'] as Map);
          // look for common name fields inside the nested classes map
          final classKeys = [
            'name',
            'class_name',
            'className',
            'class',
            'classKey',
            'classname',
          ];
          for (final k in classKeys) {
            if (c.containsKey(k) && c[k] != null) return c[k].toString();
          }
        }
      } catch (_) {}
      final alternatives = [
        'className',
        'class_name',
        'class',
        'classKey',
        'classname',
      ];
      for (final k in alternatives) {
        if (j.containsKey(k) && j[k] != null) return j[k].toString();
      }
      return '';
    }

    String pickDept(Map<String, dynamic> j) {
      try {
        if (j.containsKey('departments') && j['departments'] is Map) {
          final d = Map<String, dynamic>.from(j['departments'] as Map);
          final deptKeys = [
            'name',
            'department_name',
            'department',
            'dept',
            'departmentName',
            'department_code',
          ];
          for (final k in deptKeys) {
            if (d.containsKey(k) && d[k] != null) return d[k].toString();
          }
        }
      } catch (_) {}
      final alternatives = [
        'department_name',
        'department',
        'dept',
        'departmentName',
      ];
      for (final k in alternatives) {
        if (j.containsKey(k) && j[k] != null) return j[k].toString();
      }
      return '';
    }

    String pickCourse(Map<String, dynamic> j) {
      try {
        if (j.containsKey('courses') && j['courses'] is Map) {
          final c = Map<String, dynamic>.from(j['courses'] as Map);
          final courseKeys = [
            'name',
            'course_name',
            'course',
            'subject',
            'courseName',
            'title',
          ];
          for (final k in courseKeys) {
            if (c.containsKey(k) && c[k] != null) return c[k].toString();
          }
        }
      } catch (_) {}
      final alternatives = ['course_name', 'course', 'subject', 'courseName'];
      for (final k in alternatives) {
        if (j.containsKey(k) && j[k] != null) return j[k].toString();
      }
      return '';
    }

    Map<String, dynamic> pickSession(Map<String, dynamic> j) {
      try {
        if (j.containsKey('sessions')) {
          final s = j['sessions'];
          if (s is Map<String, dynamic>) return s;
          if (s is String) return jsonDecode(s) as Map<String, dynamic>;
        }
        if (j.containsKey('session')) {
          final s = j['session'];
          if (s is Map<String, dynamic>) return s;
          if (s is String) return jsonDecode(s) as Map<String, dynamic>;
        }
      } catch (_) {}
      return <String, dynamic>{};
    }

    // attempt to extract ids from nested structures
    String extractId(Map<String, dynamic> j, String key) {
      try {
        if (j.containsKey(key) && j[key] is Map) {
          final m = j[key] as Map;
          if (m.containsKey('id')) return m['id']?.toString() ?? '';
        }
      } catch (_) {}
      final altKeys = ['${key}_id', '${key}Id', '${key}Id'.toLowerCase()];
      for (final k in altKeys) {
        if (j.containsKey(k) && j[k] != null) return j[k].toString();
      }
      return '';
    }

    final classId = extractId(json, 'classes').isNotEmpty
        ? extractId(json, 'classes')
        : (json['class']?.toString() ?? json['classId']?.toString() ?? '');
    final deptId = extractId(json, 'departments').isNotEmpty
        ? extractId(json, 'departments')
        : (json['department']?.toString() ??
              json['departmentId']?.toString() ??
              '');
    final courseId = extractId(json, 'courses').isNotEmpty
        ? extractId(json, 'courses')
        : (json['course']?.toString() ?? json['courseId']?.toString() ?? '');

    return LecturerSchedule(
      id: json['id']?.toString() ?? json['time_table_id']?.toString() ?? '',
      className: pickClass(json),
      departmentName: pickDept(json),
      classId: classId,
      departmentId: deptId,
      teacher:
          (json['teacher'] ?? json['teacher_id'] ?? json['teacherId'] ?? '')
              .toString(),
      courseName: pickCourse(json),
      courseId: courseId,
      facultyId: (json['faculty_id'] ?? json['facultyId'] ?? '').toString(),
      session: pickSession(json),
    );
  }
}

class UseQRGeneration {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// 1️⃣ Get teacher unique ID from teachers table.
  ///
  /// This will try multiple strategies:
  /// - If Supabase auth current user exists, match `user_id`.
  /// - If `displayName` or `username` is provided, attempt to match
  ///   against `teacher_name` or `username` columns in `teachers`.
  Future<String?> getTeacherDatabaseId({
    String? displayName,
    String? username,
  }) async {
    try {
      final current = Supabase.instance.client.auth.currentUser;

      if (current != null) {
        final res = await _supabase
            .from('teachers')
            .select('id')
            .eq('user_id', current.id)
            .maybeSingle();
        if (res != null && res['id'] != null) return res['id'].toString();

        // fallback: maybe the teachers row stores username as email or auth id
        if (current.email != null && current.email!.isNotEmpty) {
          final r2 = await _supabase
              .from('teachers')
              .select('id')
              .eq('username', current.email!)
              .maybeSingle();
          if (r2 != null && r2['id'] != null) return r2['id'].toString();
        }
      }

      // If provided, try finding by explicit username
      if (username != null && username.isNotEmpty) {
        final r = await _supabase
            .from('teachers')
            .select('id')
            .or('username.eq.$username,teacher_name.eq.$username')
            .maybeSingle();
        if (r != null && r['id'] != null) return r['id'].toString();
      }

      // Try by displayName -> teacher_name
      if (displayName != null && displayName.isNotEmpty) {
        // use case-insensitive match
        final r = await _supabase
            .from('teachers')
            .select('id')
            .ilike('teacher_name', displayName)
            .maybeSingle();
        if (r != null && r['id'] != null) return r['id'].toString();
      }

      // As a final fallback, attempt to look up user_handling row with matching username
      if (username != null && username.isNotEmpty) {
        try {
          final uh = await _supabase
              .from('user_handling')
              .select('id, username')
              .eq('username', username)
              .maybeSingle();
          if (uh != null) {
            final teacherRow = await _supabase
                .from('teachers')
                .select('id')
                .eq('username', uh['username'])
                .maybeSingle();
            if (teacherRow != null && teacherRow['id'] != null) {
              return teacherRow['id'].toString();
            }
          }
        } catch (_) {}
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  /// 2️⃣ Fetch teacher timetable (corrected)
  Future<List<LecturerSchedule>> fetchScheduleByTeacher({
    String? displayName,
    String? username,
  }) async {
    // Try several identifier candidates using the robust timetable helper.
    final candidates = <String?>[];
    try {
      final tid = await getTeacherDatabaseId(
        displayName: displayName,
        username: username,
      );
      if (tid != null && tid.isNotEmpty) candidates.add(tid);
    } catch (_) {}

    if (username != null && username.isNotEmpty) candidates.add(username);
    if (displayName != null && displayName.isNotEmpty) {
      candidates.add(displayName);
    }

    try {
      final current = Supabase.instance.client.auth.currentUser;
      if (current != null) {
        if (current.id.isNotEmpty) candidates.add(current.id);
        if (current.email != null && current.email!.isNotEmpty) {
          candidates.add(current.email);
        }
      }
    } catch (_) {}

    List<Map<String, dynamic>> rows = [];
    for (final c in candidates) {
      if (c == null || c.isEmpty) continue;
      try {
        final found = await UseTimetable.instance.findTimetablesByTeacher(c);
        if (found.isNotEmpty) {
          rows = found;
          break;
        }
      } catch (_) {}
    }

    // If still empty, try unscoped frontend-only queries targeting the
    // teacher identifier directly (avoid relying on admin faculty resolution).
    if (rows.isEmpty) {
      for (final c in candidates) {
        if (c == null || c.isEmpty) continue;
        try {
          // Try direct teacher FK lookup (no faculty filter)
          final q = _supabase
              .from('time_table')
              .select('*, classes(*), departments(*), courses(*)')
              .eq('teacher', c);
          final r = await q;
          try {
            final list = List<Map<String, dynamic>>.from(r as List);
            if (list.isNotEmpty) {
              rows = list;
              break;
            }
          } catch (_) {}
        } catch (_) {}

        try {
          final q2 = _supabase
              .from('timetables')
              .select('*, classes(*), departments(*), courses(*)')
              .eq('teacher', c);
          final r2 = await q2;
          try {
            final list2 = List<Map<String, dynamic>>.from(r2 as List);
            if (list2.isNotEmpty) {
              rows = list2;
              break;
            }
          } catch (_) {}
        } catch (_) {}

        try {
          // Try searching sessions JSON/text for the candidate
          final s1 = _supabase
              .from('time_table')
              .select('*, classes(*), departments(*), courses(*)')
              .ilike('sessions', '%$c%');
          final r3 = await s1;
          try {
            final list3 = List<Map<String, dynamic>>.from(r3 as List);
            if (list3.isNotEmpty) {
              rows = list3;
              break;
            }
          } catch (_) {}
        } catch (_) {}

        try {
          final s2 = _supabase
              .from('timetables')
              .select('*, classes(*), departments(*), courses(*)')
              .ilike('sessions', '%$c%');
          final r4 = await s2;
          try {
            final list4 = List<Map<String, dynamic>>.from(r4 as List);
            if (list4.isNotEmpty) {
              rows = list4;
              break;
            }
          } catch (_) {}
        } catch (_) {}
      }

      // Last-resort: if none of the targeted queries found anything,
      // fall back to reading the whole timetables tables (expand relations)
      if (rows.isEmpty) {
        try {
          final q = _supabase
              .from('time_table')
              .select('*, classes(*), departments(*), courses(*)');
          final r = await q;
          try {
            rows = List<Map<String, dynamic>>.from(r as List);
          } catch (_) {}
        } catch (_) {}
        if (rows.isEmpty) {
          try {
            final q2 = await _supabase
                .from('timetables')
                .select('*, classes(*), departments(*), courses(*)');
            try {
              rows = List<Map<String, dynamic>>.from(q2 as List);
            } catch (_) {}
          } catch (_) {}
        }
      }
    }

    // Map and return unique LecturerSchedule entries
    final mapped = rows
        .map<LecturerSchedule>(
          (r) => LecturerSchedule.fromJson(Map<String, dynamic>.from(r)),
        )
        .toList();

    // Deduplicate by id
    final seen = <String>{};
    final out = <LecturerSchedule>[];
    for (final m in mapped) {
      if (m.id.isEmpty) continue;
      if (seen.add(m.id)) out.add(m);
    }
    return out;
  }

  /// 3️⃣ Insert generated QR to table
  Future<Map<String, dynamic>> createQr({
    required String payload,
    String? teacherId,
  }) async {
    final row = await _supabase
        .from('qr_generation')
        .insert({
          'generate_qr_code': payload,
          if (teacherId != null) 'teacher_id': teacherId,
        })
        .select()
        .maybeSingle();

    if (row == null) {
      throw Exception('Insert failed.');
    }

    return Map<String, dynamic>.from(row);
  }
}
