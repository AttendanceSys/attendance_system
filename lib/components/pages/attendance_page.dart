import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'student_details_panel.dart';
import 'dart:async';

import '../../hooks/use_attendance_fetch.dart';
import '../../models/attendance.dart';

class AttendanceUnifiedPage extends StatefulWidget {
  const AttendanceUnifiedPage({super.key});

  @override
  State<AttendanceUnifiedPage> createState() => _AttendanceUnifiedPageState();
}

class _AttendanceUnifiedPageState extends State<AttendanceUnifiedPage> {
  final Map<String, List<String>> departmentClasses = {
    "CS": ["B2CS", "B3CS", "B4CS"],
    "GEO": ["B2GEO", "B3GEO"],
  };

  final Map<String, List<String>> departmentCourses = {
    "CS": ["Cloud", "Networking", "Algorithms"],
    "GEO": ["Minerals", "Geology", "Mapping"],
  };

  final Map<String, bool> classHasSections = {
    "B2CS": true,
    "B3CS": true,
    "B4CS": false,
    "B2GEO": false,
    "B3GEO": true,
  };

  final Map<String, Map<String, List<Map<String, dynamic>>>>
  classSectionStudents = {
    "B2CS": {
      "A": [
        {
          "id": "5555",
          "name": "Ali Hassan",
          "status": true,
          "courses": [
            {
              "course": "Cloud",
              "total": 12,
              "present": 10,
              "percentage": "83.3%",
            },
            {
              "course": "Networking",
              "total": 12,
              "present": 9,
              "percentage": "75%",
            },
            {
              "course": "Algorithms",
              "total": 12,
              "present": 11,
              "percentage": "91.6%",
            },
          ],
        },
        {
          "id": "6666",
          "name": "Qali Abdi",
          "status": false,
          "courses": [
            {
              "course": "Cloud",
              "total": 12,
              "present": 8,
              "percentage": "66.6%",
            },
            {
              "course": "Networking",
              "total": 12,
              "present": 10,
              "percentage": "83.3%",
            },
          ],
        },
      ],
      "B": [
        {
          "id": "8888",
          "name": "Ahmed Farah",
          "status": true,
          "courses": [
            {
              "course": "Cloud",
              "total": 12,
              "present": 12,
              "percentage": "100%",
            },
          ],
        },
      ],
    },
    "B3CS": {
      "A": [
        {
          "id": "9999",
          "name": "Fatima Noor",
          "status": true,
          "courses": [
            {
              "course": "Cloud",
              "total": 12,
              "present": 11,
              "percentage": "91.6%",
            },
            {
              "course": "Algorithms",
              "total": 12,
              "present": 10,
              "percentage": "83.3%",
            },
          ],
        },
      ],
    },
    "B4CS": {
      "None": [
        {
          "id": "7777",
          "name": "Layla Yusuf",
          "status": false,
          "courses": [
            {
              "course": "Cloud",
              "total": 12,
              "present": 10,
              "percentage": "83.3%",
            },
            {
              "course": "Algorithms",
              "total": 12,
              "present": 12,
              "percentage": "100%",
            },
          ],
        },
      ],
    },
    "B2GEO": {
      "None": [
        {
          "id": "1234",
          "name": "Mohamed Ali",
          "status": true,
          "courses": [
            {
              "course": "Minerals",
              "total": 12,
              "present": 10,
              "percentage": "83.3%",
            },
            {
              "course": "Geology",
              "total": 12,
              "present": 12,
              "percentage": "100%",
            },
          ],
        },
      ],
    },
    "B3GEO": {
      "A": [
        {
          "id": "4321",
          "name": "Asha Osman",
          "status": true,
          "courses": [
            {
              "course": "Mapping",
              "total": 12,
              "present": 11,
              "percentage": "91.6%",
            },
            {
              "course": "Geology",
              "total": 12,
              "present": 10,
              "percentage": "83.3%",
            },
          ],
        },
      ],
    },
  };

