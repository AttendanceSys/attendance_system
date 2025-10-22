import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Upsert (update or insert) a row in `user_handling` for the provided username.
/// Returns the id of the inserted/updated user_handling row, or null on failure.
Future<String?> upsertUserHandling(
  SupabaseClient client,
  String username,
  String role,
  String? password,
) async {
  try {
    final normalizedRoleForDb =
        (role.trim().toLowerCase() == 'faculty admin' ||
            role.trim().toLowerCase() == 'faculty_admin')
        ? 'admin'
        : role.trim().toLowerCase();

    // Check existing
    final existing = await client
        .from('user_handling')
        .select('id')
        .eq('usernames', username)
        .maybeSingle();

    if (existing != null && existing['id'] != null) {
      // Update existing row
      final updateData = <String, dynamic>{
        'role': normalizedRoleForDb,
        if (password != null && password.isNotEmpty) 'passwords': password,
      };

      final updated = await client
          .from('user_handling')
          .update(updateData)
          .eq('usernames', username)
          .select()
          .maybeSingle();

      if (updated != null && updated['id'] != null) {
        return updated['id'] as String;
      }
      return existing['id'] as String;
    }

    // Insert new row
    final insertData = <String, dynamic>{
      'usernames': username,
      'role': normalizedRoleForDb,
      if (password != null && password.isNotEmpty) 'passwords': password,
    };

    final inserted = await client
        .from('user_handling')
        .insert(insertData)
        .select()
        .maybeSingle();

    if (inserted != null && inserted['id'] != null) {
      debugPrint('Inserted user_handling for $username: ${inserted['id']}');
      return inserted['id'] as String;
    }

    return null;
  } catch (e) {
    debugPrint('upsertUserHandling error for $username: $e');
    return null;
  }
}

/// Represents a user entry from the `user_handling` table.
class UserHandling {
  final String id;
  final String? authUid;
  final String? usernames;
  final String role;
  final String? passwords;
  final DateTime? createdAt;

  UserHandling({
    required this.id,
    required this.role,
    this.authUid,
    this.usernames,
    this.passwords,
    this.createdAt,
  });

  factory UserHandling.fromJson(Map<String, dynamic> json) {
    return UserHandling(
      id: json['id'] as String,
      authUid: json['auth_uid'] as String?,
      usernames: json['usernames'] as String?,
      role: (json['role'] ?? '') as String,
      passwords: json['passwords'] as String?,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString()),
    );
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'auth_uid': authUid,
      'usernames': usernames,
      'role': role,
      'passwords': passwords,
    };
  }
}

/// Represents a student entry from the `user_handling` table.
class StudentHandling {
  final String id;
  final String? authUid;
  final String? usernames;
  final String role;
  final String? passwords;
  final DateTime? createdAt;

  StudentHandling({
    required this.id,
    required this.role,
    this.authUid,
    this.usernames,
    this.passwords,
    this.createdAt,
  });

  factory StudentHandling.fromJson(Map<String, dynamic> json) {
    return StudentHandling(
      id: json['id'] as String,
      authUid: json['auth_uid'] as String?,
      usernames: json['usernames'] as String?,
      role: (json['role'] ?? 'student') as String,
      passwords: json['passwords'] as String?,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString()),
    );
  }
}

/// Service class to handle fetch and sync logic for students.
///
/// NOTE: Per request, this service will NOT create new user_handling rows.
/// Sync routines will only update existing user_handling rows when a matching
/// username exists; missing rows are logged/skipped (no inserts).
class UseStudentHandling {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetch all student users from user_handling, but only if they exist in students table
  Future<List<StudentHandling>> fetchStudents() async {
    try {
      final List<dynamic> userRows = await _supabase
          .from('user_handling')
          .select('id, usernames, role, passwords, created_at')
          .eq('role', 'student');

      final List<dynamic> studentRows = await _supabase
          .from('students')
          .select('username');

      final Set<String> studentUsernames = (studentRows)
          .map(
            (r) => (r as Map<String, dynamic>)['username']?.toString().trim(),
          )
          .where((s) => s != null && s.isNotEmpty)
          .cast<String>()
          .toSet();

      final filtered = userRows
          .where((json) {
            final uname = (json['usernames'] ?? '').toString().trim();
            return studentUsernames.contains(uname);
          })
          .map((json) => StudentHandling.fromJson(json as Map<String, dynamic>))
          .toList();

      debugPrint(
        'Fetched ${filtered.length} student user_handling rows (filtered by students table)',
      );
      return filtered;
    } catch (e) {
      debugPrint('fetchStudents error: $e');
      throw Exception('Failed to fetch student_handling: $e');
    }
  }

