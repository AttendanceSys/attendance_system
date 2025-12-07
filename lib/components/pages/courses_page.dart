import 'package:flutter/material.dart';
import '../../models/course.dart';
import '../../hooks/use_courses.dart';
import '../../hooks/use_lectureres.dart';
import '../../hooks/use_classes.dart';
import '../../hooks/use_departments.dart';
import '../popup/add_course_popup.dart';
import '../cards/searchBar.dart';

class CoursesPage extends StatefulWidget {
  const CoursesPage({super.key});

  @override
  State<CoursesPage> createState() => _CoursesPageState();
}

class _CoursesPageState extends State<CoursesPage> {
  final UseCourses _courseHook = UseCourses();
  final List<Course> _courses = [];

  final UseTeachers _teacherHook = UseTeachers();
  final UseClasses _classesHook = UseClasses();
  final UseDepartments _departmentsHook = UseDepartments();

  final List<String> teachers = [];
  final List<String> classes = [];
  final List<String> departments = [];

  // helper maps to translate ids -> display names when API returns ids
  final Map<String, String> _deptNameById = {};
  final Map<String, String> _teacherNameById = {};
  final Map<String, String> _classNameById = {};

  String? _facultyId;

  String _searchText = '';
  int? _selectedIndex;

  bool _isLoading = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    // Load masters (teachers/classes/departments) first so we can resolve
    // the admin's faculty id and then fetch faculty-scoped courses.
    _loadMasters().then((_) => _loadCourses());
  }

  Future<void> _loadMasters() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      // Resolve faculty id first so classes/departments are fetched
      // scoped to the current admin's faculty (avoids empty lists on web
      // startup when auth state hasn't stabilised yet).
      final facultyId = await _departmentsHook.resolveAdminFacultyId();

      // Persist resolved faculty id so other methods (add/update/fetch)
      // can pass it explicitly to hooks. Keep it in state so UI can
      // react if needed.
      if (facultyId != null && facultyId.isNotEmpty) {
        _facultyId = facultyId;
      }

      // fetch teachers, classes and departments in parallel (scope by faculty)
      final results = await Future.wait([
        _teacherHook.fetchTeachers(),
        _classesHook.fetchClasses(facultyId: facultyId),
        _departmentsHook.fetchDepartments(facultyId: facultyId),
      ]);

      final teacherRows = results[0] as List<Teacher>;
      final classRows = (results[1] as List).cast();
      final deptRows = (results[2] as List).cast();

      if (!mounted) return;

      // Build id->display maps for robust edit-time selection
      final Map<String, String> deptMap = {};
      for (final d in deptRows) {
        try {
          if (d == null) continue;
          if (d is Map) {
            final id = (d['id'] ?? '').toString();
            final name =
                (d['department_name'] ??
                        d['name'] ??
                        d['department_code'] ??
                        id)
                    .toString();
            if (id.isNotEmpty) deptMap[id] = name;
          } else {
            final id = (d as dynamic).id?.toString() ?? '';
            final name = (d as dynamic).name?.toString() ?? '';
            if (id.isNotEmpty) deptMap[id] = name;
          }
        } catch (_) {}
      }

      final Map<String, String> classMap = {};
      for (final c in classRows) {
        try {
          if (c == null) continue;
          if (c is Map) {
            final id = (c['id'] ?? '').toString();
            final name = (c['class_name'] ?? c['name'] ?? id).toString();
            if (id.isNotEmpty) classMap[id] = name;
          } else {
            final id = (c as dynamic).id?.toString() ?? '';
            final name = (c as dynamic).name?.toString() ?? '';
            if (id.isNotEmpty) classMap[id] = name;
          }
        } catch (_) {}
      }

      final Map<String, String> teacherMap = {};
      for (final t in teacherRows) {
        try {
          final id = (t.id ?? '').toString();
          final name = ((t.teacherName ?? t.username) ?? '').toString();
          if (id.isNotEmpty && name.isNotEmpty) teacherMap[id] = name;
        } catch (_) {}
      }

      setState(() {
        // ensure faculty id makes it into state updates
        if (facultyId != null && facultyId.isNotEmpty) _facultyId = facultyId;
        _deptNameById.clear();
        _deptNameById.addAll(deptMap);
        _classNameById.clear();
        _classNameById.addAll(classMap);
        _teacherNameById.clear();
        _teacherNameById.addAll(teacherMap);

        teachers.clear();
        teachers.addAll(
          teacherRows
              .map((t) => (t.teacherName ?? t.username ?? '').trim())
              .where((s) => s.isNotEmpty),
        );

        classes.clear();
        classes.addAll(
          classRows
              .map((c) {
                try {
                  if (c == null) return '';
                  if (c is Map) {
                    return (c['class_name'] ?? c['name'] ?? c['id'])
                            ?.toString() ??
                        '';
                  }
                  return (c as dynamic).name?.toString() ?? '';
                } catch (_) {
                  return '';
                }
              })
              .where((s) => s.isNotEmpty),
        );
        departments.clear();
        departments.addAll(
          deptRows
              .map((d) {
                try {
                  if (d == null) return '';
                  if (d is Map) {
                    return (d['department_name'] ??
                                d['name'] ??
                                d['department_code'] ??
                                d['id'])
                            ?.toString() ??
                        '';
                  }
                  return (d as dynamic).name?.toString() ?? '';
                } catch (_) {
                  return '';
                }
              })
              .where((s) => s.isNotEmpty),
        );
      });
    } catch (e, st) {
      debugPrint('Failed to load teachers/classes: $e\n$st');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = e.toString();
      });
    }
  }

  Future<void> _loadCourses() async {
    try {
      final data = await _courseHook.fetchCourses(facultyId: _facultyId);
      if (!mounted) return;
      setState(() {
        _courses.clear();
        _courses.addAll(data);
        _isLoading = false;
      });
    } catch (e, st) {
      debugPrint('Error loading courses: $e\n$st');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = e.toString();
      });
    }
  }

  List<Course> get _filteredCourses => _courses
      .where(
        (course) =>
            course.code.toLowerCase().contains(_searchText.toLowerCase()) ||
            course.name.toLowerCase().contains(_searchText.toLowerCase()) ||
            course.teacher.toLowerCase().contains(_searchText.toLowerCase()) ||
            course.className.toLowerCase().contains(
              _searchText.toLowerCase(),
            ) ||
            course.department.toLowerCase().contains(
              _searchText.toLowerCase(),
            ) ||
            course.semester.toString().contains(_searchText),
      )
      .toList();

  Future<void> _showAddCoursePopup() async {
    final result = await showDialog<Course>(
      context: context,
      builder: (context) => AddCoursePopup(
        teachers: teachers,
        classes: classes,
        departments: _deptNameById.entries
            .map((e) => {'id': e.key, 'name': e.value})
            .toList(),
        facultyId: _facultyId,
      ),
    );
    if (result != null) {
      try {
        await _courseHook.addCourse(result, facultyId: _facultyId);
        await _loadCourses();
        setState(() => _selectedIndex = null);
      } catch (e) {
        debugPrint('Failed to add course: $e');
      }
    }
  }

  Future<void> _showEditCoursePopup() async {
    if (_selectedIndex == null) return;
    final course = _filteredCourses[_selectedIndex!];
    // Ensure the course passed to the popup has department set to the
    // department id (if we can resolve it). `course.department` may be a
    // display name or an id depending on what the API returned.
    String initialDeptId = '';
    if (course.department.isNotEmpty) {
      // if it's already an id present in map, use it
      if (_deptNameById.containsKey(course.department)) {
        initialDeptId = course.department;
      } else {
        // try to find an id by matching the display name
        try {
          final entry = _deptNameById.entries.firstWhere(
            (e) => e.value == course.department,
          );
          initialDeptId = entry.key;
        } catch (_) {
          initialDeptId = '';
        }
      }
    }

    final popupCourse = Course(
      id: course.id,
      code: course.code,
      name: course.name,
      teacher: course.teacher,
      className: course.className,
      department: initialDeptId,
      semester: course.semester,
    );

    final result = await showDialog<Course>(
      context: context,
      builder: (context) => AddCoursePopup(
        course: popupCourse,
        teachers: teachers,
        classes: classes,
        departments: _deptNameById.entries
            .map((e) => {'id': e.key, 'name': e.value})
            .toList(),
        facultyId: _facultyId,
      ),
    );
    if (result != null) {
      try {
        // course should have an id when loaded from DB
        await _courseHook.updateCourse(
          course.id,
          result,
          facultyId: _facultyId,
        );
        await _loadCourses();
      } catch (e) {
        debugPrint('Failed to update course: $e');
      }
    }
  }

  Future<void> _confirmDeleteCourse() async {
    if (_selectedIndex == null) return;
    final course = _filteredCourses[_selectedIndex!];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Course"),
        content: Text("Are you sure you want to delete '${course.name}'?"),
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
        await _courseHook.deleteCourse(course.id);
        await _loadCourses();
        setState(() => _selectedIndex = null);
      } catch (e) {
        debugPrint('Failed to delete course: $e');
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
      padding: const EdgeInsets.all(32.0),
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
                'Failed to load courses: $_loadError',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                "Courses",
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
                        await _loadMasters();
                        await _loadCourses();
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
                      hintText: "Search Courses...",
                      buttonText: "Add Course",
                      onAddPressed: _showAddCoursePopup,
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
                                : _showEditCoursePopup,
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
                                : _confirmDeleteCourse,
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
                // clicking blank area unselects
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

  Widget _buildDesktopTable() {
    return Table(
      columnWidths: const {
        0: FixedColumnWidth(64), // No
        1: FixedColumnWidth(100), // sub Code
        2: FixedColumnWidth(140), // sub name
        3: FixedColumnWidth(140), // Teach Assi
        4: FixedColumnWidth(120), // Class
        5: FixedColumnWidth(120), // Department
        6: FixedColumnWidth(90), // Semester
      },
      border: TableBorder(
        horizontalInside: BorderSide(color: Colors.grey.shade300),
      ),
      children: [
        TableRow(
          children: [
            _tableHeaderCell("No"),
            _tableHeaderCell("Course Code"),
            _tableHeaderCell("Course Name"),
            _tableHeaderCell("Teacher"),
            _tableHeaderCell("Class"),
            _tableHeaderCell("Department"),
            _tableHeaderCell("Semester"),
          ],
        ),
        for (int index = 0; index < _filteredCourses.length; index++)
          TableRow(
            decoration: BoxDecoration(
              color: _selectedIndex == index
                  ? Colors.blue.shade50
                  : Colors.transparent,
            ),
            children: [
              _tableBodyCell('${index + 1}', onTap: () => _handleRowTap(index)),
              _tableBodyCell(
                _filteredCourses[index].code,
                onTap: () => _handleRowTap(index),
              ),
              _tableBodyCell(
                _filteredCourses[index].name,
                onTap: () => _handleRowTap(index),
              ),
              _tableBodyCell(
                _filteredCourses[index].teacher,
                onTap: () => _handleRowTap(index),
              ),
              _tableBodyCell(
                _filteredCourses[index].className,
                onTap: () => _handleRowTap(index),
              ),
              _tableBodyCell(
                _filteredCourses[index].department,
                onTap: () => _handleRowTap(index),
              ),
              _tableBodyCell(
                _filteredCourses[index].semester.toString(),
                onTap: () => _handleRowTap(index),
              ),
            ],
          ),
      ],
    );
  }

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
            _tableHeaderCell("Course Code"),
            _tableHeaderCell("Course Name"),
            _tableHeaderCell("Teacher"),
            _tableHeaderCell("Class"),
            _tableHeaderCell("Department"),
            _tableHeaderCell("Semester"),
          ],
        ),
        for (int index = 0; index < _filteredCourses.length; index++)
          TableRow(
            decoration: BoxDecoration(
              color: _selectedIndex == index
                  ? Colors.blue.shade50
                  : Colors.transparent,
            ),
            children: [
              _tableBodyCell('${index + 1}', onTap: () => _handleRowTap(index)),
              _tableBodyCell(
                _filteredCourses[index].code,
                onTap: () => _handleRowTap(index),
              ),
              _tableBodyCell(
                _filteredCourses[index].name,
                onTap: () => _handleRowTap(index),
              ),
              _tableBodyCell(
                _filteredCourses[index].teacher,
                onTap: () => _handleRowTap(index),
              ),
              _tableBodyCell(
                _filteredCourses[index].className,
                onTap: () => _handleRowTap(index),
              ),
              _tableBodyCell(
                _filteredCourses[index].department,
                onTap: () => _handleRowTap(index),
              ),
              _tableBodyCell(
                _filteredCourses[index].semester.toString(),
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
