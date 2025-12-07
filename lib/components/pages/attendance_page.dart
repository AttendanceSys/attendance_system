import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:attendance_system/services/session.dart';
import 'student_details_panel.dart';

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
      selectedDepartment = null;
      selectedClass = null;
      selectedCourse = null;
      classSectionStudents = {};
    });

    try {
      final deptSet = <String>{};

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
            final deptValue =
                (d['department_code'] ??
                        d['department_name'] ??
                        d['department'])
                    ?.toString() ??
                '';
            if (deptValue.isNotEmpty) deptSet.add(deptValue);
          }
        } catch (_) {
          // ignore and fall back
        }
      }

      // 2) Legacy fallback: if no departments found for this user, fall back to timetables-based discovery
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
      final qs = await _firestore
          .collection('timetables')
          .where('department', isEqualTo: dept)
          .get();
      final clsSet = <String>{};
      for (final doc in qs.docs) {
        final d = doc.data();
        final cls = (d['className'] ?? '').toString();
        if (cls.isNotEmpty) clsSet.add(cls);
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
      final qs = await _firestore
          .collection('timetables')
          .where('className', isEqualTo: cls)
          .get();
      final courseSet = <String>{};
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
            final classesInDept = await _firestore
                .collection('classes')
                .where('department', isEqualTo: selectedDepartment)
                .get();
            for (final cd in classesInDept.docs) {
              final cname = (cd.data()['className'] ?? '').toString();
              if (cname.isNotEmpty && _looseNameMatch(cname, selectedClass))
                classDocIds.add(cd.id);
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
              classes: classes,
              courses: courses,
              selectedDepartment: selectedDepartment,
              selectedClass: selectedClass,
              selectedCourse: selectedCourse,
              selectedDate: selectedDate,
              onChanged:
                  ({
                    String? department,
                    String? className,
                    String? course,
                    DateTime? date,
                  }) {
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
                      if (date != null) selectedDate = date;
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
  final DateTime? selectedDate;
  final Function({
    String? department,
    String? className,
    String? course,
    DateTime? date,
  })
  onChanged;

  const _FiltersRow({
    required this.departments,
    required this.classes,
    required this.courses,
    this.selectedDepartment,
    this.selectedClass,
    this.selectedCourse,
    this.selectedDate,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
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
        _DateFilter(
          date: selectedDate,
          onChanged: (date) => onChanged(date: date),
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

  const _DropdownFilter({
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 170,
      child: DropdownButtonFormField<String?>(
        value: value,
        hint: Text(hint),
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text('Select')),
          ...items
              .map(
                (item) =>
                    DropdownMenuItem<String?>(value: item, child: Text(item)),
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
  }
}

class _DateFilter extends StatelessWidget {
  final DateTime? date;
  final ValueChanged<DateTime> onChanged;
  const _DateFilter({required this.date, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      child: InkWell(
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: date ?? DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
          );
          if (picked != null) onChanged(picked);
        },
        child: InputDecorator(
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                date != null
                    ? '${date!.day}/${date!.month}/${date!.year}'
                    : 'Date',
              ),
              const Icon(Icons.calendar_today, size: 18),
            ],
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