  /// Sync existing students from `students` table into `user_handling` by updating
  /// any matching user_handling rows. This WILL NOT insert new rows.
  Future<void> syncStudents() async {
    try {
      final List<dynamic> studentRows = await _supabase
          .from('students')
          .select('username, password');

      for (final s in studentRows) {
        final row = s as Map<String, dynamic>;
        final username = (row['username'] as String?)?.trim();
        final pwd = (row['password'] as String?)?.trim();

        if (username == null || username.isEmpty) continue;
        try {
          final uhId = await upsertUserHandling(
            _supabase,
            username,
            'student',
            pwd,
          );
          if (uhId != null && uhId.isNotEmpty) {
            // update students table to reference the created/updated user_handling row
            await _supabase
                .from('students')
                .update({'user_handling_id': uhId, 'user_id': uhId})
                .eq('username', username);
          }
        } catch (e) {
          debugPrint(
            'syncStudents: failed to upsert/attach user_handling for $username: $e',
          );
        }
      }

      debugPrint('✅ Students sync complete (updated existing rows only)');
    } catch (e) {
      debugPrint('❌ syncStudents error: $e');
      throw Exception('Failed to sync students: $e');
    }
  }

  /// Helper: update student in user_handling only if a matching usernames row exists.

  // (upsertUserHandling implemented as a top-level helper above)

  /// Fetch students and auto-sync updates if missing/changed. Does NOT insert rows.
  Future<List<StudentHandling>> fetchStudentsWithSync({
    bool attemptSyncIfEmpty = true,
  }) async {
    final students = await fetchStudents();

    if (students.isEmpty && attemptSyncIfEmpty) {
      debugPrint(
        '⚠️ No students found in user_handling; attempting to update existing entries from students table (no inserts)...',
      );
      await syncStudents();
      return await fetchStudents();
    }

    // Check for missing student records (we will not create them; just attempt update)
    try {
      final studentRows = await _supabase.from('students').select('username');
      final studentNames = (studentRows as List<dynamic>)
          .map((r) => (r as Map<String, dynamic>)['username'])
          .where((v) => v != null)
          .map((v) => v.toString().trim())
          .where((s) => s.isNotEmpty)
          .toSet();

      final existingUsernames = students
          .map((u) => (u.usernames ?? '').trim())
          .where((s) => s.isNotEmpty)
          .toSet();

      final missingStudents = studentNames.difference(existingUsernames);

      if (missingStudents.isNotEmpty) {
        debugPrint(
          'Detected missing students in user_handling: $missingStudents — will attempt to update existing rows only (no inserts).',
        );
        await syncStudents();
        return await fetchStudents();
      }
    } catch (e) {
      debugPrint('Student check failed: $e');
    }

    return students;
  }
}

