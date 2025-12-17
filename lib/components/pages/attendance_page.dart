import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:attendance_system/services/session.dart';
import 'student_details_panel.dart';

class AttendanceUnifiedPage extends StatefulWidget {
  const AttendanceUnifiedPage({super.key});

  @override
  State<AttendanceUnifiedPage> createState() => _AttendanceUnifiedPageState();
}

class _AttendanceUnifiedPageState extends State<AttendanceUnifiedPage> {
  // Return cached courses for this class if available
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Data sources populated from Firestore
  List<String> departments = [];
  List<String> departmentIds = [];
  List<String> classesForDept = [];
  List<String> coursesForClass = [];
  // Simple in-memory caches to avoid repeated Firestore queries
  final Map<String, List<String>> _classesCache = {};
  final Map<String, List<String>> _coursesCache = {};
  // Map class display name -> list of class doc ids (populated when loading classes)
  final Map<String, List<String>> _classDocIdsCache = {};

  bool _deptMatchesSessionFaculty(Map<String, dynamic> data) {
    if (Session.facultyRef == null) return true;
    final sessionId = Session.facultyRef!.id;
    final sessionPath = '/${Session.facultyRef!.path}';

    final cand =
        data['faculty_ref'] ??
        data['faculty_id'] ??
        data['faculty'] ??
        data['facultyId'];
    if (cand == null) return false;
    if (cand is DocumentReference) return cand.id == sessionId;
    if (cand is String) {
      if (cand == sessionId) return true;
      if (cand == sessionPath) return true;
      final normalized = cand.startsWith('/') ? cand : '/$cand';
      if (normalized == sessionPath) return true;
      final parts = cand.split('/').where((p) => p.isNotEmpty).toList();
      if (parts.isNotEmpty && parts.last == sessionId) return true;
    }
    return false;
  }

  // Roster grouped by class -> section -> list of student maps
  // Each student map includes 'docId' so we can update the student doc.
  Map<String, Map<String, List<Map<String, dynamic>>>> classSectionStudents =
      {};

  // UI selections
  // selectedDepartment holds the display name; selectedDepartmentId holds the doc id
  String? selectedDepartment;
  String? selectedDepartmentId;
  String? selectedClass;
  String? selectedCourse;
  String? selectedUsername;
  String? selectedStudentName;
  String? selectedStudentClass;
  String searchText = '';

  // Prefetch / loading state
  bool loadingDepartments = false;
  bool loadingClasses = false;
  bool loadingSubjects = false;
  bool loadingStudents = false;

