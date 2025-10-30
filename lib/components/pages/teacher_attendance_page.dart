import 'package:flutter/material.dart';
import '../../hooks/use_attendance1.dart';
import '../../hooks/use_students.dart';
import '../../models/student.dart';

class TeacherAttendancePage extends StatefulWidget {
  const TeacherAttendancePage({super.key});

  @override
  State<TeacherAttendancePage> createState() => _TeacherAttendancePageState();
}

class _TeacherAttendancePageState extends State<TeacherAttendancePage> {
  final UseAttendance _useAttendance = UseAttendance();
  final UseStudents _useStudents = UseStudents();

  // UI state
  List<Map<String, dynamic>> students = [];
  List<Student> _fetchedStudents = [];
  bool loading = false;

  // dropdown data from DB
  List<Map<String, String>> _departments = [];
  List<Map<String, String>> _classes = [];

  String? departmentId;
  String? classId;

  // attendance date (YYYY-MM-DD)
  String date = DateTime.now().toIso8601String().substring(0, 10);

  @override
  void initState() {
    super.initState();
    _loadDropdowns();
  }

  Future<void> _loadDropdowns() async {
    setState(() {
      loading = true;
    });

    try {
      final depts = await _useStudents.fetchDepartments();
      String? firstDeptId;
      if (depts.isNotEmpty) {
        firstDeptId = depts.first['id'];
      }

      final classes = await _useStudents.fetchClasses(
        departmentId: firstDeptId,
      );

      setState(() {
        _departments = depts;
        _classes = classes;
        departmentId = firstDeptId;
        classId = classes.isNotEmpty ? classes.first['id'] : null;
      });

      if (departmentId != null && classId != null) {
        await _loadForSelection();
      }
    } catch (e) {
      debugPrint('Failed to load dropdowns: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load departments/classes: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> _onDepartmentChanged(String? newDeptId) async {
    if (newDeptId == null) return;
    setState(() {
      departmentId = newDeptId;
      classId = null;
      _classes = [];
      students = [];
    });

    try {
      final classes = await _useStudents.fetchClasses(
        departmentId: departmentId,
      );
      setState(() {
        _classes = classes;
        classId = classes.isNotEmpty ? classes.first['id'] : null;
      });

      if (classId != null) {
        await _loadForSelection();
      }
    } catch (e) {
      debugPrint('Failed to load classes for dept: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load classes: $e')));
      }
    }
  }

  Future<void> _onClassChanged(String? newClassId) async {
    if (newClassId == null) return;
    setState(() {
      classId = newClassId;
      students = [];
    });
    await _loadForSelection();
  }

  Future<void> _loadForSelection() async {
    if (departmentId == null || classId == null) return;

    setState(() {
      loading = true;
      students = [];
      _fetchedStudents = [];
    });

    try {
      // 1) Fetch students by deptId & classId (server-side)
      final fetched = await _useStudents.fetchStudentsByDeptClassId(
        departmentId: departmentId!,
        classId: classId!,
      );
      _fetchedStudents = fetched;

      // 2) Initialize attendance rows for those student IDs for the selected date
      final studentIds = _fetchedStudents
          .map((s) => s.id)
          .whereType<String>()
          .toList();
      await _useAttendance.initializeAttendanceForStudents(
        departmentId: departmentId!,
        classId: classId!,
        date: date,
        studentIds: studentIds,
        defaultPresent: false,
      );

      // 3) Fetch attendance rows with relations filtered by departmentId/classId/date
      final attRows = await _useAttendance.fetchAttendanceWithRelations(
        departmentId: departmentId,
        classId: classId,
        date: date,
      );

      // 4) Map attendance rows that belong to our fetched students
      // Deduplicate by student (in case the attendance table contains duplicated rows
      // for the same student/date). It's better to enforce a DB-constraint like
      // UNIQUE(student, date) to prevent duplicates, but we guard here client-side.
      final Set<String> wantedIds = _fetchedStudents.map((s) => s.id).toSet();

      // Keep only the first attendance row per student id
      final Map<String, Map<String, dynamic>> byStudent = {};
      for (final r in attRows) {
        final student = r['student'];
        String? sid;
        if (student is Map) {
          sid = (student['id'] ?? student['username'])?.toString();
        }
        if (sid == null) continue;
        if (!wantedIds.contains(sid)) continue;
        if (!byStudent.containsKey(sid)) {
          byStudent[sid] = Map<String, dynamic>.from(r as Map);
        }
      }

      final uniqueRows = byStudent.values.toList();

      final uiList = uniqueRows.map<Map<String, dynamic>>((r) {
        final student = r['student'] as Map;
        final status = r['status']?.toString();
        final present = status != null && status.toLowerCase() == 'present';
        final name = (student['fullname'] ?? student['username'] ?? '')
            .toString();
        // Show username as the ID in the table when available (falls back to uuid)
        final displayId =
            (student['username'] ?? student['id'])?.toString() ?? '';
        return {
          'id': displayId,
          'name': name,
          'present': present,
          'attendanceRow': r,
        };
      }).toList();

      setState(() {
        students = uiList;
      });
    } catch (e) {
      debugPrint('Error loading attendance: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading attendance: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> _togglePresent(int index, bool v) async {
    setState(() {
      students[index]['present'] = v;
    });

    final row = students[index]['attendanceRow'] as Map<String, dynamic>?;

    final deptId =
        departmentId ??
        (row != null && row['department'] is String
            ? row['department'] as String
            : '');
    final clsId =
        classId ??
        (row != null && row['class'] is String ? row['class'] as String : '');

    try {
      await _useAttendance.updateAttendanceSingle(
        studentId: students[index]['id'] as String,
        date: date,
        present: v,
        departmentId: deptId,
        classId: clsId,
      );

      final att = students[index]['attendanceRow'] as Map<String, dynamic>?;
      if (att != null) {
        att['status'] = v ? 'present' : 'absent';
      }
    } catch (e) {
      debugPrint('Failed to update attendance single: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
      }
      setState(() {
        students[index]['present'] = !v;
      });
    }
  }

  Future<void> _submitAll() async {
    if (students.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No students to submit')));
      }
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final updates = students.map<Map<String, dynamic>>((s) {
        return {
          'studentId': s['id'] as String,
          'present': s['present'] as bool,
        };
      }).toList();

      final deptId = departmentId ?? '';
      final clsId = classId ?? '';

      await _useAttendance.batchUpdateAttendance(
        departmentId: deptId,
        classId: clsId,
        date: date,
        updates: updates,
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Attendance submitted')));
      }
      await _loadForSelection();
    } catch (e) {
      debugPrint('Batch submit failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Submit failed: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Widget _dropdownFromData({
    required String? value,
    required List<Map<String, String>> items,
    required ValueChanged<String?> onChanged,
    required String hint,
  }) {
    return DropdownButton<String>(
      value: value,
      hint: Text(hint),
      items: items
          .map(
            (e) =>
                DropdownMenuItem(value: e['id'], child: Text(e['name'] ?? '')),
          )
          .toList(),
      onChanged: onChanged,
      style: const TextStyle(fontSize: 18, color: Colors.black87),
      underline: const SizedBox(),
      borderRadius: BorderRadius.circular(10),
      dropdownColor: Colors.white,
    );
  }

  Widget _headerCell(
    String text, {
    int flex = 1,
    TextAlign align = TextAlign.left,
  }) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        textAlign: align,
      ),
    );
  }

  Widget _tableCell(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
        child: Text(text, style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Attendance",
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 14,
            runSpacing: 12,
            children: [
              _dropdownFromData(
                value: departmentId,
                items: _departments,
                onChanged: (v) => _onDepartmentChanged(v),
                hint: 'Select department',
              ),
              _dropdownFromData(
                value: classId,
                items: _classes,
                onChanged: (v) => _onClassChanged(v),
                hint: 'Select class',
              ),
            ],
          ),
          const SizedBox(height: 28),
          Container(
            color: Colors.grey[100],
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Row(
              children: [
                _headerCell("No", flex: 1),
                _headerCell("ID", flex: 2),
                _headerCell("Student Name", flex: 4),
                _headerCell("Status", flex: 2, align: TextAlign.center),
              ],
            ),
          ),
          if (loading)
            const Expanded(child: Center(child: CircularProgressIndicator()))
          else
            Expanded(
              child: ListView.builder(
                itemCount: students.length,
                itemBuilder: (context, index) {
                  final s = students[index];
                  return Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey.shade300,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        _tableCell('${index + 1}', flex: 1),
                        _tableCell(s['id']?.toString() ?? '', flex: 2),
                        _tableCell(s['name']?.toString() ?? '', flex: 4),
                        Expanded(
                          flex: 2,
                          child: Center(
                            child: Switch(
                              value: s['present'] as bool? ?? false,
                              onChanged: (v) => _togglePresent(index, v),
                              activeColor: Colors.green,
                              inactiveThumbColor: Colors.redAccent,
                              inactiveTrackColor: Colors.red[200],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          Align(
            alignment: Alignment.bottomRight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(
                  horizontal: 34,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              onPressed: loading ? null : _submitAll,
              child: const Text(
                "Submit",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