/// Service class to handle fetch and update logic for user_handling table.
///
/// NOTE: Per request, this service will NOT provide public add or delete methods.
/// It will only fetch and update existing rows. Sync routines will update existing
/// rows only and will not create new user_handling rows.
class UseUserHandling {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Fetch all users (admins, teachers, etc.)
  Future<List<UserHandling>> fetchUsers() async {
    try {
      final dynamic rowsRaw = await _supabase
          .from('user_handling')
          .select('id, usernames, role, passwords, created_at');

      debugPrint('RAW user_handling response: $rowsRaw');

      final List<dynamic> rows = (rowsRaw is List) ? rowsRaw : <dynamic>[];

      debugPrint('Fetched ${rows.length} user_handling rows');

      final List<UserHandling> users = [];

      for (final e in rows) {
        if (e == null) continue;
        final json = e as Map<String, dynamic>;
        String role = (json['role'] ?? '').toString().trim();

        // Map 'admin' to 'faculty admin' dynamically for display purposes
        if (role == 'admin') {
          final username = (json['usernames'] ?? '').toString().trim();
          if (username.isNotEmpty) {
            Map<String, dynamic>? adminRow;
            try {
              // Removed top-level 'faculty_name' from the select because it doesn't exist
              // in the admins table in some schemas. We rely on the joined 'faculty'
              // relation (faculty:faculties(...)) to provide faculty_name.
              final ar = await _supabase
                  .from('admins')
                  .select('faculty_id, faculty:faculties(id, faculty_name)')
                  .eq('username', username)
                  .maybeSingle();
              if (ar != null) adminRow = ar;
            } catch (err) {
              debugPrint('Warning: admins lookup failed for $username: $err');
              adminRow = null;
            }

            if (adminRow != null) {
              String facultyName = '';
              // some schemas might have a top-level faculty_name column; check it if present
              if (adminRow.containsKey('faculty_name') &&
                  adminRow['faculty_name'] != null &&
                  (adminRow['faculty_name'] as String).isNotEmpty) {
                facultyName = (adminRow['faculty_name'] ?? '')
                    .toString()
                    .trim();
              } else if (adminRow['faculty'] != null &&
                  adminRow['faculty'] is Map) {
                facultyName =
                    ((adminRow['faculty'] as Map)['faculty_name'] ?? '')
                        .toString()
                        .trim();
              }
              if (facultyName.isNotEmpty) {
                role = 'faculty admin';
              }
            }
          }
        }

        users.add(
          UserHandling(
            id: json['id'] as String,
            authUid: json['auth_uid'] as String?,
            usernames: json['usernames'] as String?,
            role: role,
            passwords: json['passwords'] as String?,
            createdAt: json['created_at'] == null
                ? null
                : DateTime.tryParse(json['created_at'].toString()),
          ),
        );
      }

      debugPrint('Mapped ${users.length} user_handling rows into models');
      return users;
    } catch (e) {
      debugPrint('fetchUsers error: $e');
      // rethrow so callers can handle; include stacktrace in logs
      throw Exception('Failed to fetch user_handling: $e');
    }
  }

  /// Debug helper: fetch raw rows from user_handling and return them.
  /// Use this from a debug page or console to print what the client receives.
  Future<List<dynamic>> debugFetchUserHandlingRaw() async {
    try {
      final dynamic rows = await _supabase
          .from('user_handling')
          .select('id, usernames, role, passwords, created_at');
      debugPrint('debugFetchUserHandlingRaw -> $rows');
      if (rows is List) return rows;
      return <dynamic>[];
    } catch (e, st) {
      debugPrint('debugFetchUserHandlingRaw error: $e\n$st');
      rethrow;
    }
  }

  /// Fetch only Admins and Teachers
  Future<List<UserHandling>> fetchAdminsAndTeachers() async {
    final allUsers = await fetchUsers();
    return allUsers
        .where(
          (u) =>
              u.role.toLowerCase() == 'teacher' ||
              u.role.toLowerCase() == 'admin' ||
              u.role.toLowerCase() == 'faculty admin',
        )
        .toList();
  }

  /// Compatibility wrapper: some UI code calls `fetchAllUsers()`.
  /// Delegate to `fetchUsersWithSync` to preserve the previous behavior
  /// (attempt sync when empty) and avoid NoSuchMethodError in callers.
  Future<List<UserHandling>> fetchAllUsers({
    bool attemptSyncIfEmpty = true,
  }) async {
    return await fetchUsersWithSync(attemptSyncIfEmpty: attemptSyncIfEmpty);
  }

  /// Resolve the current authenticated user's faculty id (uuid) when the
  /// authenticated user is an admin. Returns null when not found or not an admin.
  Future<String?> resolveCurrentAdminFacultyId(SupabaseClient client) async {
    try {
      final current = client.auth.currentUser;
      if (current == null) return null;
      final authUid = current.id;

      // Find the user_handling row for this auth uid
      final uh = await client
          .from('user_handling')
          .select('id, usernames, role')
          .eq('auth_uid', authUid)
          .maybeSingle();

      if (uh == null) return null;
      final role = (uh['role'] ?? '').toString().trim().toLowerCase();
      if (role != 'admin') return null;

      final uhId = (uh['id'] ?? '')?.toString() ?? '';
      final username = (uh['usernames'] ?? '')?.toString() ?? '';

      // Try to find an admins row linked to this user_handling id
      Map<String, dynamic>? adminRow;
      if (uhId.isNotEmpty) {
        final ar = await client
            .from('admins')
            .select(
              'id, faculty_id, faculty_name, user_handling_id, user_id, username',
            )
            .eq('user_handling_id', uhId)
            .maybeSingle();
        if (ar != null) adminRow = ar;
      }

      // Fallback: try matching by username
      if (adminRow == null && username.isNotEmpty) {
        final ar2 = await client
            .from('admins')
            .select(
              'id, faculty_id, faculty_name, user_handling_id, user_id, username',
            )
            .eq('username', username)
            .maybeSingle();
        if (ar2 != null) adminRow = ar2;
      }

      if (adminRow == null) return null;

      // Prefer faculty_id if present, otherwise resolve faculty_name -> faculties.id
      final facultyId = (adminRow['faculty_id'] ?? '')?.toString() ?? '';
      if (facultyId.isNotEmpty) return facultyId;

      final facultyName = (adminRow['faculty_name'] ?? '')?.toString() ?? '';
      if (facultyName.isNotEmpty) {
        final f = await client
            .from('faculties')
            .select('id')
            .eq('faculty_name', facultyName)
            .maybeSingle();
        if (f != null && f['id'] != null) return f['id'].toString();
      }

      return null;
    } catch (e) {
      debugPrint('resolveCurrentAdminFacultyId error: $e');
      return null;
    }
  }

