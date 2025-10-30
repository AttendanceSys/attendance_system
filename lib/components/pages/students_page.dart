import 'dart:async';

import 'package:flutter/material.dart';
import '../../models/student.dart';
import '../../models/department.dart';
import '../../models/classes.dart';
import '../../hooks/use_students.dart';
import '../../hooks/use_departments.dart';
import '../../hooks/use_classes.dart';
import '../popup/add_student_popup.dart';
import '../cards/searchBar.dart';

class StudentsPage extends StatefulWidget {
  final String? facultyId;

  const StudentsPage({super.key, this.facultyId});

  @override
  State<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage> {
  final List<Student> _students = [];
  final UseStudents _studentsService = UseStudents();
  StreamSubscription<List<Map<String, dynamic>>>? _studentsSub;

  final List<String> _genders = ['Male', 'Female'];
  final UseDepartments _departmentsService = UseDepartments();
  final UseClasses _classesService = UseClasses();

  List<Department> _departments = [];
  List<SchoolClass> _classes = [];

  String _searchText = '';
  int? _selectedIndex;

  // Loading & error state (made consistent with CoursesPage / DepartmentsPage)
  bool _isLoading = false;
  String? _loadError;

  List<Student> get _filteredStudents => _students
      .where(
        (student) =>
            student.id.toLowerCase().contains(_searchText.toLowerCase()) ||
            student.fullName.toLowerCase().contains(
              _searchText.toLowerCase(),
            ) ||
            student.gender.toLowerCase().contains(_searchText.toLowerCase()) ||
            student.department.toLowerCase().contains(
              _searchText.toLowerCase(),
            ) ||
            student.className.toLowerCase().contains(_searchText.toLowerCase()),
      )
      .toList();

  Future<void> _showAddStudentPopup() async {
    String? resolvedFacultyId = widget.facultyId;
    if (resolvedFacultyId == null || resolvedFacultyId.isEmpty) {
      try {
        resolvedFacultyId = await _studentsService.resolveAdminFacultyId();
      } catch (_) {
        resolvedFacultyId = null;
      }
    }

    final result = await showDialog<Student>(
      context: context,
      builder: (context) => AddStudentPopup(
        genders: _genders,
        departments: _departments,
        classes: _classes,
        facultyId: resolvedFacultyId,
      ),
    );
    if (result != null) {
      try {
        await _studentsService.addStudent(result, facultyId: widget.facultyId);
        // refresh list
        await _loadStudents();
        setState(() => _selectedIndex = null);
      } catch (e) {
        // show error
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to add student: $e')));
        }
      }
    }
  }

