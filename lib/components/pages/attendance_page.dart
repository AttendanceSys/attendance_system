import 'package:flutter/material.dart';
import 'student_details_panel.dart';

class AttendanceUnifiedPage extends StatefulWidget {
  const AttendanceUnifiedPage({Key? key}) : super(key: key);

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

  final Map<String, Map<String, List<Map<String, dynamic>>>> classSectionStudents = {
    "B2CS": {
      "A": [
        {
          "id": "5555",
          "name": "Ali Hassan",
          "status": true,
          "courses": [
            {"course": "Cloud", "total": 12, "present": 10, "percentage": "83.3%"},
            {"course": "Networking", "total": 12, "present": 9, "percentage": "75%"},
            {"course": "Algorithms", "total": 12, "present": 11, "percentage": "91.6%"},
          ],
        },
        {
          "id": "6666",
          "name": "Qali Abdi",
          "status": false,
          "courses": [
            {"course": "Cloud", "total": 12, "present": 8, "percentage": "66.6%"},
            {"course": "Networking", "total": 12, "present": 10, "percentage": "83.3%"},
          ],
        },
      ],
      "B": [
        {
          "id": "8888",
          "name": "Ahmed Farah",
          "status": true,
          "courses": [
            {"course": "Cloud", "total": 12, "present": 12, "percentage": "100%"},
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
            {"course": "Cloud", "total": 12, "present": 11, "percentage": "91.6%"},
            {"course": "Algorithms", "total": 12, "present": 10, "percentage": "83.3%"},
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
            {"course": "Cloud", "total": 12, "present": 10, "percentage": "83.3%"},
            {"course": "Algorithms", "total": 12, "present": 12, "percentage": "100%"},
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
            {"course": "Minerals", "total": 12, "present": 10, "percentage": "83.3%"},
            {"course": "Geology", "total": 12, "present": 12, "percentage": "100%"},
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
            {"course": "Mapping", "total": 12, "present": 11, "percentage": "91.6%"},
            {"course": "Geology", "total": 12, "present": 10, "percentage": "83.3%"},
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

  // --- Calculated lists ---
  List<String> get classes => selectedDepartment != null ? departmentClasses[selectedDepartment!] ?? [] : [];
  List<String> get courses => selectedDepartment != null ? departmentCourses[selectedDepartment!] ?? [] : [];
  List<String> get sections {
    if (selectedClass == null) return [];
    final hasSections = classHasSections[selectedClass!] ?? false;
    return hasSections ? ["A", "B", "C", "D"] : ["None"];
  }

  // --- Student details logic ---
  List<Map<String, dynamic>> get filteredRecordsForStudent {
    if (selectedStudentId == null || selectedClass == null || selectedSection == null) return [];
    final students = classSectionStudents[selectedClass]?[selectedSection] ?? [];
    final student = students.firstWhere(
      (s) => s['id'] == selectedStudentId,
      orElse: () => <String, dynamic>{},
    );
    if (student.isEmpty) return [];
    List<Map<String, dynamic>> records = List<Map<String, dynamic>>.from(student['courses'] ?? []);
    return records;
  }

  // Update student attendance on edit/save
  void _updateAttendanceForStudent(List<Map<String, dynamic>> updatedRecords) {
    if (selectedStudentId == null || selectedClass == null || selectedSection == null) return;
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
    final showTable = selectedDepartment != null && selectedClass != null && selectedCourse != null && selectedSection != null && selectedStudentId == null;
    final showStudentDetails = selectedStudentId != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Attendance"),
      ),
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
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
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
              onChanged: ({
                String? department,
                String? className,
                String? course,
                String? section,
                DateTime? date,
              }) {
                setState(() {
                  if (department != null && department != selectedDepartment) {
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
                });
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: showTable
                  ? _AttendanceTable(
                      department: selectedDepartment!,
                      className: selectedClass!,
                      course: selectedCourse!,
                      section: selectedSection!,
                      date: selectedDate,
                      searchText: searchText,
                      classSectionStudents: classSectionStudents,
                      onStudentSelected: (studentId) {
                        setState(() {
                          selectedStudentId = studentId;
                        });
                      },
                      onStatusChanged: (studentId, newStatus) {
                        setState(() {
                          final students = classSectionStudents[selectedClass]?[selectedSection];
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
                    )
                  : showStudentDetails
                      ? StudentDetailsPanel(
                          studentId: selectedStudentId!,
                          selectedDate: selectedDate,
                          attendanceRecords: filteredRecordsForStudent,
                          searchText: searchText, // Pass main search to details panel!
                          onBack: () {
                            setState(() {
                              selectedStudentId = null;
                            });
                          },
                          onEdit: _updateAttendanceForStudent,
                        )
                      : Center(child: Text("Select all filters to view attendance")),
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
  final String? selectedDepartment, selectedClass, selectedCourse, selectedSection;
  final DateTime? selectedDate;
  final Function({
    String? department,
    String? className,
    String? course,
    String? section,
    DateTime? date,
  }) onChanged;

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
  final String hint;
  final String? value;
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
      child: DropdownButtonFormField<String>(
        value: value,
        hint: Text(hint),
        items: items
            .map((item) => DropdownMenuItem(value: item, child: Text(item)))
            .toList(),
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
              Text(date != null ? '${date!.day}/${date!.month}/${date!.year}' : 'Date'),
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
  final Map<String, Map<String, List<Map<String, dynamic>>>> classSectionStudents;
  final Function(String studentId) onStudentSelected;
  final void Function(String studentId, bool newStatus)? onStatusChanged;

  const _AttendanceTable({
    required this.department,
    required this.className,
    required this.course,
    required this.section,
    required this.classSectionStudents,
    this.date,
    required this.searchText,
    required this.onStudentSelected,
    this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    final students = classSectionStudents[className]?[section] ?? [];

    final filtered = students.where((row) {
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
                DataColumn(label: Text("No", style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text("ID", style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text("Student Name", style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text("Department", style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text("Class", style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text("Course", style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text("Status", style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: List.generate(filtered.length, (index) {
                final row = filtered[index];
                if (row == null || row.isEmpty) return null;
                return DataRow(
                  cells: [
                    DataCell(Text('${index + 1}')),
                    DataCell(Text(row['id']?.toString() ?? '')),
                    DataCell(
                      InkWell(
                        onTap: () => onStudentSelected(row['id']),
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
                    DataCell(Text('$className${section != "None" ? section : ""}')),
                    DataCell(Text(course)),
                    DataCell(
                      Switch(
                        value: row['status'] ?? false,
                        activeColor: Colors.green,
                        inactiveThumbColor: Colors.red,
                        onChanged: (val) {
                          if (onStatusChanged != null) {
                            onStatusChanged!(row['id'], val);
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