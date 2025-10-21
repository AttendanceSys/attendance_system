import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

/// Check user credentials from Supabase
Future<Map<String, dynamic>?> loginUser(
  String username,
  String password,
) async {
  try {
    final response = await supabase
        .from('user_handling')
        .select()
        .eq('usernames', username)
        .eq('passwords', password)
        .maybeSingle();

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
            .select('full_name')
            .eq('username', username)
            .maybeSingle();
        if (a != null) fullName = (a['full_name'] ?? '').toString().trim();
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
          : (response['usernames'] ?? username);
      return out;
    } catch (e) {
      // If any lookup fails, return the base row with username as fallback
      final Map<String, dynamic> out = Map<String, dynamic>.from(
        response as Map,
      );
      out['full_name'] = response['usernames'] ?? username;
      return out;
    }
  } catch (e) {
    print('Login error: $e');
    return null;
  }
}
