import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

/// FacultyScope
/// Central resolver to determine the current user's faculty id (UUID as String).
/// Cache result per app session. Use in hooks to scope queries and payloads.
class FacultyScope {
  final SupabaseClient _supabase = Supabase.instance.client;
  String? _cachedFacultyId;
  bool _resolved = false;

  /// Tracks an in-flight resolution so concurrent callers share the same work.
  Future<String?>? _resolving;

  /// Resolve and cache the current user's faculty id.
  /// Returns null for unresolved or global users (super admin).
  Future<String?> resolveCurrentFacultyId({bool forceRefresh = false}) async {
    if (_resolved && !forceRefresh) return _cachedFacultyId;

    if (_resolving != null && !forceRefresh) {
      return await _resolving;
    }

    _cachedFacultyId = null;
    _resolving = _doResolve();
    final result = await _resolving;
    return result;
  }

  Future<String?> _doResolve() async {
    try {
      final current = _supabase.auth.currentUser;
      if (current == null) return null;

      // Try reading faculty_id from user_handling (if you populated it)
      Map<String, dynamic>? uh;
      try {
        uh = await _supabase
            .from('user_handling')
            .select('faculty_id, role, username')
            .eq('auth_uid', current.id)
            .maybeSingle();
      } catch (e) {
        debugPrint('user_handling auth_uid lookup failed: $e');
      }

      if (uh != null) {
        final role = _normalizeRole(uh['role']);
        final facultyId = (uh['faculty_id'] ?? '').toString();
        if (facultyId.isNotEmpty) {
          _cachedFacultyId = facultyId;
          return _cachedFacultyId;
        }

        // Role that indicates global access (treat as null)
        if (role == 'super_admin') {
          _cachedFacultyId = null;
          return null;
        }
      }

      // Fallback: find admins row linked to this user_handling or username
      final uhByAuth =
          uh ??
          await _supabase
              .from('user_handling')
              .select('id, username')
              .eq('auth_uid', current.id)
              .maybeSingle();

      String? uhId;
      dynamic usernamesRaw;
      if (uhByAuth != null) {
        uhId = (uhByAuth['id'] ?? '').toString();
        usernamesRaw = uhByAuth['username'];
      }

      Map? adminRow;
      if (uhId != null && uhId.isNotEmpty) {
        adminRow = await _supabase
            .from('admins')
            .select('faculty_id, faculty_name')
            .eq('user_handling_id', uhId)
            .maybeSingle();
      }

      final usernameCandidates = _parseUsernames(usernamesRaw);
      if (adminRow == null && usernameCandidates.isNotEmpty) {
        for (final uname in usernameCandidates) {
          final candidate = await _supabase
              .from('admins')
              .select('faculty_id, faculty_name')
              .eq('username', uname)
              .maybeSingle();
          if (candidate != null) {
            adminRow = Map<String, dynamic>.from(candidate as Map);
            break;
          }
        }
      }

      if (adminRow != null) {
        final fid = (adminRow['faculty_id'] ?? '').toString();
        if (fid.isNotEmpty) {
          _cachedFacultyId = fid;
          return _cachedFacultyId;
        }
        final fname = (adminRow['faculty_name'] ?? '').toString();
        if (fname.isNotEmpty) {
          var f = await _supabase
              .from('faculties')
              .select('id')
              .eq('faculty_name', fname)
              .maybeSingle();
          if (f == null) {
            try {
              // try case-insensitive fallback if supported
              f = await _supabase
                  .from('faculties')
                  .select('id')
                  .ilike('faculty_name', fname)
                  .maybeSingle();
            } catch (_) {
              // ignore if ilike isn't supported by client version
            }
          }
          if (f != null && f['id'] != null) {
            _cachedFacultyId = f['id'].toString();
            return _cachedFacultyId;
          }
        }
      }
    } catch (e, st) {
      debugPrint('FacultyScope.resolveCurrentFacultyId error: $e\n$st');
    } finally {
      _resolved = true;
      _resolving = null;
    }

    _cachedFacultyId = null;
    return null;
  }

  String _normalizeRole(dynamic roleVal) {
    if (roleVal == null) return '';
    if (roleVal is String) return roleVal.trim().toLowerCase();
    if (roleVal is List && roleVal.isNotEmpty) {
      return roleVal.first.toString().trim().toLowerCase();
    }
    return roleVal.toString().trim().toLowerCase();
  }

  List<String> _parseUsernames(dynamic val) {
    if (val == null) return [];
    if (val is List) {
      return val
          .map((e) => e?.toString().trim())
          .where((s) => s != null && s.isNotEmpty)
          .cast<String>()
          .toList();
    }
    final s = val.toString().trim();
    if (s.isEmpty) return [];
    if (s.contains(',')) {
      return s
          .split(',')
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList();
    }
    if (s.contains(' ')) {
      return s
          .split(RegExp(r"\s+"))
          .map((p) => p.trim())
          .where((p) => p.isNotEmpty)
          .toList();
    }
    return [s];
  }

  /// Apply scope to a PostgREST builder if resolvedFacultyId is non-null.
  /// Returns the (possibly transformed) builder so callers can reassign it.
  dynamic applyScope(dynamic builder, String? resolvedFacultyId) {
    if (resolvedFacultyId != null && resolvedFacultyId.isNotEmpty) {
      try {
        return (builder as dynamic).eq('faculty_id', resolvedFacultyId);
      } catch (_) {
        // ignore if builder doesn't accept eq dynamically
        if (kDebugMode) debugPrint('applyScope: builder does not support eq');
      }
    }
    return builder;
  }

  /// Returns true if the current user is a super_admin according to user_handling.role
  Future<bool> isSuperAdmin() async {
    try {
      final current = _supabase.auth.currentUser;
      if (current == null) return false;

      // Try user_handling by auth_uid
      try {
        final uh = await _supabase
            .from('user_handling')
            .select('role')
            .eq('auth_uid', current.id)
            .maybeSingle();
        if (uh != null && uh['role'] != null) {
          final role = _normalizeRole(uh['role']);
          return role == 'super_admin';
        }
      } catch (_) {}

      // Fallback: try to find role by usernames/email mapping
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Clear cached faculty id (use on logout)
  void clearCache() {
    _resolved = false;
    _cachedFacultyId = null;
    _resolving = null;
  }
}
