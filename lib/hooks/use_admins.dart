import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'use_user_handling.dart';

class Admin {
  final String id; // uuid (DB generated)
  final String? username; // FK to login username (unique)
  final String? fullName;
  final String?
  facultyName; // FK to faculties.faculty_name (read-only convenience)
  final String? facultyId; // FK to faculties.id (uuid)
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
        if (json['faculty_name'] != null) {
          return json['faculty_name'] as String?;
        }
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
    };
  }
}

class UseAdmins {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Fetch faculties as id/name pairs for dropdowns
  Future<List<Map<String, String>>> fetchFacultyOptions() async {
    try {
      final List<dynamic> rows = await _supabase
          .from('faculties')
          .select('id, faculty_name')
          .order('faculty_name', ascending: true);
      return rows
          .map((e) {
            final m = e as Map<String, dynamic>;
            return {
              'id': (m['id'] ?? '').toString(),
              'name': (m['faculty_name'] ?? '').toString(),
            };
          })
          .where((m) => (m['id']?.isNotEmpty ?? false))
          .toList();
    } catch (e) {
      debugPrint('fetchFacultyOptions error: $e');
      rethrow;
    }
  }

  /// Fetch faculties with id and name so caller can map names -> ids.
  Future<List<Map<String, String>>> fetchFaculties() async {
    try {
      final List<dynamic> rows = await _supabase
          .from('faculties')
          .select('id, faculty_name');
      return rows
          .map((e) => (e as Map<String, dynamic>))
          .where(
            (m) =>
                m['faculty_name'] != null &&
                (m['faculty_name'] as String).isNotEmpty,
          )
          .map(
            (m) => {
              'id': m['id'].toString(),
              'name': m['faculty_name'].toString(),
            },
          )
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch faculties: $e');
    }
  }

  // Resolve current authenticated user's username by auth.uid -> user_handling
  Future<String> _resolveCurrentUsername() async {
    try {
      final current = _supabase.auth.currentUser;
      if (current == null) return '';

      // prefer mapping via auth_uid column in user_handling
      try {
        final uh = await _supabase
            .from('user_handling')
            .select('username')
            .eq('auth_uid', current.id)
            .maybeSingle();
        if (uh != null && uh['username'] != null) {
          return uh['username'].toString();
        }
      } catch (e) {
        debugPrint('mapping auth_uid -> username failed: $e');
      }

      // fallback to email
      if (current.email != null && current.email!.isNotEmpty) {
        return current.email!;
      }

      // final fallback to auth uid
      return current.id;
    } catch (e) {
      debugPrint('UseAdmins._resolveCurrentUsername error: $e');
      return '';
    }
  }

