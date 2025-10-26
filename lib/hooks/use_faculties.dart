import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/faculty.dart';

class UseFaculties {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<Faculty>> fetchFaculties() async {
    try {
      // Request explicit columns to avoid surprises and make parsing safer
      final response = await _supabase
          .from('faculties')
          .select('faculty_code, faculty_name, created_at, establishment_date')
          .order('created_at', ascending: false);
      debugPrint('Fetched faculties raw: $response');

      final rows = (response as List<dynamic>?) ?? <dynamic>[];
      return rows.map((e) {
        final m = e as Map<String, dynamic>;

        DateTime? createdAt;
        DateTime? establishmentDate;

        if (m['created_at'] != null) {
          createdAt = DateTime.tryParse(m['created_at'].toString());
        }
        if (m['establishment_date'] != null) {
          establishmentDate = DateTime.tryParse(
            m['establishment_date'].toString(),
          );
        }

        // if establishmentDate missing, fallback to createdAt; if both missing, leave null
        establishmentDate ??= createdAt;

        return Faculty(
          code: m['faculty_code']?.toString() ?? '',
          name: m['faculty_name']?.toString() ?? '',
          createdAt: createdAt ?? DateTime.now(),
          establishmentDate: establishmentDate ?? DateTime.now(),
        );
      }).toList();
    } catch (e) {
      debugPrint('Error fetching faculties: $e');
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
      final payload = {
        'faculty_code': faculty.code,
        'faculty_name': faculty.name,
        'establishment_date': faculty.establishmentDate.toIso8601String().split(
          'T',
        )[0],
      };

      final resp = await _supabase
          .from('faculties')
          .update(payload)
          .eq('faculty_code', oldCode)
          .select();

      debugPrint('Update faculty response: $resp');
    } catch (e) {
      debugPrint('Error updating faculty: $e');
    }
  }

  Future<void> deleteFaculty(String code) async {
    try {
      // Delete faculty directly by code (no RPC). If your DB has cascades
      // configured, related rows will be removed automatically.
      final resp = await _supabase
          .from('faculties')
          .delete()
          .eq('faculty_code', code)
          .select();
      print('Delete faculty response: $resp');
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
