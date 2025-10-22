import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'use_user_handling.dart' show upsertUserHandling;

class Admin {
  final String id; // uuid (DB generated)
  final String? username; // FK to login username (unique)
  final String? fullName;
  final String? facultyName; // FK to faculties.faculty_name
  final String? facultyId; // FK to faculties.id
  final String? password; // stored but never displayed in tables
  final DateTime? createdAt;

  Admin({
    required this.id,
    this.username,
    this.fullName,
    this.facultyName,
    this.facultyId,
    this.password,
    this.createdAt,
  });

  factory Admin.fromJson(Map<String, dynamic> json) {
    return Admin(
      id: json['id'] as String,
      username: json['username'] as String?,
      fullName: json['full_name'] as String?,
      facultyName: (() {
        if (json['faculty_name'] != null)
          return json['faculty_name'] as String?;
        if (json['faculty'] != null && json['faculty'] is Map) {
          return (json['faculty'] as Map)['faculty_name'] as String?;
        }
        return null;
      })(),
      facultyId: (() {
        if (json['faculty_id'] != null) return json['faculty_id'] as String?;
        if (json['faculty'] != null && json['faculty'] is Map) {
          return (json['faculty'] as Map)['id'] as String?;
        }
        return null;
      })(),
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
      'faculty_id': facultyId,
      'password': password,
      // created_at is DB-managed (default now())
    };
  }
}

class UseAdmins {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Resolve current authenticated admin's faculty id (local, avoids cross-file helper)
  Future<String?> _resolveCurrentAdminFacultyId() async {
    try {
      final current = _supabase.auth.currentUser;
      if (current == null) return null;
      final authUid = current.id;

      final uh = await _supabase
          .from('user_handling')
          .select('id, usernames, role')
          .eq('auth_uid', authUid)
          .maybeSingle();
      if (uh == null) {
        debugPrint('UseAdmins: no user_handling row for auth uid $authUid');
        return null;
      }
      final role = (uh['role'] ?? '').toString().trim().toLowerCase();
      // accept both 'admin' and 'faculty admin' variants
      if (role != 'admin' && role != 'faculty admin' && role != 'faculty_admin')
        return null;

      final uhId = (uh['id'] ?? '').toString();
      final username = (uh['usernames'] ?? '').toString();

      Map<String, dynamic>? adminRow;
      if (uhId.isNotEmpty) {
        final ar = await _supabase
            .from('admins')
            .select(
              'faculty_id, faculty_name, user_handling_id, user_id, username',
            )
            .eq('user_handling_id', uhId)
            .maybeSingle();
        if (ar != null) adminRow = ar;
      }

      if (adminRow == null && username.isNotEmpty) {
        final ar2 = await _supabase
            .from('admins')
            .select(
              'faculty_id, faculty_name, user_handling_id, user_id, username',
            )
            .eq('username', username)
            .maybeSingle();
        if (ar2 != null) adminRow = ar2;
      }

      if (adminRow == null) return null;
      final facultyId = (adminRow['faculty_id'] ?? '').toString();
      if (facultyId.isNotEmpty) {
        debugPrint(
          'UseAdmins: resolved faculty_id from admins row: $facultyId',
        );
        return facultyId;
      }
      final facultyName = (adminRow['faculty_name'] ?? '').toString();
      if (facultyName.isNotEmpty) {
        debugPrint(
          'UseAdmins: looking up faculty id for faculty_name="$facultyName"',
        );
        final f = await _supabase
            .from('faculties')
            .select('id')
            .eq('faculty_name', facultyName)
            .maybeSingle();
        if (f != null && f['id'] != null) {
          debugPrint('UseAdmins: resolved faculty_name -> id ${f['id']}');
          return f['id'].toString();
        }
      }

      return null;
    } catch (e) {
      debugPrint('UseAdmins._resolveCurrentAdminFacultyId error: $e');
      return null;
    }
  }