  Future<List<Admin>> fetchAdmins() async {
    try {
      final current = _supabase.auth.currentUser;
      if (current == null) {
        debugPrint(
          'UseAdmins.fetchAdmins: no auth user, returning all admins (public case)',
        );
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

      // If authenticated, try to determine faculty_id of current admin (restrict results)
      String? facultyId;
      // try to find mapping in user_handling using auth_uid
      try {
        final uh = await _supabase
            .from('user_handling')
            .select('id, username, role, faculty_id')
            .eq('auth_uid', current.id)
            .maybeSingle();
        if (uh != null) {
          final role = (uh['role'] ?? '').toString().trim().toLowerCase();
          // If user is super_admin, return all admins (no faculty scoping)
          if (role == 'super_admin') {
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

          if (role == 'admin' ||
              role == 'faculty admin' ||
              role == 'faculty_admin') {
            // prefer faculty_id column on user_handling if set
            final fid = (uh['faculty_id'] ?? '').toString();
            if (fid.isNotEmpty) {
              facultyId = fid;
            } else {
              // try admins table by username
              final username = (uh['username'] ?? '').toString();
              if (username.isNotEmpty) {
                final ar = await _supabase
                    .from('admins')
                    .select('faculty_id, faculty_name')
                    .eq('username', username)
                    .maybeSingle();
                if (ar != null) {
                  final aFid = (ar['faculty_id'] ?? '').toString();
                  if (aFid.isNotEmpty) {
                    facultyId = aFid;
                  } else {
                    final fname = (ar['faculty_name'] ?? '').toString();
                    if (fname.isNotEmpty) {
                      final f = await _supabase
                          .from('faculties')
                          .select('id')
                          .eq('faculty_name', fname)
                          .maybeSingle();
                      if (f != null && f['id'] != null) {
                        facultyId = f['id'].toString();
                      }
                    }
                  }
                }
              }
            }
          }
        }
      } catch (e) {
        debugPrint('faculty resolution error: $e');
      }

      // Query admins: if facultyId known, filter; else return empty to avoid leaking
      List<dynamic> rows = [];
      if (facultyId != null && facultyId.isNotEmpty) {
        rows = await _supabase
            .from('admins')
            .select(
              'id, username, full_name, faculty_id, faculty:faculties(id,faculty_name), password, created_at',
            )
            .eq('faculty_id', facultyId)
            .order('created_at', ascending: false);
      } else {
        // if no faculty resolved, return empty list (safe)
        return <Admin>[];
      }

      return rows
          .map((e) => Admin.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      debugPrint('fetchAdmins error: $e\n$st');
      throw Exception('Failed to fetch admins: $e');
    }
  }

  Future<void> addAdmin(Admin admin) async {
    try {
      // Validate required fields (username + facultyId expected)
      final username = admin.username?.trim() ?? '';
      final password = admin.password?.trim() ?? '';
      final facultyId = admin.facultyId?.trim();

      if (username.isEmpty) {
        throw Exception('Admin username is required');
      }
      if (password.isEmpty) {
        throw Exception('Admin password is required');
      }

      // Resolve actor (creator). We need a canonical username to pass to the RPC.
      final creator = await _resolveCurrentUsername();

      if (creator.isEmpty) {
        debugPrint(
          'addAdmin: no authenticated creator found - RPC call may fail authentication/authorization checks',
        );
      }

      // If you require facultyId, validate here and throw / show validation in UI if missing.
      if (facultyId == null || facultyId.isEmpty) {
        debugPrint(
          'addAdmin: facultyId is missing - admin will be created with p_faculty_id=null unless your UI prevents it',
        );
      }

      final params = {
        'p_full_name': admin.fullName ?? '',
        'p_username': username,
        'p_password': password,
        'p_faculty_id': (facultyId != null && facultyId.isNotEmpty)
            ? facultyId
            : null,
        'p_created_by': creator,
      };

      debugPrint('create_admin params: $params');
      // Insert directly into admins table and ensure user_handling exists
      final insertData = <String, dynamic>{
        'username': username,
        'full_name': admin.fullName ?? '',
        'faculty_id': facultyId,
        'password': password,
        'created_at': DateTime.now().toIso8601String(),
      };

      // Ensure user_handling row exists for login BEFORE inserting into admins
      try {
        final uhId = await upsertUserHandling(
          _supabase,
          username,
          'admin',
          password,
        );
        if (uhId == null) {
          throw Exception(
            'Failed to create or find user_handling for $username',
          );
        }
      } catch (e) {
        debugPrint('upsertUserHandling failed before admin insert: $e');
        rethrow;
      }

      final tmp = await _supabase
          .from('admins')
          .insert(insertData)
          .select()
          .limit(1);
      Map<String, dynamic>? inserted;
      if ((tmp as List).isNotEmpty) {
        inserted = Map<String, dynamic>.from(tmp[0] as Map);
      }

      if (inserted == null) {
        throw Exception('Failed to insert admin directly');
      }

      // Ensure user_handling row exists for login
      try {
        await upsertUserHandling(_supabase, username, 'admin', password);
      } catch (e) {
        debugPrint('upsertUserHandling failed after admin insert: $e');
      }

      return;
    } catch (e, st) {
      debugPrint('addAdmin error: $e\n$st');
      throw Exception('Failed to add admin: $e');
    }
  }

  Future<void> updateAdmin(String id, Admin admin) async {
    try {
      // Resolve actor username (must be someone with permission e.g., super_admin)
      final actor = await _resolveCurrentUsername();

      if (actor.isEmpty) {
        debugPrint(
          'updateAdmin: no authenticated actor available; p_updated_by will be empty',
        );
      }

      final pFacultyId =
          (admin.facultyId != null && admin.facultyId!.trim().isNotEmpty)
          ? admin.facultyId!.trim()
          : null;

      final params = {
        'p_username': admin.username ?? '',
        'p_full_name': admin.fullName ?? '',
        'p_password': admin.password ?? '',
        'p_faculty_id': pFacultyId,
        'p_updated_by': actor,
      };

      debugPrint('update_admin params: $params');
      // Update admins table directly and sync user_handling
      try {
        // Get existing username before update
        final existing = await _supabase
            .from('admins')
            .select('username')
            .eq('id', id)
            .maybeSingle();
        final oldUsername = (existing != null && existing['username'] != null)
            ? existing['username'].toString()
            : '';

        // Update admins row by id but avoid changing username here to prevent
        // FK violations. We'll handle username changes separately below.
        final updateData = admin.toJson();
        updateData.remove('id');
        // remove username from initial update so FK is not enforced mid-update
        updateData.remove('username');

        await _supabase.from('admins').update(updateData).eq('id', id).select();

        // Update user_handling: if username changed, ensure new user_handling exists
        final newUsername = (admin.username ?? '').trim();
        final newPassword = (admin.password ?? '').trim();

        if (newUsername.isNotEmpty && newUsername != oldUsername) {
          // Ensure target user_handling exists (insert or update)
          try {
            final uhId = await upsertUserHandling(
              _supabase,
              newUsername,
              'admin',
              newPassword,
            );
            if (uhId == null) {
              debugPrint('upsertUserHandling returned null for $newUsername');
            }
          } catch (e) {
            debugPrint(
              'upsertUserHandling failed for new admin username $newUsername: $e',
            );
          }

          // Now update admins.username to the newUsername
          try {
            await _supabase
                .from('admins')
                .update({'username': newUsername})
                .eq('id', id)
                .select();
          } catch (e) {
            debugPrint('Failed to set new username on admin record: $e');
          }

          // Optionally remove old user_handling if present
          if (oldUsername.isNotEmpty && oldUsername != newUsername) {
            try {
              final deleted = await safeDeleteUserHandling(
                _supabase,
                oldUsername,
              );
              if (!deleted) {
                debugPrint(
                  'Skipped deleting old user_handling $oldUsername because references exist',
                );
              }
            } catch (e) {
              debugPrint(
                'Failed to attempt safe delete of old user_handling $oldUsername: $e',
              );
            }
          }
        } else if (newUsername.isNotEmpty) {
          // username unchanged or was previously empty - ensure role/password are synced
          try {
            await upsertUserHandling(
              _supabase,
              newUsername,
              'admin',
              newPassword,
            );
          } catch (e) {
            debugPrint(
              'upsertUserHandling failed during admin update sync: $e',
            );
          }
        }

        return;
      } catch (e) {
        debugPrint('Fallback update admin direct failed: $e');
        rethrow;
      }
    } catch (e, st) {
      debugPrint('updateAdmin error: $e\n$st');
      throw Exception('Failed to update admin: $e');
    }
  }

  Future<void> deleteAdmin(String id) async {
    try {
      // Find admin username by id
      final existing = await _supabase
          .from('admins')
          .select('username')
          .eq('id', id)
          .maybeSingle();
      final username = (existing != null && existing['username'] != null)
          ? existing['username'].toString()
          : '';

      if (username.isEmpty) {
        throw Exception('Admin username not found for id $id');
      }

      final actor = await _resolveCurrentUsername();
      if (actor.isEmpty) {
        debugPrint(
          'deleteAdmin: no authenticated actor available; p_deleted_by will be empty',
        );
      }

      final delParams = {'p_username': username, 'p_deleted_by': actor};
      debugPrint('delete_admin params: $delParams');
      // Delete admin row directly and remove user_handling
      await _supabase.from('admins').delete().eq('id', id).select();
      if (username.isNotEmpty) {
        try {
          final deleted = await safeDeleteUserHandling(_supabase, username);
          if (!deleted) {
            debugPrint(
              'Skipped deleting linked user_handling $username because references exist',
            );
          }
        } catch (e) {
          debugPrint(
            'Failed to attempt safe delete of linked user_handling for username=$username: $e',
          );
        }
      }
      return;
    } catch (e, st) {
      debugPrint('deleteAdmin error: $e\n$st');
      throw Exception('Failed to delete admin: $e');
    }
  }
}