  Future<void> _showEditStudentPopup() async {
    if (_selectedIndex == null) return;
    final student = _filteredStudents[_selectedIndex!];
    String? resolvedFacultyId = widget.facultyId;
    if (resolvedFacultyId == null || resolvedFacultyId.isEmpty) {
      try {
        resolvedFacultyId = await _studentsService.resolveAdminFacultyId();
      } catch (_) {
        resolvedFacultyId = null;
      }
    }

    final result = await showDialog<Student>(
      context: context,
      builder: (context) => AddStudentPopup(
        student: student,
        genders: _genders,
        departments: _departments,
        classes: _classes,
        facultyId: resolvedFacultyId,
      ),
    );
    if (result != null) {
      try {
        await _studentsService.updateStudent(
          student.id,
          result,
          facultyId: widget.facultyId,
        );
        await _loadStudents();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update student: $e')),
          );
        }
      }
    }
  }

  Future<void> _confirmDeleteStudent() async {
    if (_selectedIndex == null) return;
    final student = _filteredStudents[_selectedIndex!];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Student"),
        content: Text("Are you sure you want to delete '${student.fullName}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        await _studentsService.deleteStudent(student.id);
        await _loadStudents();
        setState(() => _selectedIndex = null);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete student: $e')),
          );
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadStudents();
    _loadDepartmentsAndClasses();
    // subscribe to realtime changes (with robust onError/onDone handling)
    // when a realtime change occurs, re-fetch students so we get related
    // department/class display names (fetchStudents requests related rows)
    _startStudentsSub();
  }

  @override
  void dispose() {
    _stopStudentsSub();
    super.dispose();
  }

  void _startStudentsSub() {
    // Cancel any existing subscription first
    _studentsSub?.cancel();

    _studentsSub = _studentsService.subscribeStudents().listen(
      (_) async {
        try {
          await _loadStudents();
        } catch (e, st) {
          debugPrint(
            'Error while reloading students from realtime event: $e\n$st',
          );
        }
      },
      onError: (error, stack) async {
        debugPrint('students realtime subscription error: $error\n$stack');
        if (mounted) {
          setState(() {
            _loadError = 'Realtime subscription error: $error';
          });
        }

        // Cancel the failing subscription and retry after a short delay.
        try {
          await _studentsSub?.cancel();
        } catch (_) {}
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _startStudentsSub();
        });
      },
      onDone: () {
        debugPrint('students realtime subscription closed (done) — restarting');
        if (mounted) {
          Future.delayed(const Duration(seconds: 2), _startStudentsSub);
        }
      },
      cancelOnError: true,
    );
  }

  void _stopStudentsSub() {
    try {
      _studentsSub?.cancel();
    } catch (_) {}
    _studentsSub = null;
  }

  Future<void> _loadStudents() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }
    try {
      final list = await _studentsService.fetchStudents(
        facultyId: widget.facultyId,
      );
      if (mounted) {
        setState(() {
          _students
            ..clear()
            ..addAll(list);
        });
      }
    } catch (e, st) {
      debugPrint('Failed to load students: $e\n$st');
      if (mounted) {
        setState(() {
          _loadError = e.toString();
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load students: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadDepartmentsAndClasses() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }
    try {
      final deps = await _departmentsService.fetchDepartments(
        facultyId: widget.facultyId,
      );
      final cls = await _classesService.fetchClasses(
        facultyId: widget.facultyId,
      );
      if (mounted) {
        setState(() {
          _departments = deps;
          _classes = cls;
        });
      }
    } catch (e, st) {
      debugPrint('Failed to load departments/classes: $e\n$st');
      if (mounted) {
        setState(() {
          _loadError = e.toString();
        });
        // non-blocking, still allow students to load
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load departments/classes: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _handleRowTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth > 800;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: LinearProgressIndicator(),
            ),
          if (_loadError != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'Failed to load students: $_loadError',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                "Students",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Reload from DB',
                icon: const Icon(Icons.refresh),
                onPressed: _isLoading
                    ? null
                    : () async {
                        debugPrint('Manual reload requested');
                        await _loadStudents();
                        await _loadDepartmentsAndClasses();
                      },
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SearchAddBar(
                      hintText: "Search students...",
                      buttonText: "Add Students",
                      onAddPressed: _showAddStudentPopup,
                      onChanged: (value) {
                        setState(() {
                          _searchText = value;
                          _selectedIndex = null;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SizedBox(
                          width: 80,
                          height: 36,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 0,
                                horizontal: 0,
                              ),
                            ),
                            onPressed: _selectedIndex == null
                                ? null
                                : _showEditStudentPopup,
                            child: const Text(
                              "Edit",
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 80,
                          height: 36,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 0,
                                horizontal: 0,
                              ),
                            ),
                            onPressed: _selectedIndex == null
                                ? null
                                : _confirmDeleteStudent,
                            child: const Text(
                              "Delete",
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                setState(() {
                  _selectedIndex = null;
                });
              },
              child: Container(
                width: double.infinity,
                color: Colors.transparent,
                child: isDesktop
                    ? _buildDesktopTable()
                    : SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: _buildMobileTable(),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Desktop/tablet: clean, wide fixed column design (like Departments screenshot)
  Widget _buildDesktopTable() {
    return Table(
      columnWidths: const {
        0: FixedColumnWidth(50), // No
        1: FixedColumnWidth(120), // ID
        2: FixedColumnWidth(160), // Name
        3: FixedColumnWidth(100), // Gender
        4: FixedColumnWidth(120), // Department
        5: FixedColumnWidth(120), // Class
      },
      border: TableBorder(
        horizontalInside: BorderSide(color: Colors.grey.shade300),
      ),
      children: [
        TableRow(
          children: [
            _tableHeaderCell("No"),
            _tableHeaderCell("Username"),
            _tableHeaderCell("Student name"),
            _tableHeaderCell("Gender"),
            _tableHeaderCell("Department"),
            _tableHeaderCell("Class"),
          ],
        ),
        for (int index = 0; index < _filteredStudents.length; index++)
          TableRow(
            decoration: BoxDecoration(
              color: _selectedIndex == index
                  ? Colors.blue.shade50
                  : Colors.transparent,
            ),
            children: [
              _tableBodyCell('${index + 1}', onTap: () => _handleRowTap(index)),
              _tableBodyCell(
                _filteredStudents[index].username,
                onTap: () => _handleRowTap(index),
              ),
              _tableBodyCell(
                _filteredStudents[index].fullName,
                onTap: () => _handleRowTap(index),
              ),
              _tableBodyCell(
                _filteredStudents[index].gender,
                onTap: () => _handleRowTap(index),
              ),
              _tableBodyCell(
                _filteredStudents[index].department,
                onTap: () => _handleRowTap(index),
              ),
              _tableBodyCell(
                _filteredStudents[index].className,
                onTap: () => _handleRowTap(index),
              ),
            ],
          ),
      ],
    );
  }

  // Mobile: keep existing scrollable table
  Widget _buildMobileTable() {
    return Table(
      defaultColumnWidth: const IntrinsicColumnWidth(),
      border: TableBorder(
        horizontalInside: BorderSide(color: Colors.grey.shade300),
      ),
      children: [
        TableRow(
          children: [
            _tableHeaderCell("No"),
            _tableHeaderCell("Username"),
            _tableHeaderCell("Student name"),
            _tableHeaderCell("Gender"),
            _tableHeaderCell("Department"),
            _tableHeaderCell("Class"),
          ],
        ),
        for (int index = 0; index < _filteredStudents.length; index++)
          TableRow(
            decoration: BoxDecoration(
              color: _selectedIndex == index
                  ? Colors.blue.shade50
                  : Colors.transparent,
            ),
            children: [
              _tableBodyCell('${index + 1}', onTap: () => _handleRowTap(index)),
              _tableBodyCell(
                _filteredStudents[index].username,
                onTap: () => _handleRowTap(index),
              ),
              _tableBodyCell(
                _filteredStudents[index].fullName,
                onTap: () => _handleRowTap(index),
              ),
              _tableBodyCell(
                _filteredStudents[index].gender,
                onTap: () => _handleRowTap(index),
              ),
              _tableBodyCell(
                _filteredStudents[index].department,
                onTap: () => _handleRowTap(index),
              ),
              _tableBodyCell(
                _filteredStudents[index].className,
                onTap: () => _handleRowTap(index),
              ),
            ],
          ),
      ],
    );
  }

  Widget _tableHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold),
        textAlign: TextAlign.left,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _tableBodyCell(String text, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Text(text, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}
