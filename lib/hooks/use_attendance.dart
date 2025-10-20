import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/attendance.dart';

class UseAttendance {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetch attendance records with optional filters and pagination.
  /// Joins related tables (departments, classes, courses, students) to provide
  /// readable names when available.
  Future<List<Attendance>> fetchAttendance({
    String? departmentId,
    String? classId,
    String? courseId,
    String? studentId,
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

      final query = _supabase.from('attendance').select(select);

      if (departmentId != null) query.eq('department', departmentId);
      if (classId != null) query.eq('class', classId);
      if (courseId != null) query.eq('course', courseId);
      if (studentId != null) query.eq('student', studentId);
      if (date != null)
        query.eq('date', date.toIso8601String().split('T').first);

      // Apply transforms (order, range) on a separate variable so types match
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
          if (e['student'] is Map)
            return (e['student']['fullname'] ?? '') as String;
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

  /// Stream for real-time attendance changes.
  Stream<List<Map<String, dynamic>>> subscribeAttendance() {
    return _supabase
        .from('attendance')
        .stream(primaryKey: ['id'])
        .order('date', ascending: false);
  }
}
