import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

/// Check user credentials from Supabase
Future<Map<String, dynamic>?> loginUser(
  String username,
  String password,
) async {
  print('🔍 username=$username, password=$password');
  try {
    final response = await supabase
        .from('user_handling')
        .select()
        .eq('username', username)
        .eq('password', password)
        .maybeSingle();

    print('🔍 Supabase response=$response');

    if (response == null) return null;

    // Attempt to fetch a human-friendly full name from role-specific tables
    try {
      final roleRaw = (response['role'] ?? '').toString().trim().toLowerCase();
      String? fullName;

      if (roleRaw == 'teacher') {
        final t = await supabase
            .from('teachers')
            .select('teacher_name')
            .eq('username', username)
            .maybeSingle();
        if (t != null) fullName = (t['teacher_name'] ?? '').toString().trim();
      } else if (roleRaw == 'admin' || roleRaw == 'faculty admin') {
        final a = await supabase
            .from('admins')
            .select(
              'full_name, faculty_id, faculty:faculties(id, faculty_name)',
            )
            .eq('username', username)
            .maybeSingle();
        if (a != null) {
          fullName = (a['full_name'] ?? '').toString().trim();
          // attach faculty_name to response if available
          if (a['faculty'] != null && a['faculty'] is Map) {
            final facultyName = ((a['faculty'] as Map)['faculty_name'] ?? '')
                .toString()
                .trim();
            if (facultyName.isNotEmpty) {
              // we'll include this in the returned map below
            }
          }
        }
      } else if (roleRaw == 'student') {
        final s = await supabase
            .from('students')
            .select('fullname')
            .eq('username', username)
            .maybeSingle();
        if (s != null) fullName = (s['fullname'] ?? '').toString().trim();
      }

      // Add display name to the returned map for convenience
      final Map<String, dynamic> out = Map<String, dynamic>.from(
        response as Map,
      );
      out['full_name'] = (fullName != null && fullName.isNotEmpty)
          ? fullName
          : (response['username'] ?? username);
      return out;
    } catch (e) {
      // If any lookup fails, return the base row with username as fallback
      final Map<String, dynamic> out = Map<String, dynamic>.from(
        response as Map,
      );
      out['full_name'] = response['username'] ?? username;
      return out;
    }
  } catch (e) {
    print('Login error: $e');
    return null;
  }
}
