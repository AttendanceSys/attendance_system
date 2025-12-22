import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/course.dart';
import '../popup/add_course_popup.dart';
import '../cards/searchBar.dart';
import '../../services/session.dart';
import '../../theme/super_admin_theme.dart';

class CoursesPage extends StatefulWidget {
  const CoursesPage({super.key});

  @override
  State<CoursesPage> createState() => _CoursesPageState();
}

class _CoursesPageState extends State<CoursesPage> {
  final CollectionReference coursesCollection = FirebaseFirestore.instance
      .collection('courses');
  final CollectionReference teachersCollection = FirebaseFirestore.instance
      .collection('teachers');
  final CollectionReference classesCollection = FirebaseFirestore.instance
      .collection('classes');
  final CollectionReference departmentsCollection = FirebaseFirestore.instance
      .collection('departments');
  final CollectionReference facultiesCollection = FirebaseFirestore.instance
      .collection('faculties');

  List<Course> _courses = [];
  Map<String, String> _teacherNames = {};
  Map<String, String> _classNames = {};
  final Map<String, String> _classDeptId = {};
  Map<String, String> _departmentNames = {};
  Map<String, String> _facultyNames = {};
  bool _loading = true;

  String _searchText = '';
  int? _selectedIndex;

  List<Course> get _filteredCourses => _courses.where((c) {
    final teacher = _teacherNames[c.teacherRef] ?? '';
    final className = _classNames[c.classRef] ?? '';
    final faculty = _facultyNames[c.facultyRef] ?? '';
    final q = _searchText.toLowerCase();
    return c.courseCode.toLowerCase().contains(q) ||
        c.courseName.toLowerCase().contains(q) ||
        teacher.toLowerCase().contains(q) ||
        className.toLowerCase().contains(q) ||
        faculty.toLowerCase().contains(q) ||
        (c.semester ?? '').toLowerCase().contains(q);
  }).toList();

  @override
  void initState() {
    super.initState();
    // Ensure lookups load before courses so names are available when
    // we map course teacher ids to display names.
    _init();
  }

