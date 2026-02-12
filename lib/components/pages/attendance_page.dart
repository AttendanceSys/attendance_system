import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../theme/super_admin_theme.dart';
import 'package:attendance_system/services/session.dart';
import 'student_details_panel.dart';
import '../cards/searchBar.dart';

class AttendanceUnifiedPage extends StatefulWidget {
  const AttendanceUnifiedPage({super.key});

  @override
  State<AttendanceUnifiedPage> createState() => _AttendanceUnifiedPageState();
}

class _AttendanceUnifiedPageState extends State<AttendanceUnifiedPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Scroll controller for the page scrollbar
  final ScrollController _pageScrollController = ScrollController();

  // Data sources populated from Firestore
  List<String> departments = [];
  List<String> classesForDept = [];
  List<String> coursesForClass = [];
  List<String> teachersForDept = [];

  // Lookups to resolve ids from names for queries
  final Map<String, String> _deptNameToId = {};
  final Map<String, String> _classNameToId = {};
  final Map<String, String> _teacherNameToId = {};

  // Roster grouped by class -> section -> list of student maps
  // Each student map includes 'docId' so we can update the student doc.
  Map<String, Map<String, List<Map<String, dynamic>>>> classSectionStudents =
      {};

  // UI selections
  String? selectedDepartment;
  String? selectedClass;
  String? selectedCourse;
  String? selectedTeacher;
  DateTime? selectedDate;
  String? selectedUsername;
  String? selectedStudentName;
  String? selectedStudentClass;
  String searchText = '';

  // Prefetch / loading state
  bool loadingDepartments = false;
  bool loadingClasses = false;
  bool loadingSubjects = false;
  bool loadingStudents = false;
  bool loadingTeachers = false;

  // Percentage results state
  bool loadingPercentage = false;
  List<Map<String, dynamic>> percentageRows = [];

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  @override
  void dispose() {
    _pageScrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchPercentageForDepartment() async {
    if (selectedDepartment == null) return;
    setState(() {
      loadingPercentage = true;
      percentageRows = [];
    });

    final dept = selectedDepartment!;
    final firestore = FirebaseFirestore.instance;
    // If a teacher is selected, derive the classes from qr_generation docs
    // authored/owned by that teacher; otherwise use the loaded classes list.
    final Map<String, List<String>> classCodes = {};
    List<String> classList = [];
    String? selTeacher = selectedTeacher;
    String teacherDocId = '';
    String teacherUsername = '';
    String? teacherName = selTeacher;
    // map className -> list of 7 ints representing Mon..Sun session counts
    Map<String, List<int>> classSessionDayCounts = {};
    if (selTeacher != null) {
      teacherDocId = _teacherNameToId[selTeacher] ?? '';
      // try to fetch teacher doc to get username if we have an id
      if (teacherDocId.isNotEmpty) {
        try {
          final tdoc = await firestore
              .collection('teachers')
              .doc(teacherDocId)
              .get();
          if (tdoc.exists) {
            final td = tdoc.data();
            teacherUsername = (td?['username'] ?? td?['user'] ?? '').toString();
            teacherName =
                (td?['teacher_name'] ?? td?['teacherName'] ?? teacherName)
                    .toString();
          }
        } catch (_) {}
      }

      try {
        // Build classes taught by this teacher from the timetables collection.
        final timetableSnap = await firestore
            .collection('timetables')
            .where('department', isEqualTo: dept)
            .get();
        classSessionDayCounts.clear();
        for (final t in timetableSnap.docs) {
          final td = t.data();
          // match timetable doc to the teacher
          if (!_qrDocMatchesTeacher(
            td,
            teacherDocId,
            teacherUsername,
            teacherName,
          )) {
            continue;
          }
          final cls =
              (td['class'] ??
                      td['className'] ??
                      td['class_name'] ??
                      td['class_id'] ??
                      td['classRef'] ??
                      '')
                  .toString();
          if (cls.isEmpty) continue;

          // count matching cells in grid and grid_meta (weekly sessions)
          // we'll attribute cells to weekday indices (0..6)
          final dayCounts = List<int>.filled(7, 0);
          try {
            final grid = td['grid'];
            if (grid is Iterable) {
              var rIndex = 0;
              for (final row in grid) {
                if (row is Map && row.containsKey('cells')) {
                  final cells = row['cells'];
                  if (cells is Iterable) {
                    for (final cell in cells) {
                      if (_qrDocMatchesTeacher(
                        {'v': cell},
                        teacherDocId,
                        teacherUsername,
                        teacherName,
                      )) {
                        final idx = (rIndex >= 0 && rIndex < 7)
                            ? rIndex
                            : (rIndex % 7);
                        dayCounts[idx] = dayCounts[idx] + 1;
                      }
                    }
                  }
                }
                rIndex++;
              }
            }
            final gridMeta = td['grid_meta'];
            if (gridMeta is Iterable) {
              var gmRowIndex = 0;
              for (final gm in gridMeta) {
                if (gm is Map && gm.containsKey('cells')) {
                  final rows = gm['cells'];
                  if (rows is Iterable) {
                    for (final r in rows) {
                      if (r is Map && r.containsKey('cells')) {
                        final cells = r['cells'];
                        if (cells is Iterable) {
                          for (final cell in cells) {
                            if (_qrDocMatchesTeacher(
                              {'v': cell},
                              teacherDocId,
                              teacherUsername,
                              teacherName,
                            )) {
                              final idx = (gmRowIndex >= 0 && gmRowIndex < 7)
                                  ? gmRowIndex
                                  : (gmRowIndex % 7);
                              dayCounts[idx] = dayCounts[idx] + 1;
                            }
                          }
                        }
                      }
                      gmRowIndex++;
                    }
                  }
                }
              }
            }
          } catch (_) {}

          final totalFromDays = dayCounts.fold<int>(0, (p, n) => p + n);
          if (totalFromDays > 0) {
            classSessionDayCounts[cls] =
                (classSessionDayCounts[cls] ?? List<int>.filled(7, 0))
                    .asMap()
                    .map((i, v) => MapEntry(i, v + dayCounts[i]))
                    .values
                    .toList();
          }
        }

        // If nothing found by dept-name filter, try fetching all timetables and match loose
        if (classSessionDayCounts.isEmpty) {
          try {
            final allTimetables = await firestore
                .collection('timetables')
                .get();
            for (final t in allTimetables.docs) {
              final td = t.data();
              if (!_qrDocMatchesTeacher(
                td,
                teacherDocId,
                teacherUsername,
                teacherName,
              )) {
                continue;
              }
              final dep =
                  (td['department'] ??
                          td['department_name'] ??
                          td['dept'] ??
                          '')
                      .toString();
              if (!_looseNameMatch(dep, dept)) continue;
              final cls =
                  (td['class'] ??
                          td['className'] ??
                          td['class_name'] ??
                          td['class_id'] ??
                          td['classRef'] ??
                          '')
                      .toString();
              if (cls.isEmpty) continue;

              // count matching cells in grid and grid_meta (weekly sessions)
              final dayCounts = List<int>.filled(7, 0);
              try {
                final grid = td['grid'];
                if (grid is Iterable) {
                  var rIndex = 0;
                  for (final row in grid) {
                    if (row is Map && row.containsKey('cells')) {
                      final cells = row['cells'];
                      if (cells is Iterable) {
                        for (final cell in cells) {
                          if (_qrDocMatchesTeacher(
                            {'v': cell},
                            teacherDocId,
                            teacherUsername,
                            teacherName,
                          )) {
                            final idx = (rIndex >= 0 && rIndex < 7)
                                ? rIndex
                                : (rIndex % 7);
                            dayCounts[idx] = dayCounts[idx] + 1;
                          }
                        }
                      }
                    }
                    rIndex++;
                  }
                }
                final gridMeta = td['grid_meta'];
                if (gridMeta is Iterable) {
                  var gmRowIndex = 0;
                  for (final gm in gridMeta) {
                    if (gm is Map && gm.containsKey('cells')) {
                      final rows = gm['cells'];
                      if (rows is Iterable) {
                        for (final r in rows) {
                          if (r is Map && r.containsKey('cells')) {
                            final cells = r['cells'];
                            if (cells is Iterable) {
                              for (final cell in cells) {
                                if (_qrDocMatchesTeacher(
                                  {'v': cell},
                                  teacherDocId,
                                  teacherUsername,
                                  teacherName,
                                )) {
                                  final idx =
                                      (gmRowIndex >= 0 && gmRowIndex < 7)
                                      ? gmRowIndex
                                      : (gmRowIndex % 7);
                                  dayCounts[idx] = dayCounts[idx] + 1;
                                }
                              }
                            }
                          }
                          gmRowIndex++;
                        }
                      }
                    }
                  }
                }
              } catch (_) {}

              final totalFromDays = dayCounts.fold<int>(0, (p, n) => p + n);
              if (totalFromDays > 0) {
                classSessionDayCounts[cls] =
                    (classSessionDayCounts[cls] ?? List<int>.filled(7, 0))
                        .asMap()
                        .map((i, v) => MapEntry(i, v + dayCounts[i]))
                        .values
                        .toList();
              }
            }
          } catch (_) {}
        }

        // For each class, collect QR codes generated that match the teacher
        for (final cls in classSessionDayCounts.keys) {
          try {
            final qrSnap = await firestore
                .collection('qr_generation')
                .where('department', isEqualTo: dept)
                .where('className', isEqualTo: cls)
                .where('active', isEqualTo: true)
                .get();
            for (final d in qrSnap.docs) {
              final qd = d.data();
              if (!_qrDocMatchesTeacher(
                qd,
                teacherDocId,
                teacherUsername,
                teacherName,
              )) {
                continue;
              }
              // Only include QR codes for the current week (teacher report)
              DateTime? psDt;
              try {
                final ps =
                    qd['period_starts_at'] ??
                    qd['period_starts_at_iso'] ??
                    qd['created_at'] ??
                    qd['created_at_iso'];
                if (ps != null) {
                  if (ps is Timestamp) {
                    psDt = ps.toDate();
                  } else if (ps is String) {
                    psDt = DateTime.tryParse(ps);
                  } else if (ps is int) {
                    psDt = DateTime.fromMillisecondsSinceEpoch(ps);
                  }
                }
              } catch (_) {}
              if (psDt == null) continue;
              final now = DateTime.now();
              final startOfWeek = DateTime(
                now.year,
                now.month,
                now.day,
              ).subtract(Duration(days: now.weekday - 1));
              final endOfWeek = startOfWeek.add(const Duration(days: 7));
              if (!(psDt.isAtSameMomentAs(startOfWeek) ||
                  (psDt.isAfter(startOfWeek) && psDt.isBefore(endOfWeek)) ||
                  psDt.isAtSameMomentAs(endOfWeek))) {
                continue;
              }
              final code = (qd['code'] ?? '').toString();
              if (code.isEmpty) continue;
              classCodes.putIfAbsent(cls, () => []).add(code);
            }
          } catch (e) {
            debugPrint('qr fetch error for class $cls: $e');
          }
        }

        classList = classSessionDayCounts.keys.toList()..sort();
        // store session counts in a map accessible in loop below via local variable
        // we'll keep classSessionCount in lexical scope by assigning to an outer var
        // (we'll reuse it below)
        // assign to a local final via closure
        // (we'll reference classSessionCount directly below)
      } catch (e) {
        debugPrint('timetable fetch error for teacher filter: $e');
      }
    }
    if (selTeacher == null) {
      classList = classesForDept;
    }

    final rows = <Map<String, dynamic>>[];

    for (var i = 0; i < classList.length; i++) {
      final cls = classList[i];

      int totalQr = 0;
      List<String> codes = [];
      try {
        if (selTeacher != null) {
          // use pre-collected codes for teacher
          codes = classCodes[cls] ?? [];
          totalQr = codes.length;
        } else {
          final qrSnap = await firestore
              .collection('qr_generation')
              .where('department', isEqualTo: dept)
              .where('className', isEqualTo: cls)
              .where('active', isEqualTo: true)
              .get();
          totalQr = qrSnap.docs.length;
          codes = qrSnap.docs
              .map((d) => (d.data()['code'] ?? '').toString())
              .where((c) => c.isNotEmpty)
              .toList();
        }
      } catch (e) {
        debugPrint('qr fetch error for $cls: $e');
      }

      int totalAttendances = 0;
      try {
        const batchSize = 10;
        for (var start = 0; start < codes.length; start += batchSize) {
          final end = (start + batchSize) > codes.length
              ? codes.length
              : (start + batchSize);
          final chunk = codes.sublist(start, end);
          if (chunk.isEmpty) continue;
          final attSnap = await firestore
              .collection('attendance_records')
              .where('code', whereIn: chunk)
              .get();
          totalAttendances += attSnap.docs.length;
        }
      } catch (e) {
        debugPrint('attendance fetch error for $cls: $e');
      }

      int totalStudents = 0;
      try {
        final s1 = await firestore
            .collection('students')
            .where('className', isEqualTo: cls)
            .get();
        totalStudents = s1.docs.length;
        if (totalStudents == 0) {
          final s2 = await firestore
              .collection('students')
              .where('class_name', isEqualTo: cls)
              .get();
          totalStudents = s2.docs.length;
        }
      } catch (e) {
        debugPrint('students fetch error for $cls: $e');
      }

      // If teacher selected, expected should be based on scheduled sessions from timetables
      final expectedSessions = selTeacher != null
          ? (classSessionDayCounts[cls]?.fold<int>(0, (p, n) => p + n) ?? 0)
          : totalQr;
      final expected = totalStudents * expectedSessions;
      int absence = 0;
      int absencePercent = 0;
      if (expected > 0) {
        absence = expected - totalAttendances;
        if (absence < 0) absence = 0;
        absencePercent = ((absence / expected) * 100).round();
      }

      final totalNeeded =
          expectedSessions; // count of scheduled sessions (week total)
      final totalNotGenerated = (totalNeeded - totalQr) < 0
          ? 0
          : (totalNeeded - totalQr);

      // Display 'pct' as the percentage of ABSENCE per your request.
      // include per-day breakdown for teacher view if available
      final dayList = selTeacher != null
          ? (classSessionDayCounts[cls] ?? List<int>.filled(7, 0))
          : List<int>.filled(7, 0);

      // Calculate teacher absence percentage as (notGenerated / needed) * 100
      int absencePct = 0;
      if (totalNeeded > 0) {
        absencePct = ((totalNotGenerated / totalNeeded) * 100).round();
      }

      if (selTeacher == null) {
        // Department-wide row: include attended/absence and show attendance pct as `pct`
        rows.add({
          'no': i + 1,
          'class': cls,
          'totalGenerated': totalQr,
          'attended': totalAttendances,
          'absence': absence,
          'totalNeeded': totalNeeded,
          'totalNotGenerated': totalNotGenerated,
          'pct': absencePercent, // show ABSENCE % in the Percentage column
          'absencePct': absencePercent, // used to colour the row
        });
      } else {
        // Teacher-scoped row: include per-day counts and teacher absence %
        rows.add({
          'no': i + 1,
          'class': cls,
          'd0': dayList.isNotEmpty ? dayList[0] : 0,
          'd1': dayList.length > 1 ? dayList[1] : 0,
          'd2': dayList.length > 2 ? dayList[2] : 0,
          'd3': dayList.length > 3 ? dayList[3] : 0,
          'd4': dayList.length > 4 ? dayList[4] : 0,
          'd5': dayList.length > 5 ? dayList[5] : 0,
          'd6': dayList.length > 6 ? dayList[6] : 0,
          'totalNeeded': totalNeeded,
          'totalGenerated': totalQr,
          'totalNotGenerated': totalNotGenerated,
          'pct': absencePct,
          'absencePct': absencePct,
        });
      }
    }

    setState(() {
      percentageRows = rows;
      loadingPercentage = false;
    });
  }

  bool _qrDocMatchesTeacher(
    Map<String, dynamic> qd,
    String teacherDocId,
    String teacherUsername,
    String? teacherName,
  ) {
    if (teacherDocId.isEmpty &&
        (teacherUsername.isEmpty &&
            (teacherName == null || teacherName.isEmpty))) {
      return false;
    }

    bool checkString(String s) {
      if (s.isEmpty) return false;
      if (teacherDocId.isNotEmpty && s.contains(teacherDocId)) return true;
      if (teacherUsername.isNotEmpty) {
        final low = s.toLowerCase();
        if (low == teacherUsername.toLowerCase() ||
            low.contains(teacherUsername.toLowerCase())) {
          return true;
        }
      }
      if (teacherName != null &&
          teacherName.isNotEmpty &&
          _looseNameMatch(s, teacherName)) {
        return true;
      }
      return false;
    }

    bool searchValue(dynamic v) {
      if (v == null) return false;
      if (v is DocumentReference) {
        if (teacherDocId.isNotEmpty && v.id == teacherDocId) return true;
        if (teacherDocId.isNotEmpty && v.path.contains(teacherDocId)) {
          return true;
        }
        return false;
      }
      if (v is String) return checkString(v);
      if (v is Map) {
        for (final e in v.values) {
          if (searchValue(e)) return true;
        }
        return false;
      }
      if (v is Iterable) {
        for (final e in v) {
          if (searchValue(e)) return true;
        }
        return false;
      }
      // Fallback to string compare
      return checkString(v.toString());
    }

    // common candidate keys at top-level
    final candidates = <dynamic>[
      qd['created_by'],
      qd['creator'],
      qd['created_by_username'],
      qd['teacher'],
      qd['lecturer'],
      qd['owner'],
      qd['username'],
    ];
    for (final cand in candidates) {
      if (searchValue(cand)) return true;
    }

    // lastly, recursively search the whole document for any matching string
    return searchValue(qd);
  }

  // --------------------------
  // Firestore loaders
  // --------------------------
  Future<void> _loadDepartments() async {
    setState(() {
      loadingDepartments = true;
      departments = [];
      classesForDept = [];
      coursesForClass = [];
      teachersForDept = [];
      _deptNameToId.clear();
      _classNameToId.clear();
      _teacherNameToId.clear();
      selectedDepartment = null;
      selectedClass = null;
      selectedCourse = null;
      selectedTeacher = null;
      classSectionStudents = {};
    });

    try {
      final deptSet = <String>{};
      // Prefer departments within the current faculty
      if (Session.facultyRef != null) {
        final facRef = Session.facultyRef!;
        final facId = facRef.id;
        final facPath = facRef.path; // e.g., 'faculties/<id>'

        try {
          // Common schema: DocumentReference stored as 'faculty_ref'
          final q1 = await _firestore
              .collection('departments')
              .where('faculty_ref', isEqualTo: facRef)
              .where('status', isEqualTo: true)
              .get();
          for (final doc in q1.docs) {
            final d = doc.data();
            final deptValue =
                (d['department_name'] ??
                        d['name'] ??
                        d['department_code'] ??
                        d['department'])
                    ?.toString() ??
                '';
            if (deptValue.isNotEmpty) {
              deptSet.add(deptValue);
              _deptNameToId.putIfAbsent(deptValue, () => doc.id);
            }
          }
        } catch (_) {}

        // Alternate schemas where id/path is stored as string
        for (final field in ['faculty_id', 'faculty']) {
          for (final value in [facId, facPath]) {
            try {
              final qAlt = await _firestore
                  .collection('departments')
                  .where(field, isEqualTo: value)
                  .where('status', isEqualTo: true)
                  .get();
              for (final doc in qAlt.docs) {
                final d = doc.data();
                final deptValue =
                    (d['department_name'] ??
                            d['name'] ??
                            d['department_code'] ??
                            d['department'])
                        ?.toString() ??
                    '';
                if (deptValue.isNotEmpty) {
                  deptSet.add(deptValue);
                  _deptNameToId.putIfAbsent(deptValue, () => doc.id);
                }
              }
            } catch (_) {}
          }
        }
      }

      // If facultyRef isn't set or yielded nothing, fall back to previous logic
      if (deptSet.isEmpty) {
        // Use only Session.username (adjust here if your Session exposes a different id field)
        final currentUsername = (Session.username ?? '').toString();

        // Departments headed by the current user
        if (currentUsername.isNotEmpty) {
          try {
            final q = await _firestore
                .collection('departments')
                .where('head_of_department', isEqualTo: currentUsername)
                .where('status', isEqualTo: true)
                .get();
            for (final doc in q.docs) {
              final d = doc.data();
              final deptValue =
                  (d['department_name'] ??
                          d['name'] ??
                          d['department_code'] ??
                          d['department'])
                      ?.toString() ??
                  '';
              if (deptValue.isNotEmpty) {
                deptSet.add(deptValue);
                _deptNameToId.putIfAbsent(deptValue, () => doc.id);
              }
            }
          } catch (_) {}
        }

        // Legacy fallback: derive from timetables
        if (deptSet.isEmpty) {
          try {
            final qs = await _firestore.collection('timetables').get();
            for (final doc in qs.docs) {
              final d = doc.data();
              final dep = (d['department'] ?? '').toString();
              if (dep.isNotEmpty) deptSet.add(dep);
            }
          } catch (e) {
            debugPrint('Failed fallback timetables fetch: $e');
          }
        }
      }

      setState(() {
        departments = deptSet.toList()..sort();
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load departments: $e')));
    } finally {
      setState(() {
        loadingDepartments = false;
      });
    }
  }

  Future<void> _loadClassesForDepartment(String dept) async {
    setState(() {
      loadingClasses = true;
      classesForDept = [];
      selectedClass = null;
      selectedCourse = null;
      coursesForClass = [];
      classSectionStudents = {};
    });

    try {
      final clsSet = <String>{};
      final classesSnap = await _firestore.collection('classes').get();
      String selectedDeptId = _deptNameToId[dept] ?? '';

      // If we don't have the department id (e.g., when departments came from
      // a timetable fallback), resolve it by name/code now so class matching
      // can use an id comparison.
      if (selectedDeptId.isEmpty) {
        try {
          final dqs = await _firestore
              .collection('departments')
              .where('status', isEqualTo: true)
              .get();
          for (final dd in dqs.docs) {
            final data = dd.data();
            final nameCandidates = [
              data['department_name'],
              data['name'],
              data['department_code'],
              data['department'],
            ].where((v) => v != null).map((v) => v.toString()).toList();
            if (nameCandidates.any((n) => _looseNameMatch(n, dept))) {
              selectedDeptId = dd.id;
              _deptNameToId.putIfAbsent(dept, () => selectedDeptId);
              break;
            }
          }
        } catch (_) {}
      }

      for (final doc in classesSnap.docs) {
        final data = doc.data();

        // Optional faculty scoping: skip classes not in session faculty
        if (Session.facultyRef != null) {
          final facCandidate =
              data['faculty_ref'] ?? data['faculty_id'] ?? data['faculty'];
          String facId = '';
          if (facCandidate != null) {
            if (facCandidate is DocumentReference) {
              facId = facCandidate.id;
            } else if (facCandidate is String) {
              final s = facCandidate;
              facId = s.contains('/')
                  ? s.split('/').where((p) => p.isNotEmpty).toList().last
                  : s;
            } else {
              facId = facCandidate.toString();
            }
          }
          if (facId.isNotEmpty && facId != Session.facultyRef!.id) {
            continue;
          }
        }

        // Resolve the department assigned to this class
        final deptCandidate =
            data['department_ref'] ??
            data['department_id'] ??
            data['department'];
        String deptIdOnClass = '';
        String deptStrOnClass = '';
        if (deptCandidate != null) {
          if (deptCandidate is DocumentReference) {
            deptIdOnClass = deptCandidate.id;
            deptStrOnClass = deptCandidate.path;
          } else if (deptCandidate is String) {
            deptStrOnClass = deptCandidate;
            deptIdOnClass = deptStrOnClass.contains('/')
                ? deptStrOnClass
                      .split('/')
                      .where((p) => p.isNotEmpty)
                      .toList()
                      .last
                : deptStrOnClass;
          } else {
            deptStrOnClass = deptCandidate.toString();
          }
        }

        // Check match by id if available, else loose match by name/path
        final belongsToSelected =
            (selectedDeptId.isNotEmpty && deptIdOnClass == selectedDeptId) ||
            _looseNameMatch(deptStrOnClass, dept);
        if (!belongsToSelected) continue;

        final className =
            (data['class_name'] ?? data['name'] ?? data['className'] ?? '')
                .toString()
                .trim();
        if (className.isNotEmpty) {
          clsSet.add(className);
          _classNameToId[className] = doc.id;
        }
      }

      setState(() {
        classesForDept = clsSet.toList()..sort();
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load classes: $e')));
    } finally {
      setState(() {
        loadingClasses = false;
      });
    }
  }

  // --------------------------
  // NEW: load teachers for the selected department
  // --------------------------
  Future<void> _loadTeachersForDepartment(String dept) async {
    setState(() {
      loadingTeachers = true;
      teachersForDept = [];
      selectedTeacher = null;
      _teacherNameToId.clear();
    });

    try {
      final teacherSet = <String>{};
      // fetch all teachers and filter client-side similar to classes loader
      final snap = await _firestore.collection('teachers').get();

      // Try to resolve department id if we have mapping
      String selectedDeptId = _deptNameToId[dept] ?? '';

      if (selectedDeptId.isEmpty) {
        try {
          final dqs = await _firestore
              .collection('departments')
              .where('status', isEqualTo: true)
              .get();
          for (final dd in dqs.docs) {
            final data = dd.data();
            final nameCandidates = [
              data['department_name'],
              data['name'],
              data['department_code'],
              data['department'],
            ].where((v) => v != null).map((v) => v.toString()).toList();
            if (nameCandidates.any((n) => _looseNameMatch(n, dept))) {
              selectedDeptId = dd.id;
              _deptNameToId.putIfAbsent(dept, () => selectedDeptId);
              break;
            }
          }
        } catch (_) {}
      }

      for (final doc in snap.docs) {
        final data = doc.data();

        // teachers may include a department reference/field; support multiple possibilities
        final deptCandidate =
            data['department_ref'] ??
            data['department_id'] ??
            data['department'] ??
            data['dept'];
        String deptIdOnTeacher = '';
        String deptStrOnTeacher = '';
        if (deptCandidate != null) {
          if (deptCandidate is DocumentReference) {
            deptIdOnTeacher = deptCandidate.id;
            deptStrOnTeacher = deptCandidate.path;
          } else if (deptCandidate is String) {
            deptStrOnTeacher = deptCandidate;
            deptIdOnTeacher = deptStrOnTeacher.contains('/')
                ? deptStrOnTeacher
                      .split('/')
                      .where((p) => p.isNotEmpty)
                      .toList()
                      .last
                : deptStrOnTeacher;
          } else {
            deptStrOnTeacher = deptCandidate.toString();
          }
        }

        // Teachers might not have department but have faculty_id as in your sample.
        // We'll consider a teacher belonging to the department if:
        //  - dept id matches, OR
        //  - loose name match with department field string, OR
        //  - teacher has no department but the selected department's faculty matches teacher.faculty_id (best-effort)
        bool belongsToSelected = false;
        if (selectedDeptId.isNotEmpty && deptIdOnTeacher == selectedDeptId) {
          belongsToSelected = true;
        } else if (_looseNameMatch(deptStrOnTeacher, dept)) {
          belongsToSelected = true;
        } else {
          // try matching by faculty if available on teacher
          final facCandidate =
              data['faculty_id'] ?? data['faculty'] ?? data['faculty_ref'];
          String facIdOnTeacher = '';
          if (facCandidate != null) {
            if (facCandidate is DocumentReference) {
              facIdOnTeacher = facCandidate.id;
            } else if (facCandidate is String) {
              final s = facCandidate;
              facIdOnTeacher = s.contains('/')
                  ? s.split('/').where((p) => p.isNotEmpty).toList().last
                  : s;
            } else {
              facIdOnTeacher = facCandidate.toString();
            }
          }
          if (!belongsToSelected &&
              facIdOnTeacher.isNotEmpty &&
              Session.facultyRef != null) {
            if (facIdOnTeacher == Session.facultyRef!.id) {
              // if dept is in the same faculty, include teacher as possible match (best-effort)
              belongsToSelected = true;
            }
          }
        }

        if (!belongsToSelected) continue;

        final teacherName =
            (data['teacher_name'] ??
                    data['name'] ??
                    data['fullname'] ??
                    data['fullName'] ??
                    data['username'])
                .toString()
                .trim();
        if (teacherName.isNotEmpty) {
          teacherSet.add(teacherName);
          _teacherNameToId.putIfAbsent(teacherName, () => doc.id);
        }
      }

      setState(() {
        teachersForDept = teacherSet.toList()..sort();
      });
    } catch (e) {
      debugPrint('Failed to load teachers: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load teachers: $e')));
    } finally {
      setState(() {
        loadingTeachers = false;
      });
    }
  }

  Future<void> _loadSubjectsForClass(String cls) async {
    setState(() {
      loadingSubjects = true;
      coursesForClass = [];
      selectedCourse = null;
      classSectionStudents = {};
    });

    try {
      final courseSet = <String>{};
      final coursesColl = _firestore.collection('courses');

      // Resolve class id from name; if missing, try a quick lookup
      String? classId = _classNameToId[cls];
      if (classId == null || classId.isEmpty) {
        try {
          final cSnap = await _firestore
              .collection('classes')
              .where('class_name', isEqualTo: cls)
              .get();
          if (cSnap.docs.isNotEmpty) classId = cSnap.docs.first.id;
        } catch (_) {}
      }
      if (classId == null || classId.isEmpty) {
        setState(() {
          coursesForClass = [];
        });
        return;
      }

      final classDocRef = _firestore.collection('classes').doc(classId);
      final possibleClassKeys = <dynamic>{
        classDocRef,
        classId,
        'classes/$classId',
        '/classes/$classId',
      };

      // Fetch all courses and filter client-side to support mixed storage formats
      final snap = await coursesColl.get();
      for (final doc in snap.docs) {
        final data = doc.data();

        // Optional faculty scoping
        if (Session.facultyRef != null) {
          final facCandidate =
              data['faculty_ref'] ?? data['faculty_id'] ?? data['faculty'];
          String facId = '';
          if (facCandidate != null) {
            if (facCandidate is DocumentReference) {
              facId = facCandidate.id;
            } else if (facCandidate is String) {
              final s = facCandidate;
              facId = s.contains('/')
                  ? s.split('/').where((p) => p.isNotEmpty).toList().last
                  : s;
            } else {
              facId = facCandidate.toString();
            }
          }
          if (facId.isNotEmpty && facId != Session.facultyRef!.id) {
            continue;
          }
        }

        // Match course to the selected class
        final classField =
            data['class'] ?? data['classRef'] ?? data['class_ref'];
        if (classField != null) {
          if (possibleClassKeys.contains(classField)) {
            final courseName =
                (data['course_name'] ??
                        data['courseName'] ??
                        data['course_code'] ??
                        '')
                    .toString()
                    .trim();
            if (courseName.isNotEmpty) courseSet.add(courseName);
          } else if (classField is String) {
            final s = classField;
            if (s.endsWith(classId) || s.contains('/$classId')) {
              final courseName =
                  (data['course_name'] ??
                          data['courseName'] ??
                          data['course_code'] ??
                          '')
                      .toString()
                      .trim();
              if (courseName.isNotEmpty) courseSet.add(courseName);
            }
          }
        }
      }

      setState(() {
        coursesForClass = courseSet.toList()..sort();
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load subjects: $e')));
    } finally {
      setState(() {
        loadingSubjects = false;
      });
    }
  }

  // --------------------------
  // Students loader for selected class
  // --------------------------
  Future<void> _fetchStudentsForSelection() async {
    if (selectedDepartment == null ||
        selectedClass == null ||
        selectedCourse == null) {
      return;
    }

    setState(() {
      loadingStudents = true;
      classSectionStudents = {};
    });

    try {
      final existingIds = <String>{};
      final fetchedDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];

      final variants = <String>{
        selectedClass!.trim(),
        selectedClass!.trim().toUpperCase(),
        selectedClass!.trim().toLowerCase(),
        selectedClass!.replaceAll(' ', ''),
      }..removeWhere((e) => e.isEmpty);

      for (final v in variants) {
        final q = await _firestore
            .collection('students')
            .where('className', isEqualTo: v)
            .get();
        for (final d in q.docs) {
          if (!existingIds.contains(d.id)) {
            fetchedDocs.add(d);
            existingIds.add(d.id);
          }
        }
      }

      if (fetchedDocs.isEmpty) {
        final q2 = await _firestore
            .collection('students')
            .where('class_name', isEqualTo: selectedClass)
            .get();
        for (final d in q2.docs) {
          if (!existingIds.contains(d.id)) {
            fetchedDocs.add(d);
            existingIds.add(d.id);
          }
        }
      }

      if (fetchedDocs.isEmpty) {
        final classDocIds = <String>{};
        for (final v in variants) {
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
                .where('department', isEqualTo: selectedDepartment)
                .get();
            for (final cd in classesInDept.docs) {
              final cname = (cd.data()['className'] ?? '').toString();
              if (cname.isNotEmpty && _looseNameMatch(cname, selectedClass)) {
                classDocIds.add(cd.id);
              }
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
                fetchedDocs.add(d);
                existingIds.add(d.id);
              }
            }
          } catch (_) {}
        }
      }

      if (fetchedDocs.isEmpty) {
        try {
          final deptQ = await _firestore
              .collection('students')
              .where('department', isEqualTo: selectedDepartment)
              .limit(2000)
              .get();
          for (final d in deptQ.docs) {
            final data = d.data();
            final sClass =
                (data['className'] ?? data['class_name'] ?? data['class'] ?? '')
                    .toString();
            final sClassRef =
                (data['class_ref'] ??
                        data['classRef'] ??
                        data['class_id'] ??
                        '')
                    .toString();
            if (_looseNameMatch(sClass, selectedClass) ||
                (sClassRef.isNotEmpty && sClassRef.contains(selectedClass!))) {
              if (!existingIds.contains(d.id)) {
                fetchedDocs.add(d);
                existingIds.add(d.id);
              }
            }
          }
        } catch (_) {}
      }

      final Map<String, List<Map<String, dynamic>>> sections = {};
      for (final d in fetchedDocs) {
        final data = d.data();
        final username = (data['username'] ?? d.id).toString();
        final fullname =
            (data['fullname'] ?? data['fullName'] ?? data['name'] ?? username)
                .toString();
        final courses = (data['courses'] is List)
            ? List<Map<String, dynamic>>.from(data['courses'])
            : <Map<String, dynamic>>[];
        final section = (data['section'] ?? data['section_name'] ?? 'None')
            .toString();
        final studentMap = <String, dynamic>{
          'username': username,
          'name': fullname,
          'courses': courses,
          'docId': d.id,
        };
        sections.putIfAbsent(section, () => []).add(studentMap);
      }

      setState(() {
        classSectionStudents = {selectedClass!: sections};
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load students: $e')));
      setState(() {
        classSectionStudents = {};
      });
    } finally {
      setState(() {
        loadingStudents = false;
      });
    }
  }

  // --------------------------
  // Update student status (present/absent) in Firestore
  // --------------------------
  // student status field and toggling removed (view-only for status)

  // --------------------------
  // Update student courses array in Firestore
  // --------------------------
  Future<void> _updateStudentCoursesInFirestore(
    String docId,
    List<Map<String, dynamic>> courses,
  ) async {
    try {
      await _firestore.collection('students').doc(docId).update({
        'courses': courses,
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update student courses: $e')),
      );
    }
  }

  // Called by details panel when editing records
  void _updateAttendanceForStudent(
    List<Map<String, dynamic>> updatedRecords,
  ) async {
    if (selectedUsername == null || selectedClass == null) return;

    final sectionsMap = classSectionStudents[selectedClass!] ?? {};
    String? foundDocId;
    for (final list in sectionsMap.values) {
      for (final s in list) {
        if (s['username'] == selectedUsername) {
          foundDocId = s['docId']?.toString();
          s['courses'] = updatedRecords;
          break;
        }
      }
      if (foundDocId != null) break;
    }

    setState(() {});

    if (foundDocId != null) {
      await _updateStudentCoursesInFirestore(foundDocId, updatedRecords);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Student document not found to save changes.'),
        ),
      );
    }
  }

  // --------------------------
  // Utilities
  // --------------------------
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

  // --------------------------
  // UI helpers & build
  // --------------------------
  List<String> get classes => classesForDept;
  List<String> get courses => coursesForClass;

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<SuperAdminColors>();
    final surfaceColor =
        palette?.surface ?? Theme.of(context).colorScheme.surface;
    final borderColor = palette?.border ?? Theme.of(context).dividerColor;
    final isMobile = MediaQuery.of(context).size.width < 800;

    final showTable =
        selectedDepartment != null &&
        selectedClass != null &&
        selectedCourse != null;
    final showStudentDetails = showTable && selectedUsername != null;

    return Scaffold(
      body: SafeArea(
        // Wrap the whole page in a Scrollbar + SingleChildScrollView so the user can scroll the entire page
        child: Scrollbar(
          controller: _pageScrollController,
          thumbVisibility: false,
          child: SingleChildScrollView(
            controller: _pageScrollController,
            padding: EdgeInsets.fromLTRB(
              isMobile ? 16.0 : 32.0,
              isMobile ? 20.0 : 32.0,
              isMobile ? 16.0 : 32.0,
              32.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Attendance Report',
                  style: TextStyle(
                    fontSize: isMobile ? 22 : 28,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(
                      context,
                    ).extension<SuperAdminColors>()?.textPrimary,
                  ),
                ),
                SizedBox(height: isMobile ? 12 : 16),
                SearchAddBar(
                  hintText: 'Search Attendance...',
                  buttonText: '',
                  onAddPressed: () {},
                  onChanged: (value) => setState(() => searchText = value),
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: borderColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: _FiltersRow(
                    departments: departments,
                    classes: classes,
                    courses: courses,
                    teachers: teachersForDept,
                    selectedDepartment: selectedDepartment,
                    selectedClass: selectedClass,
                    selectedCourse: selectedCourse,
                    selectedTeacher: selectedTeacher,
                    loadingDepartments: loadingDepartments,
                    loadingClasses: loadingClasses,
                    loadingCourses: loadingSubjects,
                    loadingTeachers: loadingTeachers,
                    onChanged:
                        ({
                          String? department,
                          String? className,
                          String? course,
                          String? lecturer,
                        }) {
                          setState(() {
                            if (department != null &&
                                department != selectedDepartment) {
                              selectedDepartment = department;
                              selectedClass = null;
                              selectedCourse = null;
                              selectedTeacher = null;
                              selectedUsername = null;
                              selectedStudentName = null;
                              selectedStudentClass = null;
                              classesForDept = [];
                              coursesForClass = [];
                              teachersForDept = [];
                              classSectionStudents = {};
                              percentageRows = [];
                              _loadClassesForDepartment(department);
                              _loadTeachersForDepartment(department);
                            }
                            if (className != null &&
                                className != selectedClass) {
                              selectedClass = className;
                              selectedCourse = null;
                              selectedUsername = null;
                              selectedStudentName = null;
                              selectedStudentClass = null;
                              coursesForClass = [];
                              classSectionStudents = {};
                              percentageRows = [];
                              _loadSubjectsForClass(className);
                            }
                            if (course != null && course != selectedCourse) {
                              selectedCourse = course;
                              selectedUsername = null;
                              selectedStudentName = null;
                              selectedStudentClass = null;
                              classSectionStudents = {};
                              if (selectedDepartment != null &&
                                  selectedClass != null &&
                                  selectedCourse != null) {
                                _fetchStudentsForSelection();
                              }
                            }
                            if (lecturer != null &&
                                lecturer != selectedTeacher) {
                              selectedTeacher = lecturer;
                              selectedUsername = null;
                              selectedStudentName = null;
                              selectedStudentClass = null;
                              // Clear class/course selections when a teacher is chosen
                              selectedClass = null;
                              selectedCourse = null;
                              classesForDept = [];
                              coursesForClass = [];
                              classSectionStudents = {};
                              percentageRows = [];
                            }
                          });
                        },
                    onPercentagePressed: selectedDepartment == null
                        ? null
                        : () {
                            setState(() {
                              // Clear selected class and course boxes when Percentage is requested
                              // but preserve selectedTeacher so department+teacher percentages work.
                              selectedClass = null;
                              selectedCourse = null;
                              selectedUsername = null;
                              selectedStudentName = null;
                              selectedStudentClass = null;
                              // Clear dependent UI lists/state to reflect cleared selections
                              coursesForClass = [];
                              classSectionStudents = {};
                              percentageRows = [];
                            });
                            _fetchPercentageForDepartment();
                          },
                    onRefreshPressed: () {
                      setState(() {
                        selectedDepartment = null;
                        selectedClass = null;
                        selectedCourse = null;
                        selectedTeacher = null;
                        selectedUsername = null;
                        selectedStudentName = null;
                        selectedStudentClass = null;
                        classesForDept = [];
                        coursesForClass = [];
                        teachersForDept = [];
                        classSectionStudents = {};
                        percentageRows = [];
                      });
                      _loadDepartments();
                    },
                  ),
                ),
                const SizedBox(height: 12),
                // Inline percentage results
                if (loadingPercentage)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: LinearProgressIndicator(),
                  ),

                if (!loadingPercentage && percentageRows.isNotEmpty)
                  Builder(
                    builder: (context) {
                      final scheme = Theme.of(context).colorScheme;
                      final avgPct = percentageRows.isEmpty
                          ? 0
                          : (percentageRows
                                      .map(
                                        (r) => (r['pct'] as num?)?.toDouble() ?? 0,
                                      )
                                      .fold<double>(0, (a, b) => a + b) /
                                  percentageRows.length)
                              .round();
                      final worst = percentageRows.isEmpty
                          ? null
                          : (percentageRows.toList()
                            ..sort(
                              (a, b) => ((b['pct'] as num?)?.toInt() ?? 0)
                                  .compareTo((a['pct'] as num?)?.toInt() ?? 0),
                            )).first;
                      final worstClass = (worst?['class'] ?? '-').toString();
                      final worstPct = ((worst?['pct'] as num?)?.toInt() ?? 0);

                      Widget kpiCard({
                        required String title,
                        required String value,
                        String? hint,
                      }) {
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: surfaceColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: borderColor.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: palette?.textSecondary ??
                                      scheme.onSurface.withValues(alpha: 0.8),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                value,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: palette?.textPrimary ?? scheme.onSurface,
                                ),
                              ),
                              if (hint != null && hint.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  hint,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: palette?.textSecondary ??
                                        scheme.onSurface.withValues(alpha: 0.75),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }

                      Widget pctPill(int pct) {
                        final bool danger = pct >= 25;
                        final bg = danger
                            ? scheme.errorContainer.withValues(alpha: 0.72)
                            : scheme.tertiaryContainer.withValues(alpha: 0.72);
                        final fg = danger
                            ? scheme.onErrorContainer
                            : scheme.onTertiaryContainer;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '$pct%',
                            style: TextStyle(
                              color: fg,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        );
                      }

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: borderColor.withValues(alpha: 0.3),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(
                                context,
                              ).shadowColor.withValues(alpha: 0.08),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedTeacher == null
                                  ? 'Department Attendance Analytics'
                                  : 'Teacher Attendance Analytics',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: palette?.textPrimary ?? scheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 10),
                            LayoutBuilder(
                              builder: (context, c) {
                                final narrow = c.maxWidth < 900;
                                final cards = [
                                  Expanded(
                                    child: kpiCard(
                                      title: 'Classes Analyzed',
                                      value: percentageRows.length.toString(),
                                    ),
                                  ),
                                  Expanded(
                                    child: kpiCard(
                                      title: 'Average Absence',
                                      value: '$avgPct%',
                                    ),
                                  ),
                                  Expanded(
                                    child: kpiCard(
                                      title: 'Highest Risk Class',
                                      value: worstClass,
                                      hint: '$worstPct% absence',
                                    ),
                                  ),
                                ];
                                if (narrow) {
                                  return Column(
                                    children: [
                                      Row(
                                        children: [
                                          cards[0],
                                          const SizedBox(width: 8),
                                          cards[1],
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Row(children: [cards[2]]),
                                    ],
                                  );
                                }
                                return Row(
                                  children: [
                                    cards[0],
                                    const SizedBox(width: 10),
                                    cards[1],
                                    const SizedBox(width: 10),
                                    cards[2],
                                  ],
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            LayoutBuilder(
                              builder: (context, tableBox) {
                                final compactTable = tableBox.maxWidth < 700;
                                if (compactTable) {
                                  return Column(
                                    children: percentageRows.map((r) {
                                      final pct = (r['pct'] as num?)?.toInt() ?? 0;
                                      return Container(
                                        width: double.infinity,
                                        margin: const EdgeInsets.only(bottom: 8),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: borderColor.withValues(alpha: 0.35),
                                          ),
                                          color: surfaceColor,
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${r['class'] ?? '-'}',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                color: palette?.textPrimary ?? scheme.onSurface,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Wrap(
                                              spacing: 12,
                                              runSpacing: 8,
                                              children: selectedTeacher == null
                                                  ? [
                                                      Text('No: ${r['no'] ?? 0}'),
                                                      Text('QR: ${r['totalGenerated'] ?? 0}'),
                                                      Text('Attended: ${r['attended'] ?? 0}'),
                                                      Text('Absence: ${r['absence'] ?? 0}'),
                                                    ]
                                                  : [
                                                      Text('No: ${r['no'] ?? 0}'),
                                                      Text('Needed: ${r['totalNeeded'] ?? 0}'),
                                                      Text('Generated: ${r['totalGenerated'] ?? 0}'),
                                                      Text('Not Generated: ${r['totalNotGenerated'] ?? 0}'),
                                                    ],
                                            ),
                                            const SizedBox(height: 8),
                                            pctPill(pct),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  );
                                }

                                return Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: borderColor.withValues(alpha: 0.35),
                                    ),
                                  ),
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      showCheckboxColumn: false,
                                      headingRowColor:
                                          WidgetStateProperty.all<Color?>(
                                        palette?.surfaceHigh ??
                                            scheme.surfaceContainerHighest,
                                      ),
                                      headingTextStyle: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        color: palette?.textPrimary ?? scheme.onSurface,
                                      ),
                                      dataTextStyle: TextStyle(
                                        color: palette?.textPrimary ?? scheme.onSurface,
                                      ),
                                      columns: selectedTeacher == null
                                          ? const [
                                              DataColumn(label: Text('No')),
                                              DataColumn(label: Text('Class')),
                                              DataColumn(label: Text('Total QR')),
                                              DataColumn(label: Text('Attended')),
                                              DataColumn(label: Text('Absence')),
                                              DataColumn(label: Text('Abs %')),
                                            ]
                                          : const [
                                              DataColumn(label: Text('No')),
                                              DataColumn(label: Text('Class')),
                                              DataColumn(label: Text('Needed')),
                                              DataColumn(label: Text('Generated')),
                                              DataColumn(label: Text('Not Generated')),
                                              DataColumn(label: Text('Abs %')),
                                            ],
                                      rows: percentageRows.map((r) {
                                        final pct = (r['pct'] as num?)?.toInt() ?? 0;
                                        return DataRow(
                                          cells: selectedTeacher == null
                                              ? [
                                                  DataCell(Text('${r['no'] ?? 0}')),
                                                  DataCell(Text('${r['class'] ?? ''}')),
                                                  DataCell(
                                                    Text('${r['totalGenerated'] ?? 0}'),
                                                  ),
                                                  DataCell(
                                                    Text('${r['attended'] ?? 0}'),
                                                  ),
                                                  DataCell(
                                                    Text('${r['absence'] ?? 0}'),
                                                  ),
                                                  DataCell(pctPill(pct)),
                                                ]
                                              : [
                                                  DataCell(Text('${r['no'] ?? 0}')),
                                                  DataCell(Text('${r['class'] ?? ''}')),
                                                  DataCell(
                                                    Text('${r['totalNeeded'] ?? 0}'),
                                                  ),
                                                  DataCell(
                                                    Text('${r['totalGenerated'] ?? 0}'),
                                                  ),
                                                  DataCell(
                                                    Text('${r['totalNotGenerated'] ?? 0}'),
                                                  ),
                                                  DataCell(pctPill(pct)),
                                                ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                const SizedBox(height: 16),

                // Table / details area: make this a fixed-height box so it renders nicely inside the SingleChildScrollView.
                // We pick a reasonable height based on viewport; this keeps the page scrollable while the table itself can still
                // scroll horizontally if needed.
                LayoutBuilder(
                  builder: (context, constraints) {
                    // Calculate a height for the content area roughly equal to 55% of the remaining viewport height.
                    final viewportHeight = MediaQuery.of(context).size.height;
                    final showEmptyHint = !showTable && percentageRows.isEmpty;
                    final contentHeight = showEmptyHint
                        ? 170.0
                        : ((constraints.maxWidth < 980 && showStudentDetails)
                              ? (viewportHeight * 0.72).clamp(420.0, 1100.0)
                              : (viewportHeight * 0.55).clamp(300.0, 900.0));

                    return SizedBox(
                      height: contentHeight,
                      child: showTable
                          ? LayoutBuilder(
                              builder: (context, inner) {
                                final isWide = inner.maxWidth >= 980;
                                final panelWidth = (inner.maxWidth * 0.34)
                                    .clamp(320.0, 460.0)
                                    .toDouble();
                                final panelGap = inner.maxWidth >= 1280
                                    ? 16.0
                                    : 12.0;
                                final table = _AttendanceTable(
                                  department: selectedDepartment ?? '',
                                  className: selectedClass ?? '',
                                  course: selectedCourse ?? '',
                                  date: selectedDate,
                                  searchText: searchText,
                                  selectedStudentId: selectedUsername,
                                  classSectionStudents: classSectionStudents,
                                  onStudentSelected: (studentId) {
                                    final sectionsMap =
                                        classSectionStudents[selectedClass] ?? {};
                                    String? foundSection;
                                    Map<String, dynamic>? student;
                                    for (final entry in sectionsMap.entries) {
                                      final s = entry.value.firstWhere(
                                        (it) => it['username'] == studentId,
                                        orElse: () => <String, dynamic>{},
                                      );
                                      if (s.isNotEmpty) {
                                        foundSection = entry.key;
                                        student = s;
                                        break;
                                      }
                                    }
                                    if (student == null || student.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Student data not available.',
                                          ),
                                        ),
                                      );
                                      return;
                                    }
                                    setState(() {
                                      selectedUsername = studentId;
                                      selectedStudentName = student!['name']
                                          ?.toString();
                                      selectedStudentClass =
                                          '$selectedClass${(foundSection != null && foundSection != "None") ? foundSection : ""}';
                                    });
                                  },
                                );

                                if (!isWide) {
                                  return showStudentDetails
                                      ? StudentDetailsPanel(
                                          key: ValueKey(
                                            'student_${selectedUsername}_${selectedCourse ?? ''}',
                                          ),
                                          studentId: selectedUsername!,
                                          studentName: selectedStudentName,
                                          studentClass: selectedStudentClass,
                                          selectedCourse: selectedCourse,
                                          compact: true,
                                          selectedDate: selectedDate,
                                          attendanceRecords:
                                              _getRecordsForSelectedStudent(),
                                          searchText: searchText,
                                          onBack: () {
                                            setState(() {
                                              selectedUsername = null;
                                              selectedStudentName = null;
                                              selectedStudentClass = null;
                                            });
                                          },
                                          onEdit: _updateAttendanceForStudent,
                                        )
                                      : table;
                                }

                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: table),
                                    AnimatedContainer(
                                      duration: const Duration(milliseconds: 220),
                                      curve: Curves.easeOutCubic,
                                      width: showStudentDetails ? panelWidth : 0,
                                      margin: EdgeInsets.only(
                                        left: showStudentDetails ? panelGap : 0,
                                      ),
                                      child: showStudentDetails
                                          ? Container(
                                              decoration: BoxDecoration(
                                                color: surfaceColor,
                                                borderRadius: BorderRadius.circular(
                                                  14,
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Theme.of(context)
                                                        .shadowColor
                                                        .withValues(alpha: 0.12),
                                                    blurRadius: 18,
                                                    offset: const Offset(-2, 8),
                                                  ),
                                                ],
                                                border: Border.all(
                                                  color: borderColor.withValues(
                                                    alpha: 0.35,
                                                  ),
                                                ),
                                              ),
                                              child: Column(
                                                children: [
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.fromLTRB(
                                                      16,
                                                      14,
                                                      10,
                                                      10,
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        const Expanded(
                                                          child: Text(
                                                            'Student Details',
                                                            style: TextStyle(
                                                              fontSize: 20,
                                                              fontWeight:
                                                                  FontWeight.w700,
                                                            ),
                                                          ),
                                                        ),
                                                        IconButton(
                                                          tooltip: 'Close',
                                                          onPressed: () {
                                                            setState(() {
                                                              selectedUsername =
                                                                  null;
                                                              selectedStudentName =
                                                                  null;
                                                              selectedStudentClass =
                                                                  null;
                                                            });
                                                          },
                                                          icon: const Icon(
                                                            Icons.close,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const Divider(height: 1),
                                                  Expanded(
                                                    child: StudentDetailsPanel(
                                                      key: ValueKey(
                                                        'student_${selectedUsername}_${selectedCourse ?? ''}',
                                                      ),
                                                      studentId:
                                                          selectedUsername!,
                                                      studentName:
                                                          selectedStudentName,
                                                      studentClass:
                                                          selectedStudentClass,
                                                      selectedCourse:
                                                          selectedCourse,
                                                      compact: true,
                                                      selectedDate: selectedDate,
                                                      attendanceRecords:
                                                          _getRecordsForSelectedStudent(),
                                                      searchText: searchText,
                                                      onBack: null,
                                                      onEdit:
                                                          _updateAttendanceForStudent,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          : const SizedBox.shrink(),
                                    ),
                                  ],
                                );
                              },
                            )
                          : Center(
                              child: percentageRows.isNotEmpty
                                  ? const SizedBox.shrink()
                                  : const Text(
                                      "Select all filters to view attendance",
                                    ),
                            ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getRecordsForSelectedStudent() {
    if (selectedUsername == null || selectedClass == null) return [];
    final studentsMap = classSectionStudents[selectedClass] ?? {};
    final studentsList = studentsMap.values.expand((e) => e).toList();
    final student = studentsList.firstWhere(
      (s) => s['username'] == selectedUsername,
      orElse: () => <String, dynamic>{},
    );
    if (student.isEmpty) return [];
    return List<Map<String, dynamic>>.from(student['courses'] ?? []);
  }
}

// --- Filters Widget (inline) ---
class _FiltersRow extends StatelessWidget {
  final List<String> departments;
  final List<String> classes;
  final List<String> courses;
  final List<String> teachers;
  final String? selectedDepartment,
      selectedClass,
      selectedCourse,
      selectedTeacher;
  final bool loadingDepartments;
  final bool loadingClasses;
  final bool loadingCourses;
  final bool loadingTeachers;
  final Function({
    String? department,
    String? className,
    String? course,
    String? lecturer,
  })
  onChanged;
  final VoidCallback? onRefreshPressed;
  final VoidCallback? onPercentagePressed;

  const _FiltersRow({
    required this.departments,
    required this.classes,
    required this.courses,
    required this.teachers,
    this.selectedDepartment,
    this.selectedClass,
    this.selectedCourse,
    this.selectedTeacher,
    required this.loadingDepartments,
    required this.loadingClasses,
    required this.loadingCourses,
    required this.loadingTeachers,
    required this.onChanged,
    this.onPercentagePressed,
    this.onRefreshPressed,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
        _DropdownFilter(
          hint: "Department",
          value: selectedDepartment,
          items: departments,
          isLoading: loadingDepartments,
          isEnabled: true,
          onChanged: (val) => onChanged(department: val),
        ),
        _DropdownFilter(
          hint: "Class",
          value: selectedClass,
          items: classes,
          isLoading: loadingClasses,
          // Enable only after a department is selected
          isEnabled: selectedDepartment != null,
          onChanged: (val) => onChanged(className: val),
        ),
        _DropdownFilter(
          hint: "Course",
          value: selectedCourse,
          items: courses,
          isLoading: loadingCourses,
          // Enable only after a class is selected
          isEnabled: selectedClass != null,
          onChanged: (val) => onChanged(course: val),
        ),
        // NEW: Lecturer dropdown
        _DropdownFilter(
          hint: "Lecturer",
          value: selectedTeacher,
          items: teachers,
          isLoading: loadingTeachers,
          isEnabled: selectedDepartment != null,
          onChanged: (val) => onChanged(lecturer: val),
        ),
        // Percentage button + Refresh
        Padding(
          padding: EdgeInsets.only(left: compact ? 0 : 4.0),
          child: SizedBox(
            width: compact ? constraints.maxWidth : null,
            child: Row(
            mainAxisSize: compact ? MainAxisSize.max : MainAxisSize.min,
            children: [
              if (compact)
                Expanded(
                  child: ElevatedButton(
                    onPressed:
                        (selectedDepartment == null || onPercentagePressed == null)
                        ? null
                        : onPercentagePressed,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Percentage'),
                  ),
                )
              else
                ElevatedButton(
                  onPressed:
                      (selectedDepartment == null || onPercentagePressed == null)
                      ? null
                      : onPercentagePressed,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Percentage'),
                ),
              const SizedBox(width: 8),
              if (compact)
                Expanded(
                  child: ElevatedButton(
                    onPressed: onRefreshPressed,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text('Refresh'),
                  ),
                )
              else
                ElevatedButton(
                  onPressed: onRefreshPressed,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Refresh'),
                ),
            ],
          ),
        ),
        ),
      ],
        );
      },
    );
  }
}

class _DropdownFilter extends StatelessWidget {
  final String? value;
  final String hint;
  final List<String> items;
  final ValueChanged<String?> onChanged;
  final bool isLoading;
  final bool isEnabled;

  const _DropdownFilter({
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
    this.isLoading = false,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<SuperAdminColors>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isNarrow = MediaQuery.of(context).size.width < 760;
    final hintStyle = TextStyle(
      fontSize: 16,
      color:
          palette?.textSecondary ??
          (isDark ? const Color(0xFF9EA5B5) : Colors.black54),
    );
    final itemStyle = TextStyle(
      fontSize: 16,
      color:
          palette?.textPrimary ??
          (isDark ? const Color(0xFFE6EAF1) : Colors.black87),
    );
    final borderColor =
        palette?.border ??
        (isDark ? const Color(0xFF3A404E) : const Color(0xFFC7BECF));
    final borderShape = OutlineInputBorder(
      borderRadius: const BorderRadius.all(Radius.circular(10)),
      borderSide: BorderSide(color: borderColor, width: 1.1),
    );
    return SizedBox(
      width: isNarrow ? double.infinity : null,
      child: ConstrainedBox(
      constraints: isNarrow
          ? const BoxConstraints(minWidth: 0, maxWidth: double.infinity)
          : const BoxConstraints(minWidth: 150, maxWidth: 240),
      child: InputDecorator(
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 5,
          ),
          border: borderShape,
          enabledBorder: borderShape,
          focusedBorder: borderShape,
          isDense: true,
          filled: true,
          fillColor:
              palette?.inputFill ??
              (isDark ? const Color(0xFF2B303D) : Colors.white),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String?>(
            isExpanded: true,
            style: itemStyle,
            iconEnabledColor:
                palette?.iconColor ??
                (isDark ? const Color(0xFFE6EAF1) : const Color(0xFF6D6D6D)),
            value: value,
            hint: Text(
              isLoading
                  ? 'Loading...'
                  : (isEnabled
                        ? hint
                        : (hint == 'Class'
                              ? 'Select Department first'
                              : hint == 'Course'
                              ? 'Select Class first'
                              : hint)),
              style: hintStyle,
            ),
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text(hint, style: hintStyle),
              ),
              ...items.map(
                (item) => DropdownMenuItem<String?>(
                  value: item,
                  child: Text(item, style: itemStyle),
                ),
              ),
            ],
            onChanged: (isLoading || !isEnabled) ? null : onChanged,
            dropdownColor:
                palette?.surface ??
                (isDark ? const Color(0xFF262C3A) : Colors.white),
          ),
        ),
      ),
    ),
    );
  }
}

// --- Attendance Table ---
class _AttendanceTable extends StatelessWidget {
  final String department, className, course;
  final DateTime? date;
  final String searchText;
  final String? selectedStudentId;
  final Map<String, Map<String, List<Map<String, dynamic>>>>
  classSectionStudents;
  final Function(String studentId) onStudentSelected;

  const _AttendanceTable({
    required this.department,
    required this.className,
    required this.course,
    this.selectedStudentId,
    required this.classSectionStudents,
    this.date,
    required this.searchText,
    required this.onStudentSelected,
  });

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<SuperAdminColors>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sectionsMap = classSectionStudents[className] ?? {};
    final students = sectionsMap.values.expand((e) => e).toList();

    final filtered = students.where((row) {
      final name = (row['name'] ?? '').toString();
      final username = (row['username'] ?? '').toString();
      final matchesSearch =
          name.toLowerCase().contains(searchText.toLowerCase()) ||
          username.toLowerCase().contains(searchText.toLowerCase());
      return matchesSearch;
    }).toList();

    String initialsOf(String value) {
      final parts = value.trim().split(' ').where((p) => p.isNotEmpty).toList();
      if (parts.isEmpty) return '?';
      if (parts.length == 1) return parts.first[0].toUpperCase();
      return (parts[0][0] + parts[1][0]).toUpperCase();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final int tableColSpacing = constraints.maxWidth < 1200 ? 16 : 22;
        final scheme = Theme.of(context).colorScheme;
        final headerTextStyle = TextStyle(
          fontWeight: FontWeight.w700,
          color: palette?.textPrimary ?? scheme.onSurface,
        );
        final rowTextStyle = TextStyle(
          color: palette?.textPrimary ?? scheme.onSurface,
        );

        return Container(
          decoration: BoxDecoration(
            color: palette?.surface ?? scheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: palette?.border ?? scheme.outline.withValues(alpha: 0.35),
            ),
            boxShadow: [
              BoxShadow(
                color: Theme.of(
                  context,
                ).shadowColor.withValues(alpha: isDark ? 0.24 : 0.08),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
                showCheckboxColumn: false,
                columnSpacing: tableColSpacing.toDouble(),
                horizontalMargin: 16,
                dividerThickness: 0.8,
                headingRowHeight: 48,
                dataRowMinHeight: 56,
                dataRowMaxHeight: 56,
                headingRowColor: WidgetStateProperty.all<Color?>(
                  palette?.surfaceHigh ?? scheme.surfaceContainerHighest,
                ),
                columns: [
                  DataColumn(
                    label: Text("No", style: headerTextStyle),
                  ),
                  DataColumn(
                    label: Text("Student", style: headerTextStyle),
                  ),
                  DataColumn(
                    label: Text("Department", style: headerTextStyle),
                  ),
                  DataColumn(
                    label: Text("Class", style: headerTextStyle),
                  ),
                  DataColumn(
                    label: Text("Course", style: headerTextStyle),
                  ),
                ],
                rows: List.generate(filtered.length, (index) {
                  final row = filtered[index];
                  final username = row['username']?.toString() ?? '';
                  final fullName = row['name']?.toString() ?? '';
                  final selected = selectedStudentId == username;

                  void openStudentDetails() {
                    try {
                      final idVal = username;
                      if (idVal.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Student id is missing.'),
                          ),
                        );
                        return;
                      }
                      onStudentSelected(idVal);
                    } catch (e, st) {
                      debugPrint('Error selecting student: $e\n$st');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error selecting student: $e'),
                        ),
                      );
                    }
                  }

                  return DataRow(
                    selected: selected,
                    onSelectChanged: (_) => openStudentDetails(),
                    color: WidgetStateProperty.resolveWith<Color?>((states) {
                      if (states.contains(WidgetState.selected)) {
                        return scheme.primaryContainer.withValues(alpha: 0.55);
                      }
                      if (states.contains(WidgetState.hovered)) {
                        return scheme.surfaceContainerHighest.withValues(
                          alpha: 0.45,
                        );
                      }
                      return null;
                    }),
                    cells: [
                      DataCell(Text('${index + 1}', style: rowTextStyle)),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor:
                                  palette?.highlight ??
                                  scheme.primaryContainer.withValues(alpha: 0.7),
                              child: Text(
                                initialsOf(fullName.isEmpty ? username : fullName),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: palette?.textPrimary ??
                                      scheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  fullName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: rowTextStyle.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      DataCell(Text(department, style: rowTextStyle)),
                      DataCell(Text(className, style: rowTextStyle)),
                      DataCell(
                        Text(
                          course,
                          style: rowTextStyle.copyWith(fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        );
      },
    );
  }
}
