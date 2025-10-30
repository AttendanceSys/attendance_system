import 'package:supabase_flutter/supabase_flutter.dart';
// import '../models/student.dart';

class UseAttendance {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetch attendance rows with related student/department/class info.
  Future<List<Map<String, dynamic>>> fetchAttendanceWithRelations({
    String? departmentId,
    String? classId,
    String? date, // 'YYYY-MM-DD'
    String? facultyId,
    int? limit,
    int? page,
  }) async {
    try {
      final selectQuery =
          'id, department, class, course, student, date, created_at, status, '
          'student:students(id, fullname, username, department, class), '
          'department:departments(id, department_name), '
          'class:classes(id, class_name)';

      var builder = _supabase.from('attendance').select(selectQuery);

      if (facultyId != null && facultyId.isNotEmpty) {
        builder = (builder as dynamic).eq('faculty_id', facultyId);
      }

      if (departmentId != null && departmentId.trim().isNotEmpty) {
        builder = (builder as dynamic).eq('department', departmentId);
      }
      if (classId != null && classId.trim().isNotEmpty) {
        builder = (builder as dynamic).eq('class', classId);
      }
      if (date != null && date.trim().isNotEmpty) {
        builder = (builder as dynamic).eq('date', date);
      }

      dynamic executor = builder;
      if (limit != null) {
        final int offset = (page ?? 0) * limit;
        executor = executor.range(offset, offset + limit - 1);
      }

      final resp = await executor;
      final List<dynamic> rows = (resp is List) ? resp : <dynamic>[];
      final result = rows.map<Map<String, dynamic>>((r) {
        return {
          'id': r['id'],
          'department': r['department'],
          'class': r['class'],
          'course': r['course'],
          'student': r['student'] is Map ? r['student'] : {'id': r['student']},
          'date': r['date'],
          'created_at': r['created_at'],
          'status': r['status'],
          'department_row': r['department'] is Map ? r['department'] : null,
          'class_row': r['class'] is Map ? r['class'] : null,
        };
      }).toList();

      return result;
    } catch (e) {
      throw Exception('Failed to fetch attendance with relations: $e');
    }
  }

  /// Initialize attendance rows for a list of student IDs (upsert).
  Future<bool> initializeAttendanceForStudents({
    required String departmentId,
    required String classId,
    required String date,
    required List<String> studentIds,
    bool defaultPresent = false,
    String presentValue = 'present',
    String absentValue = 'absent',
  }) async {
    try {
      if (studentIds.isEmpty) return true;

      final payload = studentIds.map<Map<String, dynamic>>((sid) {
        return {
          'department': departmentId,
          'class': classId,
          'course': null,
          'student': sid,
          'date': date,
          'status': defaultPresent ? presentValue : absentValue,
          if (departmentId.isNotEmpty) 'faculty_id': departmentId,
        };
      }).toList();

      await _supabase.from('attendance').upsert(payload);
      return true;
    } catch (e, st) {
      // Log full details to help debugging (preserve original stack)
      print('Failed to initialize attendance for students: $e\n$st');
      rethrow;
    }
  }

  /// Upsert a single attendance row for [studentId] and [date].
  Future<bool> updateAttendanceSingle({
    required String studentId,
    required String date,
    required bool present,
    required String departmentId,
    required String classId,
    String? courseId,
    String presentValue = 'present',
    String absentValue = 'absent',
  }) async {
    try {
      final status = present ? presentValue : absentValue;
      final payload = {
        'department': departmentId,
        'class': classId,
        'course': courseId,
        'student': studentId,
        'date': date,
        'status': status,
        if (departmentId.isNotEmpty) 'faculty_id': departmentId,
      };

      await _supabase.from('attendance').upsert(payload);
      return true;
    } catch (e, st) {
      print('Failed to update attendance single: $e\n$st');
      rethrow;
    }
  }

  /// Batch upsert multiple attendance rows at once.
  Future<bool> batchUpdateAttendance({
    required String departmentId,
    required String classId,
    String? courseId,
    required String date,
    required List<Map<String, dynamic>> updates,
    String presentValue = 'present',
    String absentValue = 'absent',
  }) async {
    try {
      if (updates.isEmpty) return true;

      final payload = updates.map<Map<String, dynamic>>((u) {
        final String sid = u['studentId'] as String;
        final bool present = u['present'] as bool;
        return {
          'department': departmentId,
          'class': classId,
          'course': courseId,
          'student': sid,
          'date': date,
          'status': present ? presentValue : absentValue,
          if (departmentId.isNotEmpty) 'faculty_id': departmentId,
        };
      }).toList();

      await _supabase.from('attendance').upsert(payload);
      return true;
    } catch (e, st) {
      print('Failed to batch update attendance: $e\n$st');
      rethrow;
    }
  }
}
