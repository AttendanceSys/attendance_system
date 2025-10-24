import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'use_user_handling.dart';

class Teacher {
  final String id;
  final String? username;
  final String? teacherName;
  final String? password;
  final DateTime? createdAt;
  final String? facultyId;

  Teacher({
    required this.id,
    this.username,
    this.teacherName,
    this.password,
    this.createdAt,
    this.facultyId,
  });

  factory Teacher.fromJson(Map<String, dynamic> json) {
    return Teacher(
      id: json['id'] as String,
      username: json['username'] as String?,
      teacherName: json['teacher_name'] as String?,
      password: json['password'] as String?,
      facultyId: json['faculty_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'teacher_name': teacherName,
      'password': password,
      'faculty_id': facultyId,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

class UseTeachers {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ================================
  // 🔹 FETCH ALL TEACHERS
  // ================================
  Future<List<Teacher>> fetchTeachers() async {
    try {
      final response = await _supabase
          .from('teachers')
          .select()
          .order('created_at', ascending: false);
      print('Fetched teachers: $response');

      return (response as List)
          .map((e) => Teacher.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching teachers: $e');
      return [];
    }
  }

  // ================================
  // 🔹 ADD TEACHER (RPC)
  // ================================
  Future<Teacher?> addTeacher(
    Teacher teacher, {
    String? facultyId,
    String? createdBy,
  }) async {
    try {
      final rpcParams = {
        'p_teacher_name': teacher.teacherName,
        'p_username': teacher.username,
        'p_password': teacher.password,
        'p_faculty_id': facultyId,
        'p_created_by': createdBy,
      };

      final resp = await _supabase.rpc('create_teacher', params: rpcParams);
      print('Add teacher RPC response: $resp');

      Map<String, dynamic>? row;
      if (resp == null) return null;
      if (resp is List && resp.isNotEmpty) {
        row = Map<String, dynamic>.from(resp[0]);
      } else if (resp is Map) {
        row = Map<String, dynamic>.from(resp);
      }

      return row != null ? Teacher.fromJson(row) : null;
    } catch (e) {
      debugPrint('Error adding teacher: $e');
      return null;
    }
  }

  // ================================
  // 🔹 UPDATE TEACHER
  // ================================
  Future<void> updateTeacher(
    String id,
    Teacher teacher, {
    String? updatedBy,
  }) async {
    // Determine who is performing the update. Prefer the explicit `updatedBy`
    // parameter; otherwise try to resolve the currently authenticated user's
    // username via the `user_handling` table (auth_uid -> username), falling
    // back to email or auth uid when necessary.
    String updater = '';
    if (updatedBy != null && updatedBy.isNotEmpty) {
      updater = updatedBy;
    } else {
      final current = _supabase.auth.currentUser;
      if (current == null) {
        updater = '';
      } else {
        try {
          final uh = await _supabase
              .from('user_handling')
              .select('username')
              .eq('auth_uid', current.id)
              .maybeSingle();
          if (uh != null && uh['username'] != null) {
            updater = uh['username'].toString();
          } else if (current.email != null && current.email!.isNotEmpty) {
            updater = current.email!;
          } else {
            updater = current.id;
          }
        } catch (e) {
          // fallback to email or auth id if mapping fails
          updater = current.email ?? current.id;
        }
      }
    }
    try {
      final data = teacher.toJson();
      data.remove('id');

      // Get the old username first
      final existing = await _supabase
          .from('teachers')
          .select('username')
          .eq('id', id)
          .maybeSingle();

      final oldUsername = (existing != null && existing['username'] != null)
          ? existing['username'].toString().trim()
          : '';

      // Prefer server-side RPC which can handle linked user_handling updates.
      // Call the RPC with parameter names matching the Postgres function
      // signature (username-based). The DB function returns void, so do not
      // call .select() here. If the RPC call fails, fall back to client-side
      // updates below.
      try {
        debugPrint(
          'Calling update_teacher RPC with: p_username=$oldUsername, p_new_username=${teacher.username}, p_new_teacher_name=${teacher.teacherName}, p_new_faculty_id=${teacher.facultyId}, p_updated_by=$updater',
        );
        debugPrint(
          'Auth context: authUserId=${_supabase.auth.currentUser?.id}, authEmail=${_supabase.auth.currentUser?.email}',
        );

        await _supabase.rpc(
          'update_teacher',
          params: {
            'p_username': oldUsername, // current username (identifier)
            'p_new_username': teacher.username,
            'p_new_teacher_name': teacher.teacherName,
            'p_new_password': teacher.password,
            'p_new_faculty_id': teacher.facultyId,
            'p_updated_by': updater,
          },
        );
        // RPC succeeded — done.
        debugPrint('update_teacher RPC invoked successfully');
        return;
      } catch (e) {
        debugPrint(
          'update_teacher RPC failed, falling back to client update: $e',
        );
        // continue to fallback logic
      }

      // Fallback: Update teacher info in teachers table directly
      final resp = await _supabase.from('teachers').update(data).eq('id', id);
      print('Update teacher response: $resp');

      // Update user_handling account
      final newUsername = (teacher.username ?? '').trim();
      final newPassword = (teacher.password ?? '').trim();

      if (oldUsername.isNotEmpty) {
        final updateData = <String, dynamic>{
          if (newUsername.isNotEmpty) 'username': newUsername,
          'role': 'teacher',
          if (newPassword.isNotEmpty) 'password': newPassword,
        };

        try {
          final updated = await _supabase
              .from('user_handling')
              .update(updateData)
              .eq('username', oldUsername)
              .select();
          if (updated.isEmpty) {
            // If old username not found, fallback to upsert
            try {
              await upsertUserHandling(
                _supabase,
                newUsername,
                'teacher',
                newPassword,
              );
            } catch (e, st) {
              debugPrint(
                'Fallback upsertUserHandling failed for $newUsername: $e\n$st',
              );
            }
          }
        } catch (e) {
          debugPrint(
            'Failed to update user_handling by old username $oldUsername: $e',
          );
        }
      } else if (newUsername.isNotEmpty) {
        // Fallback — create new user_handling record
        try {
          await upsertUserHandling(
            _supabase,
            newUsername,
            'teacher',
            newPassword,
          );
        } catch (e, st) {
          debugPrint(
            'Fallback upsertUserHandling failed for $newUsername: $e\n$st',
          );
        }
      }
    } catch (e) {
      debugPrint('Error updating teacher: $e');
    }
  }

  // ================================
  // 🔹 DELETE TEACHER
  // ================================
  Future<void> deleteTeacher(String id) async {
    try {
      // Fetch teacher info before deleting
      final teacher = await _supabase
          .from('teachers')
          .select('username')
          .eq('id', id)
          .maybeSingle();

      final username = teacher?['username'] as String?;

      // Delete teacher from teachers table
      final resp = await _supabase
          .from('teachers')
          .delete()
          .eq('id', id)
          .select();
      print('Delete teacher response: $resp');

      // Delete linked user_handling record
      if (username != null && username.isNotEmpty) {
        try {
          await _supabase
              .from('user_handling')
              .delete()
              .eq('username', username)
              .select();
        } catch (e) {
          debugPrint(
            'Failed to delete linked user_handling for username=$username: $e',
          );
        }
      }
    } catch (e) {
      debugPrint('Error deleting teacher: $e');
    }
  }
}