  @override
  void initState() {
    super.initState();
    _loadDepartments();
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
      selectedDepartment = null;
      selectedDepartmentId = null;
      selectedClass = null;
      selectedCourse = null;
      classSectionStudents = {};
    });

    try {
      final Map<String, String> deptMap = {};

      // Use only Session.username (adjust here if your Session exposes a different id field)
      final currentUsername = (Session.username ?? '').toString();

      // 1) Try to find departments where head_of_department == currentUsername
      if (currentUsername.isNotEmpty) {
        try {
          final q = await _firestore
              .collection('departments')
              .where('head_of_department', isEqualTo: currentUsername)
              .where('status', isEqualTo: true)
              .get();

          for (final doc in q.docs) {
            final d = doc.data();
            if (!_deptMatchesSessionFaculty(d)) continue;
            final deptValue =
                (d['department_name'] ??
                        d['department_code'] ??
                        d['department'])
                    ?.toString() ??
                '';
            if (deptValue.isNotEmpty) deptMap[doc.id] = deptValue;
          }
        } catch (_) {
          // ignore and fall back
        }
      }

      // 2) Legacy fallback: if no departments found for this user, fall back to timetables-based discovery
      // If no departments found for this user, fetch departments collection (all active)
      if (deptMap.isEmpty) {
        try {
          final qs = await _firestore
              .collection('departments')
              .where('status', isEqualTo: true)
              .get();
          for (final doc in qs.docs) {
            final d = doc.data();
            if (!_deptMatchesSessionFaculty(d)) continue;
            final dep =
                (d['department_name'] ??
                        d['department_code'] ??
                        d['department'])
                    ?.toString() ??
                '';
            if (dep.isNotEmpty) deptMap[doc.id] = dep;
          }
        } catch (e) {
          debugPrint('Failed fallback departments fetch: $e');
        }
      }

      // Turn deptMap into parallel lists sorted by display name
      final entries = deptMap.entries.toList();
      entries.sort((a, b) => a.value.compareTo(b.value));
      setState(() {
        departmentIds = entries.map((e) => e.key).toList();
        departments = entries.map((e) => e.value).toList();
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
      // Return cached classes if available
      if (_classesCache.containsKey(dept) && _classesCache[dept]!.isNotEmpty) {
        setState(() {
          classesForDept = List<String>.from(_classesCache[dept]!);
        });
        return;
      }
      // Try multiple strategies to discover classes for the selected department.
      final clsSet = <String>{};

      // Helper to extract class name from class doc data
      String _extractClassName(Map<String, dynamic> d) =>
          (d['className'] ?? d['class_name'] ?? d['class'] ?? '')
              .toString()
              .trim();

      // 1) Direct match: try classes where 'department_ref' == dept (doc id),
      // then try where 'department' == dept (legacy/code)
      try {
        // try department_ref first
        try {
          final qsRef = await _firestore
              .collection('classes')
              .where('department_ref', isEqualTo: dept)
              .get();
          for (final doc in qsRef.docs) {
            final cls = _extractClassName(doc.data());
            if (cls.isNotEmpty) {
              clsSet.add(cls);
              _classDocIdsCache.putIfAbsent(cls, () => []).add(doc.id);
            }
          }
        } catch (_) {}

        // then try department field (code or name)
        if (clsSet.isEmpty) {
          final qs = await _firestore
              .collection('classes')
              .where('department', isEqualTo: dept)
              .get();
          for (final doc in qs.docs) {
            final cls = _extractClassName(doc.data());
            if (cls.isNotEmpty) {
              clsSet.add(cls);
              _classDocIdsCache.putIfAbsent(cls, () => []).add(doc.id);
            }
          }
        }
      } catch (e) {
        debugPrint('Direct classes by department failed: $e');
      }

      // 2) Try matching classes documents that store department name/code in different fields
      if (clsSet.isEmpty) {
        try {
          final qs = await _firestore.collection('classes').get();
          for (final doc in qs.docs) {
            final d = doc.data();
            final deptCandidates = <String>{
              (d['department_name'] ?? '').toString(),
              (d['departmentName'] ?? '').toString(),
              (d['department_code'] ?? '').toString(),
              (d['department'] ?? '').toString(),
            }..removeWhere((e) => e.isEmpty);
            for (final cand in deptCandidates) {
              if (_looseNameMatch(cand, dept)) {
                final cls = _extractClassName(d);
                if (cls.isNotEmpty) {
                  clsSet.add(cls);
                  _classDocIdsCache.putIfAbsent(cls, () => []).add(doc.id);
                }
                break;
              }
            }
          }
        } catch (e) {
          debugPrint('Scanning classes for dept fields failed: $e');
        }
      }

      // 3) Resolve department document(s) from 'departments' collection and query classes by doc id or code
      if (clsSet.isEmpty) {
        try {
          final deptQs = await _firestore
              .collection('departments')
              .where('status', isEqualTo: true)
              .get();
          final matchedDeptDocs =
              <QueryDocumentSnapshot<Map<String, dynamic>>>[];
          for (final d in deptQs.docs) {
            final data = d.data();
            final name = (data['department_name'] ?? data['department'] ?? '')
                .toString();
            final code = (data['department_code'] ?? '').toString();
            if (_looseNameMatch(name, dept) ||
                _looseNameMatch(code, dept) ||
                name == dept ||
                code == dept) {
              matchedDeptDocs.add(d);
            }
          }

          for (final md in matchedDeptDocs) {
            // try classes where department_ref equals the department doc id
            try {
              final qs = await _firestore
                  .collection('classes')
                  .where('department_ref', isEqualTo: md.id)
                  .get();
              for (final doc in qs.docs) {
                final cls = _extractClassName(doc.data());
                if (cls.isNotEmpty) {
                  clsSet.add(cls);
                  _classDocIdsCache.putIfAbsent(cls, () => []).add(doc.id);
                }
              }
            } catch (_) {}

            // try classes where department equals the department code (legacy)
            try {
              final code = (md.data()['department_code'] ?? '').toString();
              if (code.isNotEmpty) {
                final qs2 = await _firestore
                    .collection('classes')
                    .where('department', isEqualTo: code)
                    .get();
                for (final doc in qs2.docs) {
                  final cls = _extractClassName(doc.data());
                  if (cls.isNotEmpty) {
                    clsSet.add(cls);
                    _classDocIdsCache.putIfAbsent(cls, () => []).add(doc.id);
                  }
                }
              }
            } catch (_) {}
          }
        } catch (e) {
          debugPrint('Resolving departments docs failed: $e');
        }
      }

      // 4) Last fallback: legacy timetables
      if (clsSet.isEmpty) {
        try {
          final qs = await _firestore
              .collection('timetables')
              .where('department', isEqualTo: dept)
              .get();
          for (final doc in qs.docs) {
            final d = doc.data();
            final cls = (d['className'] ?? '').toString();
            if (cls.isNotEmpty) clsSet.add(cls);
          }
        } catch (e) {
          debugPrint('Failed to load classes from timetables fallback: $e');
        }
      }

      setState(() {
        classesForDept = clsSet.toList()..sort();
        // cache
        _classesCache[dept] = List<String>.from(classesForDept);
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

  Future<void> _loadSubjectsForClass(String cls) async {
    setState(() {
      loadingSubjects = true;
      coursesForClass = [];
      selectedCourse = null;
      classSectionStudents = {};
    });

    try {
      // Return cached courses for this class if available
      if (_coursesCache.containsKey(cls) && _coursesCache[cls]!.isNotEmpty) {
        setState(() {
          coursesForClass = List<String>.from(_coursesCache[cls]!);
        });
        return;
      }
      // Prefer querying classes collection to find matching class docs and then fetch courses
      final courseSet = <String>{};
      final classDocIds = <String>{};

      // If we already discovered class doc ids earlier when loading classes, use them.
      if (_classDocIdsCache.containsKey(cls)) {
        classDocIds.addAll(_classDocIdsCache[cls]!);
      }

      // Use cached course list if available
      try {
        // try to find class documents matching cls (several variants)
        final variants = <String>{
          cls.trim(),
          cls.trim().toUpperCase(),
          cls.trim().toLowerCase(),
          cls.replaceAll(' ', ''),
        }..removeWhere((e) => e.isEmpty);

        for (final v in variants) {
          try {
            final cQ = await _firestore
                .collection('classes')
                .where('className', isEqualTo: v)
                .get();
            for (final cd in cQ.docs) {
              classDocIds.add(cd.id);
              try {
                final cname =
                    (cd.data()['className'] ??
                            cd.data()['class_name'] ??
                            cd.data()['class'] ??
                            '')
                        .toString()
                        .trim();
                if (cname.isNotEmpty)
                  _classDocIdsCache.putIfAbsent(cname, () => []).add(cd.id);
              } catch (_) {}
            }
          } catch (_) {}
        }
      } catch (e) {
        debugPrint('Error finding class docs: $e');
      }

      // If we found class doc IDs, query courses by class ref
      if (classDocIds.isNotEmpty) {
        for (final cid in classDocIds) {
          // Query courses by class id (fast)
          try {
            final cq = await _firestore
                .collection('courses')
                .where('class', isEqualTo: cid)
                .get();
            for (final doc in cq.docs) {
              final data = doc.data();
              final name =
                  (data['course_name'] ??
                          data['course'] ??
                          data['course_code'] ??
                          '')
                      .toString();
              if (name.isNotEmpty) courseSet.add(name.trim());
            }
          } catch (e) {
            debugPrint('Error querying courses for class id $cid: $e');
          }
        }
      }

      // Fallback: try to query courses where 'class' equals the given cls string (in case cls is id)
      if (courseSet.isEmpty) {
        try {
          // Last-resort fallback: scan timetables for subjects (legacy)
          final cq = await _firestore
              .collection('courses')
              .where('class', isEqualTo: cls)
              .get();
          for (final doc in cq.docs) {
            final data = doc.data();
            final name =
                (data['course_name'] ??
                        data['course'] ??
                        data['course_code'] ??
                        '')
                    .toString();
            if (name.isNotEmpty) courseSet.add(name.trim());
          }
        } catch (_) {}
      }

      // Last-resort fallback: scan timetables for subjects (legacy)
      if (courseSet.isEmpty) {
        try {
          final qs = await _firestore
              .collection('timetables')
              .where('className', isEqualTo: cls)
              .get();
          for (final doc in qs.docs) {
            final d = doc.data();
            final gm = d['grid_meta'];
            if (gm is List) {
              for (final gmItem in gm) {
                if (gmItem is Map && gmItem['cells'] is List) {
                  for (final cell in (gmItem['cells'] as List)) {
                    if (cell is Map && cell['course'] != null) {
                      final c = cell['course'].toString().trim();
                      if (c.isNotEmpty) courseSet.add(c);
                    } else if (cell is String) {
                      final c = cell.toString().trim();
                      if (c.isNotEmpty) courseSet.add(c);
                    }
                  }
                }
              }
            }
          }
        } catch (e) {
          debugPrint('Failed legacy timetables subject fetch: $e');
        }
      }

      setState(() {
        coursesForClass = courseSet.toList()..sort();
        _coursesCache[cls] = List<String>.from(coursesForClass);
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
    if (selectedDepartmentId == null ||
        selectedClass == null ||
        selectedCourse == null)
      return;

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
            for (final cd in cQ.docs) classDocIds.add(cd.id);
          } catch (_) {}
        }
        if (classDocIds.isEmpty) {
          try {
            // Prefer classes where department_ref == selectedDepartmentId
            try {
              final classesInDept = await _firestore
                  .collection('classes')
                  .where('department_ref', isEqualTo: selectedDepartmentId)
                  .get();
              for (final cd in classesInDept.docs) {
                final cname = (cd.data()['className'] ?? '').toString();
                if (cname.isNotEmpty && _looseNameMatch(cname, selectedClass))
                  classDocIds.add(cd.id);
              }
            } catch (_) {}

            // Fallback: try department field matching id or display name
            if (classDocIds.isEmpty) {
              try {
                final qs = await _firestore
                    .collection('classes')
                    .where('department', isEqualTo: selectedDepartmentId)
                    .get();
                for (final cd in qs.docs) {
                  final cname = (cd.data()['className'] ?? '').toString();
                  if (cname.isNotEmpty && _looseNameMatch(cname, selectedClass))
                    classDocIds.add(cd.id);
                }
              } catch (_) {}

              if (classDocIds.isEmpty && selectedDepartment != null) {
                try {
                  final qs2 = await _firestore
                      .collection('classes')
                      .where('department', isEqualTo: selectedDepartment)
                      .get();
                  for (final cd in qs2.docs) {
                    final cname = (cd.data()['className'] ?? '').toString();
                    if (cname.isNotEmpty &&
                        _looseNameMatch(cname, selectedClass))
                      classDocIds.add(cd.id);
                  }
                } catch (_) {}
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
          // Try students where department equals the selectedDepartmentId first
          QuerySnapshot<Map<String, dynamic>> deptQ;
          try {
            deptQ = await _firestore
                .collection('students')
                .where('department', isEqualTo: selectedDepartmentId)
                .limit(2000)
                .get();
          } catch (_) {
            // fallback to department display name if id-based lookup fails
            deptQ = await _firestore
                .collection('students')
                .where('department', isEqualTo: selectedDepartment)
                .limit(2000)
                .get();
          }
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

  // status update removed

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
    final showTable =
        selectedDepartmentId != null &&
        selectedClass != null &&
        selectedCourse != null &&
        selectedUsername == null;
    final showStudentDetails = selectedUsername != null;

    return Scaffold(
      appBar: AppBar(title: const Text("Attendance")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              decoration: InputDecoration(
                hintText: "Search Attendance...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 16,
                ),
              ),
              onChanged: (value) => setState(() => searchText = value),
            ),
            const SizedBox(height: 12),
            _FiltersRow(
              departments: departments,
              departmentIds: departmentIds,
              classes: classes,
              courses: courses,
              selectedDepartment: selectedDepartment,
              selectedDepartmentId: selectedDepartmentId,
              selectedClass: selectedClass,
              selectedCourse: selectedCourse,
              onChanged:
                  ({String? department, String? className, String? course}) {
                    setState(() {
                      if (department != null &&
                          department != selectedDepartmentId) {
                        // department is the department doc id
                        selectedDepartmentId = department;
                        final idx = departmentIds.indexOf(department);
                        selectedDepartment = idx >= 0 ? departments[idx] : null;
                        selectedClass = null;
                        selectedCourse = null;
                        classesForDept = [];
                        coursesForClass = [];
                        classSectionStudents = {};
                        _loadClassesForDepartment(department);
                      }
                      if (className != null && className != selectedClass) {
                        selectedClass = className;
                        selectedCourse = null;
                        coursesForClass = [];
                        classSectionStudents = {};
                        _loadSubjectsForClass(className);
                      }
                      if (course != null && course != selectedCourse) {
                        selectedCourse = course;
                        classSectionStudents = {};
                        if (selectedDepartmentId != null &&
                            selectedClass != null &&
                            selectedCourse != null) {
                          _fetchStudentsForSelection();
                        }
                      }
                    });
                  },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: showTable
                  ? _AttendanceTable(
                      department: selectedDepartment ?? '',
                      className: selectedClass ?? '',
                      course: selectedCourse ?? '',
                      searchText: searchText,
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
                              content: Text('Student data not available.'),
                            ),
                          );
                          return;
                        }
                        setState(() {
                          selectedUsername = studentId;
                          selectedStudentName = student!['name']?.toString();
                          selectedStudentClass =
                              '$selectedClass${(foundSection != null && foundSection != "None") ? foundSection : ""}';
                        });
                      },
                    )
                  : showStudentDetails
                  ? StudentDetailsPanel(
                      studentId: selectedUsername!,
                      studentName: selectedStudentName,
                      studentClass: selectedStudentClass,
                      selectedCourse: selectedCourse,
                      attendanceRecords: _getRecordsForSelectedStudent(),
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
                  : Center(
                      child: Text("Select all filters to view attendance"),
                    ),
            ),
          ],
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
  final List<String>? departmentIds;
  final List<String> classes;
  final List<String> courses;
  final String? selectedDepartment, selectedClass, selectedCourse;
  final String? selectedDepartmentId;
  final Function({String? department, String? className, String? course})
  onChanged;

  const _FiltersRow({
    required this.departments,
    this.departmentIds,
    required this.classes,
    required this.courses,
    this.selectedDepartment,
    this.selectedDepartmentId,
    this.selectedClass,
    this.selectedCourse,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        // Department dropdown: prefer using doc ids as values when provided
        if (departmentIds != null && departmentIds!.isNotEmpty)
          SizedBox(
            width: 230,
            child: DropdownButtonFormField<String?>(
              value: selectedDepartmentId,
              hint: const Text('Dep'),
              items: [
                DropdownMenuItem<String?>(value: null, child: Text('Dep')),
                for (var i = 0; i < departmentIds!.length; i++)
                  DropdownMenuItem<String?>(
                    value: departmentIds![i],
                    child: Text(departments[i]),
                  ),
              ],
              onChanged: (val) => onChanged(department: val),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  vertical: 8,
                  horizontal: 12,
                ),
              ),
            ),
          )
        else
          _DropdownFilter(
            hint: "Dep",
            value: selectedDepartment,
            items: departments,
            onChanged: (val) => onChanged(department: val),
          ),
        _DropdownFilter(
          hint: "Class",
          value: selectedClass,
          items: classes,
          onChanged: (val) => onChanged(className: val),
        ),
        _DropdownFilter(
          hint: "Course",
          value: selectedCourse,
          items: courses,
          onChanged: (val) => onChanged(course: val),
        ),
        // Date filter removed
      ],
    );
  }
}

class _DropdownFilter extends StatelessWidget {
  final String? value;
  final String hint;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _DropdownFilter({
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : double.infinity;
        final width = available.isFinite
            ? math.min(230, available).toDouble()
            : 230.0;
        return SizedBox(
          width: width,
          child: DropdownButtonFormField<String?>(
            value: value,
            hint: Text(hint),
            items: [
              DropdownMenuItem<String?>(value: null, child: Text(hint)),
              ...items
                  .map(
                    (item) => DropdownMenuItem<String?>(
                      value: item,
                      child: Text(item),
                    ),
                  )
                  .toList(),
            ],
            onChanged: onChanged,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            ),
          ),
        );
      },
    );
  }
}

// Date filter widget removed

// --- Attendance Table ---
class _AttendanceTable extends StatelessWidget {
  final String department, className, course;
  final String searchText;
  final Map<String, Map<String, List<Map<String, dynamic>>>>
  classSectionStudents;
  final Function(String studentId) onStudentSelected;

  const _AttendanceTable({
    required this.department,
    required this.className,
    required this.course,
    required this.classSectionStudents,
    required this.searchText,
    required this.onStudentSelected,
  });

  @override
  Widget build(BuildContext context) {
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

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: DataTable(
              columnSpacing: 24,
              headingRowHeight: 44,
              dataRowHeight: 40,
              columns: const [
                DataColumn(
                  label: Text(
                    "No",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    "Username",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    "full Name",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    "Department",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    "Class",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    "Course",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                // Status column removed
              ],
              rows: List.generate(filtered.length, (index) {
                final row = filtered[index];
                return DataRow(
                  cells: [
                    DataCell(Text('${index + 1}')),
                    DataCell(Text(row['username']?.toString() ?? '')),
                    DataCell(
                      InkWell(
                        onTap: () {
                          try {
                            final idVal = row['username']?.toString() ?? '';
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
                        },
                        child: Text(
                          row['name']?.toString() ?? '',
                          style: const TextStyle(
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                    DataCell(Text(department)),
                    DataCell(Text(className)),
                    DataCell(Text(course)),
                    // Status control removed
                  ],
                );
              }),
            ),
          ),
        );
      },
    );
  }
}
