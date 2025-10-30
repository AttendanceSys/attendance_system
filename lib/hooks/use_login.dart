import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

/// Check user credentials from Supabase.
///
/// Behaviour:
/// 1. Try RPC-based login first (if your backend exposes a function like
///    `login_user` or `rpc_login_user`). RPC is preferred because it can
///    centralize role logic server-side. RPC function name guesses are made
///    but the call is tolerant — if the RPC does not exist or fails, we
///    gracefully fallback to a direct table query (original behaviour).
Future<Map<String, dynamic>?> loginUser(
  String username,
  String password,
) async {
  print('🔍 loginUser: username=$username');

  // Direct table query for credentials (no RPC call)
  try {
    final response = await supabase
        .from('user_handling')
        .select()
        .eq('username', username)
        .eq('password', password)
        .maybeSingle();

    print('🔍 Direct query response=$response');

    if (response == null) return null;

    // If the account has been disabled in `user_handling`, treat as no-login.
    // Return a marker map so callers can show a specific message if desired.
    try {
      if ((response as Map).containsKey('is_disabled')) {
        final isDisabled = response['is_disabled'];
        if (isDisabled == true ||
            (isDisabled is String && isDisabled.toLowerCase() == 'true')) {
          final out = Map<String, dynamic>.from(response as Map);
          out['disabled'] = true;
          out['auth_source'] = 'direct';
          return out;
        }
      }
    } catch (_) {
      // ignore parsing errors and continue
    }

    // Attempt to fetch a human-friendly full name from role-specific tables
    try {
      final roleRaw = (response['role'] ?? '').toString().trim().toLowerCase();
      String? fullName;
      String? discoveredFacultyId;

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
          if (a['faculty_id'] != null) {
            discoveredFacultyId = a['faculty_id'].toString();
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
      out['auth_source'] = 'direct';
      // Propagate a discovered faculty id (from admins lookup) or the
      // value stored on the user_handling row if present.
      final respFaculty = (response as Map)['faculty_id'];
      if (respFaculty != null && respFaculty.toString().isNotEmpty) {
        out['faculty_id'] = respFaculty.toString();
      } else if (discoveredFacultyId != null &&
          discoveredFacultyId.isNotEmpty) {
        out['faculty_id'] = discoveredFacultyId;
      }
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
    print('Login error (direct query): $e');
    return null;
  }
}
