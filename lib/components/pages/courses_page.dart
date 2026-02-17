import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/course.dart';
import '../popup/add_course_popup.dart';
import '../cards/searchBar.dart';
import '../../services/session.dart';
import '../../theme/super_admin_theme.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../../utils/download_bytes.dart';

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
    // Fetch lookups first so teacher lookup map is available when rendering courses.
    _init();
  }

  Future<void> _init() async {
    try {
      await _fetchLookups();
      await _fetchCourses();
      await _prefetchMissingTeachersFromCourses();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _fetchLookups() async {
    try {
      Query cq = classesCollection;
      Query fq = facultiesCollection;

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
      Query dq = departmentsCollection;
      if (Session.facultyRef != null) {
        dq = dq.where('faculty_ref', isEqualTo: Session.facultyRef);
      }
      final dSnap = await dq.get();
      final fSnap = await fq.get();

      // Build teacher map with multiple key forms for robust lookup
      final Map<String, String> teacherMap = {};
      for (final d in tDocs) {
        final data = d.data() as Map<String, dynamic>? ?? {};
        final name = (data['teacher_name'] ?? data['name'] ?? '') as String;
        final id = d.id;
        teacherMap[id] = name;
        teacherMap[d.reference.path] = name; // 'teachers/abc'
        teacherMap['/${d.reference.path}'] = name; // '/teachers/abc'
        // and also try common prefix forms if your DB used them
        teacherMap['teachers/$id'] = name;
        teacherMap['/teachers/$id'] = name;
      }

      setState(() {
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
                    // if it's a path like 'teachers/abc' or '/teachers/abc' extract last
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
      final Map<String, dynamic> payload = {
        'course_code': course.courseCode,
        'course_name': course.courseName,
        'class': course.classRef ?? '',
        'faculty_ref': Session.facultyRef ?? course.facultyRef ?? '',
        'faculty_id': Session.facultyRef != null
            ? Session.facultyRef!.id
            : (course.facultyRef ?? ''),
        'semester': course.semester ?? '',
        'created_at': FieldValue.serverTimestamp(),
      };
      // If teacherRef is provided, save as a DocumentReference to keep type consistent
      if (course.teacherRef != null && course.teacherRef!.isNotEmpty) {
        payload['teacher_assigned'] = teachersCollection.doc(
          course.teacherRef!,
        );
      } else {
        payload['teacher_assigned'] = '';
      }

      await coursesCollection.add(payload);
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
      final Map<String, dynamic> payload = {
        'course_code': newC.courseCode,
        'course_name': newC.courseName,
        'class': newC.classRef ?? '',
        'faculty_ref': Session.facultyRef ?? newC.facultyRef ?? '',
        'faculty_id': Session.facultyRef != null
            ? Session.facultyRef!.id
            : (newC.facultyRef ?? ''),
        'semester': newC.semester ?? '',
        'updated_at': FieldValue.serverTimestamp(),
      };
      if (newC.teacherRef != null && newC.teacherRef!.isNotEmpty) {
        payload['teacher_assigned'] = teachersCollection.doc(newC.teacherRef!);
      } else {
        payload['teacher_assigned'] = '';
      }

      await coursesCollection.doc(oldC.id).update(payload);
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
    setState(() => _selectedIndex = _selectedIndex == index ? null : index);
  }

  void _clearSelection() {
    if (_selectedIndex == null) return;
    setState(() => _selectedIndex = null);
  }

  String _facultyDisplay(String? facultyRef) {
    final raw = (facultyRef ?? '').trim();
    if (raw.isEmpty) {
      if (Session.facultyRef == null) return '';
      return _facultyNames[Session.facultyRef!.id] ?? Session.facultyRef!.id;
    }
    if (_facultyNames.containsKey(raw)) return _facultyNames[raw]!;
    if (raw.contains('/')) {
      final parts = raw.split('/').where((p) => p.isNotEmpty).toList();
      if (parts.isNotEmpty && _facultyNames.containsKey(parts.last)) {
        return _facultyNames[parts.last]!;
      }
    }
    return raw;
  }

  String _departmentDisplayForClass(String? classRef) {
    final classId = (classRef ?? '').trim();
    if (classId.isEmpty) return '';
    final deptId = _classDeptId[classId] ?? '';
    if (deptId.isEmpty) return '';
    return _departmentNames[deptId] ?? deptId;
  }

  Future<void> _handleExportCoursesCsv() async {
    try {
      final rows = <List<dynamic>>[
        [
          'No',
          'Course code',
          'Course name',
          'Lecturer',
          'Department',
          'Class',
          'Faculty',
          'Semester',
        ],
      ];

      for (int i = 0; i < _courses.length; i++) {
        final c = _courses[i];
        rows.add([
          i + 1,
          c.courseCode,
          c.courseName,
          _teacherDisplay(c.teacherRef),
          _departmentDisplayForClass(c.classRef),
          _classNames[c.classRef] ?? '',
          _facultyDisplay(c.facultyRef),
          c.semester ?? '',
        ]);
      }

      final csv = const ListToCsvConverter().convert(rows);
      final bytes = Uint8List.fromList(utf8.encode(csv));
      final now = DateTime.now();
      final fileName =
          'courses_${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.csv';

      final downloaded = await downloadBytes(
        bytes: bytes,
        fileName: fileName,
        mimeType: 'text/csv;charset=utf-8',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            downloaded
                ? 'CSV exported: $fileName'
                : 'CSV export is currently supported on web only',
          ),
        ),
      );
    } catch (e) {
      print('Error exporting courses CSV: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to export CSV')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth > 800;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final disabledActionBg = isDark
        ? const Color(0xFF4234A4)
        : const Color(0xFF8372FE);

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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isDesktop)
                Row(
                  children: [
                    Expanded(
                      child: SearchAddBar(
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
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _handleUploadCourses,
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Upload Courses'),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: const Color.fromARGB(
                            255,
                            0,
                            150,
                            80,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _handleExportCoursesCsv,
                        icon: const Icon(Icons.download),
                        label: const Text('Export CSV'),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: const Color(0xFF1F6FEB),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              else ...[
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
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _handleUploadCourses,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Upload Courses'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: const Color.fromARGB(255, 0, 150, 80),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _handleExportCoursesCsv,
                    icon: const Icon(Icons.download),
                    label: const Text('Export CSV'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: const Color(0xFF1F6FEB),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
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
                        disabledBackgroundColor: disabledActionBg,
                        disabledForegroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _selectedIndex == null ? null : _showEditCoursePopup,
                      child: const Text(
                        'Edit',
                        style: TextStyle(fontSize: 15, color: Colors.white),
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
                        disabledBackgroundColor: disabledActionBg,
                        disabledForegroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _selectedIndex == null ? null : _confirmDeleteCourse,
                      child: const Text(
                        'Delete',
                        style: TextStyle(fontSize: 14, color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
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
                            scrollDirection: Axis.horizontal,
                            child: _buildMobileTable(),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  // Try multiple candidate forms for teacherRef and fallback to the raw ref so you can
  // see what was stored (useful when CSV/input used unexpected formats).
  String _teacherDisplay(String? teacherRef) {
    if (teacherRef == null || teacherRef.isEmpty) return '';
    // direct id lookup
    if (_teacherNames.containsKey(teacherRef)) {
      return _teacherNames[teacherRef]!;
    }
    // full path forms
    final path = 'teachers/$teacherRef';
    final pathWithSlash = '/$path';
    if (_teacherNames.containsKey(path)) return _teacherNames[path]!;
    if (_teacherNames.containsKey(pathWithSlash)) {
      return _teacherNames[pathWithSlash]!;
    }
    // maybe teacherRef already contains a path; try last segment
    if (teacherRef.contains('/')) {
      final parts = teacherRef.split('/').where((p) => p.isNotEmpty).toList();
      if (parts.isNotEmpty) {
        final last = parts.last;
        if (_teacherNames.containsKey(last)) return _teacherNames[last]!;
        final p2 = 'teachers/$last';
        if (_teacherNames.containsKey(p2)) return _teacherNames[p2]!;
        final p3 = '/$p2';
        if (_teacherNames.containsKey(p3)) return _teacherNames[p3]!;
      }
    }
    // fallback: return the raw ref so the UI shows something (helps debug)
    // If you prefer an empty string, change this to return ''.
    return teacherRef;
  }

  Future<void> _prefetchMissingTeachersFromCourses() async {
    try {
      final ids = <String>{};
      for (final c in _courses) {
        final t = c.teacherRef ?? '';
        if (t.isEmpty) continue;
        // add multiple candidate forms so we attempt to fetch by doc id
        ids.add(t);
        if (t.contains('/')) {
          final parts = t.split('/').where((p) => p.isNotEmpty).toList();
          if (parts.isNotEmpty) ids.add(parts.last);
        } else {
          // also consider full path forms
          ids.add('teachers/$t');
          ids.add('/teachers/$t');
        }
      }

      // Only keep those that actually don't have a name yet
      final missing = ids.where((id) {
        return !_teacherNames.containsKey(id);
      }).toList();

      if (missing.isEmpty) return;

      // For server query we need actual document ids (not paths like 'teachers/abc').
      // Extract last segments and deduplicate.
      final docIds = missing
          .map((m) {
            if (m.contains('/')) {
              final parts = m.split('/').where((p) => p.isNotEmpty).toList();
              return parts.isNotEmpty ? parts.last : m;
            }
            return m;
          })
          .toSet()
          .toList();

      // fetch in chunks (whereIn has size limits)
      const chunkSize = 10;
      for (var i = 0; i < docIds.length; i += chunkSize) {
        final chunk = docIds.skip(i).take(chunkSize).toList();
        final snap = await teachersCollection
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final d in snap.docs) {
          final data = d.data() as Map<String, dynamic>? ?? {};
          final name = (data['teacher_name'] ?? data['name'] ?? '').toString();
          if (name.isNotEmpty) {
            // add multiple key forms so lookups succeed later
            _teacherNames[d.id] = name;
            _teacherNames[d.reference.path] = name;
            _teacherNames['/${d.reference.path}'] = name;
            _teacherNames['teachers/${d.id}'] = name;
            _teacherNames['/teachers/${d.id}'] = name;
          }
        }
      }

      if (mounted) setState(() {});
    } catch (e) {
      print('Error prefetching teachers: $e');
    }
  }

  Widget _buildDesktopTable() {
    return _buildSaasTable(
      columnWidths: const {
        0: FixedColumnWidth(72),
        1: FlexColumnWidth(1.1),
        2: FlexColumnWidth(1.7),
        3: FlexColumnWidth(1.5),
        4: FlexColumnWidth(1.5),
        5: FlexColumnWidth(1.1),
        6: FixedColumnWidth(120),
      },
    );
  }

  Widget _buildMobileTable() {
    return _buildSaasTable(
      columnWidths: const {
        0: FixedColumnWidth(72),
        1: FixedColumnWidth(130),
        2: FixedColumnWidth(220),
        3: FixedColumnWidth(170),
        4: FixedColumnWidth(170),
        5: FixedColumnWidth(130),
        6: FixedColumnWidth(120),
      },
    );
  }

  Widget _buildSaasTable({required Map<int, TableColumnWidth> columnWidths}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = Theme.of(context).extension<SuperAdminColors>();
    final scheme = Theme.of(context).colorScheme;
    final surface = palette?.surface ?? scheme.surface;
    final border =
        palette?.border ??
        (isDark ? const Color(0xFF3A404E) : const Color(0xFFD7DCEA));
    final headerBg = palette?.surfaceHigh ?? scheme.surfaceContainerHighest;
    final textPrimary = palette?.textPrimary ?? scheme.onSurface;
    final selectedBg =
        palette?.selectedBg ??
        Color.alphaBlend(
          (palette?.accent ?? const Color(0xFF6A46FF)).withValues(alpha: 0.12),
          surface,
        );
    final divider = border.withValues(alpha: isDark ? 0.7 : 0.85);

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: divider),
        boxShadow: [
          BoxShadow(
            color: (palette?.accent ?? const Color(0xFF6A46FF)).withValues(
              alpha: isDark ? 0.06 : 0.08,
            ),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Table(
              columnWidths: columnWidths,
              children: [
                TableRow(
                  decoration: BoxDecoration(color: headerBg),
                  children: [
                    _tableHeaderCell('No', textPrimary),
                    _tableHeaderCell('Course code', textPrimary),
                    _tableHeaderCell('Course name', textPrimary),
                    _tableHeaderCell('Lecturer', textPrimary),
                    _tableHeaderCell('Department', textPrimary),
                    _tableHeaderCell('Class', textPrimary),
                    _tableHeaderCell('Semester', textPrimary),
                  ],
                ),
              ],
            ),
            Container(height: 1, color: divider),
            Expanded(
              child: SingleChildScrollView(
                primary: false,
                child: Table(
                  columnWidths: columnWidths,
                  border: TableBorder(horizontalInside: BorderSide(color: divider)),
                  children: [
                    for (int i = 0; i < _filteredCourses.length; i++)
                      TableRow(
                        decoration: BoxDecoration(
                          color: _selectedIndex == i ? selectedBg : surface,
                        ),
                        children: [
                          _tableBodyCell(
                            '${i + 1}',
                            textPrimary,
                            onTap: () => _handleRowTap(i),
                          ),
                          _tableBodyCell(
                            _filteredCourses[i].courseCode,
                            textPrimary,
                            onTap: () => _handleRowTap(i),
                          ),
                          _tableBodyCell(
                            _filteredCourses[i].courseName,
                            textPrimary,
                            onTap: () => _handleRowTap(i),
                          ),
                          _tableBodyCell(
                            _teacherDisplay(_filteredCourses[i].teacherRef),
                            textPrimary,
                            onTap: () => _handleRowTap(i),
                          ),
                          _tableBodyCell(
                            _departmentNames[_classDeptId[_filteredCourses[i].classRef]] ??
                                '',
                            textPrimary,
                            onTap: () => _handleRowTap(i),
                          ),
                          _tableBodyCell(
                            _classNames[_filteredCourses[i].classRef] ?? '',
                            textPrimary,
                            onTap: () => _handleRowTap(i),
                          ),
                          _tableBodyCell(
                            _filteredCourses[i].semester ?? '',
                            textPrimary,
                            onTap: () => _handleRowTap(i),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tableHeaderCell(String text, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: textColor,
          letterSpacing: 0.1,
        ),
        textAlign: TextAlign.left,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _tableBodyCell(String text, Color textColor, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      hoverColor: Colors.transparent,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        child: Text(
          text,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14.5,
            color: textColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // CSV import helpers unchanged from previous version (omitted here for brevity)
  // ... (keep _handleUploadCourses and _addCourseFromUpload as in earlier version)
  // For brevity in this snippet, the CSV functions aren't repeated. Keep them as you have.
  // Helpers copied/adapted from StudentsPage for CSV import + lookup resolution

  String? _findIdByName(Map<String, String> map, String name) {
    final entry = map.entries.firstWhere(
      (e) => e.value.toLowerCase().trim() == name.toLowerCase().trim(),
      orElse: () => const MapEntry('', ''),
    );
    final key = entry.key;
    if (key.isEmpty) return null;
    // Normalize to a document id: prefer the last segment if a path was stored.
    if (key.contains('/')) {
      final parts = key.split('/').where((p) => p.isNotEmpty).toList();
      return parts.isNotEmpty ? parts.last : key;
    }
    return key;
  }

  String? _resolveRef(Map<String, String> map, String? val) {
    if (val == null || val.isEmpty) return null;
    // if it's already an id present in the lookup map
    if (map.containsKey(val)) {
      // normalize to simple id if caller passed a path-like key
      if (val.contains('/')) {
        final parts = val.split('/').where((p) => p.isNotEmpty).toList();
        return parts.isNotEmpty ? parts.last : val;
      }
      return val;
    }
    // try to match by name
    final byName = _findIdByName(map, val);
    if (byName != null) return byName;
    // fallback: return the value as-is (may be an id or path)
    return val;
  }

  Future<void> _handleUploadCourses() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );
      if (result == null) return;
      final file = result.files.first;
      if (file.bytes == null) return;
      final content = utf8.decode(file.bytes!);
      final rows = const CsvToListConverter(eol: '\n').convert(content);
      if (rows.isEmpty) return;

      final headers = rows.first
          .map((h) => h.toString().toLowerCase().trim())
          .toList();
      final List<Map<String, dynamic>> parsed = [];
      for (var i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.every((cell) => (cell ?? '').toString().trim().isEmpty)) {
          continue;
        }
        final map = <String, dynamic>{};
        for (var c = 0; c < headers.length && c < row.length; c++) {
          map[headers[c]] = row[c]?.toString() ?? '';
        }
        parsed.add(map);
      }

      if (parsed.isEmpty) return;

      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirm upload'),
          content: Text('Import ${parsed.length} courses?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Import'),
            ),
          ],
        ),
      );
      if (proceed != true) return;

      final added = <String>[];
      final skipped = <String>[];
      for (final row in parsed) {
        final courseCode =
            (row['course_code'] ?? row['coursecode'] ?? row['code'] ?? '')
                .toString()
                .trim();
        final courseName =
            (row['course_name'] ?? row['coursename'] ?? row['name'] ?? '')
                .toString()
                .trim();
        final semester = (row['semester'] ?? '').toString().trim();
        final rawTeacher =
            (row['teacher'] ??
                    row['teacher_assigned'] ??
                    row['teacher_id'] ??
                    row['lecturer'] ??
                    '')
                .toString()
                .trim();
        final rawClass =
            (row['class'] ??
                    row['class_ref'] ??
                    row['classid'] ??
                    row['class_name'] ??
                    '')
                .toString()
                .trim();
        final rawFaculty =
            (row['faculty'] ??
                    row['faculty_ref'] ??
                    row['facultyid'] ??
                    row['faculty_id'] ??
                    '')
                .toString()
                .trim();

        if (courseCode.isEmpty || courseName.isEmpty) {
          skipped.add(courseCode.isEmpty ? courseName : courseCode);
          continue;
        }

        // avoid duplicates by course_code (basic)
        final exists = await coursesCollection
            .where('course_code', isEqualTo: courseCode)
            .get();
        if (exists.docs.isNotEmpty) {
          skipped.add(courseCode);
          continue;
        }

        final teacherId = _resolveRef(_teacherNames, rawTeacher);
        final classId = _resolveRef(_classNames, rawClass);
        final facultyId = rawFaculty.isEmpty ? null : rawFaculty;

        final course = Course(
          courseCode: courseCode,
          courseName: courseName,
          teacherRef: teacherId,
          classRef: classId,
          facultyRef: facultyId,
          semester: semester.isEmpty ? null : semester,
        );

        final ok = await _addCourseFromUpload(course);
        if (ok) {
          added.add(courseCode);
        } else {
          skipped.add(courseCode);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Imported ${added.length}, skipped ${skipped.length}',
            ),
          ),
        );
      }
      await _fetchCourses();
    } catch (e) {
      print('Error importing courses: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to import courses')),
        );
      }
    }
  }

  Future<bool> _addCourseFromUpload(Course c) async {
    try {
      // basic duplicate check
      final q = await coursesCollection
          .where('course_code', isEqualTo: c.courseCode)
          .get();
      if (q.docs.isNotEmpty) return false;

      final Map<String, dynamic> payload = {
        'course_code': c.courseCode,
        'course_name': c.courseName,
        'class': c.classRef ?? '',
        'faculty_ref': Session.facultyRef ?? c.facultyRef ?? '',
        'faculty_id': Session.facultyRef != null
            ? Session.facultyRef!.id
            : (c.facultyRef ?? ''),
        'semester': c.semester ?? '',
        'created_at': FieldValue.serverTimestamp(),
      };
      if (c.teacherRef != null && c.teacherRef!.isNotEmpty) {
        // ensure we store a DocumentReference for the teacher
        payload['teacher_assigned'] = teachersCollection.doc(c.teacherRef!);
      } else {
        payload['teacher_assigned'] = '';
      }

      await coursesCollection.add(payload);

      return true;
    } catch (e) {
      print('Error adding course from upload: $e');
      return false;
    }
  }
}