  /// NOTE: addUser has been intentionally removed (no add/inserts).
  /// Update user data and sync password to related table.
  Future<void> updateUser(String id, UserHandling user) async {
    try {
      final username = user.usernames?.trim();
      final roleRaw = user.role.trim();
      final roleLower = roleRaw.toLowerCase();
      final password = user.passwords?.trim();

      if (username == null || username.isEmpty) {
        throw Exception("Username missing for update");
      }

      // Normalize role for DB: keep same mapping as earlier upsert logic
      final normalizedRoleForDb =
          (roleLower == 'faculty admin' || roleLower == 'faculty_admin')
          ? 'admin'
          : roleLower;

      final updateData = <String, dynamic>{
        'usernames': username,
        'role': normalizedRoleForDb,
        if (password != null && password.isNotEmpty) 'passwords': password,
      };

      // Verify the row exists (helps catch id mismatches)
      final existingRow = await _supabase
          .from('user_handling')
          .select('id, usernames, role')
          .eq('id', id)
          .maybeSingle();

      if (existingRow == null) {
        throw Exception(
          'No user_handling row found with id=$id (username=$username)',
        );
      }

      // Perform update and return updated row
      final updatedRow = await _supabase
          .from('user_handling')
          .update(updateData)
          .eq('id', id)
          .select()
          .maybeSingle();

      if (updatedRow == null) {
        throw Exception(
          "Failed to update user_handling for $username (id=$id)",
        );
      }

      debugPrint('✅ Updated user_handling row: $updatedRow');

      final oldUsername = (existingRow['usernames'] ?? '').toString().trim();
      // final oldPassword = (existingRow['passwords'] ?? '').toString();
      // Propagate username changes to related tables (students, teachers, admins)
      try {
        final newUsername = username;
        if (newUsername.isNotEmpty) {
          // Update by user_handling_id where link exists
          await _supabase
              .from('students')
              .update({'username': newUsername})
              .eq('user_handling_id', id);
          await _supabase
              .from('teachers')
              .update({'username': newUsername})
              .eq('user_handling_id', id);
          await _supabase
              .from('admins')
              .update({'username': newUsername})
              .eq('user_handling_id', id);

          // Also update by old username fallback (if link wasn't established)
          if (oldUsername.isNotEmpty && oldUsername != newUsername) {
            await _supabase
                .from('students')
                .update({'username': newUsername})
                .eq('username', oldUsername);
            await _supabase
                .from('teachers')
                .update({'username': newUsername})
                .eq('username', oldUsername);
            await _supabase
                .from('admins')
                .update({'username': newUsername})
                .eq('username', oldUsername);
          }
        }
      } catch (e) {
        debugPrint('Failed to propagate username to related tables: $e');
      }

      // Propagate password changes as well
      try {
        if (password != null && password.isNotEmpty) {
          // Update linked rows by user_handling_id first
          await _supabase
              .from('students')
              .update({'password': password})
              .eq('user_handling_id', id);
          await _supabase
              .from('teachers')
              .update({'password': password})
              .eq('user_handling_id', id);
          await _supabase
              .from('admins')
              .update({'password': password})
              .eq('user_handling_id', id);

          // Fallback: update by old username where link isn't established
          if (oldUsername.isNotEmpty) {
            await _supabase
                .from('students')
                .update({'password': password})
                .eq('username', oldUsername);
            await _supabase
                .from('teachers')
                .update({'password': password})
                .eq('username', oldUsername);
            await _supabase
                .from('admins')
                .update({'password': password})
                .eq('username', oldUsername);
          }
        }
      } catch (e) {
        debugPrint('Failed to propagate password to related tables: $e');
      }
      // password propagation handled above (by user_handling_id and fallback username)
    } catch (e, st) {
      debugPrint('❌ updateUser error: $e\n$st');
      throw Exception('Failed to update user_handling and sync: $e');
    }
  }

