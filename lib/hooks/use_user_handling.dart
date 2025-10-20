import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  /// Fetch all student users from user_handling
  Future<List<StudentHandling>> fetchStudents() async {
    try {
      final List<dynamic> rows = await _supabase
          .from('user_handling')
          .select('id, auth_uid, usernames, role, passwords, created_at')
          .eq('role', 'student');

      debugPrint('Fetched ${rows.length} student user_handling rows');

      return rows
          .map((json) => StudentHandling.fromJson(json as Map<String, dynamic>))
          .toList();
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
        await _updateStudentIfExists(username, pwd);
      }

      debugPrint('✅ Students sync complete (updated existing rows only)');
    } catch (e) {
      debugPrint('❌ syncStudents error: $e');
      throw Exception('Failed to sync students: $e');
    }
  }

  /// Helper: update student in user_handling only if a matching usernames row exists.
  Future<void> _updateStudentIfExists(String username, String? password) async {
    try {
      final existing = await _supabase
          .from('user_handling')
          .select('id')
          .eq('usernames', username)
          .maybeSingle();

      if (existing != null) {
        final updateData = <String, dynamic>{
          'role': 'student',
          if (password != null && password.isNotEmpty) 'passwords': password,
        };

        final updated = await _supabase
            .from('user_handling')
            .update(updateData)
            .eq('usernames', username)
            .select()
            .maybeSingle();

        debugPrint(
            'Updated user_handling for existing student $username: $updated');
      } else {
        // Per request, do not insert. Log and continue.
        debugPrint(
            '_updateStudentIfExists: no user_handling row for username="$username", skipping (no insert).');
      }
    } catch (e) {
      debugPrint('_updateStudentIfExists failed for $username: $e');
    }
  }

  /// Fetch students and auto-sync updates if missing/changed. Does NOT insert rows.
  Future<List<StudentHandling>> fetchStudentsWithSync({
    bool attemptSyncIfEmpty = true,
  }) async {
    final students = await fetchStudents();

    if (students.isEmpty && attemptSyncIfEmpty) {
      debugPrint(
          '⚠️ No students found in user_handling; attempting to update existing entries from students table (no inserts)...');
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
            'Detected missing students in user_handling: $missingStudents — will attempt to update existing rows only (no inserts).');
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
      final List<dynamic> rows = await _supabase
          .from('user_handling')
          .select('id, auth_uid, usernames, role, passwords, created_at');

      debugPrint('Fetched ${rows.length} user_handling rows');

      final List<UserHandling> users = [];

      for (final e in rows) {
        final json = e as Map<String, dynamic>;
        String role = (json['role'] ?? '').toString().trim();

        // Map 'admin' to 'faculty admin' dynamically for display purposes
        if (role == 'admin') {
          final username = (json['usernames'] ?? '').toString().trim();
          if (username.isNotEmpty) {
            final adminRow = await _supabase
                .from('admins')
                .select('faculty_name')
                .eq('username', username)
                .maybeSingle();

            if (adminRow != null) {
              final facultyName =
                  (adminRow['faculty_name'] ?? '').toString().trim();
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

      return users;
    } catch (e) {
      debugPrint('fetchUsers error: $e');
      throw Exception('Failed to fetch user_handling: $e');
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
        throw Exception('No user_handling row found with id=$id (username=$username)');
      }

      // Perform update and return updated row
      final updatedRow = await _supabase
          .from('user_handling')
          .update(updateData)
          .eq('id', id)
          .select()
          .maybeSingle();

      if (updatedRow == null) {
        throw Exception("Failed to update user_handling for $username (id=$id)");
      }

      debugPrint('✅ Updated user_handling row: $updatedRow');

      // Sync password to related table using the normalized role
      if (password != null && password.isNotEmpty) {
        if (normalizedRoleForDb == 'teacher') {
          final rt = await _supabase
              .from('teachers')
              .update({'password': password})
              .eq('username', username);
          debugPrint('Synced password to teachers for $username: $rt');
        } else if (normalizedRoleForDb == 'admin') {
          final rt = await _supabase
              .from('admins')
              .update({'password': password})
              .eq('username', username);
          debugPrint('Synced password to admins for $username: $rt');
        }
      }
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
      debugPrint('No users found, attempting to update existing user_handling rows from admins and teachers (no inserts)...');
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
        debugPrint('Detected missing teachers: $missingTeachers — will attempt to update existing rows only (no inserts).');
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

        await _updateUserIfExists(username, 'admin', pwd);
      }

      // Process teachers: only update existing user_handling rows
      for (final t in teacherRows) {
        final row = t as Map<String, dynamic>;
        final username = (row['username'] as String?)?.trim();
        final pwd = (row['password'] as String?)?.trim();
        if (username == null || username.isEmpty) continue;

        await _updateUserIfExists(username, 'teacher', pwd);
      }

      debugPrint('Sync complete ✅ (updated existing rows only)');
    } catch (e) {
      debugPrint('syncRolesFromAdminsAndTeachers error: $e');
      throw Exception('Failed to sync roles: $e');
    }
  }

  /// Helper: update user_handling record if it exists; do NOT insert.
  Future<void> _updateUserIfExists(
    String username,
    String role,
    String? password,
  ) async {
    try {
      final existing = await _supabase
          .from('user_handling')
          .select('id')
          .eq('usernames', username)
          .maybeSingle();

      final normalizedRole = role.trim().toLowerCase();
      final roleForDb = (normalizedRole == 'faculty admin' ||
              normalizedRole == 'faculty_admin')
          ? 'admin'
          : normalizedRole;

      if (existing != null) {
        final updateData = <String, dynamic>{
          'role': roleForDb,
          if (password != null && password.isNotEmpty) 'passwords': password,
        };

        final updated = await _supabase
            .from('user_handling')
            .update(updateData)
            .eq('usernames', username)
            .select()
            .maybeSingle();

        debugPrint('_updateUserIfExists: updated $username -> $updated');
      } else {
        // Per request, do not create new rows; log and continue.
        debugPrint('_updateUserIfExists: no user_handling row for username="$username", skipping (no insert).');
      }
    } catch (e) {
      debugPrint('_updateUserIfExists failed for $username ($role): $e');
    }
  }
}