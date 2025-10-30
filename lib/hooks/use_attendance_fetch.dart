import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/attendance.dart';

/// New attendance fetch hook. Provides a typed fetch that maps to the
/// `Attendance` model and a raw fetch that preserves date and timestamps.
class UseAttendanceFetch {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetch attendance records and map them to the `Attendance` model.
  /// Supports optional filtering and pagination.
  Future<List<Attendance>> fetchAttendance({
    String? departmentId,
    String? classId,
    String? courseId,
    String? studentId,
    String? facultyId,
    DateTime? date,
    int? limit,
    int? page,
  }) async {
    try {
      final select = '''
        id,
        date,
        created_at,
        department,
        class,
        course,
        student,
        department:departments(id, department_name),
        class:classes(id, class_name),
        course:courses(id, course_name),
        student:students(id, fullname, username)
      ''';

      var query = _supabase.from('attendance').select(select);

      if (facultyId != null && facultyId.isNotEmpty) {
        query = (query as dynamic).eq('faculty_id', facultyId);
      }
      if (departmentId != null) {
        query = (query as dynamic).eq('department', departmentId);
      }
      if (classId != null) query = (query as dynamic).eq('class', classId);
      if (courseId != null) query = (query as dynamic).eq('course', courseId);
      if (studentId != null) {
        query = (query as dynamic).eq('student', studentId);
      }
      if (date != null) {
        query = (query as dynamic).eq(
          'date',
          date.toIso8601String().split('T').first,
        );
      }

      var request = query.order('date', ascending: false);

      if (limit != null) {
        final int offset = (page ?? 0) * limit;
        request = request.range(offset, offset + limit - 1);
      }

      final response = await request;

      String extractName(dynamic value, String altKey) {
        if (value == null) return '';
        if (value is Map) return (value[altKey] ?? '') as String;
        if (value is List && value.isNotEmpty) {
          final first = value.first;
          if (first is Map) return (first[altKey] ?? '') as String;
        }
        return '';
      }

      return (response as List).map((e) {
        final rawDept = e['department'];
        final rawClass = e['class'];
        final rawStudent = e['student'];

        final deptName =
            (e['department_name'] ?? extractName(rawDept, 'department_name'))
                as String;
        final className =
            (e['class_name'] ?? extractName(rawClass, 'class_name')) as String;

        final studentName = (() {
          if (e['student'] is Map) {
            return (e['student']['fullname'] ?? '') as String;
          }
          return extractName(rawStudent, 'fullname');
        })();

        return Attendance(
          id: e['id'] as String,
          name: studentName,
          department: deptName,
          className: className,
          status: true,
        );
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch attendance: $e');
    }
  }

  /// Fetch attendance as raw maps including `date` and `created_at` fields.
  Future<List<Map<String, dynamic>>> fetchAttendanceRaw({
    String? departmentId,
    String? classId,
    String? courseId,
    String? studentId,
    String? facultyId,
    DateTime? date,
    int? limit,
    int? page,
  }) async {
    try {
      final select = '''
        id,
        date,
        created_at,
        department,
        class,
        course,
        student,
        department:departments(id, department_name),
        class:classes(id, class_name),
        course:courses(id, course_name),
        student:students(id, fullname, username)
      ''';

      var query = _supabase.from('attendance').select(select);
      if (facultyId != null && facultyId.isNotEmpty) {
        query = (query as dynamic).eq('faculty_id', facultyId);
      }
      if (departmentId != null) {
        query = (query as dynamic).eq('department', departmentId);
      }
      if (classId != null) query = (query as dynamic).eq('class', classId);
      if (courseId != null) query = (query as dynamic).eq('course', courseId);
      if (studentId != null) {
        query = (query as dynamic).eq('student', studentId);
      }
      if (date != null) {
        query = (query as dynamic).eq(
          'date',
          date.toIso8601String().split('T').first,
        );
      }

      var request = query.order('date', ascending: false);

      if (limit != null) {
        final int offset = (page ?? 0) * limit;
        request = request.range(offset, offset + limit - 1);
      }

      final response = await request;

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      throw Exception('Failed to fetch attendance (raw): $e');
    }
  }

  /// Stream for real-time attendance row changes.
  Stream<List<Map<String, dynamic>>> subscribeAttendance() {
    return _supabase
        .from('attendance')
        .stream(primaryKey: ['id'])
        .order('date', ascending: false);
  }
}
