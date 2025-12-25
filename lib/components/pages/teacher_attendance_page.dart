import '../../services/theme_controller.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../theme/teacher_theme.dart';
import '../../services/session.dart';

class Student {
  String username;
  String name;
  bool present;
  String? existingDocId;

  Student({
    required this.username,
    required this.name,
    this.present = false,
    this.existingDocId,
  });

  factory Student.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final username = (data['username'] ?? doc.id).toString();
    final name =
        (data['fullname'] ?? data['fullName'] ?? data['name'] ?? username)
            .toString();
    return Student(
      username: username,
      name: name,
      present: false,
      existingDocId: null,
    );
  }
}

class TeacherAttendancePage extends StatefulWidget {
  const TeacherAttendancePage({super.key});

  @override
  State<TeacherAttendancePage> createState() => _TeacherAttendancePageState();
}

class _TeacherAttendancePageState extends State<TeacherAttendancePage> {
  Widget _themeToggleButton() {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeMode,
      builder: (context, mode, _) {
        final isDark = mode == ThemeMode.dark;
        return IconButton(
          icon: Icon(
            isDark ? Icons.light_mode : Icons.dark_mode,
            color: isDark ? Colors.white : Colors.black87,
          ),
          tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
          onPressed: () {
            ThemeController.setThemeMode(
              isDark ? ThemeMode.light : ThemeMode.dark,
            );
          },
        );
      },
    );
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Dropdown selections
  String? department;
  String? className;
  String? subject;

  // Options
  List<String> departments = [];
  List<String> classes = [];
  List<String> subjects = [];

  // Roster
  List<Student> students = [];

  // UI state
  bool loadingDropdowns = false;
  bool loadingStudents = false;
  bool submitting = false;

  // Prefill guard
  bool _prefillAppliedForCurrentSelection = false;

  // Active session context
  String? currentSessionId; // qr_generation doc id
  String? currentSessionCode; // qr payload code (string)
  String?
  _noActiveSessionMessage; // If set, indicates why no session is available

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  // --------------------------
  // Helpers
  // --------------------------
  String? _stringFrom(dynamic v) => v?.toString();

  Timestamp? _parseTimestampField(dynamic tsField) {
    if (tsField == null) return null;
    if (tsField is Timestamp) return tsField;
    if (tsField is Map && tsField['seconds'] != null) {
      try {
        final sec = int.parse(tsField['seconds'].toString());
        final nanos =
            int.tryParse((tsField['nanoseconds'] ?? '0').toString()) ?? 0;
        return Timestamp(sec, nanos);
      } catch (_) {}
    }
    return null;
  }

