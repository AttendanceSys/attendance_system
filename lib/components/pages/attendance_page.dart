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

  // Data sources populated from Firestore
  List<String> departments = [];
  List<String> classesForDept = [];
  List<String> coursesForClass = [];
  // Lookups to resolve ids from names for queries
  final Map<String, String> _deptNameToId = {};
  final Map<String, String> _classNameToId = {};

  // Roster grouped by class -> section -> list of student maps
  // Each student map includes 'docId' so we can update the student doc.
  Map<String, Map<String, List<Map<String, dynamic>>>> classSectionStudents =
      {};

  // UI selections
  String? selectedDepartment;
  String? selectedClass;
  String? selectedCourse;
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
      _deptNameToId.clear();
      _classNameToId.clear();
      selectedDepartment = null;
      selectedClass = null;
      selectedCourse = null;
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
        final status = data['status'] == true;
        final courses = (data['courses'] is List)
            ? List<Map<String, dynamic>>.from(data['courses'])
            : <Map<String, dynamic>>[];
        final section = (data['section'] ?? data['section_name'] ?? 'None')
            .toString();
        final studentMap = <String, dynamic>{
          'username': username,
          'name': fullname,
          'status': status,
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
  Future<void> _updateStudentStatusInFirestore(
    String docId,
    bool status,
  ) async {
    try {
      await _firestore.collection('students').doc(docId).update({
        'status': status,
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update student status: $e')),
      );
    }
  }

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
        selectedDepartment != null &&
        selectedClass != null &&
        selectedCourse != null &&
        selectedUsername == null;
    final showStudentDetails = selectedUsername != null;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(
                'Attendance',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(
                    context,
                  ).extension<SuperAdminColors>()?.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              SearchAddBar(
                hintText: 'Search Attendance...',
                buttonText: '',
                onAddPressed: () {},
                onChanged: (value) => setState(() => searchText = value),
              ),
              const SizedBox(height: 10),
              _FiltersRow(
                departments: departments,
                classes: classes,
                courses: courses,
                selectedDepartment: selectedDepartment,
                selectedClass: selectedClass,
                selectedCourse: selectedCourse,
                loadingDepartments: loadingDepartments,
                loadingClasses: loadingClasses,
                loadingCourses: loadingSubjects,
                onChanged:
                    ({String? department, String? className, String? course}) {
                      setState(() {
                        if (department != null &&
                            department != selectedDepartment) {
                          selectedDepartment = department;
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
                          if (selectedDepartment != null &&
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
                        date: selectedDate,
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
                        onStatusChanged: (studentId, newStatus) async {
                          setState(() {
                            final sectionsMap =
                                classSectionStudents[selectedClass] ?? {};
                            for (final list in sectionsMap.values) {
                              final student = list.firstWhere(
                                (s) => s['username'] == studentId,
                                orElse: () => <String, dynamic>{},
                              );
                              if (student.isNotEmpty) {
                                student['status'] = newStatus;
                                break;
                              }
                            }
                          });
                          String? docId;
                          final sectionsMap =
                              classSectionStudents[selectedClass] ?? {};
                          for (final list in sectionsMap.values) {
                            final student = list.firstWhere(
                              (s) => s['username'] == studentId,
                              orElse: () => <String, dynamic>{},
                            );
                            if (student.isNotEmpty) {
                              docId = student['docId']?.toString();
                              break;
                            }
                          }
                          if (docId != null) {
                            await _updateStudentStatusInFirestore(
                              docId,
                              newStatus,
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Could not find student document to update.',
                                ),
                              ),
                            );
                          }
                        },
                      )
                    : showStudentDetails
                    ? StudentDetailsPanel(
                        studentId: selectedUsername!,
                        studentName: selectedStudentName,
                        studentClass: selectedStudentClass,
                        selectedDate: selectedDate,
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
  final String? selectedDepartment, selectedClass, selectedCourse;
  final bool loadingDepartments;
  final bool loadingClasses;
  final bool loadingCourses;
  final Function({String? department, String? className, String? course})
  onChanged;

  const _FiltersRow({
    required this.departments,
    required this.classes,
    required this.courses,
    this.selectedDepartment,
    this.selectedClass,
    this.selectedCourse,
    required this.loadingDepartments,
    required this.loadingClasses,
    required this.loadingCourses,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
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
      ],
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
      borderRadius: const BorderRadius.all(Radius.circular(8)),
      borderSide: BorderSide(color: borderColor, width: 1.1),
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 150, maxWidth: 240),
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
    );
  }
}

// --- Attendance Table ---
class _AttendanceTable extends StatelessWidget {
  final String department, className, course;
  final DateTime? date;
  final String searchText;
  final Map<String, Map<String, List<Map<String, dynamic>>>>
  classSectionStudents;
  final Function(String studentId) onStudentSelected;
  final void Function(String studentId, bool newStatus)? onStatusChanged;

  const _AttendanceTable({
    required this.department,
    required this.className,
    required this.course,
    required this.classSectionStudents,
    this.date,
    required this.searchText,
    required this.onStudentSelected,
    this.onStatusChanged,
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
                DataColumn(
                  label: Text(
                    "Status",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
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
                    DataCell(
                      Switch(
                        value: row['status'] ?? false,
                        activeColor: Colors.green,
                        inactiveThumbColor: Colors.red,
                        onChanged: (val) {
                          if (onStatusChanged != null) {
                            onStatusChanged!(row['username'], val);
                          }
                        },
                      ),
                    ),
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