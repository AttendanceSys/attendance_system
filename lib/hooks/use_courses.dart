import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/course.dart';

class UseCourses {
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _looksLikeUuid(String s) {
    final uuidReg = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\$',
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

    final resp = await _supabase
        .from('classes')
        .select('id')
        .eq('class_name', val)
        .maybeSingle();
    if (resp == null) return null;
    if (resp['id'] != null) return resp['id'].toString();
    return null;
  }

  Future<List<Course>> fetchCourses({int? limit, int? page}) async {
    try {
      var query = _supabase
          .from('courses')
          .select(
            'id, course_code, course_name, teacher_assigned, class, semister, created_at, teacher_assigned:teachers(id, teacher_name, username), class:classes(id, class_name)',
          )
          .order('created_at', ascending: false);

      if (limit != null) {
        final int offset = (page ?? 0) * limit;
        query = query.range(offset, offset + limit - 1);
      }

      final response = await query;
      final rows = response as List<dynamic>;

      // collect teacher and class ids when API returned plain uuids
      final Set<String> teacherIds = {};
      final Set<String> classIds = {};

      for (final r in rows) {
        if (r is Map) {
          final t = r['teacher_assigned'];
          if (t is String && t.isNotEmpty) teacherIds.add(t);
          final c = r['class'];
          if (c is String && c.isNotEmpty) classIds.add(c);
        }
      }

      // batch fetch teacher names and class names if needed
      Map<String, String> teacherNameById = {};
      Map<String, String> classNameById = {};

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

        return Course.fromMap(map);
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch courses: $e');
    }
  }

  Future<Course?> fetchCourseById(String id) async {
    try {
      final dynamic response = await _supabase
          .from('courses')
          .select(
            'id, course_code, course_name, teacher_assigned, class, semister, created_at, teacher_assigned:teachers(id, teacher_name, username), class:classes(id, class_name)',
          )
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return Course.fromMap(response);
    } catch (e) {
      throw Exception('Failed to fetch course by id: $e');
    }
  }

  Future<void> addCourse(Course course) async {
    try {
      // resolve teacher/class display values to IDs when possible
      final Map<String, dynamic> data = {
        'course_code': course.code,
        'course_name': course.name,
        'semister': course.semester.toString(),
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

      // debug: log outgoing payload to help diagnose insertion issues
      // ignore: avoid_print
      print('Inserting course: $data');

      final resp = await _supabase.from('courses').insert(data);
      // ignore: avoid_print
      print('Insert response: $resp');
    } catch (e) {
      // ignore: avoid_print
      print('Failed to add course: $e');
      throw Exception('Failed to add course: $e');
    }
  }

  Future<void> updateCourse(String id, Course course) async {
    try {
      final Map<String, dynamic> data = {
        'course_code': course.code,
        'course_name': course.name,
        'semister': course.semester.toString(),
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

      // debug
      // ignore: avoid_print
      print('Updating course $id with $data');
      final resp = await _supabase.from('courses').update(data).eq('id', id);
      // ignore: avoid_print
      print('Update response: $resp');
    } catch (e) {
      // ignore: avoid_print
      print('Failed to update course: $e');
      throw Exception('Failed to update course: $e');
    }
  }

  Future<void> deleteCourse(String id) async {
    try {
      await _supabase.from('courses').delete().eq('id', id);
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