  String? selectedDepartment;
  String? selectedClass;
  String? selectedCourse;
  String? selectedSection;
  DateTime? selectedDate;
  String? selectedStudentId;
  String searchText = '';

  // --- Attendance fetch state ---
  final UseAttendanceFetch _attendanceHook = UseAttendanceFetch();
  List<Attendance> _attendanceList = [];
  StreamSubscription? _attendanceSubscription;
  bool _attendanceLoading = false;

  @override
  void initState() {
    super.initState();
    // initial load (if some defaults are set later this will be a no-op)
    // do not await here
    WidgetsBinding.instance.addPostFrameCallback((_) => _reloadAttendance());
  }

  @override
  void dispose() {
    _attendanceSubscription?.cancel();
    super.dispose();
  }

  void _reloadAttendance() async {
    // Only fetch when department, class, course and section are selected
    if (selectedDepartment == null ||
        selectedClass == null ||
        selectedCourse == null)
      return;

    setState(() {
      _attendanceLoading = true;
    });

    try {
      final list = await _attendanceHook.fetchAttendance(
        departmentId: selectedDepartment,
        classId: selectedClass,
        courseId: selectedCourse,
        date: selectedDate,
        limit: 200,
        page: 0,
      );
      setState(() {
        _attendanceList = list;
      });

      // setup real-time subscription
      _attendanceSubscription?.cancel();
      _attendanceSubscription = _attendanceHook.subscribeAttendance().listen((
        rows,
      ) {
        // Convert rows to Attendance model where possible and update
        final mapped = rows.map((e) {
          final rawDept = e['department'];
          final rawClass = e['class'];
          String extractName(dynamic value, String key) {
            if (value == null) return '';
            if (value is Map) return (value[key] ?? '') as String;
            if (value is List && value.isNotEmpty) {
              final first = value.first;
              if (first is Map) return (first[key] ?? '') as String;
            }
            return '';
          }

          final deptName =
              (e['department_name'] ?? extractName(rawDept, 'department_name'))
                  as String;
          final className =
              (e['class_name'] ?? extractName(rawClass, 'class_name'))
                  as String;
          final studentName = (() {
            if (e['student'] is Map)
              return (e['student']['fullname'] ?? '') as String;
            if (e['student'] is String) return e['student'] as String;
            return '';
          })();

          return Attendance(
            id: e['id'] as String,
            name: studentName,
            department: deptName,
            className: className,
            status: true,
          );
        }).toList();

        setState(() {
          _attendanceList = mapped;
        });
      });
    } catch (e) {
      // keep previous data but stop loading
    } finally {
      setState(() {
        _attendanceLoading = false;
      });
    }
  }

  // --- Calculated lists ---
  List<String> get classes => selectedDepartment != null
      ? departmentClasses[selectedDepartment!] ?? []
      : [];
  List<String> get courses => selectedDepartment != null
      ? departmentCourses[selectedDepartment!] ?? []
      : [];
  List<String> get sections {
    if (selectedClass == null) return [];
    final hasSections = classHasSections[selectedClass!] ?? false;
    return hasSections ? ["A", "B", "C", "D"] : ["None"];
  }

  // --- Student details logic ---
  List<Map<String, dynamic>> get filteredRecordsForStudent {
    if (selectedStudentId == null ||
        selectedClass == null ||
        selectedSection == null)
      return [];
    final students =
        classSectionStudents[selectedClass]?[selectedSection] ?? [];
    final student = students.firstWhere(
      (s) => s['id'] == selectedStudentId,
      orElse: () => <String, dynamic>{},
    );
    if (student.isEmpty) return [];
    List<Map<String, dynamic>> records = List<Map<String, dynamic>>.from(
      student['courses'] ?? [],
    );
    return records;
  }

