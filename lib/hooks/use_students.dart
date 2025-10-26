import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'use_user_handling.dart';
import '../models/student.dart';

class UseStudents {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<String?> _resolveAdminFacultyId() async {
    try {
      final current = _supabase.auth.currentUser;
      if (current == null) return null;
      final authUid = current.id;

      Map<String, dynamic>? uh;
      try {
        final res = await _supabase
            .from('user_handling')
            .select('id, usernames, role')
            .eq('auth_uid', authUid)
            .maybeSingle();
        if (res != null) uh = res as Map<String, dynamic>?;
      } catch (e) {
        debugPrint('user_handling auth_uid lookup failed in students: $e');
      }
      if (uh == null) return null;
      final role = (uh['role'] ?? '').toString().trim().toLowerCase();
      if (role != 'admin') return null;

      final uhId = (uh['id'] ?? '').toString();
      final username = (uh['usernames'] ?? '').toString();

      Map<String, dynamic>? adminRow;
      if (uhId.isNotEmpty) {
        final ar = await _supabase
            .from('admins')
            .select(
              'faculty_id, faculty_name, user_handling_id, user_id, username',
            )
            .eq('user_handling_id', uhId)
            .maybeSingle();
        if (ar != null) adminRow = ar;
      }
      if (adminRow == null && username.isNotEmpty) {
        final ar2 = await _supabase
            .from('admins')
            .select(
              'faculty_id, faculty_name, user_handling_id, user_id, username',
            )
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
    } catch (_) {
      return null;
    }
  }

