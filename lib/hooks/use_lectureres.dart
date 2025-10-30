import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'use_user_handling.dart';

class Teacher {
  final String id;
  final String? username;
  final String? teacherName;
  final String? password;
  final DateTime? createdAt;
  final String? facultyId;

  Teacher({
    required this.id,
    this.username,
    this.teacherName,
    this.password,
    this.createdAt,
    this.facultyId,
  });

  factory Teacher.fromJson(Map<String, dynamic> json) {
    return Teacher(
      id: json['id'] as String,
      username: json['username'] as String?,
      teacherName: json['teacher_name'] as String?,
      password: json['password'] as String?,
      facultyId: json['faculty_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'teacher_name': teacherName,
      'password': password,
      'faculty_id': facultyId,
      'created_at': createdAt?.toIso8601String(),
    };
  }
}

class UseTeachers {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ================================
  // 🔹 FETCH ALL TEACHERS
  // ================================
  Future<List<Teacher>> fetchTeachers() async {
    try {
      final response = await _supabase
          .from('teachers')
          .select()
          .order('created_at', ascending: false);
      print('Fetched teachers: $response');

      return (response as List)
          .map((e) => Teacher.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error fetching teachers: $e');
      return [];
    }
  }

  // ================================
  // 🔹 ADD TEACHER (RPC)
  // ================================
  Future<Teacher?> addTeacher(
    Teacher teacher, {
    String? facultyId,
    String? createdBy,
  }) async {
    // Insert directly into the teachers table and create/upsert user_handling
    try {
      final insertData = <String, dynamic>{
        'teacher_name': teacher.teacherName,
        'faculty_id': facultyId ?? teacher.facultyId,
        'created_at': DateTime.now().toIso8601String(),
      };

      // Ensure user_handling row exists before creating teacher when username provided
      final uname = (teacher.username ?? '').toString().trim();
      if (uname.isNotEmpty) {
        try {
          await upsertUserHandling(
            _supabase,
            uname,
            'teacher',
            teacher.password,
          );
          insertData['username'] = uname;
          // Also write the password to the teachers row if provided
          if (teacher.password != null && teacher.password!.isNotEmpty) {
            insertData['password'] = teacher.password;
          }
        } catch (e) {
          debugPrint('upsertUserHandling before teacher insert failed: $e');
          // If upsert failed, propagate to avoid FK violation
          rethrow;
        }
      } else {
        insertData['username'] = null;
        insertData['password'] = teacher.password;
      }

      final tmpRaw = await _supabase
          .from('teachers')
          .insert(insertData)
          .select()
          .limit(1);

      Map<String, dynamic>? insertedRow;
      if ((tmpRaw as List).isNotEmpty) {
        insertedRow = Map<String, dynamic>.from(tmpRaw[0] as Map);
      }

      if (insertedRow != null) {
        // Ensure user_handling has an account
        try {
          await upsertUserHandling(
            _supabase,
            (teacher.username ?? '').trim(),
            'teacher',
            teacher.password,
          );
        } catch (e) {
          debugPrint('upsertUserHandling failed after teacher insert: $e');
        }

        return Teacher.fromJson(insertedRow);
      }

      return null;
    } catch (e) {
      debugPrint('Error adding teacher: $e');
      return null;
    }
  }

  // ================================
  // 🔹 UPDATE TEACHER
  // ================================
  Future<void> updateTeacher(
    String id,
    Teacher teacher, {
    String? updatedBy,
  }) async {
    // Determine who is performing the update. Prefer the explicit `updatedBy`
    // parameter; otherwise try to resolve the currently authenticated user's
    // username via the `user_handling` table (auth_uid -> username), falling
    // back to email or auth uid when necessary.
    String updater = '';
    if (updatedBy != null && updatedBy.isNotEmpty) {
      updater = updatedBy;
    } else {
      final current = _supabase.auth.currentUser;
      if (current == null) {
        updater = '';
      } else {
        try {
          final uh = await _supabase
              .from('user_handling')
              .select('username')
              .eq('auth_uid', current.id)
              .maybeSingle();
          if (uh != null && uh['username'] != null) {
            updater = uh['username'].toString();
          } else if (current.email != null && current.email!.isNotEmpty) {
            updater = current.email!;
          } else {
            updater = current.id;
          }
        } catch (e) {
          // fallback to email or auth id if mapping fails
          updater = current.email ?? current.id;
        }
      }
    }
    try {
      final data = teacher.toJson();
      data.remove('id');
      // Avoid updating the username directly to prevent FK constraint failures
      // when the corresponding user_handling row does not yet exist. We'll
      // synchronize username/password in user_handling after ensuring its row
      // exists and then set the teachers.username separately.
      data.remove('username');
      // Also avoid storing password in teachers update path; keep password
      // authoritative in user_handling when possible.
      data.remove('password');

      // Get the old username first
      final existing = await _supabase
          .from('teachers')
          .select('username')
          .eq('id', id)
          .maybeSingle();

      final oldUsername = (existing != null && existing['username'] != null)
          ? existing['username'].toString().trim()
          : '';

      // Prefer server-side RPC which can handle linked user_handling updates.
      // Call the RPC with parameter names matching the Postgres function
      // signature (username-based). The DB function returns void, so do not
      // call .select() here. If the RPC call fails, fall back to client-side
      // updates below.
      // Update teacher info in teachers table directly
      // Determine new username/password for use below
      final newUsername = (teacher.username ?? '').trim();
      final newPassword = (teacher.password ?? '').trim();

      // First update the teachers row WITHOUT changing the username to avoid
      // triggering DB-side behavior that could create duplicates when an
      // upsert on user_handling inserts triggers other tables. We'll handle
      // username changes separately after ensuring user_handling exists.
      final resp = await _supabase.from('teachers').update(data).eq('id', id);
      debugPrint('Update teacher response: $resp (updated_by=$updater)');

      // Handle username/password synchronization in user_handling
      if (oldUsername.isNotEmpty) {
        // Try to update existing user_handling that matches the old username
        final updateData = <String, dynamic>{
          if (newPassword.isNotEmpty) 'password': newPassword,
          'role': 'teacher',
        };

        if (newUsername.isNotEmpty && newUsername != oldUsername) {
          // Ensure target user_handling exists first (insert or update)
          try {
            await upsertUserHandling(
              _supabase,
              newUsername,
              'teacher',
              newPassword,
            );
          } catch (e) {
            debugPrint('upsertUserHandling for new username failed: $e');
          }

          // Now update teachers.username to the newUsername
          try {
            await _supabase
                .from('teachers')
                .update({'username': newUsername})
                .eq('id', id)
                .select();
          } catch (e) {
            debugPrint('Failed to set new username on teacher record: $e');
          }

          // Also update the teacher's stored password column (if present)
          if (newPassword.isNotEmpty) {
            try {
              await _supabase
                  .from('teachers')
                  .update({'password': newPassword})
                  .eq('id', id)
                  .select();
            } catch (e) {
              debugPrint('Failed to update teacher password field: $e');
            }
          }

          // Remove old user_handling only if it's safe (no remaining references)
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
        } else {
          // username unchanged — just update password/role on existing user_handling
          try {
            final updated = await _supabase
                .from('user_handling')
                .update(updateData)
                .eq('username', oldUsername)
                .select();
            if (updated.isEmpty) {
              // If update returned no rows, fallback to upsert newUsername
              if (newUsername.isNotEmpty) {
                try {
                  await upsertUserHandling(
                    _supabase,
                    newUsername,
                    'teacher',
                    newPassword,
                  );
                } catch (e) {
                  debugPrint(
                    'Fallback upsertUserHandling failed for $newUsername: $e',
                  );
                }
              }
            }
            // Mirror password change into teachers table for UI consistency
            if (newPassword.isNotEmpty) {
              try {
                await _supabase
                    .from('teachers')
                    .update({'password': newPassword})
                    .eq('id', id)
                    .select();
              } catch (e) {
                debugPrint(
                  'Failed to mirror password change to teachers table: $e',
                );
              }
            }
          } catch (e) {
            debugPrint(
              'Failed to update user_handling by old username $oldUsername: $e',
            );
          }
        }
      } else if (newUsername.isNotEmpty) {
        // Teacher previously had no username; ensure user_handling exists and set it
        try {
          await upsertUserHandling(
            _supabase,
            newUsername,
            'teacher',
            newPassword,
          );
          await _supabase
              .from('teachers')
              .update({'username': newUsername})
              .eq('id', id)
              .select();

          if (newPassword.isNotEmpty) {
            try {
              await _supabase
                  .from('teachers')
                  .update({'password': newPassword})
                  .eq('id', id)
                  .select();
            } catch (e) {
              debugPrint(
                'Failed to set password on newly-updated teacher record: $e',
              );
            }
          }
        } catch (e) {
          debugPrint('Failed to create/set user_handling for teacher: $e');
        }
      }
    } catch (e) {
      debugPrint('Error updating teacher: $e');
    }
  }

  // ================================
  // 🔹 DELETE TEACHER
  // ================================
  Future<void> deleteTeacher(String id) async {
    try {
      // Fetch teacher info before deleting
      final teacher = await _supabase
          .from('teachers')
          .select('username')
          .eq('id', id)
          .maybeSingle();

      final username = teacher?['username'] as String?;

      // Delete teacher from teachers table
      final resp = await _supabase
          .from('teachers')
          .delete()
          .eq('id', id)
          .select();
      print('Delete teacher response: $resp');

      // Delete linked user_handling record (safely) — only if no other references exist
      if (username != null && username.isNotEmpty) {
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
    } catch (e) {
      debugPrint('Error deleting teacher: $e');
    }
  }

  /// Subscribe to realtime changes for the `teachers` table.
  /// Returns a broadcast stream of List<Map<String,dynamic>> events.
  Stream<List<Map<String, dynamic>>> subscribeTeachers() {
    final controller = StreamController<List<Map<String, dynamic>>>.broadcast();
    StreamSubscription<dynamic>? supaSub;
    var attempt = 0;

    Future<void> startSubscription() async {
      try {
        final raw =
            (_supabase
                    .from('teachers')
                    .stream(primaryKey: ['id'])
                    .order('created_at', ascending: false))
                as Stream<dynamic>;

        runZonedGuarded(
          () {
            supaSub = raw.listen(
              (event) {
                try {
                  List<Map<String, dynamic>> out;
                  if (event == null) {
                    out = <Map<String, dynamic>>[];
                  } else if (event is List) {
                    out = (event)
                        .map((e) => Map<String, dynamic>.from(e))
                        .toList();
                  } else {
                    try {
                      final tmp = List.from(event);
                      out = tmp
                          .map((e) => Map<String, dynamic>.from(e))
                          .toList();
                    } catch (inner) {
                      if (event is Map) {
                        out = [Map<String, dynamic>.from(event)];
                      } else {
                        rethrow;
                      }
                    }
                  }
                  if (!controller.isClosed) controller.add(out);
                } catch (e, st) {
                  debugPrint(
                    'subscribeTeachers: failed to coerce event: $e\n$st',
                  );
                }
              },
              onError: (err, st) async {
                debugPrint('subscribeTeachers realtime error: $err\n$st');
                try {
                  await supaSub?.cancel();
                } catch (_) {}
                if (!controller.isClosed) {
                  attempt = (attempt + 1).clamp(1, 6);
                  final delaySec = 1 << (attempt > 5 ? 5 : attempt);
                  await Future.delayed(Duration(seconds: delaySec));
                  if (!controller.isClosed) startSubscription();
                }
              },
              onDone: () async {
                debugPrint('subscribeTeachers: underlying stream done');
                if (!controller.isClosed) {
                  attempt = 0;
                  await Future.delayed(const Duration(seconds: 1));
                  if (!controller.isClosed) startSubscription();
                }
              },
            );
          },
          (err, st) async {
            debugPrint('subscribeTeachers zone error: $err\n$st');
            try {
              await supaSub?.cancel();
            } catch (_) {}
            if (!controller.isClosed) {
              attempt = (attempt + 1).clamp(1, 6);
              final delaySec = 1 << (attempt > 5 ? 5 : attempt);
              await Future.delayed(Duration(seconds: delaySec));
              if (!controller.isClosed) startSubscription();
            }
          },
        );
      } catch (e, st) {
        debugPrint('subscribeTeachers failed to start: $e\n$st');
        if (!controller.isClosed) {
          attempt = (attempt + 1).clamp(1, 6);
          final delaySec = 1 << (attempt > 5 ? 5 : attempt);
          await Future.delayed(Duration(seconds: delaySec));
          if (!controller.isClosed) startSubscription();
        }
      }
    }

    controller.onListen = () {
      attempt = 0;
      startSubscription();
    };

    controller.onCancel = () async {
      try {
        await supaSub?.cancel();
      } catch (_) {}
      try {
        if (!controller.isClosed) await controller.close();
      } catch (_) {}
    };

    return controller.stream;
  }
}
