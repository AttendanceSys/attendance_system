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
      final resp = await _supabase.from('faculties').insert({
        'faculty_code': faculty.code,
        'faculty_name': faculty.name,
        'establishment_date': faculty.establishmentDate.toIso8601String().split(
          'T',
        )[0],
      });
      print('Add faculty response: $resp');
    } catch (e) {
      print('Error adding faculty: $e');
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
      final resp = await _supabase
          .from('faculties')
          .delete()
          .eq('faculty_code', code);
      print('Delete faculty response: $resp');
    } catch (e) {
      print('Error deleting faculty: $e');
    }
  }
}