  Future<List<Admin>> fetchAdmins() async {
    try {
      // If there's no authenticated user (e.g., public listing), return all admins.
      final current = _supabase.auth.currentUser;
      if (current == null) {
        debugPrint('UseAdmins.fetchAdmins: no auth user, returning all admins');
        final rowsAll = await _supabase
            .from('admins')
            .select(
              'id, username, full_name, faculty_id, faculty:faculties(id,faculty_name), password, created_at',
            )
            .order('created_at', ascending: false);
        return (rowsAll as List)
            .map((e) => Admin.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      // Try to resolve the current admin's faculty id
      String? facultyId = await _resolveCurrentAdminFacultyId();

      // Fallback: if resolver couldn't find a faculty, try to locate the admin row
      // associated with the current auth user and derive faculty from it.
      if (facultyId == null || facultyId.isEmpty) {
        try {
          final uh = await _supabase
              .from('user_handling')
              .select('id, usernames')
              .eq('auth_uid', current.id)
              .maybeSingle();
          if (uh != null) {
            final uhId = (uh['id'] ?? '').toString();
            final username = (uh['usernames'] ?? '').toString();
            Map<String, dynamic>? adminRow;
            if (uhId.isNotEmpty) {
              final ar = await _supabase
                  .from('admins')
                  .select('faculty_id, faculty_name')
                  .eq('user_handling_id', uhId)
                  .maybeSingle();
              if (ar != null) adminRow = ar;
            }
            if (adminRow == null && username.isNotEmpty) {
              final ar2 = await _supabase
                  .from('admins')
                  .select('faculty_id, faculty_name')
                  .eq('username', username)
                  .maybeSingle();
              if (ar2 != null) adminRow = ar2;
            }
            if (adminRow != null) {
              final fid = (adminRow['faculty_id'] ?? '').toString();
              if (fid.isNotEmpty) {
                facultyId = fid;
                debugPrint(
                  'UseAdmins.fetchAdmins: fallback facultyId from adminRow=$facultyId',
                );
              } else {
                final fname = (adminRow['faculty_name'] ?? '').toString();
                if (fname.isNotEmpty) {
                  final f = await _supabase
                      .from('faculties')
                      .select('id')
                      .eq('faculty_name', fname)
                      .maybeSingle();
                  if (f != null && f['id'] != null) {
                    facultyId = f['id'].toString();
                    debugPrint(
                      'UseAdmins.fetchAdmins: fallback facultyName->id $facultyId',
                    );
                  }
                }
              }
            }
          }
        } catch (e) {
          debugPrint('UseAdmins.fetchAdmins: fallback lookup error: $e');
        }
      }

      List<dynamic> rows = [];

      if (facultyId != null && facultyId.isNotEmpty) {
        // Query admins by faculty_id; select nested faculty relation so UI can show name
        try {
          rows = await _supabase
              .from('admins')
              .select(
                'id, username, full_name, faculty_id, faculty:faculties(id,faculty_name), password, created_at',
              )
              .eq('faculty_id', facultyId)
              .order('created_at', ascending: false);
          debugPrint(
            'UseAdmins.fetchAdmins: rows by faculty_id -> ${rows.length}',
          );
        } catch (e) {
          debugPrint('UseAdmins.fetchAdmins: query by faculty_id failed: $e');
          rows = [];
        }

        // Fallback: if no rows, try matching by faculty_name
        if (rows.isEmpty) {
          try {
            final f = await _supabase
                .from('faculties')
                .select('faculty_name')
                .eq('id', facultyId)
                .maybeSingle();
            final facultyName = (f == null)
                ? ''
                : (f['faculty_name'] ?? '').toString();
            if (facultyName.isNotEmpty) {
              rows = await _supabase
                  .from('admins')
                  .select(
                    'id, username, full_name, faculty_name, password, created_at',
                  )
                  .eq('faculty_name', facultyName)
                  .order('created_at', ascending: false);
              debugPrint(
                'UseAdmins.fetchAdmins: rows by faculty_name -> ${rows.length}',
              );
            }
          } catch (_) {
            rows = [];
          }
        }
      }

      // If we still don't have a resolved faculty or rows, return empty list to avoid leaking data
      if (rows.isEmpty) return <Admin>[];

      return rows
          .map((e) => Admin.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch admins: $e');
    }
  }

  Future<void> addAdmin(Admin admin) async {
    try {
      final payload = admin.toJson();
      // Insert admin and get the inserted row (to get the id)
      final inserted = await _supabase
          .from('admins')
          .insert(payload)
          .select()
          .maybeSingle();

      if (inserted == null || inserted['id'] == null) {
        throw Exception('Failed to insert admin');
      }
      final adminId = inserted['id'] as String;
      final username = admin.username ?? '';
      final password = admin.password ?? '';

      // Upsert user_handling row
      final uhId = await upsertUserHandling(
        _supabase,
        username,
        'admin',
        password,
      );

      // Link admin to user_handling
      if (uhId != null && uhId.isNotEmpty) {
        await _supabase
            .from('admins')
            .update({'user_handling_id': uhId, 'user_id': uhId})
            .eq('id', adminId);
      }
    } catch (e) {
      throw Exception('Failed to add admin: $e');
    }
  }

  Future<void> updateAdmin(String id, Admin admin) async {
    try {
      final payload = admin.toJson();

      // Fetch existing admin row to get old username and possible user_handling link
      final existing = await _supabase
          .from('admins')
          .select('username, user_handling_id')
          .eq('id', id)
          .maybeSingle();

      final oldUsername = (existing != null && existing['username'] != null)
          ? existing['username'].toString().trim()
          : '';
      final existingUhId =
          (existing != null && existing['user_handling_id'] != null)
          ? existing['user_handling_id'].toString()
          : null;

      await _supabase.from('admins').update(payload).eq('id', id);

      // Try to update existing user_handling row first to avoid duplicates
      try {
        final newUsername = (admin.username ?? '').trim();
        final newPassword = (admin.password ?? '').trim();

        String? uhId;

        if (existingUhId != null && existingUhId.isNotEmpty) {
          final updateData = <String, dynamic>{
            if (newUsername.isNotEmpty) 'usernames': newUsername,
            'role': 'admin',
            if (newPassword.isNotEmpty) 'passwords': newPassword,
          };

          try {
            final updated = await _supabase
                .from('user_handling')
                .update(updateData)
                .eq('id', existingUhId)
                .select()
                .maybeSingle();
            if (updated != null && updated['id'] != null)
              uhId = updated['id'] as String;
          } catch (e) {
            debugPrint(
              'Failed to update user_handling by id $existingUhId: $e',
            );
          }
        }

        if ((uhId == null || uhId.isEmpty) && oldUsername.isNotEmpty) {
          try {
            final updated = await _supabase
                .from('user_handling')
                .update({
                  if (newUsername.isNotEmpty) 'usernames': newUsername,
                  'role': 'admin',
                  if (newPassword.isNotEmpty) 'passwords': newPassword,
                })
                .eq('usernames', oldUsername)
                .select()
                .maybeSingle();
            if (updated != null && updated['id'] != null)
              uhId = updated['id'] as String;
          } catch (e) {
            debugPrint(
              'Failed to update user_handling by old username $oldUsername: $e',
            );
          }
        }

        // Fallback to upsert if we still have no id
        if (uhId == null || uhId.isEmpty) {
          try {
            final created = await upsertUserHandling(
              _supabase,
              newUsername,
              'admin',
              newPassword,
            );
            if (created != null && created.isNotEmpty) uhId = created;
          } catch (e) {
            debugPrint(
              'Fallback upsertUserHandling failed for $newUsername: $e',
            );
          }
        }

        if (uhId != null && uhId.isNotEmpty) {
          await _supabase
              .from('admins')
              .update({'user_handling_id': uhId, 'user_id': uhId})
              .eq('id', id);
        }
      } catch (e) {
        debugPrint(
          'Failed to upsert/link user_handling for admin ${admin.username}: $e',
        );
      }
    } catch (e) {
      throw Exception('Failed to update admin: $e');
    }
  }

  Future<void> deleteAdmin(String id) async {
    try {
      // Fetch the admin row to get the username or user_handling_id
      final admin = await _supabase
          .from('admins')
          .select('username, user_handling_id')
          .eq('id', id)
          .maybeSingle();

      String? username = admin?['username'] as String?;
      String? uhId = admin?['user_handling_id'] as String?;

      // Delete the admin row
      await _supabase.from('admins').delete().eq('id', id);

      // Delete the user_handling row (by id if possible, else by username)
      if (uhId != null && uhId.isNotEmpty) {
        await _supabase.from('user_handling').delete().eq('id', uhId);
      } else if (username != null && username.isNotEmpty) {
        await _supabase
            .from('user_handling')
            .delete()
            .eq('usernames', username);
      }
    } catch (e) {
      throw Exception('Failed to delete admin: $e');
    }
  }

  // Load FK options for popup dropdown
  Future<List<String>> fetchFacultyNames() async {
    try {
      final List<dynamic> rows = await _supabase
          .from('faculties')
          .select('faculty_name');
      return rows
          .map((e) => (e as Map<String, dynamic>)['faculty_name'] as String)
          .where((s) => s.isNotEmpty)
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch faculty names: $e');
    }
  }
}
