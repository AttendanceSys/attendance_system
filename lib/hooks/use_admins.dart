import 'package:supabase_flutter/supabase_flutter.dart';

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
      return rows.map((e) => Admin.fromJson(e as Map<String, dynamic>)).toList();
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
      await _supabase.from('admins').update(payload).eq('id', id);
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
      final List<dynamic> rows =
          await _supabase.from('faculties').select('faculty_name');
      return rows
          .map((e) => (e as Map<String, dynamic>)['faculty_name'] as String)
          .where((s) => s.isNotEmpty)
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch faculty names: $e');
    }
  }
}