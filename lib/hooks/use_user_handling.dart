import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Upsert (update or insert) a row in `user_handling` for the provided username.
/// Returns the id of the inserted/updated user_handling row, or null on failure.
Future<String?> upsertUserHandling(
  SupabaseClient client,
  String username,
  String role,
  String? password, {
  String? authUid,
}) async {
  try {
    final normalizedRoleForDb =
        (role.trim().toLowerCase() == 'faculty admin' ||
            role.trim().toLowerCase() == 'faculty_admin')
        ? 'admin'
        : role.trim().toLowerCase();

    // Check existing by username
    final existingRaw = await client
        .from('user_handling')
        .select('id')
        .eq('username', username)
        .limit(1);

    Map<String, dynamic>? existing;
    if ((existingRaw as List).isNotEmpty) {
      existing = Map<String, dynamic>.from((existingRaw as List)[0] as Map);
    }

    if (existing != null && existing['id'] != null) {
      // Update existing row
      final updateData = <String, dynamic>{
        'role': normalizedRoleForDb,
        if (password != null && password.isNotEmpty) 'password': password,
        if (authUid != null && authUid.isNotEmpty) 'auth_uid': authUid,
      };

      Map<String, dynamic>? updated;
      try {
        final tmpRaw = await client
            .from('user_handling')
            .update(updateData)
            .eq('username', username)
            .select()
            .limit(1);
        if ((tmpRaw as List).isNotEmpty) {
          updated = Map<String, dynamic>.from((tmpRaw as List)[0] as Map);
        }
      } catch (err) {
        // Postgrest may return a PGRST116 when no rows are returned for maybeSingle()
        debugPrint(
          'update user_handling .select().maybeSingle() returned no rows: $err',
        );
        updated = null;
      }

      if (updated != null && updated['id'] != null) {
        debugPrint('Updated user_handling for $username: ${updated['id']}');
        return updated['id'] as String;
      }

      // fallback to existing id
      return existing['id'] as String;
    }

    // Insert new row
    final insertData = <String, dynamic>{
      'username': username,
      'role': normalizedRoleForDb,
      if (password != null && password.isNotEmpty) 'password': password,
      if (authUid != null && authUid.isNotEmpty) 'auth_uid': authUid,
    };

    Map<String, dynamic>? inserted;
    try {
      final tmpRaw = await client
          .from('user_handling')
          .insert(insertData)
          .select()
          .limit(1);
      if ((tmpRaw as List).isNotEmpty) {
        inserted = Map<String, dynamic>.from((tmpRaw as List)[0] as Map);
      }
    } catch (err) {
      debugPrint(
        'insert user_handling .select().maybeSingle() returned no rows: $err',
      );
      inserted = null;
    }

    if (inserted != null && inserted['id'] != null) {
      debugPrint('Inserted user_handling for $username: ${inserted['id']}');
      return inserted['id'] as String;
    }

    return null;
  } catch (e, st) {
    debugPrint('upsertUserHandling error for $username: $e\n$st');
    return null;
  }
}

/// Safely delete a `user_handling` row by username only if no other tables
/// reference it. Returns true if deleted, false if skipped or failed.
Future<bool> safeDeleteUserHandling(
  SupabaseClient client,
  String username,
) async {
  try {
    if (username.trim().isEmpty) return false;

    // Check referencing tables for any existing rows that reference this username.
    final tablesToCheck = ['teachers', 'admins', 'students'];
    for (final t in tablesToCheck) {
      try {
        final res = await client
            .from(t)
            .select('id')
            .eq('username', username)
            .limit(1);
        if (res.isNotEmpty) {
          // Found a reference, so skip deletion
          debugPrint(
            'safeDeleteUserHandling: found reference in $t, skipping delete for $username',
          );
          return false;
        }
      } catch (e) {
        // If a table doesn't exist in a given schema, ignore and continue
        debugPrint('safeDeleteUserHandling: check on $t failed (ignored): $e');
      }
    }

    // No references found — perform delete
    await client
        .from('user_handling')
        .delete()
        .eq('username', username)
        .select();
    debugPrint('safeDeleteUserHandling: deleted user_handling for $username');
    return true;
  } catch (e, st) {
    debugPrint('safeDeleteUserHandling error for $username: $e\n$st');
    return false;
  }
}

