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

  Map<String, dynamic> toInsertJson() {
    return {
      'auth_uid': authUid,
      'usernames': usernames,
      'role': role,
      'passwords': passwords,
    };
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

/// Service class to handle CRUD and sync logic for user_handling table.
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

        // Map 'admin' to 'faculty admin' dynamically
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

        users.add(UserHandling(
          id: json['id'] as String,
          authUid: json['auth_uid'] as String?,
          usernames: json['usernames'] as String?,
          role: role,
          passwords: json['passwords'] as String?,
          createdAt: json['created_at'] == null
              ? null
              : DateTime.tryParse(json['created_at'].toString()),
        ));
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
        .where((u) =>
            u.role.toLowerCase() == 'teacher' ||
            u.role.toLowerCase() == 'admin' ||
            u.role.toLowerCase() == 'faculty admin')
        .toList();
  }

  /// Add new user to user_handling table
  Future<void> addUser(UserHandling user) async {
    try {
      await _supabase.from('user_handling').insert(user.toInsertJson());
    } catch (e) {
      throw Exception('Failed to add user_handling: $e');
    }
  }

  /// Update user data and sync password to related table
  Future<void> updateUser(String id, UserHandling user) async {
    try {
      final username = user.usernames?.trim();
      final role = user.role.trim().toLowerCase();
      final password = user.passwords?.trim();

      if (username == null || username.isEmpty) {
        throw Exception("Username missing for update");
      }

      // Update in user_handling
      final updateData = {
        'usernames': username,
        'role': role,
        if (password != null && password.isNotEmpty) 'passwords': password,
      };

      final res = await _supabase
          .from('user_handling')
          .update(updateData)
          .eq('id', id)
          .select();

      if (res.isEmpty) {
        throw Exception("Failed to update user_handling for $username");
      }

      debugPrint('✅ Updated user_handling for $username ($role)');

      // Sync password to related table
      if (password != null && password.isNotEmpty) {
        if (role == 'teacher') {
          await _supabase
              .from('teachers')
              .update({'password': password})
              .eq('username', username);
        } else if (role == 'admin' || role == 'faculty admin') {
          await _supabase
              .from('admins')
              .update({'password': password})
              .eq('username', username);
        }
        debugPrint('🔁 Synced password for $username');
      }
    } catch (e) {
      debugPrint('❌ updateUser error: $e');
      throw Exception('Failed to update user_handling and sync: $e');
    }
  }

  /// Fetches users and syncs if missing data is found
  Future<List<UserHandling>> fetchUsersWithSync({
    bool attemptSyncIfEmpty = true,
  }) async {
    final users = await fetchUsers();

    if (users.isEmpty && attemptSyncIfEmpty) {
      debugPrint('No users found, syncing from admins and teachers...');
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
        debugPrint('Detected missing teachers: $missingTeachers — syncing...');
        await syncRolesFromAdminsAndTeachers();
        return await fetchUsers();
      }
    } catch (e) {
      debugPrint('Teacher check failed: $e');
    }

    return users;
  }

  /// Sync roles from `admins` and `teachers` tables into `user_handling`
  Future<void> syncRolesFromAdminsAndTeachers() async {
    try {
      final List<dynamic> adminRows =
          await _supabase.from('admins').select('username, password');
      final List<dynamic> teacherRows =
          await _supabase.from('teachers').select('username, password');

      // Process admins
      for (final a in adminRows) {
        final row = a as Map<String, dynamic>;
        final username = (row['username'] as String?)?.trim();
        final pwd = (row['password'] as String?)?.trim();
        if (username == null || username.isEmpty) continue;

        await _upsertUser(username, 'admin', pwd);
      }

      // Process teachers
      for (final t in teacherRows) {
        final row = t as Map<String, dynamic>;
        final username = (row['username'] as String?)?.trim();
        final pwd = (row['password'] as String?)?.trim();
        if (username == null || username.isEmpty) continue;

        await _upsertUser(username, 'teacher', pwd);
      }

      debugPrint('Sync complete ✅');
    } catch (e) {
      debugPrint('syncRolesFromAdminsAndTeachers error: $e');
      throw Exception('Failed to sync roles: $e');
    }
  }

  /// Helper: Insert or update user_handling record
  Future<void> _upsertUser(
      String username, String role, String? password) async {
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
        await _supabase
            .from('user_handling')
            .update({
              'role': roleForDb,
              if (password != null && password.isNotEmpty) 'passwords': password,
            })
            .eq('usernames', username);
      } else {
        await _supabase.from('user_handling').insert({
          'usernames': username,
          'role': roleForDb,
          if (password != null && password.isNotEmpty) 'passwords': password,
        });
      }
    } catch (e) {
      debugPrint('_upsertUser failed for $username ($role): $e');
    }
  }
}
