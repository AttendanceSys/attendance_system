import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'use_user_handling.dart';

class Admin {
  final String id; // uuid (DB generated)
  final String? username; // FK to login username (unique)
  final String? fullName;
  final String? facultyName; // FK to faculties.faculty_name
  final String? password; // stored but never displayed in tables
  final DateTime? createdAt;

  Admin({
    required this.id,
    this.username,
    this.fullName,
    this.facultyName,
    this.password,
    this.createdAt,
  });

  factory Admin.fromJson(Map<String, dynamic> json) {
    return Admin(
      id: json['id'] as String,
      username: json['username'] as String?,
      fullName: json['full_name'] as String?,
      facultyName: json['faculty_name'] as String?,
      password: json['password'] as String?,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'full_name': fullName,
      'faculty_name': facultyName,
      'password': password,
      // created_at is DB-managed (default now())
    };
  }
}

class UseAdmins {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Admin>> fetchAdmins() async {
    try {
      final List<dynamic> rows = await _supabase
          .from('admins')
          .select('id, username, full_name, faculty_name, password, created_at')
          .order('created_at', ascending: false);
      return rows
          .map((e) => Admin.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch admins: $e');
    }
  }

  Future<void> addAdmin(Admin admin) async {
    try {
      final payload = admin.toJson();
      await _supabase.from('admins').insert(payload);
    } catch (e) {
      throw Exception('Failed to add admin: $e');
    }
  }

  Future<void> updateAdmin(String id, Admin admin) async {
    try {
      final payload = admin.toJson();

      // Fetch existing admin row to get old username and possible user_handling link
      final existing = await _supabase
          .from('admins')
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

      await _supabase.from('admins').update(payload).eq('id', id);

      // Try to update existing user_handling row first to avoid duplicates
      try {
        final newUsername = (admin.username ?? '').trim();
        final newPassword = (admin.password ?? '').trim();

        String? uhId;

        if (existingUhId != null && existingUhId.isNotEmpty) {
          final updateData = <String, dynamic>{
            if (newUsername.isNotEmpty) 'usernames': newUsername,
            'role': 'admin',
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
                  'role': 'admin',
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

        // Fallback to upsert if we still have no id
        if (uhId == null || uhId.isEmpty) {
          try {
            final created = await upsertUserHandling(
              _supabase,
              newUsername,
              'admin',
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
          await _supabase
              .from('admins')
              .update({'user_handling_id': uhId, 'user_id': uhId})
              .eq('id', id);
        }
      } catch (e) {
        debugPrint(
          'Failed to upsert/link user_handling for admin ${admin.username}: $e',
        );
      }
    } catch (e) {
      throw Exception('Failed to update admin: $e');
    }
  }

  Future<void> deleteAdmin(String id) async {
    try {
      await _supabase.from('admins').delete().eq('id', id);
    } catch (e) {
      throw Exception('Failed to delete admin: $e');
    }
  }

  // Load FK options for popup dropdown
  Future<List<String>> fetchFacultyNames() async {
    try {
      final List<dynamic> rows = await _supabase
          .from('faculties')
          .select('faculty_name');
      return rows
          .map((e) => (e as Map<String, dynamic>)['faculty_name'] as String)
          .where((s) => s.isNotEmpty)
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch faculty names: $e');
    }
  }
}