/// Represents a user entry from the `user_handling` table.
class UserHandling {
  final String id;
  final String? authUid;
  final String? username;
  final String role;
  final String? password;
  final DateTime? createdAt;
  final bool isDisabled;

  UserHandling({
    required this.id,
    required this.role,
    this.authUid,
    this.username,
    this.password,
    this.createdAt,
    this.isDisabled = false,
  });

  factory UserHandling.fromJson(Map<String, dynamic> json) {
    return UserHandling(
      id: json['id'] as String,
      authUid: json['auth_uid'] as String?,
      username: json['username'] as String?,
      role: (json['role'] ?? '') as String,
      password: json['password'] as String?,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString()),
      isDisabled: (json['is_disabled'] == null)
          ? false
          : (json['is_disabled'] is bool)
          ? json['is_disabled'] as bool
          : (json['is_disabled'].toString().toLowerCase() == 'true'),
    );
  }

  Map<String, dynamic> toUpdateJson() {
    return {
      'auth_uid': authUid,
      'username': username,
      'role': role,
      'password': password,
      'is_disabled': isDisabled,
    };
  }
}

/// Represents a student entry from the `user_handling` table.
class StudentHandling {
  final String id;
  final String? authUid;
  final String? username;
  final String role;
  final String? password;
  final DateTime? createdAt;
  final bool isDisabled;

  StudentHandling({
    required this.id,
    required this.role,
    this.authUid,
    this.username,
    this.password,
    this.createdAt,
    this.isDisabled = false,
  });

