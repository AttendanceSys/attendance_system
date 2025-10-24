import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/faculty.dart';

class UseFaculties {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Faculty>> fetchFaculties() async {
    try {
      final response = await _supabase
          .from('faculties')
          .select()
          .order('created_at', ascending: false);
      print('Fetched faculties: $response');
      return (response as List)
          .map(
            (e) => Faculty(
              code: e['faculty_code'],
              name: e['faculty_name'],
              createdAt: DateTime.parse(e['created_at']),
              establishmentDate: e['establishment_date'] != null
                  ? DateTime.parse(e['establishment_date'])
                  : DateTime.parse(e['created_at']),
            ),
          )
          .toList();
    } catch (e) {
      print('Error fetching faculties: $e');
      return [];
    }
  }

  Future<void> addFaculty(Faculty faculty) async {
    try {
      // If a user is authenticated, include their auth UID so RLS policies
      // that require auth.uid or created_by will succeed.
      final String? authUid = _supabase.auth.currentUser?.id;

      final payload = {
        'faculty_code': faculty.code,
        'faculty_name': faculty.name,
        'establishment_date': faculty.establishmentDate.toIso8601String().split(
          'T',
        )[0],
      };
      if (authUid != null) {
        // Common column names used in policies: created_by, auth_uid, user_id
        // Add all plausible fields to maximize compatibility with different schemas.
        payload['created_by'] = authUid;
        payload['auth_uid'] = authUid;
        payload['user_id'] = authUid;
      }

      final resp = await _supabase.from('faculties').insert(payload);
      print('Add faculty response: $resp');
    } catch (e) {
      // Supabase PostgrestException contains useful fields; try to print them
      if (e is PostgrestException) {
        print('Error adding faculty: ${e.message} (code: ${e.code})');
        final details = e.details?.toString() ?? '';
        final hint = e.hint?.toString() ?? '';
        if (details.isNotEmpty) {
          print('Details: $details');
        }
        if (hint.isNotEmpty) {
          print('Hint: $hint');
        }
      } else {
        print('Error adding faculty: $e');
      }
    }
  }

  Future<void> updateFaculty(String oldCode, Faculty faculty) async {
    try {
      final resp = await _supabase
          .from('faculties')
          .update({
            'faculty_code': faculty.code,
            'faculty_name': faculty.name,
            'establishment_date': faculty.establishmentDate
                .toIso8601String()
                .split('T')[0],
          })
          .eq('faculty_code', oldCode);
      print('Update faculty response: $resp');
    } catch (e) {
      print('Error updating faculty: $e');
    }
  }

  Future<void> deleteFaculty(String code) async {
    try {
      final actor =
          _supabase.auth.currentUser?.email ?? _supabase.auth.currentUser?.id;
      final resp = await _supabase.rpc(
        'delete_faculty',
        params: {'p_code': code, 'p_deleted_by': actor},
      );
      print('Delete faculty RPC response: $resp');
    } catch (e) {
      if (e is PostgrestException) {
        print('Error deleting faculty: ${e.message} (code: ${e.code})');
        final details = e.details?.toString() ?? '';
        final hint = e.hint?.toString() ?? '';
        if (details.isNotEmpty) print('Details: $details');
        if (hint.isNotEmpty) print('Hint: $hint');
      } else {
        print('Error deleting faculty: $e');
      }
    }
  }
}
