import 'package:supabase_flutter/supabase_flutter.dart';

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
      final resp = await _supabase.from('teachers').update(data).eq('id', id);
      print('Update teacher response: $resp');
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
