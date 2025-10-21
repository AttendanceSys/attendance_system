import 'package:supabase_flutter/supabase_flutter.dart';

/// Simple helper for inserting and fetching qr_generation rows.
/// This assumes your database already has a `qr_generation` table as described.
class UseQRGeneration {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Insert a generated QR payload (string) and optional teacher id.
  /// Returns the created row as a Map if successful, otherwise throws.
  Future<Map<String, dynamic>> createQr({
    required String payload,
    String? teacherId,
  }) async {
    try {
      final row = await _supabase
          .from('qr_generation')
          .insert({
            'generate_qr_code': payload,
            if (teacherId != null) 'teacher_id': teacherId,
          })
          .select()
          .maybeSingle();

      if (row == null) throw Exception('Insert returned null');
      return Map<String, dynamic>.from(row as Map);
    } catch (e) {
      throw Exception('Failed to create QR row: $e');
    }
  }

  /// Fetch latest QR rows (limit optional)
  Future<List<Map<String, dynamic>>> fetchLatest({int limit = 50}) async {
    try {
      final resp = await _supabase
          .from('qr_generation')
          .select('id, generate_qr_code, teacher_id, created_at')
          .order('created_at', ascending: false)
          .range(0, limit - 1);
      final List rows = resp as List? ?? [];
      return rows
          .map<Map<String, dynamic>>((r) => Map<String, dynamic>.from(r as Map))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch QR rows: $e');
    }
  }
}