  String _normalize(String? s) => (s ?? '').toString().trim().toLowerCase();
  String _alnum(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  bool _looseNameMatch(String? a, String? b) {
    final na = _normalize(a);
    final nb = _normalize(b);
    if (na.isEmpty || nb.isEmpty) return false;
    if (na == nb) return true;
    if (na.contains(nb) || nb.contains(na)) return true;
    final ra = _alnum(na);
    final rb = _alnum(nb);
    return ra == rb || ra.contains(rb) || rb.contains(ra);
  }

  Future<String> _getCurrentTeacher() async {
    return Session.username?.toString() ?? '';
  }

  // --------------------------
  // Dropdown loaders
  // --------------------------
  Future<void> _loadDepartments() async {
    setState(() {
      loadingDropdowns = true;
    });
    try {
      final teacher = await _getCurrentTeacher();
      final qs = await _firestore.collection('timetables').get();
      final filtered = qs.docs.where((d) {
        final data = d.data();
        final gm = data['grid_meta'];
        if (gm is List) {
          for (final gmItem in gm) {
            if (gmItem is Map && gmItem['cells'] is List) {
              for (final cell in gmItem['cells']) {
                if (cell is Map) {
                  final lec = (cell['lecturer'] ?? '').toString().toLowerCase();
                  if (lec.contains(teacher.toLowerCase())) return true;
                } else if (cell is String) {
                  if (cell.toLowerCase().contains(teacher.toLowerCase())) {
                    return true;
                  }
                }
              }
            }
          }
        }
        final grid = data['grid'];
        if (grid is List) {
          for (final row in grid) {
            if (row is Map && row['cells'] is List) {
              for (final cell in row['cells']) {
                if (cell is String &&
                    cell.toLowerCase().contains(teacher.toLowerCase())) {
                  return true;
                }
                if (cell is Map) {
                  final lec = (cell['lecturer'] ?? '').toString().toLowerCase();
                  if (lec.contains(teacher.toLowerCase())) return true;
                }
              }
            }
          }
        }
        return false;
      }).toList();

      final fetchedDepts = filtered
          .map((d) => _stringFrom(d.data()['department']) ?? '')
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();

      setState(() {
        departments = fetchedDepts;
        department = null;
        classes = [];
        className = null;
        subjects = [];
        subject = null;
        students = [];
        _prefillAppliedForCurrentSelection = false;
        currentSessionId = null;
        currentSessionCode = null;
        _noActiveSessionMessage = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load departments: $e')));
    } finally {
      setState(() {
        loadingDropdowns = false;
      });
    }
  }

  Future<void> _loadClassesForDepartment(String dept) async {
    setState(() {
      classes = [];
      className = null;
      subjects = [];
      subject = null;
      students = [];
      _prefillAppliedForCurrentSelection = false;
      currentSessionId = null;
      currentSessionCode = null;
      _noActiveSessionMessage = null;
    });

    try {
      final qs = await _firestore
          .collection('timetables')
          .where('department', isEqualTo: dept)
          .get();
      final fetched = qs.docs
          .map((d) => _stringFrom(d.data()['className']) ?? '')
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();
      setState(() {
        classes = fetched;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load classes: $e')));
    }
  }

  Future<void> _loadSubjectsForClass(String cls) async {
    setState(() {
      subjects = [];
      subject = null;
      students = [];
      _prefillAppliedForCurrentSelection = false;
      currentSessionId = null;
      currentSessionCode = null;
      // legacy no-op placeholder removed
    });
    try {
      final qs = await _firestore
          .collection('timetables')
          .where('className', isEqualTo: cls)
          .get();
      final set = <String>{};
      for (final doc in qs.docs) {
        final gm = doc.data()['grid_meta'];
        if (gm is List) {
          for (final gmItem in gm) {
            if (gmItem is Map && gmItem['cells'] is List) {
              for (final cell in (gmItem['cells'] as List)) {
                if (cell is Map && cell['course'] != null) {
                  final c = cell['course'].toString().trim();
                  if (c.isNotEmpty) set.add(c);
                } else if (cell is String) {
                  final c = cell.toString().trim();
                  if (c.isNotEmpty) set.add(c);
                }
              }
            }
          }
        }
      }
      setState(() {
        subjects = set.toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load subjects: $e')));
    }
  }

  // --------------------------
  // Main: fetch roster for selection only if active session exists AND is in-window
  // --------------------------
  Future<void> _fetchStudentsForSelection({bool forceRefresh = false}) async {
    if (department == null || className == null || subject == null) return;

    if (_prefillAppliedForCurrentSelection && !forceRefresh) return;

    setState(() {
      loadingStudents = true;
      students = [];
      currentSessionId = null;
      currentSessionCode = null;
      _noActiveSessionMessage = null;
    });

    try {
      // 1) Find active sessions for this selection
      // --------------- session selection (robust, UTC-aware) ---------------
      List<QueryDocumentSnapshot<Map<String, dynamic>>> sessionDocs = [];
      try {
        final sessionQ = await _firestore
            .collection('qr_generation')
            .where('subject', isEqualTo: subject)
            .where('className', isEqualTo: className)
            .where('department', isEqualTo: department)
            .where('active', isEqualTo: true)
            .get();
        sessionDocs = sessionQ.docs;
      } catch (_) {
        sessionDocs = [];
      }

      // Only accept a session whose period window includes now (UTC comparison).
      QueryDocumentSnapshot<Map<String, dynamic>>? pickedSession;
      if (sessionDocs.isNotEmpty) {
        final nowUtc = DateTime.now().toUtc();
        for (final sd in sessionDocs) {
          final data = sd.data();

          // Try multiple timestamp shapes:
          DateTime? startUtc;
          DateTime? endUtc;

          // 1) Firestore Timestamp object fields
          final startTs = _parseTimestampField(data['period_starts_at']);
          final endTs = _parseTimestampField(data['period_ends_at']);
          if (startTs != null) startUtc = startTs.toDate().toUtc();
          if (endTs != null) endUtc = endTs.toDate().toUtc();

          // 2) Fall back to ISO string fields if present (e.g. created_at_iso or period_starts_at stored as string)
          if (startUtc == null) {
            final sIso = _stringFrom(
              data['period_starts_at'] ??
                  data['created_at_iso'] ??
                  data['period_starts_at_iso'],
            );
            if (sIso != null) {
              try {
                startUtc = DateTime.parse(sIso).toUtc();
              } catch (_) {}
            }
          }
          if (endUtc == null) {
            final eIso = _stringFrom(
              data['period_ends_at'] ??
                  data['expires_at'] ??
                  data['period_ends_at_iso'],
            );
            if (eIso != null) {
              try {
                endUtc = DateTime.parse(eIso).toUtc();
              } catch (_) {}
            }
          }

          // If we have both start and end, require now to be inside [start, end)
          if (startUtc != null && endUtc != null) {
            if (!nowUtc.isBefore(startUtc) && nowUtc.isBefore(endUtc)) {
              pickedSession = sd;
              break;
            } else {
              // not in-window -> ignore this session
              continue;
            }
          }

          // If timestamps are missing or unparsable, don't auto-pick the session.
          // (This avoids accidentally accepting expired or malformed sessions.)
        }
      }

      // If no in-window session found, show message and stop (do NOT fetch students)
      if (pickedSession == null) {
        setState(() {
          _noActiveSessionMessage =
              'No active QR session for the selected class/subject (or session has ended).';
          students = [];
          _prefillAppliedForCurrentSelection = false;
        });
        return;
      }

      // We have a valid in-window session
      final pdata = pickedSession.data();
      currentSessionId = pickedSession.id;
      currentSessionCode = _stringFrom(pdata['code']);
      _noActiveSessionMessage = null;

      // 2) Fetch students (same robust approach as before) ------------------------------------------------
      final candidateVariants = <String>{
        className!.trim(),
        className!.trim().toUpperCase(),
        className!.trim().toLowerCase(),
        className!.replaceAll(' ', ''),
        className!.replaceAll(RegExp(r'[^A-Za-z0-9]'), ''),
      }..removeWhere((e) => e.isEmpty);

      final fetchedStudentDocs =
          <QueryDocumentSnapshot<Map<String, dynamic>>>[];

      final existingIds = <String>{};

      // Try students.className variants
      for (final v in candidateVariants) {
        final q = await _firestore
            .collection('students')
            .where('className', isEqualTo: v)
            .get();
        for (final d in q.docs) {
          if (!existingIds.contains(d.id)) {
            fetchedStudentDocs.add(d);
            existingIds.add(d.id);
          }
        }
      }

      // Try class_name
      if (fetchedStudentDocs.isEmpty) {
        final q2 = await _firestore
            .collection('students')
            .where('class_name', isEqualTo: className)
            .get();
        for (final d in q2.docs) {
          if (!existingIds.contains(d.id)) {
            fetchedStudentDocs.add(d);
            existingIds.add(d.id);
          }
        }
      }

      // Try classes -> students by class_ref with dept-aware loose matching
      if (fetchedStudentDocs.isEmpty) {
        final classDocIds = <String>{};
        for (final v in candidateVariants) {
          try {
            final cQ = await _firestore
                .collection('classes')
                .where('className', isEqualTo: v)
                .get();
            for (final cd in cQ.docs) {
              classDocIds.add(cd.id);
            }
          } catch (_) {}
        }
        if (classDocIds.isEmpty) {
          try {
            final classesInDept = await _firestore
                .collection('classes')
                .where('department', isEqualTo: department)
                .get();
            for (final cd in classesInDept.docs) {
              final cname = _stringFrom(cd.data()['className']) ?? '';
              if (_looseNameMatch(cname, className)) classDocIds.add(cd.id);
            }
          } catch (_) {}
        }

        for (final cid in classDocIds) {
          try {
            final sQ = await _firestore
                .collection('students')
                .where('class_ref', isEqualTo: cid)
                .get();
            for (final d in sQ.docs) {
              if (!existingIds.contains(d.id)) {
                fetchedStudentDocs.add(d);
                existingIds.add(d.id);
              }
            }
          } catch (_) {}
        }
      }

      // Department fallback
      if (fetchedStudentDocs.isEmpty) {
        try {
          final deptQ = await _firestore
              .collection('students')
              .where('department', isEqualTo: department)
              .limit(2000)
              .get();
          for (final d in deptQ.docs) {
            final data = d.data();
            final sClass = _stringFrom(
              data['className'] ?? data['class_name'] ?? data['class'] ?? '',
            );
            final sClassRef = _stringFrom(
              data['class_ref'] ?? data['classRef'] ?? data['class_id'] ?? '',
            );
            if (_looseNameMatch(sClass, className) ||
                (sClassRef != null && sClassRef.contains(className!))) {
              if (!existingIds.contains(d.id)) {
                fetchedStudentDocs.add(d);
                existingIds.add(d.id);
              }
            }
          }
        } catch (_) {}
      }

      // Broad scan last resort
      if (fetchedStudentDocs.isEmpty) {
        try {
          final all = await _firestore.collection('students').limit(2000).get();
          for (final d in all.docs) {
            final data = d.data();
            final sClass = _stringFrom(
              data['className'] ?? data['class_name'] ?? data['class'] ?? '',
            );
            final sClassRef = _stringFrom(
              data['class_ref'] ?? data['classRef'] ?? data['class_id'] ?? '',
            );
            if (_looseNameMatch(sClass, className) ||
                (sClassRef != null && sClassRef.contains(className!))) {
              if (!existingIds.contains(d.id)) {
                fetchedStudentDocs.add(d);
                existingIds.add(d.id);
              }
            }
          }
        } catch (_) {}
      }

      final roster = <Student>[];
      final rosterUsernames = <String>{};
      for (final d in fetchedStudentDocs) {
        final s = Student.fromDoc(d);
        roster.add(s);
        rosterUsernames.add(s.username);
      }

      // --------------------------
      // Prefill attendance_records for the current session ONLY
      // --------------------------
      QuerySnapshot<Map<String, dynamic>> attendanceQuery;
      try {
        attendanceQuery = await _firestore
            .collection('attendance_records')
            .where('session_id', isEqualTo: currentSessionId)
            .where('subject', isEqualTo: subject)
            .get();
      } catch (e) {
        attendanceQuery = await _firestore
            .collection('attendance_records')
            .where('subject', isEqualTo: subject)
            .limit(2000)
            .get();
      }

      final attendanceByUser =
          <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
      for (final doc in attendanceQuery.docs) {
        final data = doc.data();
        final uname = _stringFrom(data['username']);
        if (uname == null || uname.isEmpty) continue;

        final sid =
            _stringFrom(data['session_id']) ?? _stringFrom(data['sessionId']);
        final code = _stringFrom(data['code']);
        if (sid == currentSessionId ||
            (currentSessionCode != null && currentSessionCode == code)) {
          attendanceByUser[uname] = doc;
        }
      }

      // Append scanned-only students (mark present)
      final missingFromRoster = attendanceByUser.keys
          .where((u) => !rosterUsernames.contains(u))
          .toList();
      for (final uname in missingFromRoster) {
        try {
          final q = await _firestore
              .collection('students')
              .where('username', isEqualTo: uname)
              .limit(1)
              .get();
          if (q.docs.isNotEmpty) {
            final s = Student.fromDoc(q.docs.first);
            s.present = true;
            s.existingDocId = attendanceByUser[uname]?.id;
            roster.add(s);
            rosterUsernames.add(s.username);
          } else {
            roster.add(
              Student(
                username: uname,
                name: uname,
                present: true,
                existingDocId: attendanceByUser[uname]?.id,
              ),
            );
            rosterUsernames.add(uname);
          }
        } catch (_) {}
      }

      // Mark present for roster entries
      for (final s in roster) {
        if (attendanceByUser.containsKey(s.username)) {
          s.present = true;
          s.existingDocId = attendanceByUser[s.username]?.id;
        }
      }

      setState(() {
        students = roster;
        _prefillAppliedForCurrentSelection = true;
        _noActiveSessionMessage = null;
      });
    } catch (e) {
      setState(() {
        _noActiveSessionMessage = 'Failed to load students: $e';
        students = [];
      });
    } finally {
      setState(() {
        loadingStudents = false;
      });
    }
  }

  // --------------------------
  // Submit (session-aware) with final active-session re-check
  // --------------------------
  Future<void> _submitAttendance() async {
    if (department == null || className == null || subject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select department, class and subject.'),
        ),
      );
      return;
    }

    // Re-check: ensure there is an active in-window session for the selected department/class/subject
    try {
      DocumentSnapshot<Map<String, dynamic>>? sessionDoc;

      // If we already have currentSessionId, verify the doc is still active and in-window
      if (currentSessionId != null) {
        final docSnap = await _firestore
            .collection('qr_generation')
            .doc(currentSessionId)
            .get();
        if (docSnap.exists) {
          final data = docSnap.data();
          if (data != null) {
            final activeFlag = data['active'] == true;
            final startTs = _parseTimestampField(data['period_starts_at']);
            final endTs = _parseTimestampField(data['period_ends_at']);
            final nowUtc = DateTime.now().toUtc();
            DateTime? startUtc = startTs?.toDate().toUtc();
            DateTime? endUtc = endTs?.toDate().toUtc();

            // also try ISO fields if timestamps missing
            if (startUtc == null) {
              final sIso = _stringFrom(
                data['period_starts_at'] ?? data['created_at_iso'],
              );
              if (sIso != null) {
                try {
                  startUtc = DateTime.parse(sIso).toUtc();
                } catch (_) {}
              }
            }
            if (endUtc == null) {
              final eIso = _stringFrom(
                data['period_ends_at'] ??
                    data['expires_at'] ??
                    data['period_ends_at_iso'],
              );
              if (eIso != null) {
                try {
                  endUtc = DateTime.parse(eIso).toUtc();
                } catch (_) {}
              }
            }

            if (activeFlag &&
                startUtc != null &&
                endUtc != null &&
                !nowUtc.isBefore(startUtc) &&
                nowUtc.isBefore(endUtc)) {
              sessionDoc = docSnap;
            } else {
              // session invalid or ended
              sessionDoc = null;
            }
          }
        } else {
          sessionDoc = null;
        }
      }

      // If no valid session found by id, attempt to find any currently in-window session for the selection
      if (sessionDoc == null) {
        final sQ = await _firestore
            .collection('qr_generation')
            .where('subject', isEqualTo: subject)
            .where('className', isEqualTo: className)
            .where('department', isEqualTo: department)
            .where('active', isEqualTo: true)
            .get();

        final nowUtc = DateTime.now().toUtc();
        for (final sd in sQ.docs) {
          final data = sd.data();
          DateTime? startUtc;
          DateTime? endUtc;
          final startTs = _parseTimestampField(data['period_starts_at']);
          final endTs = _parseTimestampField(data['period_ends_at']);
          if (startTs != null) startUtc = startTs.toDate().toUtc();
          if (endTs != null) endUtc = endTs.toDate().toUtc();

          // fallback to ISO strings
          if (startUtc == null) {
            final sIso = _stringFrom(
              data['period_starts_at'] ?? data['created_at_iso'],
            );
            if (sIso != null) {
              try {
                startUtc = DateTime.parse(sIso).toUtc();
              } catch (_) {}
            }
          }
          if (endUtc == null) {
            final eIso = _stringFrom(
              data['period_ends_at'] ??
                  data['expires_at'] ??
                  data['period_ends_at_iso'],
            );
            if (eIso != null) {
              try {
                endUtc = DateTime.parse(eIso).toUtc();
              } catch (_) {}
            }
          }

          if (startUtc != null &&
              endUtc != null &&
              !nowUtc.isBefore(startUtc) &&
              nowUtc.isBefore(endUtc)) {
            sessionDoc = sd;
            break;
          }
        }
      }

      if (sessionDoc == null) {
        // No in-window session: block submit
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No active QR session for the selected class/subject (or session has ended). Submission blocked.',
            ),
          ),
        );
        return;
      }

      // If we reach here, we have a valid in-window session — ensure currentSessionId/code reflect it
      currentSessionId = sessionDoc.id;
      currentSessionCode = _stringFrom(sessionDoc.data()?['code']);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to validate active session: $e')),
      );
      return;
    }

    // Proceed to confirmation dialog (same as before)
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm submit'),
        content: const Text(
          'This will create/update/delete attendance records for the current session only. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() {
      submitting = true;
    });

    try {
      final teacher = await _getCurrentTeacher();
      final batch = _firestore.batch();

      for (final s in students) {
        final q = await _firestore
            .collection('attendance_records')
            .where('username', isEqualTo: s.username)
            .where('session_id', isEqualTo: currentSessionId)
            .get();

        if (s.present) {
          if (q.docs.isNotEmpty) {
            final ref = q.docs.first.reference;
            batch.update(ref, {
              'present': true,
              'teacher': teacher,
              'department': department,
              'className': className,
              'subject': subject,
              'updatedAt': FieldValue.serverTimestamp(),
              'source': 'manual',
            });
          } else {
            final ref = _firestore.collection('attendance_records').doc();
            batch.set(ref, {
              'username': s.username,
              'subject': subject,
              'department': department,
              'className': className,
              'teacher': teacher,
              'present': true,
              'scannedAt': FieldValue.serverTimestamp(),
              'source': 'manual',
              'session_id': currentSessionId,
              'code': currentSessionCode,
            });
          }
        } else {
          for (final doc in q.docs) {
            batch.delete(doc.reference);
          }
        }
      }

      await batch.commit();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attendance submitted successfully')),
      );

      _prefillAppliedForCurrentSelection = false;
      await _fetchStudentsForSelection(forceRefresh: true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit attendance: $e')),
      );
    } finally {
      setState(() {
        submitting = false;
      });
    }
  }

  // --------------------------
  // UI
  // --------------------------
  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<TeacherThemeColors>();
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Attendance',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Theme.of(
                context,
              ).extension<TeacherThemeColors>()?.textPrimary,
            ),
          ),
          const SizedBox(height: 18),

          Wrap(
            spacing: 14,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _styledDropdown(
                value: department,
                items: departments,
                hint: 'Select Department',
                onChanged: (v) {
                  setState(() {
                    department = v;
                    classes = [];
                    className = null;
                    subjects = [];
                    subject = null;
                    students = [];
                    _prefillAppliedForCurrentSelection = false;
                    currentSessionId = null;
                    currentSessionCode = null;
                    _noActiveSessionMessage = null;
                  });
                  if (v != null) _loadClassesForDepartment(v);
                },
              ),
              _styledDropdown(
                value: className,
                items: classes,
                hint: 'Select Class',
                onChanged: (v) {
                  setState(() {
                    className = v;
                    subjects = [];
                    subject = null;
                    students = [];
                    _prefillAppliedForCurrentSelection = false;
                    currentSessionId = null;
                    currentSessionCode = null;
                    _noActiveSessionMessage = null;
                  });
                  if (v != null) _loadSubjectsForClass(v);
                },
              ),
              _styledDropdown(
                value: subject,
                items: subjects,
                hint: 'Select Subject',
                onChanged: (v) {
                  setState(() {
                    subject = v;
                    students = [];
                    _prefillAppliedForCurrentSelection = false;
                    currentSessionId = null;
                    currentSessionCode = null;
                    _noActiveSessionMessage = null;
                  });
                  if (v != null) _fetchStudentsForSelection(forceRefresh: true);
                },
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Header
          Container(
            color: Theme.of(context).colorScheme.surface,
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 1,
                  child: Text(
                    'No',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'username',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Text(
                    'full Name',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Status',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Body: either message (no session) or roster
          Expanded(
            child: loadingStudents
                ? const Center(child: CircularProgressIndicator())
                : (_noActiveSessionMessage != null)
                ? Center(
                    child: Text(
                      _noActiveSessionMessage!,
                      style: const TextStyle(fontSize: 16),
                    ),
                  )
                : students.isEmpty
                ? Center(
                    child: Text(
                      'No students found.',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: students.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final s = students[index];
                      // Render only the student row here, not the header or theme toggle
                      // ...existing student row rendering code...
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 16,
                        ),
                        child: Row(
                          children: [
                            Expanded(flex: 1, child: Text('${index + 1}')),
                            Expanded(flex: 2, child: Text(s.username)),
                            Expanded(flex: 4, child: Text(s.name)),
                            Expanded(
                              flex: 2,
                              child: Switch(
                                value: s.present,
                                onChanged: (val) {
                                  setState(() => s.present = val);
                                },
                                activeColor: Colors.green,
                                inactiveTrackColor: Colors.red[200],
                                // Always use a visible thumb color
                                thumbColor:
                                    MaterialStateProperty.resolveWith<Color>((
                                      states,
                                    ) {
                                      if (states.contains(
                                        MaterialState.selected,
                                      )) {
                                        return Colors.white;
                                      }
                                      return Colors.white;
                                    }),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          const SizedBox(height: 12),

          Align(
            alignment: Alignment.bottomRight,
            child: ElevatedButton(
              onPressed:
                  (department != null &&
                      className != null &&
                      subject != null &&
                      students.isNotEmpty &&
                      !submitting &&
                      currentSessionId != null)
                  ? _submitAttendance
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    (department != null &&
                        className != null &&
                        subject != null &&
                        students.isNotEmpty &&
                        !submitting &&
                        currentSessionId != null)
                    ? Colors.green
                    : Colors.grey,
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              child: submitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text(
                      'Submit',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _styledDropdown({
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required String hint,
    bool isLoading = false,
  }) {
    final palette = Theme.of(context).extension<TeacherThemeColors>();
    final hintStyle = TextStyle(color: palette?.textSecondary);
    final itemStyle = TextStyle(color: palette?.textPrimary);
    final borderColor = palette?.border ?? const Color(0xFFC7BECF);
    return Container(
      constraints: const BoxConstraints(minWidth: 130, maxWidth: 240),
      child: InputDecorator(
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 5,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: borderColor, width: 1.1),
          ),
          isDense: true,
          filled: true,
          fillColor:
              palette?.inputFill ?? Theme.of(context).colorScheme.surface,
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String?>(
            isExpanded: true,
            value: value,
            hint: isLoading
                ? Text('Loading...', style: hintStyle)
                : Text(hint, style: hintStyle),
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text(hint, style: hintStyle),
              ),
              ...items.map(
                (e) => DropdownMenuItem<String?>(
                  value: e,
                  child: Text(e, style: itemStyle),
                ),
              ),
            ],
            onChanged: onChanged,
            dropdownColor:
                palette?.surface ?? Theme.of(context).colorScheme.surface,
            iconEnabledColor:
                palette?.iconColor ?? Theme.of(context).iconTheme.color,
          ),
        ),
      ),
    );
  }
}
