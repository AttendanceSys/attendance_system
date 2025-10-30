import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'use_user_handling.dart';
import '../models/student.dart';

class UseStudents {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Public wrapper to resolve the current admin's faculty id.
  /// Returns null if not an admin or resolution fails.
  Future<String?> resolveAdminFacultyId() async {
    return await _resolveAdminFacultyId();
  }

  Future<String?> _resolveAdminFacultyId() async {
    try {
      final current = _supabase.auth.currentUser;
      if (current == null) return null;
      final authUid = current.id;

      Map<String, dynamic>? uh;
      try {
        // use singular `username` column name (schema uses `username`)
        final res = await _supabase
            .from('user_handling')
            .select('id, username, role')
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
      final username = (uh['username'] ?? '').toString();

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

      // If we couldn't resolve a faculty id for the current admin, return
      // an empty list rather than performing an un-scoped query. This
      // allows the UI to present a create flow for new students instead
      // of showing an error or exposing other faculties' data.
      if (resolvedFacultyId == null || resolvedFacultyId.isEmpty) {
        return <Student>[];
      }

      // Build a select string. Some schemas may not have `gender` column.
      String selectWithGender =
          'id, username, fullname, gender, department, class, password, created_at, faculty_id, faculty:faculties(id,faculty_name), department:departments(id, department_name), class:classes(id, class_name)';
      String selectWithoutGender =
          'id, username, fullname, department, class, password, created_at, faculty_id, faculty:faculties(id,faculty_name), department:departments(id, department_name), class:classes(id, class_name)';

      dynamic query = _supabase.from('students').select(selectWithGender);
      // Apply faculty filter before ordering to avoid calling `.eq` on a
      // transform object that doesn't expose the filter methods in some
      // runtime builds.
      query = (query as dynamic).eq('faculty_id', resolvedFacultyId);
      query = query.order('created_at', ascending: false);

      if (limit != null) {
        final int offset = (page ?? 0) * limit;
        query = query.range(offset, offset + limit - 1);
      }

      List<dynamic> rows;
      try {
        rows = await query as List<dynamic>;
      } catch (e) {
        // If the error indicates a missing column (e.g., gender), retry without it.
        final msg = e.toString().toLowerCase();
        if (msg.contains('does not exist') && msg.contains('gender')) {
          dynamic fallbackQuery = _supabase
              .from('students')
              .select(selectWithoutGender);
          try {
            fallbackQuery = (fallbackQuery as dynamic).eq(
              'faculty_id',
              resolvedFacultyId,
            );
          } catch (_) {
            // ignore - defensive fallback; rare case where builder doesn't expose eq
          }
          fallbackQuery = (fallbackQuery as dynamic).order(
            'created_at',
            ascending: false,
          );
          if (limit != null) {
            final int offset = (page ?? 0) * limit;
            fallbackQuery = (fallbackQuery as dynamic).range(
              offset,
              offset + limit - 1,
            );
          }
          rows = await fallbackQuery as List<dynamic>;
        } else {
          rethrow;
        }
      }

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
      if (e is NoSuchMethodError) {
        debugPrint(
          'fetchStudents: NoSuchMethodError, returning empty list: $e',
        );
        return <Student>[];
      }
      throw Exception('Failed to fetch students: $e');
    }
  }

  Future<Student?> fetchStudentById(String id) async {
    try {
      final selectWithGender =
          'id, username, fullname, gender, department, class, password, created_at, faculty_id, faculty:faculties(id,faculty_name), department:departments(id, department_name), class:classes(id, class_name)';
      final selectWithoutGender =
          'id, username, fullname, department, class, password, created_at, faculty_id, faculty:faculties(id,faculty_name), department:departments(id, department_name), class:classes(id, class_name)';

      dynamic response;
      try {
        response = await _supabase
            .from('students')
            .select(selectWithGender)
            .eq('id', id)
            .maybeSingle();
      } catch (e) {
        final msg = e.toString().toLowerCase();
        if (msg.contains('does not exist') && msg.contains('gender')) {
          response = await _supabase
              .from('students')
              .select(selectWithoutGender)
              .eq('id', id)
              .maybeSingle();
        } else {
          rethrow;
        }
      }

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

      // Enforce presence of faculty_id for new students. If we can't resolve
      // a faculty id for the current admin, abort to avoid inserting rows
      // with NULL faculty_id.
      if (resolvedFacultyId == null || resolvedFacultyId.isEmpty) {
        throw Exception(
          'Cannot add student: no faculty assigned to current admin',
        );
      }
      // Ensure a corresponding `user_handling` row exists first. Some DB
      // schemas have a foreign-key constraint from `students.username` ->
      // `user_handling.username`, so we must upsert the user_handling row
      // before inserting the student.
      String? uhId;
      if (student.username.trim().isNotEmpty) {
        uhId = await upsertUserHandling(
          _supabase,
          student.username.trim(),
          'student',
          student.password.trim(),
        );
        if (uhId == null) {
          throw Exception(
            'Failed to ensure user_handling exists for username=${student.username}',
          );
        }
      }

      // Try inserting with `gender` first; if the column is missing in the
      // database schema (some deployments may not have it), retry without it.
      // Build payload for initial insert — do NOT include `user_handling_id`
      // here because many schemas don't have that column. Including it
      // causes the insert to fail and our fallback logic would remove
      // `gender` as well. Instead, insert the student first (with gender)
      // and then try to write `user_handling_id` in a separate update.
      final payloadWithGender = {
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
        // resolvedFacultyId is guaranteed non-null here
        'faculty_id': resolvedFacultyId,
      };

      try {
        await _supabase.from('students').insert(payloadWithGender);

        // Now attempt to write user_handling_id into the students row if we
        // created/ensured a user_handling above. Update by username (unique
        // in user_handling) so this works on schemas without the column too
        // (we'll catch missing-column errors below).
        if (uhId != null && uhId.isNotEmpty) {
          try {
            await _supabase
                .from('students')
                .update({'user_handling_id': uhId})
                .eq('username', student.username);
          } catch (e) {
            final msg = e.toString().toLowerCase();
            if (msg.contains('does not exist') &&
                msg.contains('user_handling_id')) {
              // Column missing in this schema — ignore silently.
              debugPrint(
                'students.user_handling_id column not present; skipping write',
              );
            } else {
              // Non-schema-related error — log for inspection but don't fail
              debugPrint('Failed to write user_handling_id: $e');
            }
          }
        }
      } catch (e) {
        final msg = e.toString().toLowerCase();

        // If the failure explicitly mentions `gender` missing, retry without it.
        if (msg.contains('gender') &&
            (msg.contains('does not exist') ||
                msg.contains('could not find') ||
                msg.contains('pgrst204') ||
                msg.contains('not exist'))) {
          final payloadFallback = Map<String, dynamic>.from(payloadWithGender)
            ..remove('gender');
          await _supabase.from('students').insert(payloadFallback);
        } else {
          rethrow;
        }
      }
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

      // Fetch existing student row for old username / user_handling_id.
      // Some DB schemas don't have `students.user_handling_id`. Try selecting
      // it first and fall back to selecting only `username` if the column is
      // missing (Postgrest will throw an error in that case).
      dynamic existing;
      try {
        existing = await _supabase
            .from('students')
            .select('username, user_handling_id')
            .eq('id', id)
            .maybeSingle();
      } catch (e) {
        final msg = e.toString().toLowerCase();
        if (msg.contains('does not exist') &&
            msg.contains('user_handling_id')) {
          // retry without the non-existent column
          existing = await _supabase
              .from('students')
              .select('username')
              .eq('id', id)
              .maybeSingle();
        } else {
          rethrow;
        }
      }

      final oldUsername = (existing != null && existing['username'] != null)
          ? existing['username'].toString().trim()
          : '';
      final existingUhId =
          (existing != null && existing['user_handling_id'] != null)
          ? existing['user_handling_id'].toString()
          : null;

      // If the username is changing (or new) ensure the user_handling row
      // exists/upsert BEFORE updating the students row to satisfy any
      // foreign-key constraints that reference user_handling.username.
      final newUsername = student.username.trim();
      final oldUsernameLookup =
          (existing != null && existing['username'] != null)
          ? existing['username'].toString().trim()
          : '';
      if (newUsername.isNotEmpty && newUsername != oldUsernameLookup) {
        final uhId = await upsertUserHandling(
          _supabase,
          newUsername,
          'student',
          student.password.trim(),
        );
        if (uhId == null) {
          throw Exception(
            'Failed to ensure user_handling exists for username=$newUsername before updating student',
          );
        }
      }

      // Attempt update; if `gender` column doesn't exist, retry without it.
      try {
        await _supabase.from('students').update(data).eq('id', id);
      } catch (e) {
        final msg = e.toString().toLowerCase();
        if (msg.contains('gender') &&
            (msg.contains('does not exist') ||
                msg.contains('could not find') ||
                msg.contains('pgrst204') ||
                msg.contains('not exist'))) {
          final dataNoGender = Map<String, dynamic>.from(data)
            ..remove('gender');
          await _supabase.from('students').update(dataNoGender).eq('id', id);
        } else {
          rethrow;
        }
      }

      // After updating the students table, try to update linked user_handling row first
      try {
        final newUsername = student.username.trim();
        final newPassword = student.password.trim();

        String? uhId;

        if (existingUhId != null && existingUhId.isNotEmpty) {
          final updateData = <String, dynamic>{
            if (newUsername.isNotEmpty) 'username': newUsername,
            'role': 'student',
            if (newPassword.isNotEmpty) 'password': newPassword,
          };

          try {
            final updated = await _supabase
                .from('user_handling')
                .update(updateData)
                .eq('id', existingUhId)
                .select()
                .maybeSingle();
            if (updated != null && updated['id'] != null) {
              uhId = updated['id'] as String;
            }
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
                  if (newUsername.isNotEmpty) 'username': newUsername,
                  'role': 'student',
                  if (newPassword.isNotEmpty) 'password': newPassword,
                })
                .eq('username', oldUsername)
                .select()
                .maybeSingle();
            if (updated != null && updated['id'] != null) {
              uhId = updated['id'] as String;
            }
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
          try {
            // Attempt to write the user_handling_id into the students row if the
            // column exists. If the column doesn't exist, ignore the error.
            await _supabase
                .from('students')
                .update({'user_handling_id': uhId})
                .eq('id', id);
          } catch (e) {
            final msg = e.toString().toLowerCase();
            if (msg.contains('does not exist') &&
                msg.contains('user_handling_id')) {
              // Column missing on this schema; that's fine — continue.
              debugPrint(
                'students.user_handling_id column not present; skipping write',
              );
            } else {
              debugPrint(
                'Failed to write user_handling_id into students row: $e',
              );
            }
          }
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
      // Fetch the student row to get the username or user_handling_id.
      // Some schemas don't have `students.user_handling_id` so try selecting
      // it and fall back to selecting only `username` when the column is
      // missing.
      dynamic student;
      try {
        student = await _supabase
            .from('students')
            .select('username, user_handling_id')
            .eq('id', id)
            .maybeSingle();
      } catch (e) {
        final msg = e.toString().toLowerCase();
        if (msg.contains('does not exist') &&
            msg.contains('user_handling_id')) {
          student = await _supabase
              .from('students')
              .select('username')
              .eq('id', id)
              .maybeSingle();
        } else {
          rethrow;
        }
      }

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
    // Use a StreamController so we can manage the Supabase realtime
    // subscription lifecycle explicitly and recover from channel errors
    // (RealtimeSubscribeException) or JS interop TypeErrors without
    // propagating uncaught exceptions to the UI.

    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
    StreamSubscription<dynamic>? supaSub;
    var attempt = 0;

    Future<void> startSubscription() async {
      try {
        // Resolve faculty id and scope the subscription where possible. This
        // narrows the realtime channel topic and reduces rejoin/close churn
        // (and avoids exposing other faculties' data).
        String? resolvedFacultyId;
        try {
          resolvedFacultyId = await _resolveAdminFacultyId();
        } catch (_) {}

        if (resolvedFacultyId == null || resolvedFacultyId.isEmpty) {
          // No faculty resolved for current user — do not create an unscoped
          // subscription. We'll log and return (the controller remains open
          // and callers will receive no realtime events).
          debugPrint(
            'subscribeStudents: no faculty id resolved; skipping realtime subscription',
          );
          return;
        }

        final raw =
            (_supabase
                    .from('students')
                    .stream(primaryKey: ['id'])
                    .eq('faculty_id', resolvedFacultyId)
                    .order('created_at', ascending: false))
                as Stream<dynamic>;

        // Run subscription inside its own zone so JS interop or unexpected
        // errors from the realtime client don't bubble as uncaught errors
        // to the root zone. We still log them and attempt a retry.
        runZonedGuarded(
          () {
            supaSub = raw.listen(
              (event) {
                try {
                  List<Map<String, dynamic>> out;
                  if (event == null) {
                    out = <Map<String, dynamic>>[];
                  } else if (event is List) {
                    out = (event)
                        .map((e) => Map<String, dynamic>.from(e))
                        .toList();
                  } else {
                    try {
                      final tmp = List.from(event);
                      out = tmp
                          .map((e) => Map<String, dynamic>.from(e))
                          .toList();
                    } catch (inner) {
                      if (event is Map) {
                        out = [Map<String, dynamic>.from(event)];
                      } else {
                        rethrow;
                      }
                    }
                  }

                  if (!controller.isClosed) controller.add(out);
                } catch (e, st) {
                  // Known occasional JS interop TypeError can surface here
                  // (e.g. `Instance of 'JSArray<dynamic>'` casting issues).
                  // Log minimally and continue; the outer onError/onDone will
                  // attempt to restart the subscription.
                  final msg = e.toString();
                  if (msg.contains('JSArray') ||
                      msg.contains('type') && msg.contains('Binding')) {
                    debugPrint(
                      'subscribeStudents: encountered JSArray interop error (ignored)',
                    );
                  } else {
                    debugPrint(
                      'subscribeStudents: failed to coerce event: $e\n$st',
                    );
                  }
                }
              },
              onError: (err, st) async {
                final serr = err.toString();
                // Suppress noisy stack traces for known realtime/channel errors
                if (serr.contains('JSArray') ||
                    (serr.contains('type') && serr.contains('Binding'))) {
                  debugPrint(
                    'subscribeStudents realtime error (interop JSArray) - restarting subscription',
                  );
                } else if (serr.contains('RealtimeSubscribeException') ||
                    serr.contains('channelError')) {
                  debugPrint(
                    'subscribeStudents realtime channel error - restarting subscription',
                  );
                } else {
                  debugPrint('subscribeStudents realtime error: $err\n$st');
                }
                // When an error occurs, cancel the current subscription and retry
                try {
                  await supaSub?.cancel();
                } catch (cancelErr, cancelSt) {
                  debugPrint(
                    'Error cancelling supabase subscription: $cancelErr\n$cancelSt',
                  );
                }
                if (!controller.isClosed) {
                  attempt = (attempt + 1).clamp(1, 6);
                  final delaySec = 1 << (attempt > 5 ? 5 : attempt);
                  await Future.delayed(Duration(seconds: delaySec));
                  if (!controller.isClosed) startSubscription();
                }
              },
              onDone: () async {
                debugPrint('subscribeStudents: underlying stream done');
                // attempt to restart unless controller closed
                if (!controller.isClosed) {
                  attempt = 0;
                  await Future.delayed(const Duration(seconds: 1));
                  if (!controller.isClosed) startSubscription();
                }
              },
            );
          },
          (err, st) async {
            // Errors thrown inside the zone (including JS interop TypeErrors)
            // will be captured here. For known realtime/channel errors we log
            // a short message and attempt restart to avoid noisy stacks.
            final serr = err.toString();
            if (serr.contains('RealtimeSubscribeException') ||
                serr.contains('channelError')) {
              debugPrint(
                'subscribeStudents zone realtime/channel error - restarting (short log)',
              );
            } else if (serr.contains('JSArray') ||
                (serr.contains('type') && serr.contains('Binding'))) {
              debugPrint('subscribeStudents zone JS interop error (ignored)');
            } else {
              debugPrint('subscribeStudents zone error: $err\n$st');
            }
            try {
              await supaSub?.cancel();
            } catch (_) {}
            if (!controller.isClosed) {
              attempt = (attempt + 1).clamp(1, 6);
              final delaySec = 1 << (attempt > 5 ? 5 : attempt);
              await Future.delayed(Duration(seconds: delaySec));
              if (!controller.isClosed) startSubscription();
            }
          },
        );
      } catch (e, st) {
        debugPrint('subscribeStudents failed to start: $e\n$st');
        if (!controller.isClosed) {
          attempt = (attempt + 1).clamp(1, 6);
          final delaySec = 1 << (attempt > 5 ? 5 : attempt);
          await Future.delayed(Duration(seconds: delaySec));
          if (!controller.isClosed) startSubscription();
        }
      }
    }

    controller.onListen = () {
      attempt = 0;
      startSubscription();
    };

    controller.onCancel = () async {
      try {
        await supaSub?.cancel();
      } catch (_) {}
      try {
        if (!controller.isClosed) await controller.close();
      } catch (_) {}
    };

    return controller.stream;
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

        if (section == null || section.trim().isEmpty) {
          return matchesDept && matchesClass;
        }

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

  /// Fetch departments list scoped to the current admin's faculty (or the
  /// provided `facultyId`). If no faculty can be resolved, returns an empty
  /// list to avoid exposing other faculties' departments.
  Future<List<Map<String, String>>> fetchDepartments({
    String? facultyId,
  }) async {
    try {
      String? resolvedFacultyId = facultyId;
      if (resolvedFacultyId == null || resolvedFacultyId.isEmpty) {
        try {
          resolvedFacultyId = await _resolveAdminFacultyId();
        } catch (_) {}
      }

      if (resolvedFacultyId == null || resolvedFacultyId.isEmpty) {
        return <Map<String, String>>[];
      }

      final resp = await _supabase
          .from('departments')
          .select('id, department_name, faculty_id')
          .eq('faculty_id', resolvedFacultyId)
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