  /// Fetches users and attempts to update matching rows from admins/teachers
  /// and will NOT create new user_handling rows. Missing rows are logged.
  Future<List<UserHandling>> fetchUsersWithSync({
    bool attemptSyncIfEmpty = true,
  }) async {
    final users = await fetchUsers();

    if (users.isEmpty && attemptSyncIfEmpty) {
      debugPrint(
        'No users found, attempting to update existing user_handling rows from admins and teachers (no inserts)...',
      );
      await syncRolesFromAdminsAndTeachers();
      return await fetchUsers();
    }

    // Missing teachers check
    try {
      final teacherRows = await _supabase.from('teachers').select('username');
      final teacherNames = (teacherRows as List<dynamic>)
          .map((r) => (r as Map<String, dynamic>)['username'])
          .where((v) => v != null)
          .map((v) => v.toString().trim())
          .where((s) => s.isNotEmpty)
          .toSet();

      final existingUsernames = users
          .map((u) => (u.usernames ?? '').trim())
          .where((s) => s.isNotEmpty)
          .toSet();

      final missingTeachers = teacherNames.difference(existingUsernames);

      if (missingTeachers.isNotEmpty) {
        debugPrint(
          'Detected missing teachers: $missingTeachers — will attempt to update existing rows only (no inserts).',
        );
        await syncRolesFromAdminsAndTeachers();
        return await fetchUsers();
      }
    } catch (e) {
      debugPrint('Teacher check failed: $e');
    }

    return users;
  }

  /// Sync roles from `admins` and `teachers` tables into `user_handling` by updating
  /// existing user_handling rows only. Does NOT insert new rows.
  Future<void> syncRolesFromAdminsAndTeachers() async {
    try {
      final List<dynamic> adminRows = await _supabase
          .from('admins')
          .select('username, password');
      final List<dynamic> teacherRows = await _supabase
          .from('teachers')
          .select('username, password');

      // Process admins: only update existing user_handling rows
      for (final a in adminRows) {
        final row = a as Map<String, dynamic>;
        final username = (row['username'] as String?)?.trim();
        final pwd = (row['password'] as String?)?.trim();
        if (username == null || username.isEmpty) continue;

        try {
          final uhId = await upsertUserHandling(
            _supabase,
            username,
            'admin',
            pwd,
          );
          if (uhId != null && uhId.isNotEmpty) {
            await _supabase
                .from('admins')
                .update({'user_handling_id': uhId, 'user_id': uhId})
                .eq('username', username);
          }
        } catch (e) {
          debugPrint(
            'syncRolesFromAdminsAndTeachers: failed to upsert/attach admin $username: $e',
          );
        }
      }

      // Process teachers: only update existing user_handling rows
      for (final t in teacherRows) {
        final row = t as Map<String, dynamic>;
        final username = (row['username'] as String?)?.trim();
        final pwd = (row['password'] as String?)?.trim();
        if (username == null || username.isEmpty) continue;

        try {
          final uhId = await upsertUserHandling(
            _supabase,
            username,
            'teacher',
            pwd,
          );
          if (uhId != null && uhId.isNotEmpty) {
            await _supabase
                .from('teachers')
                .update({'user_handling_id': uhId, 'user_id': uhId})
                .eq('username', username);
          }
        } catch (e) {
          debugPrint(
            'syncRolesFromAdminsAndTeachers: failed to upsert/attach teacher $username: $e',
          );
        }
      }

      debugPrint('Sync complete ✅ (updated existing rows only)');
    } catch (e) {
      debugPrint('syncRolesFromAdminsAndTeachers error: $e');
      throw Exception('Failed to sync roles: $e');
    }
  }

  // _updateUserIfExists removed; upsertUserHandling is used instead.
}