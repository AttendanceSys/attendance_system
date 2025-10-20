import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/student.dart';

class UseStudents {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Student>> fetchStudents({int? limit, int? page}) async {
    try {
      // request related department and class display names when possible
      var query = _supabase
          .from('students')
          .select(
            'id, username, fullname, gender, department, class, password, created_at, department:departments(id, department_name), class:classes(id, class_name)',
          )
          .order('created_at', ascending: false);

      if (limit != null) {
        final int offset = (page ?? 0) * limit;
        query = query.range(offset, offset + limit - 1);
      }

      final response = await query;
      // Helper to safely extract display name and id from possibly nested relation
      String extractName(dynamic value, String altNameKey) {
        if (value == null) return '';
        // if PostgREST returned nested object (Map)
        if (value is Map) {
          return (value[altNameKey] ??
                  value['department_name'] ??
                  value['class_name'] ??
                  '')
              as String;
        }
        // if an array of related rows
        if (value is List && value.isNotEmpty) {
          final first = value.first;
          if (first is Map)
            return (first[altNameKey] ??
                    first['department_name'] ??
                    first['class_name'] ??
                    '')
                as String;
        }
        // otherwise fall back to empty string (we don't want to show uuid as name)
        return '';
      }

      String extractId(dynamic value) {
        if (value == null) return '';
        if (value is String) return value;
        if (value is Map) return (value['id'] ?? '') as String;
        if (value is List && value.isNotEmpty) {
          final first = value.first;
          if (first is Map) return (first['id'] ?? '') as String;
        }
        return '';
      }

      return (response as List).map((e) {
        // raw fk values (could be id string or nested relation object)
        final rawDept = e['department'];
        final rawClass = e['class'];

        final deptName =
            (e['department_name'] ?? extractName(rawDept, 'department_name'))
                as String;
        final className =
            (e['class_name'] ?? extractName(rawClass, 'class_name')) as String;

        final deptId = extractId(rawDept);
        final classId = extractId(rawClass);

        return Student(
          id: e['id'] as String,
          fullName: (e['fullname'] ?? '') as String,
          username: (e['username'] ?? '') as String,
          gender: (e['gender'] ?? '') as String,
          department: deptName,
          className: className,
          departmentId: deptId,
          classId: classId,
          password: (e['password'] ?? '') as String,
        );
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch students: $e');
    }
  }

  Future<Student?> fetchStudentById(String id) async {
    try {
      final response = await _supabase
          .from('students')
          .select(
            'id, username, fullname, gender, department, class, password, created_at, department:departments(id, department_name), class:classes(id, class_name)',
          )
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;

      final e = response;

      // extractors (same logic as list mapping)
      String extractName(dynamic value, String altNameKey) {
        if (value == null) return '';
        if (value is Map) {
          return (value[altNameKey] ??
                  value['department_name'] ??
                  value['class_name'] ??
                  '')
              as String;
        }
        if (value is List && value.isNotEmpty) {
          final first = value.first;
          if (first is Map)
            return (first[altNameKey] ??
                    first['department_name'] ??
                    first['class_name'] ??
                    '')
                as String;
        }
        return '';
      }

      String extractId(dynamic value) {
        if (value == null) return '';
        if (value is String) return value;
        if (value is Map) return (value['id'] ?? '') as String;
        if (value is List && value.isNotEmpty) {
          final first = value.first;
          if (first is Map) return (first['id'] ?? '') as String;
        }
        return '';
      }

      final rawDept = e['department'];
      final rawClass = e['class'];

      final deptName =
          (e['department_name'] ?? extractName(rawDept, 'department_name'))
              as String;
      final className =
          (e['class_name'] ?? extractName(rawClass, 'class_name')) as String;

      final deptId = extractId(rawDept);
      final classId = extractId(rawClass);

      return Student(
        id: e['id'] as String,
        fullName: (e['fullname'] ?? '') as String,
        username: (e['username'] ?? '') as String,
        gender: (e['gender'] ?? '') as String,
        department: deptName,
        className: className,
        departmentId: deptId,
        classId: classId,
        password: (e['password'] ?? '') as String,
      );
    } catch (e) {
      throw Exception('Failed to fetch student by id: $e');
    }
  }

  Future<void> addStudent(Student student) async {
    try {
      await _supabase.from('students').insert({
        'fullname': student.fullName,
        'username': student.username,
        'gender': student.gender,
        // send FK ids if present, otherwise fallback to names
        'class': student.classId.isNotEmpty
            ? student.classId
            : student.className,
        'department': student.departmentId.isNotEmpty
            ? student.departmentId
            : student.department,
        'password': student.password,
      });
    } catch (e) {
      throw Exception('Failed to add student: $e');
    }
  }

  Future<void> updateStudent(String id, Student student) async {
    try {
      await _supabase
          .from('students')
          .update({
            'fullname': student.fullName,
            'gender': student.gender,
            'class': student.classId.isNotEmpty
                ? student.classId
                : student.className,
            'department': student.departmentId.isNotEmpty
                ? student.departmentId
                : student.department,
            'password': student.password,
          })
          .eq('id', id);
    } catch (e) {
      throw Exception('Failed to update student: $e');
    }
  }

  Future<void> deleteStudent(String id) async {
    try {
      await _supabase.from('students').delete().eq('id', id);
    } catch (e) {
      throw Exception('Failed to delete student: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> subscribeStudents() {
    return _supabase
        .from('students')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false);
  }
}
