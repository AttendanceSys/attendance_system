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
      final resp = await _supabase.from('teachers').delete().eq('id', id);
      print('Delete teacher response: $resp');
    } catch (e) {
      print('Error deleting teacher: $e');
    }
  }
}
