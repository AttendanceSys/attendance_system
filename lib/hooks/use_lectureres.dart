import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'use_user_handling.dart';

class Teacher {
  final String id;
  final String? username;
  final String? teacherName;
  final String? password;
  final DateTime? createdAt;

  Teacher({
    required this.id,
    this.username,
    this.teacherName,
    this.password,
    this.createdAt,
  });

  factory Teacher.fromJson(Map<String, dynamic> json) {
    return Teacher(
      id: json['id'] as String,
      username: json['username'] as String?,
      teacherName: json['teacher_name'] as String?,
      password: json['password'] as String?,
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
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

class UseTeachers {
  final SupabaseClient _supabase = Supabase.instance.client;

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
      print('Error fetching teachers: $e');
      return [];
    }
  }

  Future<void> addTeacher(Teacher teacher) async {
    try {
      final data = teacher.toJson();
      // Remove id so DB generates it
      data.remove('id');
      final resp = await _supabase.from('teachers').insert(data);
      print('Add teacher response: $resp');
    } catch (e) {
      print('Error adding teacher: $e');
    }
  }

  Future<void> updateTeacher(String id, Teacher teacher) async {
    try {
      final data = teacher.toJson();
      data.remove('id'); // Don't update id

      // Fetch existing teacher row to detect old username or existing user_handling_id
      final existing = await _supabase
          .from('teachers')
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

      final resp = await _supabase.from('teachers').update(data).eq('id', id);
      print('Update teacher response: $resp');

      // After teacher update, try to update the linked user_handling row instead of blindly inserting.
      try {
        final newUsername = (teacher.username ?? '').trim();
        final newPassword = (teacher.password ?? '').trim();

        String? uhId;

        if (existingUhId != null && existingUhId.isNotEmpty) {
          // Update by user_handling_id
          final updateData = <String, dynamic>{
            if (newUsername.isNotEmpty) 'usernames': newUsername,
            'role': 'teacher',
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

        // If not updated by id, try to find by old username and update that row (avoid creating duplicate)
        if ((uhId == null || uhId.isEmpty) && oldUsername.isNotEmpty) {
          try {
            final updated = await _supabase
                .from('user_handling')
                .update({
                  if (newUsername.isNotEmpty) 'usernames': newUsername,
                  'role': 'teacher',
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

        // Fallback: upsert (creates if truly missing). This is last resort and may create a new row.
        if (uhId == null || uhId.isEmpty) {
          try {
            final created = await upsertUserHandling(
              _supabase,
              newUsername,
              'teacher',
              newPassword,
            );
            if (created != null && created.isNotEmpty) uhId = created;
          } catch (e) {
            debugPrint(
              'Fallback upsertUserHandling failed for $newUsername: $e',
            );
          }
        }

        // If we have a user_handling id, ensure the teacher row references it
        if (uhId != null && uhId.isNotEmpty) {
          await _supabase
              .from('teachers')
              .update({'user_handling_id': uhId, 'user_id': uhId})
              .eq('id', id);
        }
      } catch (e) {
        debugPrint(
          'Failed to update/link user_handling for teacher ${teacher.username}: $e',
        );
      }
    } catch (e) {
      print('Error updating teacher: $e');
    }
  }

  Future<void> deleteTeacher(String id) async {
    try {
      // Fetch the teacher row to get the username or user_handling_id/user_id
      final teacher = await _supabase
          .from('teachers')
          .select('username, user_handling_id, user_id')
          .eq('id', id)
          .maybeSingle();

      String? username = teacher?['username'] as String?;
      String? uhId = teacher?['user_handling_id'] as String?;
      String? userIdField = teacher?['user_id'] as String?;

      // Prefer explicit user_handling_id, otherwise try user_id
      final candidateUhId = (uhId != null && uhId.isNotEmpty)
          ? uhId
          : (userIdField != null && userIdField.isNotEmpty)
          ? userIdField
          : null;

      // Delete the teacher row first
      final resp = await _supabase
          .from('teachers')
          .delete()
          .eq('id', id)
          .select();
      print('Delete teacher response: $resp');

      // Attempt to delete linked user_handling. Try by id first, then by username.
      try {
        bool deleted = false;
        if (candidateUhId != null && candidateUhId.isNotEmpty) {
          final delResp = await _supabase
              .from('user_handling')
              .delete()
              .eq('id', candidateUhId)
              .select();
          // delResp is typically a list of deleted rows; check length
          if (delResp.isNotEmpty) deleted = true;
        }

        if (!deleted && username != null && username.isNotEmpty) {
          final delResp2 = await _supabase
              .from('user_handling')
              .delete()
              .eq('usernames', username)
              .select();
          if (delResp2.isNotEmpty) deleted = true;
        }

        if (!deleted) {
          // Nothing deleted — surface a warning to help debug
          debugPrint(
            'No user_handling row deleted for teacher id=$id (username=$username, candidateUhId=$candidateUhId)',
          );
        }
      } catch (e) {
        // If cleaning up user_handling fails, surface the error so caller can handle it.
        throw Exception(
          'Failed to delete linked user_handling for teacher id=$id: $e',
        );
      }
    } catch (e) {
      print('Error deleting teacher: $e');
      rethrow;
    }
  }
}