  // Update student attendance on edit/save
  void _updateAttendanceForStudent(List<Map<String, dynamic>> updatedRecords) {
    if (selectedStudentId == null ||
        selectedClass == null ||
        selectedSection == null)
      return;
    final students = classSectionStudents[selectedClass]?[selectedSection];
    if (students != null) {
      final student = students.firstWhere(
        (s) => s['id'] == selectedStudentId,
        orElse: () => <String, dynamic>{},
      );
      if (student.isNotEmpty) {
        student['courses'] = updatedRecords;
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final showTable =
        selectedDepartment != null &&
        selectedClass != null &&
        selectedCourse != null &&
        selectedSection != null &&
        selectedStudentId == null;
    final showStudentDetails = selectedStudentId != null;

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
              departments: departmentClasses.keys.toList(),
              classes: classes,
              courses: courses,
              sections: sections.isNotEmpty ? sections : ["None"],
              selectedDepartment: selectedDepartment,
              selectedClass: selectedClass,
              selectedCourse: selectedCourse,
              selectedSection: selectedSection,
              selectedDate: selectedDate,
              onChanged:
                  ({
                    String? department,
                    String? className,
                    String? course,
                    String? section,
                    DateTime? date,
                  }) {
                    setState(() {
                      if (department != null &&
                          department != selectedDepartment) {
                        selectedDepartment = department;
                        selectedClass = null;
                        selectedCourse = null;
                        selectedSection = null;
                      }
                      if (className != null && className != selectedClass) {
                        selectedClass = className;
                        selectedSection = null;
                      }
                      if (course != null) selectedCourse = course;
                      if (section != null && section != selectedSection) {
                        selectedSection = section;
                      }
                      if (date != null) selectedDate = date;
                      // reload attendance when filters change
                      _reloadAttendance();
                    });
                  },
            ),
            const SizedBox(height: 16),
            const SizedBox(height: 16),
            Expanded(
              child: showTable
                  ? (_attendanceLoading
                        ? const Center(child: CircularProgressIndicator())
                        : _AttendanceTable(
                            department: selectedDepartment!,
                            className: selectedClass!,
                            course: selectedCourse!,
                            section: selectedSection!,
                            date: selectedDate,
                            searchText: searchText,
                            classSectionStudents: classSectionStudents,
                            attendanceList: _attendanceList,
                            onStudentSelected: (studentId) {
                              setState(() {
                                selectedStudentId = studentId;
                              });
                            },
                            onStatusChanged: (studentId, newStatus) {
                              setState(() {
                                final students =
                                    classSectionStudents[selectedClass]?[selectedSection];
                                if (students != null) {
                                  final student = students.firstWhere(
                                    (s) => s['id'] == studentId,
                                    orElse: () => <String, dynamic>{},
                                  );
                                  if (student.isNotEmpty) {
                                    student['status'] = newStatus;
                                  }
                                }
                              });
                            },
                          ))
                  : showStudentDetails
                  ? StudentDetailsPanel(
                      studentId: selectedStudentId!,
                      selectedDate: selectedDate,
                      attendanceRecords: filteredRecordsForStudent,
                      searchText:
                          searchText, // Pass main search to details panel!
                      onBack: () {
                        setState(() {
                          selectedStudentId = null;
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
}

// --- Filters Widget (inline, not separate file) ---
class _FiltersRow extends StatelessWidget {
  final List<String> departments;
  final List<String> classes;
  final List<String> courses;
  final List<String> sections;
  final String? selectedDepartment,
      selectedClass,
      selectedCourse,
      selectedSection;
  final DateTime? selectedDate;
  final Function({
    String? department,
    String? className,
    String? course,
    String? section,
    DateTime? date,
  })
  onChanged;

  const _FiltersRow({
    required this.departments,
    required this.classes,
    required this.courses,
    required this.sections,
    this.selectedDepartment,
    this.selectedClass,
    this.selectedCourse,
    this.selectedSection,
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
          hint: "Department",
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
        _DropdownFilter(
          hint: "Section",
          value: selectedSection,
          items: sections,
          onChanged: (val) => onChanged(section: val),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final usableWidth =
            (constraints.maxWidth.isFinite
                    ? math.min(170, constraints.maxWidth)
                    : 170.0)
                .toDouble();
        return SizedBox(
          width: usableWidth,
          child: DropdownButtonFormField<String>(
            isExpanded: true,
            value: value,
            hint: Text(hint),
            items: [
              DropdownMenuItem(
                value: null,
                child: Text(
                  'Select $hint',
                  style: const TextStyle(color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ...items
                  .map(
                    (item) => DropdownMenuItem(
                      value: item,
                      child: Text(item, overflow: TextOverflow.ellipsis),
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
            children: [
              Expanded(
                child: Text(
                  date != null
                      ? '${date!.day}/${date!.month}/${date!.year}'
                      : 'Date',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
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
  final String department, className, course, section;
  final DateTime? date;
  final String searchText;
  final Map<String, Map<String, List<Map<String, dynamic>>>>
  classSectionStudents;
  final List<Attendance>? attendanceList;
  final Function(String studentId) onStudentSelected;
  final void Function(String studentId, bool newStatus)? onStatusChanged;

  const _AttendanceTable({
    required this.department,
    required this.className,
    required this.course,
    required this.section,
    required this.classSectionStudents,
    this.attendanceList,
    this.date,
    required this.searchText,
    required this.onStudentSelected,
    this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    // If attendanceList is provided (from backend), use it. Otherwise fall back
    // to the local demo `classSectionStudents` map used previously.
    final bool usingRemote =
        attendanceList != null && attendanceList!.isNotEmpty;

    final filtered = usingRemote
        ? attendanceList!.where((a) {
            final q = searchText.toLowerCase();
            return a.name.toLowerCase().contains(q) ||
                a.id.toLowerCase().contains(q);
          }).toList()
        : (classSectionStudents[className]?[section] ?? []).where((row) {
            final matchesSearch =
                row['name'].toLowerCase().contains(searchText.toLowerCase()) ||
                row['id'].toLowerCase().contains(searchText.toLowerCase());
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
                    "ID",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    "Student Name",
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
                if (usingRemote) {
                  final Attendance a = row as Attendance;
                  return DataRow(
                    cells: [
                      DataCell(Text('${index + 1}')),
                      DataCell(Text(a.id)),
                      DataCell(
                        InkWell(
                          onTap: () => onStudentSelected(a.id),
                          child: Text(
                            a.name,
                            style: const TextStyle(
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                      DataCell(Text(a.department)),
                      DataCell(Text(a.className)),
                      DataCell(Text(course)),
                      DataCell(
                        Switch(
                          value: a.status,
                          activeColor: Colors.green,
                          inactiveThumbColor: Colors.red,
                          onChanged: (val) {
                            if (onStatusChanged != null) {
                              onStatusChanged!(a.id, val);
                            }
                          },
                        ),
                      ),
                    ],
                  );
                }

                // fallback to demo row map
                final map = row as Map<String, dynamic>;
                if (map.isEmpty) return null;
                return DataRow(
                  cells: [
                    DataCell(Text('${index + 1}')),
                    DataCell(Text(map['id']?.toString() ?? '')),
                    DataCell(
                      InkWell(
                        onTap: () => onStudentSelected(map['id']),
                        child: Text(
                          map['name']?.toString() ?? '',
                          style: const TextStyle(
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                    DataCell(Text(department)),
                    DataCell(
                      Text('$className${section != "None" ? section : ""}'),
                    ),
                    DataCell(Text(course)),
                    DataCell(
                      Switch(
                        value: map['status'] ?? false,
                        activeColor: Colors.green,
                        inactiveThumbColor: Colors.red,
                        onChanged: (val) {
                          if (onStatusChanged != null) {
                            onStatusChanged!(map['id'], val);
                          }
                        },
                      ),
                    ),
                  ],
                );
              }).whereType<DataRow>().toList(),
            ),
          ),
        );
      },
    );
  }
}