  Future<void> _init() async {
    await Future.wait([_fetchLookups(), _fetchCourses()]);
    await _prefetchMissingTeachersFromCourses();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _fetchLookups() async {
    try {
      Query cq = classesCollection;
      Query fq = facultiesCollection;

      // Fetch teacher documents in a way that tolerates mixed storage formats
      // for faculty on teacher docs. We may have either:
      // - a DocumentReference stored in 'faculty_ref'
      // - a string stored in 'faculty_id' that may be the id or the '/path'
      List<QueryDocumentSnapshot> tDocs = [];
      if (Session.facultyRef == null) {
        final tSnap = await teachersCollection.get();
        tDocs = tSnap.docs;
      } else {
        // Try multiple queries and merge results by id to avoid duplicates.
        final List<QuerySnapshot> snaps = [];
        snaps.add(
          await teachersCollection
              .where('faculty_ref', isEqualTo: Session.facultyRef)
              .get(),
        );
        snaps.add(
          await teachersCollection
              .where(
                'faculty_id',
                isEqualTo: (Session.facultyRef as DocumentReference).id,
              )
              .get(),
        );
        snaps.add(
          await teachersCollection
              .where(
                'faculty_id',
                isEqualTo: '/${(Session.facultyRef as DocumentReference).path}',
              )
              .get(),
        );
        final Map<String, QueryDocumentSnapshot> tMap = {};
        for (final s in snaps) {
          for (final d in s.docs) {
            tMap[d.id] = d;
          }
        }
        tDocs = tMap.values.toList();

        // Also filter classes and faculties by faculty_ref when session scope exists
        cq = cq.where('faculty_ref', isEqualTo: Session.facultyRef);
        fq = fq.where(
          FieldPath.documentId,
          isEqualTo: (Session.facultyRef as DocumentReference).id,
        );
      }

      final cSnap = await cq.get();
      // fetch departments (filtered by faculty when session scoped)
      Query dq = departmentsCollection;
      if (Session.facultyRef != null) {
        dq = dq.where('faculty_ref', isEqualTo: Session.facultyRef);
      }
      final dSnap = await dq.get();
      final fSnap = await fq.get();
      setState(() {
        // Build a teacher lookup that maps several possible key forms
        // (id, path, '/path') to the teacher's display name so courses
        // that store either an id or a path will resolve to the name.
        final Map<String, String> teacherMap = {};
        for (final d in tDocs) {
          final data = d.data() as Map<String, dynamic>? ?? {};
          final name = (data['teacher_name'] ?? data['name'] ?? '') as String;
          final id = d.id;
          teacherMap[id] = name;
          teacherMap[d.reference.path] = name; // e.g. 'teachers/abc'
          teacherMap['/${d.reference.path}'] = name; // e.g. '/teachers/abc'
        }
        _teacherNames = teacherMap;
        _classNames = Map.fromEntries(
          cSnap.docs.map((d) {
            final data = d.data() as Map<String, dynamic>? ?? {};
            final name = (data['class_name'] ?? data['name'] ?? '') as String;
            // capture department on the class for easy lookup
            final deptCandidate =
                data['department_ref'] ??
                data['department_id'] ??
                data['department'];
            String deptId = '';
            if (deptCandidate != null) {
              if (deptCandidate is DocumentReference) {
                deptId = deptCandidate.id;
              } else if (deptCandidate is String) {
                final s = deptCandidate;
                deptId = s.contains('/')
                    ? s.split('/').where((p) => p.isNotEmpty).toList().last
                    : s;
              } else {
                deptId = deptCandidate.toString();
              }
            }
            _classDeptId[d.id] = deptId;
            return MapEntry(d.id, name);
          }),
        );
        _facultyNames = Map.fromEntries(
          fSnap.docs.map((d) {
            final data = d.data() as Map<String, dynamic>? ?? {};
            final name = (data['faculty_name'] ?? data['name'] ?? '') as String;
            return MapEntry(d.id, name);
          }),
        );
        _departmentNames = Map.fromEntries(
          dSnap.docs.map((d) {
            final data = d.data() as Map<String, dynamic>? ?? {};
            final name =
                (data['department_name'] ?? data['name'] ?? '') as String;
            return MapEntry(d.id, name);
          }),
        );
      });
    } catch (e) {
      print('Error fetching course lookups: $e');
    }
  }

  Future<void> _fetchCourses() async {
    try {
      // NOTE: courses may store faculty as 'faculty_id' (string) in some DBs.
      // The requirement is to treat courses/admins as reading from faculty_id.
      final snap = await coursesCollection.get();
      setState(() {
        _courses = snap.docs
            .map((d) {
              final data = d.data() as Map<String, dynamic>? ?? {};
              final courseCode =
                  (data['course_code'] ?? data['courseCode'] ?? '') as String;
              final courseName =
                  (data['course_name'] ?? data['courseName'] ?? '') as String;
              // teacher can be stored under several possible fields; normalize
              String teacherRef = '';
              final teacherCandidates = [
                'teacher_assigned',
                'teacher_ref',
                'teacher',
                'teacherRef',
                'teacher_id',
                'lecturer',
                'lecturer_id',
              ];
              for (final key in teacherCandidates) {
                if (data.containsKey(key) && data[key] != null) {
                  final cand = data[key];
                  if (cand is DocumentReference) {
                    teacherRef = cand.id;
                  } else if (cand is String) {
                    final s = cand;
                    teacherRef = s.contains('/')
                        ? s.split('/').where((p) => p.isNotEmpty).toList().last
                        : s;
                  } else {
                    teacherRef = cand.toString();
                  }
                  break;
                }
              }
              final classRef = data['class'] is DocumentReference
                  ? (data['class'] as DocumentReference).id
                  : (data['class']?.toString() ??
                        data['classRef']?.toString() ??
                        '');

              // Normalize faculty stored in course doc. Support
              // - DocumentReference in faculty_ref
              // - String in faculty_id (e.g. '/faculties/Engineering' or 'Engineering')
              String courseFacultyId = '';
              final facCandidate =
                  data['faculty_ref'] ?? data['faculty_id'] ?? data['faculty'];
              if (facCandidate != null) {
                if (facCandidate is DocumentReference) {
                  courseFacultyId = facCandidate.id;
                } else if (facCandidate is String) {
                  final s = facCandidate;
                  if (s.contains('/')) {
                    final parts = s
                        .split('/')
                        .where((p) => p.isNotEmpty)
                        .toList();
                    courseFacultyId = parts.isNotEmpty ? parts.last : s;
                  } else {
                    courseFacultyId = s;
                  }
                } else {
                  courseFacultyId = facCandidate.toString();
                }
              }

              final semester = (data['semester'] ?? '') as String?;
              final createdAt = (data['created_at'] as Timestamp?)?.toDate();
              return Course(
                id: d.id,
                courseCode: courseCode,
                courseName: courseName,
                teacherRef: teacherRef.isNotEmpty ? teacherRef : null,
                classRef: classRef.isNotEmpty ? classRef : null,
                facultyRef: courseFacultyId.isNotEmpty ? courseFacultyId : null,
                semester: semester,
                createdAt: createdAt,
              );
            })
            .where((c) {
              // If session has a faculty, filter client-side by normalized faculty id
              if (Session.facultyRef == null) return true;
              final sessId = Session.facultyRef!.id;
              return (c.facultyRef ?? '') == sessId;
            })
            .toList();
      });
    } catch (e) {
      print('Error fetching courses: $e');
    }
  }

  Future<void> _showAddCoursePopup() async {
    final result = await showDialog<Course>(
      context: context,
      builder: (ctx) => const AddCoursePopup(),
    );
    if (result != null) {
      await _addCourse(result);
    }
  }

  Future<void> _showEditCoursePopup() async {
    if (_selectedIndex == null) return;
    final course = _filteredCourses[_selectedIndex!];
    final result = await showDialog<Course>(
      context: context,
      builder: (ctx) => AddCoursePopup(course: course),
    );
    if (result != null) {
      await _updateCourse(course, result);
    }
  }

  Future<void> _confirmDeleteCourse() async {
    if (_selectedIndex == null) return;
    final course = _filteredCourses[_selectedIndex!];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Course'),
        content: Text(
          "Are you sure you want to delete '${course.courseName}'?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _deleteCourse(course);
    }
  }

  Future<void> _addCourse(Course course) async {
    try {
      await coursesCollection.add({
        'course_code': course.courseCode,
        'course_name': course.courseName,
        'teacher_assigned': course.teacherRef ?? '',
        'class': course.classRef ?? '',
        'faculty_ref': Session.facultyRef ?? course.facultyRef ?? '',
        'faculty_id': Session.facultyRef != null
            ? Session.facultyRef!.id
            : (course.facultyRef ?? ''),
        'semester': course.semester ?? '',
        'created_at': FieldValue.serverTimestamp(),
      });
      await _fetchCourses();
      setState(() => _selectedIndex = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Course added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error adding course: $e');
    }
  }

  Future<void> _updateCourse(Course oldC, Course newC) async {
    if (oldC.id == null) return;
    try {
      await coursesCollection.doc(oldC.id).update({
        'course_code': newC.courseCode,
        'course_name': newC.courseName,
        'teacher_assigned': newC.teacherRef ?? '',
        'class': newC.classRef ?? '',
        'faculty_ref': Session.facultyRef ?? newC.facultyRef ?? '',
        'faculty_id': Session.facultyRef != null
            ? Session.facultyRef!.id
            : (newC.facultyRef ?? ''),
        'semester': newC.semester ?? '',
        'created_at': FieldValue.serverTimestamp(),
      });
      await _fetchCourses();
      setState(() => _selectedIndex = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Course updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error updating course: $e');
    }
  }

  Future<void> _deleteCourse(Course c) async {
    if (c.id == null) return;
    try {
      await coursesCollection.doc(c.id).delete();
      await _fetchCourses();
      setState(() => _selectedIndex = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Course deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error deleting course: $e');
    }
  }

  void _handleRowTap(int index) {
    setState(() => _selectedIndex = index);
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
          Text(
            'Courses',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Theme.of(
                context,
              ).extension<SuperAdminColors>()?.textPrimary,
            ),
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
                      hintText: 'Search Course...',
                      buttonText: 'Add Course',
                      onAddPressed: _showAddCoursePopup,
                      onChanged: (val) {
                        setState(() {
                          _searchText = val;
                          _selectedIndex = null;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SizedBox(
                          width: 90,
                          height: 36,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            onPressed: _selectedIndex == null
                                ? null
                                : _showEditCoursePopup,
                            child: const Text(
                              'Edit',
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 90,
                          height: 36,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            onPressed: _selectedIndex == null
                                ? null
                                : _confirmDeleteCourse,
                            child: const Text(
                              'Delete',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
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
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Container(
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
        ],
      ),
    );
  }

  String _teacherDisplay(String? teacherRef) {
    if (teacherRef == null || teacherRef.isEmpty) return '';
    // direct id lookup
    if (_teacherNames.containsKey(teacherRef)) {
      return _teacherNames[teacherRef]!;
    }
    // maybe teacherRef contains a path; try extracting last segment
    if (teacherRef.contains('/')) {
      final parts = teacherRef.split('/').where((p) => p.isNotEmpty).toList();
      if (parts.isNotEmpty) {
        final last = parts.last;
        if (_teacherNames.containsKey(last)) return _teacherNames[last]!;
      }
    }
    // fallback: keep empty (names are prefetched before render)
    return '';
  }

  Future<void> _prefetchMissingTeachersFromCourses() async {
    try {
      final ids = <String>{};
      for (final c in _courses) {
        final t = c.teacherRef ?? '';
        if (t.isEmpty) continue;
        ids.add(t);
        if (t.contains('/')) {
          final parts = t.split('/').where((p) => p.isNotEmpty).toList();
          if (parts.isNotEmpty) ids.add(parts.last);
        }
      }

      final missing = ids
          .where((id) => !_teacherNames.containsKey(id))
          .toList();
      if (missing.isEmpty) return;

      // batch fetch by document id (chunks of 10)
      const chunkSize = 10;
      for (var i = 0; i < missing.length; i += chunkSize) {
        final chunk = missing.skip(i).take(chunkSize).toList();
        final snap = await teachersCollection
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final d in snap.docs) {
          final data = d.data() as Map<String, dynamic>? ?? {};
          final name = (data['teacher_name'] ?? data['name'] ?? '').toString();
          if (name.isNotEmpty) {
            _teacherNames[d.id] = name;
            _teacherNames[d.reference.path] = name;
            _teacherNames['/${d.reference.path}'] = name;
          }
        }
      }
      if (mounted) setState(() {});
    } catch (_) {
      // ignore
    }
  }

  Widget _buildDesktopTable() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = Theme.of(context).extension<SuperAdminColors>();
    final highlight =
        palette?.highlight ??
        (isDark ? const Color(0xFF2E3545) : Colors.blue.shade50);
    return Table(
      columnWidths: const {
        0: FixedColumnWidth(64),
        1: FixedColumnWidth(120),
        2: FixedColumnWidth(180),
        3: FixedColumnWidth(160),
        4: FixedColumnWidth(160),
        5: FixedColumnWidth(120),
        6: FixedColumnWidth(120),
      },
      border: TableBorder(
        horizontalInside: BorderSide(color: Colors.grey.shade300),
      ),
      children: [
        TableRow(
          children: [
            _tableHeaderCell('No'),
            _tableHeaderCell('Course code'),
            _tableHeaderCell('Course name'),
            _tableHeaderCell('Lecturer'),
            _tableHeaderCell('Department'),
            _tableHeaderCell('Class'),
            _tableHeaderCell('Semester'),
          ],
        ),
        for (int i = 0; i < _filteredCourses.length; i++)
          TableRow(
            decoration: BoxDecoration(
              color: _selectedIndex == i ? highlight : Colors.transparent,
            ),
            children: [
              _tableBodyCell('${i + 1}', onTap: () => _handleRowTap(i)),
              _tableBodyCell(
                _filteredCourses[i].courseCode,
                onTap: () => _handleRowTap(i),
              ),
              _tableBodyCell(
                _filteredCourses[i].courseName,
                onTap: () => _handleRowTap(i),
              ),
              _tableBodyCell(
                _teacherDisplay(_filteredCourses[i].teacherRef),
                onTap: () => _handleRowTap(i),
              ),
              _tableBodyCell(
                _departmentNames[_classDeptId[_filteredCourses[i].classRef]] ??
                    '',
                onTap: () => _handleRowTap(i),
              ),
              _tableBodyCell(
                _classNames[_filteredCourses[i].classRef] ?? '',
                onTap: () => _handleRowTap(i),
              ),
              _tableBodyCell(
                _filteredCourses[i].semester ?? '',
                onTap: () => _handleRowTap(i),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildMobileTable() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = Theme.of(context).extension<SuperAdminColors>();
    final highlight =
        palette?.highlight ??
        (isDark ? const Color(0xFF2E3545) : Colors.blue.shade50);
    return Table(
      defaultColumnWidth: const IntrinsicColumnWidth(),
      border: TableBorder(
        horizontalInside: BorderSide(color: Colors.grey.shade300),
      ),
      children: [
        TableRow(
          children: [
            _tableHeaderCell('No'),
            _tableHeaderCell('Course code'),
            _tableHeaderCell('Course name'),
            _tableHeaderCell('Lecturer'),
            _tableHeaderCell('Department'),
            _tableHeaderCell('Class'),
            _tableHeaderCell('Semester'),
          ],
        ),
        for (int i = 0; i < _filteredCourses.length; i++)
          TableRow(
            decoration: BoxDecoration(
              color: _selectedIndex == i ? highlight : Colors.transparent,
            ),
            children: [
              _tableBodyCell('${i + 1}', onTap: () => _handleRowTap(i)),
              _tableBodyCell(
                _filteredCourses[i].courseCode,
                onTap: () => _handleRowTap(i),
              ),
              _tableBodyCell(
                _filteredCourses[i].courseName,
                onTap: () => _handleRowTap(i),
              ),
              _tableBodyCell(
                _teacherDisplay(_filteredCourses[i].teacherRef),
                onTap: () => _handleRowTap(i),
              ),
              _tableBodyCell(
                _departmentNames[_classDeptId[_filteredCourses[i].classRef]] ??
                    '',
                onTap: () => _handleRowTap(i),
              ),
              _tableBodyCell(
                _classNames[_filteredCourses[i].classRef] ?? '',
                onTap: () => _handleRowTap(i),
              ),
              _tableBodyCell(
                _filteredCourses[i].semester ?? '',
                onTap: () => _handleRowTap(i),
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