  Future<List<Student>> fetchStudents({
    int? limit,
    int? page,
    String? facultyId,
  }) async {
    try {
      String? resolvedFacultyId = facultyId;
      if (resolvedFacultyId == null || resolvedFacultyId.isEmpty) {
        try {
          resolvedFacultyId = await _resolveAdminFacultyId();
        } catch (_) {}
      }

      var query = _supabase
          .from('students')
          .select(
            'id, username, fullname, gender, department, class, password, created_at, faculty_id, faculty:faculties(id,faculty_name), department:departments(id, department_name), class:classes(id, class_name)',
          )
          .order('created_at', ascending: false);
      final dynamic builder = query;
      if (resolvedFacultyId != null && resolvedFacultyId.isNotEmpty) {
        builder.eq('faculty_id', resolvedFacultyId);
      }

      if (limit != null) {
        final int offset = (page ?? 0) * limit;
        query = query.range(offset, offset + limit - 1);
      }

      final List<dynamic> rows = await query as List<dynamic>;

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
          if (first is Map) {
            return (first[altNameKey] ??
                    first['department_name'] ??
                    first['class_name'] ??
                    '')
                as String;
          }
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

      return rows.map((e) {
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
            'id, username, fullname, gender, department, class, password, created_at, faculty_id, faculty:faculties(id,faculty_name), department:departments(id, department_name), class:classes(id, class_name)',
          )
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;

      final e = Map<String, dynamic>.from(response as Map);

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

  Future<void> addStudent(Student student, {String? facultyId}) async {
    try {
      String? resolvedFacultyId = facultyId;
      if (resolvedFacultyId == null || resolvedFacultyId.isEmpty) {
        try {
          resolvedFacultyId = await _resolveAdminFacultyId();
        } catch (_) {}
      }

      await _supabase.from('students').insert({
        'fullname': student.fullName,
        'username': student.username,
        'gender': student.gender,
        'class': student.classId.isNotEmpty
            ? student.classId
            : student.className,
        'department': student.departmentId.isNotEmpty
            ? student.departmentId
            : student.department,
        'password': student.password,
        if (resolvedFacultyId != null && resolvedFacultyId.isNotEmpty)
          'faculty_id': resolvedFacultyId,
      });
    } catch (e) {
      throw Exception('Failed to add student: $e');
    }
  }

  Future<void> updateStudent(
    String id,
    Student student, {
    String? facultyId,
  }) async {
    try {
      final Map<String, dynamic> data = {
        'fullname': student.fullName,
        'username': student.username,
        'gender': student.gender,
        'password': student.password,
      };

      // Resolve department id: prefer explicit ID, otherwise lookup by name
      String? resolvedDeptId;
      if (student.departmentId.isNotEmpty) {
        resolvedDeptId = student.departmentId;
      } else if (student.department.isNotEmpty) {
        try {
          final depResp = await _supabase
              .from('departments')
              .select('id')
              .eq('department_name', student.department)
              .maybeSingle();
          if (depResp != null && depResp['id'] != null) {
            resolvedDeptId = depResp['id'].toString();
          }
        } catch (_) {
          // ignore lookup errors and don't overwrite existing value
        }
      }
      if (resolvedDeptId != null && resolvedDeptId.isNotEmpty) {
        data['department'] = resolvedDeptId;
      }

      // Resolve class id: prefer explicit ID, otherwise lookup by name
      String? resolvedClassId;
      if (student.classId.isNotEmpty) {
        resolvedClassId = student.classId;
      } else if (student.className.isNotEmpty) {
        try {
          final clsResp = await _supabase
              .from('classes')
              .select('id')
              .eq('class_name', student.className)
              .maybeSingle();
          if (clsResp != null && clsResp['id'] != null) {
            resolvedClassId = clsResp['id'].toString();
          }
        } catch (_) {
          // ignore lookup errors and don't overwrite existing value
        }
      }
      if (resolvedClassId != null && resolvedClassId.isNotEmpty) {
        data['class'] = resolvedClassId;
      }

      String? resolvedFacultyId = facultyId;
      if (resolvedFacultyId == null || resolvedFacultyId.isEmpty) {
        try {
          resolvedFacultyId = await _resolveAdminFacultyId();
        } catch (_) {}
      }
      if (resolvedFacultyId != null && resolvedFacultyId.isNotEmpty) {
        data['faculty_id'] = resolvedFacultyId;
      }

      // Fetch existing student row for old username / user_handling_id
      final existing = await _supabase
          .from('students')
          .select('username, user_handling_id')
          .eq('id', id)
          .maybeSingle();

      final oldUsername = (existing != null && existing['username'] != null)
          ? existing['username'].toString().trim()
          : '';
      final existingUhId =
          (existing != null && existing['user_handling_id'] != null)
          ? existing['user_handling_id'].toString()
          : null;

      await _supabase.from('students').update(data).eq('id', id);

      // After updating the students table, try to update linked user_handling row first
      try {
        final newUsername = student.username.trim();
        final newPassword = student.password.trim();

        String? uhId;

        if (existingUhId != null && existingUhId.isNotEmpty) {
          final updateData = <String, dynamic>{
            if (newUsername.isNotEmpty) 'usernames': newUsername,
            'role': 'student',
            if (newPassword.isNotEmpty) 'passwords': newPassword,
          };

          try {
            final updated = await _supabase
                .from('user_handling')
                .update(updateData)
                .eq('id', existingUhId)
                .select()
                .maybeSingle();
            if (updated != null && updated['id'] != null)
              uhId = updated['id'] as String;
          } catch (e) {
            debugPrint(
              'Failed to update user_handling by id $existingUhId: $e',
            );
          }
        }

        if ((uhId == null || uhId.isEmpty) && oldUsername.isNotEmpty) {
          try {
            final updated = await _supabase
                .from('user_handling')
                .update({
                  if (newUsername.isNotEmpty) 'usernames': newUsername,
                  'role': 'student',
                  if (newPassword.isNotEmpty) 'passwords': newPassword,
                })
                .eq('usernames', oldUsername)
                .select()
                .maybeSingle();
            if (updated != null && updated['id'] != null)
              uhId = updated['id'] as String;
          } catch (e) {
            debugPrint(
              'Failed to update user_handling by old username $oldUsername: $e',
            );
          }
        }

        if (uhId == null || uhId.isEmpty) {
          try {
            final created = await upsertUserHandling(
              _supabase,
              newUsername,
              'student',
              newPassword,
            );
            if (created != null && created.isNotEmpty) uhId = created;
          } catch (e) {
            debugPrint(
              'Fallback upsertUserHandling failed for $newUsername: $e',
            );
          }
        }

        if (uhId != null && uhId.isNotEmpty) {
          // If you added user_handling_id/user_id columns to students, update them here.
          // For the default schema we only ensure username/password are kept in sync.
        }
      } catch (e) {
        debugPrint(
          'Failed to upsert/link user_handling for student ${student.username}: $e',
        );
      }
    } catch (e) {
      throw Exception('Failed to update student: $e');
    }
  }

  /// Delete a student by id.
  Future<void> deleteStudent(String id) async {
    try {
      // Fetch the student row to get the username or user_handling_id
      final student = await _supabase
          .from('students')
          .select('username, user_handling_id')
          .eq('id', id)
          .maybeSingle();

      String? username = student?['username'] as String?;
      String? uhId = student?['user_handling_id'] as String?;

      // Delete the student row
      await _supabase.from('students').delete().eq('id', id);

      // Delete the user_handling row (by id if possible, else by username)
      if (uhId != null && uhId.isNotEmpty) {
        // Try to resolve username for the user_handling row and perform a safe delete
        try {
          final uh = await _supabase
              .from('user_handling')
              .select('username')
              .eq('id', uhId)
              .maybeSingle();
          final resolvedUsername = (uh != null && uh['username'] != null)
              ? uh['username'].toString().trim()
              : '';

          if (resolvedUsername.isNotEmpty) {
            await safeDeleteUserHandling(_supabase, resolvedUsername);
          } else {
            // fallback: try delete by id but ignore failures
            try {
              await _supabase.from('user_handling').delete().eq('id', uhId);
            } catch (e) {
              debugPrint('Failed to delete user_handling by id $uhId: $e');
            }
          }
        } catch (e) {
          debugPrint('Failed to resolve user_handling by id $uhId: $e');
        }
      } else if (username != null && username.isNotEmpty) {
        try {
          await safeDeleteUserHandling(_supabase, username);
        } catch (e) {
          debugPrint(
            'Failed to attempt safe delete of user_handling for username=$username: $e',
          );
        }
      }
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

  /// Fetch students for a given department and class (and optionally section).
  /// This reuses fetchStudents and filters client-side by display names.
  Future<List<Student>> fetchStudentsByDeptClassSection({
    required String department,
    required String className,
    String? section,
    int? limit,
    int? page,
  }) async {
    try {
      final int fetchLimit = limit ?? 1000;
      final students = await fetchStudents(limit: fetchLimit, page: page ?? 0);

      final filtered = students.where((s) {
        final matchesDept = s.department.toString().trim() == department.trim();
        final matchesClass = s.className.toString().trim() == className.trim();

        if (section == null || section.trim().isEmpty)
          return matchesDept && matchesClass;

        final dynamic maybeSection = (s as dynamic).section;
        if (maybeSection != null) {
          return matchesDept &&
              matchesClass &&
              maybeSection.toString().trim() == section.trim();
        }

        return matchesDept && matchesClass;
      }).toList();

      return filtered;
    } catch (e) {
      throw Exception(
        'Failed to fetch students by department/class/section: $e',
      );
    }
  }

  /// Server-side: Fetch students by departmentId and classId (preferred for performance).
  Future<List<Student>> fetchStudentsByDeptClassId({
    required String departmentId,
    required String classId,
    int? limit,
    int? page,
  }) async {
    try {
      var query = _supabase
          .from('students')
          .select(
            'id, username, fullname, gender, department, class, password, created_at, faculty_id, faculty:faculties(id,faculty_name), department:departments(id, department_name), class:classes(id, class_name)',
          )
          .eq('department', departmentId)
          .eq('class', classId)
          .order('fullname', ascending: true);

      if (limit != null) {
        final int offset = (page ?? 0) * limit;
        query = query.range(offset, offset + limit - 1);
      }

      final List<dynamic> data = await query as List<dynamic>;

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

      return data.map<Student>((e) {
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
      throw Exception('Failed to fetch students by department/class ids: $e');
    }
  }

  /// Fetch departments list
  Future<List<Map<String, String>>> fetchDepartments() async {
    try {
      final resp = await _supabase
          .from('departments')
          .select('id, department_name, faculty_id')
          .order('department_name', ascending: true);
      final List<dynamic> rows = resp as List<dynamic>;
      return rows.map((r) {
        return {
          'id': (r['id'] ?? '') as String,
          'name': (r['department_name'] ?? '') as String,
        };
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch departments: $e');
    }
  }

  /// Fetch classes list (optionally filtered by departmentId)
  Future<List<Map<String, String>>> fetchClasses({String? departmentId}) async {
    try {
      dynamic builder = _supabase
          .from('classes')
          .select('id, class_name, department, faculty_id');
      if (departmentId != null && departmentId.isNotEmpty) {
        builder = builder.eq('department', departmentId);
      }
      builder = builder.order('class_name', ascending: true);
      final resp = await builder;
      final List<dynamic> rows = resp as List<dynamic>;
      return rows.map((r) {
        return {
          'id': (r['id'] ?? '') as String,
          'name': (r['class_name'] ?? '') as String,
          'department': (r['department'] ?? '') as String,
        };
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch classes: $e');
    }
  }
}