  factory StudentHandling.fromJson(Map<String, dynamic> json) {
    return StudentHandling(
      id: json['id'] as String,
      authUid: json['auth_uid'] as String?,
      username: json['username'] as String?,
      role: (json['role'] ?? 'student') as String,
      password: json['password'] as String?,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString()),
      isDisabled: (json['is_disabled'] == null)
          ? false
          : (json['is_disabled'] is bool)
          ? json['is_disabled'] as bool
          : (json['is_disabled'].toString().toLowerCase() == 'true'),
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
          .select('id, username, role, password, created_at, is_disabled')
          .eq('role', 'student');

      final List<dynamic> studentRows = await _supabase
          .from('students')
          .select('username');

      // Defensive: if there are no student rows at all, return empty early.
      if (studentRows.isEmpty) {
        debugPrint(
          'Fetched 0 students from students table; returning 0 student user_handling rows',
        );
        return <StudentHandling>[];
      }

      // Build a clean set of usernames from the students table; normalize by
      // trimming to avoid mismatches due to whitespace.
      final Set<String> studentUsernames = studentRows
          .where((r) => r != null)
          .map((r) {
            try {
              final u = (r as Map<String, dynamic>)['username'];
              return (u ?? '').toString().trim();
            } catch (_) {
              return '';
            }
          })
          .where((s) => s.isNotEmpty)
          .cast<String>()
          .toSet();

      if (studentUsernames.isEmpty) {
        debugPrint(
          'No valid student usernames found in students table; returning empty list',
        );
        return <StudentHandling>[];
      }

      final filtered = userRows
          .where((json) {
            final uname = (json['username'] ?? '').toString().trim();
            return uname.isNotEmpty && studentUsernames.contains(uname);
          })
          .map((json) => StudentHandling.fromJson(json as Map<String, dynamic>))
          .toList();

      debugPrint(
        'Fetched ${filtered.length} student user_handling rows (filtered by students table)',
      );
      return filtered;
    } catch (e, st) {
      debugPrint('fetchStudents error: $e\n$st');
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
            // NOTE: the database schema uses `students.username` to link to
            // `user_handling.username` (no user_handling_id column). We avoid
            // writing non-existent columns here. If you added `user_handling_id`
            // to the students table, change this to update that column.
            debugPrint('Resolved user_handling id for $username -> $uhId');
          }
        } catch (e, st) {
          debugPrint(
            'syncStudents: failed to upsert/attach user_handling for $username: $e\n$st',
          );
        }
      }

      debugPrint('✅ Students sync complete (updated existing rows only)');
    } catch (e, st) {
      debugPrint('❌ syncStudents error: $e\n$st');
      throw Exception('Failed to sync students: $e');
    }
  }

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
          .map((u) => (u.username ?? '').trim())
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
    } catch (e, st) {
      debugPrint('Student check failed: $e\n$st');
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
          .select('id, username, role, password, created_at, is_disabled');

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
          final username = (json['username'] ?? '').toString().trim();
          if (username.isNotEmpty) {
            Map<String, dynamic>? adminRow;
            try {
              // rely on the joined 'faculty' relation (faculty:faculties(...)) to provide faculty_name.
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
            username: json['username'] as String?,
            role: role,
            password: json['password'] as String?,
            createdAt: json['created_at'] == null
                ? null
                : DateTime.tryParse(json['created_at'].toString()),
            isDisabled: (json['is_disabled'] == null)
                ? false
                : (json['is_disabled'] is bool)
                ? json['is_disabled'] as bool
                : (json['is_disabled'].toString().toLowerCase() == 'true'),
          ),
        );
      }

      debugPrint('Mapped ${users.length} user_handling rows into models');
      return users;
    } catch (e, st) {
      debugPrint('fetchUsers error: $e\n$st');
      throw Exception('Failed to fetch user_handling: $e');
    }
  }

  /// Update only the `is_disabled` flag for a user_handling row by id.
  /// This is an instance method so callers can call `UseUserHandling().setUserDisabled(...)`.
  Future<void> setUserDisabled(String id, bool disabled) async {
    try {
      await _supabase
          .from('user_handling')
          .update({'is_disabled': disabled})
          .eq('id', id)
          .select()
          .maybeSingle();
      debugPrint('setUserDisabled: id=$id -> $disabled');
    } catch (e, st) {
      debugPrint('setUserDisabled error for id=$id: $e\n$st');
      throw Exception('Failed to set is_disabled on user_handling: $e');
    }
  }

  /// Resolve the currently authenticated user's username.
  ///
  /// This tries to map the Supabase auth user's `id` (auth_uid) to a
  /// `user_handling.username` row. If no mapping is found it falls back to the
  /// user's email or finally the auth uid. Returns an empty string when there
  /// is no authenticated user.
  Future<String> resolveCurrentUsername() async {
    try {
      final client = Supabase.instance.client;
      final current = client.auth.currentUser;
      if (current == null) return '';

      try {
        final uh = await client
            .from('user_handling')
            .select('username')
            .eq('auth_uid', current.id)
            .maybeSingle();
        if (uh != null && uh['username'] != null) {
          return uh['username'].toString();
        }
      } catch (e) {
        debugPrint('resolveCurrentUsername: auth_uid mapping failed: $e');
      }

      if (current.email != null && current.email!.isNotEmpty) {
        return current.email!;
      }

      return current.id;
    } catch (e) {
      debugPrint('resolveCurrentUsername error: $e');
      return '';
    }
  }

  /// Debug helper: fetch raw rows from user_handling and return them.
  /// Use this from a debug page or console to print what the client receives.
  Future<List<dynamic>> debugFetchUserHandlingRaw() async {
    try {
      final dynamic rows = await _supabase
          .from('user_handling')
          .select('id, username, role, password, created_at, is_disabled');
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

  /// Fetch admins and teachers scoped to a faculty. If [facultyId] is not
  /// provided, resolve the current admin's faculty id. When no faculty can be
  /// resolved, returns an empty list.
  Future<List<UserHandling>> fetchAdminsAndTeachersForFaculty({
    String? facultyId,
  }) async {
    try {
      String? resolvedFacultyId = facultyId;
      if (resolvedFacultyId == null || resolvedFacultyId.isEmpty) {
        resolvedFacultyId = await resolveCurrentAdminFacultyId(_supabase);
      }
      if (resolvedFacultyId == null || resolvedFacultyId.isEmpty) {
        return <UserHandling>[];
      }

      // Find admin usernames for the faculty
      final adminRows = await _supabase
          .from('admins')
          .select('username')
          .eq('faculty_id', resolvedFacultyId);
      final teacherRows = await _supabase
          .from('teachers')
          .select('username')
          .eq('faculty_id', resolvedFacultyId);

      final adminUsernames = (adminRows as List)
          .map((r) => (r as Map)['username']?.toString().trim())
          .where((s) => s != null && s.isNotEmpty)
          .cast<String>()
          .toSet();

      final teacherUsernames = (teacherRows as List)
          .map((r) => (r as Map)['username']?.toString().trim())
          .where((s) => s != null && s.isNotEmpty)
          .cast<String>()
          .toSet();

      final usernames = {...adminUsernames, ...teacherUsernames};
      if (usernames.isEmpty) return <UserHandling>[];

      // Fetch matching user_handling rows
      final rows = await _supabase
          .from('user_handling')
          .select('id, username, role, password, created_at, is_disabled')
          .filter('username', 'in', usernames.toList());

      final List<UserHandling> users = (rows as List)
          .map((r) => UserHandling.fromJson(r as Map<String, dynamic>))
          .toList();

      return users;
    } catch (e) {
      debugPrint('fetchAdminsAndTeachersForFaculty error: $e');
      throw Exception('Failed to fetch admins/teachers for faculty: $e');
    }
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
      Map<String, dynamic>? uh;
      try {
        final res = await client
            .from('user_handling')
            .select('id, username, role, faculty_id')
            .eq('auth_uid', authUid)
            .maybeSingle();
        if (res != null) uh = res as Map<String, dynamic>?;
      } catch (e) {
        debugPrint('user_handling auth_uid lookup failed: $e');
      }

      if (uh == null) return null;
      final role = (uh['role'] ?? '').toString().trim().toLowerCase();
      if (role != 'admin') return null;

      // prefer faculty_id column on user_handling if set
      final fid = (uh['faculty_id'] ?? '')?.toString() ?? '';
      if (fid.isNotEmpty) return fid;

      final username = (uh['username'] ?? '')?.toString() ?? '';

      // Try to find an admins row linked to this username
      if (username.isNotEmpty) {
        final ar2 = await client
            .from('admins')
            .select('faculty_id, faculty_name')
            .eq('username', username)
            .maybeSingle();
        if (ar2 != null) {
          final aFid = (ar2['faculty_id'] ?? '')?.toString() ?? '';
          if (aFid.isNotEmpty) return aFid;

          final facultyName = (ar2['faculty_name'] ?? '')?.toString() ?? '';
          if (facultyName.isNotEmpty) {
            final f = await client
                .from('faculties')
                .select('id')
                .eq('faculty_name', facultyName)
                .maybeSingle();
            if (f != null && f['id'] != null) return f['id'].toString();
          }
        }
      }

      return null;
    } catch (e, st) {
      debugPrint('resolveCurrentAdminFacultyId error: $e\n$st');
      return null;
    }
  }

  /// Update an existing user_handling row and propagate username/password changes
  /// to related tables (students, teachers, admins). This WILL NOT create new rows.
  Future<void> updateUser(String id, UserHandling user) async {
    try {
      final username = user.username?.trim();
      final roleRaw = user.role.trim();
      final roleLower = roleRaw.toLowerCase();
      final password = user.password?.trim();

      if (username == null || username.isEmpty) {
        throw Exception("Username missing for update");
      }

      // Normalize role for DB: keep same mapping as earlier upsert logic
      final normalizedRoleForDb =
          (roleLower == 'faculty admin' || roleLower == 'faculty_admin')
          ? 'admin'
          : roleLower;

      final updateData = <String, dynamic>{
        'username': username,
        'role': normalizedRoleForDb,
        if (password != null && password.isNotEmpty) 'password': password,
      };

      // Verify the row exists (helps catch id mismatches)
      final existingRow = await _supabase
          .from('user_handling')
          .select('id, username, role')
          .eq('id', id)
          .maybeSingle();

      if (existingRow == null) {
        throw Exception(
          'No user_handling row found with id=$id (username=$username)',
        );
      }

      final oldUsername = (existingRow['username'] ?? '').toString().trim();
      final newUsername = username;

      // If username is changing, we must ensure the *new* username exists in
      // `user_handling` before updating referencing tables (otherwise the DB
      // will reject the update with FK violations). Strategy:
      // 1) Upsert a user_handling row for the new username (may create new row)
      // 2) Update referencing tables (students/teachers/admins) to point to the new username
      // 3) Safely delete the old user_handling row (only if it's no longer referenced)
      // If username is unchanged, perform a normal update on the existing row.
      if (newUsername.isNotEmpty &&
          oldUsername.isNotEmpty &&
          oldUsername != newUsername) {
        try {
          // Ensure new username exists (insert or update). Use the normalized role
          // and provided password so the new row is created with the correct data.
          final newUhId = await upsertUserHandling(
            _supabase,
            newUsername,
            normalizedRoleForDb,
            password,
          );

          if (newUhId == null || newUhId.isEmpty) {
            throw Exception(
              'Failed to create or ensure user_handling for new username: $newUsername',
            );
          }

          // Now it is safe to point referencing rows to the new username.
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

          // After references moved, attempt to delete the old user_handling row.
          // Use safeDeleteUserHandling which checks for remaining references.
          try {
            await safeDeleteUserHandling(_supabase, oldUsername);
          } catch (e) {
            debugPrint(
              'Warning: failed to delete old user_handling $oldUsername (ignored): $e',
            );
          }

          debugPrint('✅ Username migrated: $oldUsername -> $newUsername');
        } catch (e, st) {
          debugPrint('Failed to migrate username to new value: $e\n$st');
          throw Exception(
            'Failed to update referencing tables for username change: $e',
          );
        }
      } else {
        // No username change — update the existing user_handling row in-place.
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
      }

      // Propagate password changes as well. Use the current username value
      // (prefer newUsername if set, otherwise oldUsername) to locate rows.
      try {
        final targetUsernameForPwd = (newUsername.isNotEmpty)
            ? newUsername
            : oldUsername;
        if (password != null &&
            password.isNotEmpty &&
            targetUsernameForPwd.isNotEmpty) {
          await _supabase
              .from('students')
              .update({'password': password})
              .eq('username', targetUsernameForPwd);
          await _supabase
              .from('teachers')
              .update({'password': password})
              .eq('username', targetUsernameForPwd);
          await _supabase
              .from('admins')
              .update({'password': password})
              .eq('username', targetUsernameForPwd);
        }
      } catch (e, st) {
        debugPrint('Failed to propagate password to related tables: $e\n$st');
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
          .map((u) => (u.username ?? '').trim())
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
      debugPrint('Sync complete ✅ (updated existing rows only)');
    } catch (e, st) {
      debugPrint('syncRolesFromAdminsAndTeachers error: $e\n$st');
      throw Exception('Failed to sync roles: $e');
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
            // If your schema has user_handling_id/user_id columns on admins, update them.
            await _supabase
                .from('admins')
                .update({'user_handling_id': uhId, 'user_id': uhId})
                .eq('username', username);
          }
        } catch (e, st) {
          debugPrint(
            'syncRolesFromAdminsAndTeachers: failed to upsert/attach admin $username: $e\n$st',
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
        } catch (e, st) {
          debugPrint(
            'syncRolesFromAdminsAndTeachers: failed to upsert/attach teacher $username: $e\n$st',
          );
        }
      }

      debugPrint('Sync complete ✅ (updated existing rows only)');
    } catch (e, st) {
      debugPrint('syncRolesFromAdminsAndTeachers error: $e\n$st');
      throw Exception('Failed to sync roles: $e');
    }
  }
}
