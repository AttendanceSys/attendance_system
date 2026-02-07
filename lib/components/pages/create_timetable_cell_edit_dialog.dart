// TimetableCellEditDialog — revised & fixed (type-corrected)
// - Courses and lecturers are stored as lists of maps {id,name} when loaded from Firestore.
// - UI uses ids for Dropdown value but displays names.
// - Handles missing fields and errors safely.
// - Returns TimetableCellEditResult(cellText: null) on Cancel, '' on Clear, and "Course\nLecturer" on Save.
//
// Save as: lib/components/pages/create_timetable_cell_edit_dialog.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../theme/super_admin_theme.dart';

class TimetableCellEditResult {
  final String? cellText;
  TimetableCellEditResult({required this.cellText});
}

class TimetableCellEditDialog extends StatefulWidget {
  final String? initialCourse; // display name or "CourseName" (not id)
  final String? initialLecturer; // display name
  final List<String> courses; // optional static fallback (display names)
  final List<String> lecturers; // optional static fallback (display names)
  final String?
  classId; // optional: if provided, dialog will fetch courses for this class

  const TimetableCellEditDialog({
    super.key,
    this.initialCourse,
    this.initialLecturer,
    required this.courses,
    required this.lecturers,
    this.classId,
  });

  @override
  State<TimetableCellEditDialog> createState() =>
      _TimetableCellEditDialogState();
}

class _TimetableCellEditDialogState extends State<TimetableCellEditDialog> {
  // Selected/displayed values
  String?
  _selectedCourseId; // the Firestore doc id of the selected course (if we loaded docs)
  String? _selectedCourseName; // display name shown in dropdown
  bool _useCustomCourse = false;
  final TextEditingController _courseCustomCtrl = TextEditingController();

  String? _selectedLecturerId; // optional if we load teachers by id
  String? _selectedLecturerName;
  bool _useCustomLecturer = false;
  final TextEditingController _customLecturerCtrl = TextEditingController();

  // loaded lists (id + display)
  List<Map<String, String>> _courses = []; // [{'id': id, 'name': name}, ...]
  List<Map<String, String>> _lecturers = []; // [{'id': id, 'name': name}, ...]

  bool _loadingCourses = false;
  bool _loadingLecturers = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();

    // Initialize from widget-provided static lists (fallback)
    _courses = widget.courses.map((c) => {'id': '', 'name': c}).toList();
    _lecturers = widget.lecturers.map((t) => {'id': '', 'name': t}).toList();

    // Initialize selection values from initialCourse/initialLecturer
    if (widget.initialCourse != null &&
        widget.initialCourse!.trim().isNotEmpty) {
      _selectedCourseName = widget.initialCourse!.trim();
      // If this matches a static fallback, keep it; otherwise switch to custom entry
      final match = _courses.indexWhere(
        (c) => c['name']!.toLowerCase() == _selectedCourseName!.toLowerCase(),
      );
      if (match >= 0) {
        _selectedCourseId = _courses[match]['id'];
        _useCustomCourse = false;
      } else {
        _useCustomCourse = true;
        _courseCustomCtrl.text = _selectedCourseName!;
      }
    } else if (_courses.isEmpty) {
      // prefer custom if no static choices
      _useCustomCourse = true;
    }

    if (widget.initialLecturer != null &&
        widget.initialLecturer!.trim().isNotEmpty) {
      _selectedLecturerName = widget.initialLecturer!.trim();
      final match = _lecturers.indexWhere(
        (t) => t['name']!.toLowerCase() == _selectedLecturerName!.toLowerCase(),
      );
      if (match >= 0) {
        _selectedLecturerId = _lecturers[match]['id'];
        _useCustomLecturer = false;
      } else {
        _useCustomLecturer = true;
        _customLecturerCtrl.text = _selectedLecturerName!;
      }
    } else if (_lecturers.isEmpty) {
      _useCustomLecturer = true;
    }

    // If a classId is provided, fetch courses (and optionally lecturers later) from Firestore.
    if (widget.classId != null && widget.classId!.trim().isNotEmpty) {
      _loadCoursesAndClearSelection(widget.classId!.trim());
    }
  }

  @override
  void dispose() {
    _courseCustomCtrl.dispose();
    _customLecturerCtrl.dispose();
    super.dispose();
  }

  // ---------- Firestore lookups (safe) ----------

  // Fetch course documents for a class id. Returns list of maps {id,name}.
  Future<List<Map<String, String>>> _fetchCoursesForClass(
    String classId,
  ) async {
    final col = _firestore.collection('courses');
    try {
      // Try multiple common fields
      QuerySnapshot snap = await col.where('class', isEqualTo: classId).get();
      if (snap.docs.isEmpty) {
        snap = await col.where('class_id', isEqualTo: classId).get();
      }
      if (snap.docs.isEmpty) {
        snap = await col.where('classId', isEqualTo: classId).get();
      }
      if (snap.docs.isEmpty) {
        // try matching by DocumentReference if courses use refs
        try {
          final classRef = _firestore.collection('classes').doc(classId);
          // Common schemas: class is the DocumentReference itself
          snap = await col.where('class', isEqualTo: classRef).get();
          if (snap.docs.isEmpty) {
            snap = await col.where('class_ref', isEqualTo: classRef).get();
          }
          if (snap.docs.isEmpty) {
            snap = await col.where('classRef', isEqualTo: classRef).get();
          }
        } catch (_) {}
      }

      final out = <Map<String, String>>[];
      for (final d in snap.docs) {
        final data = d.data() as Map<String, dynamic>;
        final name =
            (data['course_name'] ??
                    data['title'] ??
                    data['course_code'] ??
                    d.id)
                .toString();
        out.add({'id': d.id, 'name': name});
      }
      return out;
    } catch (e, st) {
      debugPrint('fetchCoursesForClass error: $e\n$st');
      return [];
    }
  }

  // Fetch lecturers for a course doc id. Returns list of maps {id,name}.
  Future<List<Map<String, String>>> _fetchLecturersForCourseDoc(
    String courseDocId,
  ) async {
    try {
      final doc = await _firestore.collection('courses').doc(courseDocId).get();
      if (!doc.exists || doc.data() == null) return [];

      final data = doc.data() as Map<String, dynamic>;
      String extractId(dynamic value) {
        if (value == null) return '';
        if (value is DocumentReference) return value.id;
        if (value is String) {
          final s = value.trim();
          if (s.isEmpty) return '';
          if (s.contains('/')) {
            final parts = s.split('/').where((p) => p.isNotEmpty).toList();
            return parts.isNotEmpty ? parts.last : s;
          }
          return s;
        }
        return value.toString();
      }

      Future<List<Map<String, String>>> loadTeacherById(
        String teacherId,
      ) async {
        final tid = teacherId.trim();
        if (tid.isEmpty) return [];
        final tdoc = await _firestore.collection('teachers').doc(tid).get();
        if (!tdoc.exists || tdoc.data() == null) return [];
        final tdata = tdoc.data() as Map<String, dynamic>;
        final tname =
            (tdata['full_name'] ??
                    tdata['fullName'] ??
                    tdata['fullname'] ??
                    tdata['teacher_name'] ??
                    tdata['name'] ??
                    tdata['username'] ??
                    tid)
                .toString();
        return [
          {'id': tid, 'name': tname},
        ];
      }

      // Try common teacher keys (id string, path string, or DocumentReference)
      const teacherKeys = [
        'teacher_assigned',
        'teacher_ref',
        'teacher',
        'teacherRef',
        'teacher_id',
        'lecturer',
        'lecturer_id',
      ];
      for (final key in teacherKeys) {
        if (!data.containsKey(key) || data[key] == null) continue;
        // Some schemas use a map for teacher
        if (data[key] is Map) {
          final t = data[key] as Map;
          final tid = extractId(t['id'] ?? t['teacher_id'] ?? t['ref']);
          final tname =
              (t['full_name'] ??
                      t['fullName'] ??
                      t['fullname'] ??
                      t['teacher_name'] ??
                      t['name'] ??
                      t['username'] ??
                      '')
                  .toString();
          if (tname.trim().isNotEmpty) {
            return [
              {'id': tid, 'name': tname.trim()},
            ];
          }
          final byId = await loadTeacherById(tid);
          if (byId.isNotEmpty) return byId;
          continue;
        }

        final tid = extractId(data[key]);
        final byId = await loadTeacherById(tid);
        if (byId.isNotEmpty) return byId;
      }

      // Some schemas embed teacher info in the course doc
      if (data.containsKey('teacher') && data['teacher'] is Map) {
        final t = data['teacher'] as Map<String, dynamic>;
        final tid = (t['id'] ?? t['teacher_id'] ?? '').toString();
        final tname =
            (t['full_name'] ??
                    t['fullName'] ??
                    t['fullname'] ??
                    t['teacher_name'] ??
                    t['name'] ??
                    t['username'] ??
                    '')
                .toString();
        if (tname.isNotEmpty) {
          return [
            {'id': tid, 'name': tname},
          ];
        }
      }

      // If course doc has 'teachers' array of refs or ids, try to fetch the first
      if (data.containsKey('teachers') && data['teachers'] is List) {
        final list = data['teachers'] as List;
        for (final item in list) {
          try {
            if (item is DocumentReference) {
              final tdoc = await item.get();
              if (tdoc.exists && tdoc.data() != null) {
                final tdata = tdoc.data() as Map<String, dynamic>;
                final tname =
                    (tdata['full_name'] ??
                            tdata['fullName'] ??
                            tdata['fullname'] ??
                            tdata['teacher_name'] ??
                            tdata['name'] ??
                            tdata['username'] ??
                            '')
                        .toString();
                final tid = tdoc.id;
                if (tname.isNotEmpty) {
                  return [
                    {'id': tid, 'name': tname},
                  ];
                }
              }
            } else if (item is String) {
              final tdoc = await _firestore
                  .collection('teachers')
                  .doc(item)
                  .get();
              if (tdoc.exists && tdoc.data() != null) {
                final tdata = tdoc.data() as Map<String, dynamic>;
                final tname =
                    (tdata['full_name'] ??
                            tdata['fullName'] ??
                            tdata['fullname'] ??
                            tdata['teacher_name'] ??
                            tdata['name'] ??
                            tdata['username'] ??
                            '')
                        .toString();
                if (tname.isNotEmpty) {
                  return [
                    {'id': item, 'name': tname},
                  ];
                }
              }
            }
          } catch (_) {}
        }
      }
    } catch (e, st) {
      debugPrint('fetchLecturersForCourseDoc error: $e\n$st');
    }
    return [];
  }

  // ---------- UI actions ----------

  Future<void> _loadCoursesAndClearSelection(String? classId) async {
    setState(() {
      _loadingCourses = true;
      _selectedCourseId = null;
      _selectedCourseName = null;
      _useCustomCourse = false;
      _courseCustomCtrl.clear();
    });
    if (classId == null || classId.trim().isEmpty) {
      setState(() => _loadingCourses = false);
      return;
    }
    final courses = await _fetchCoursesForClass(classId);
    setState(() {
      // Keep widget-provided fallback if Firestore returns nothing
      if (courses.isNotEmpty) {
        _courses = courses;
      }
      // If widget.initialCourse matches one of these, pick it
      if (widget.initialCourse != null) {
        final match = _courses.indexWhere(
          (c) =>
              c['name']!.toLowerCase() == widget.initialCourse!.toLowerCase(),
        );
        if (match >= 0) {
          _selectedCourseId = _courses[match]['id'];
          _selectedCourseName = _courses[match]['name'];
          _useCustomCourse = false;
        }
      }
      if (_courses.isEmpty && (widget.courses.isEmpty)) _useCustomCourse = true;
      _loadingCourses = false;
    });

    if (_selectedCourseId != null && _selectedCourseId!.trim().isNotEmpty) {
      _loadLecturersForCourse(_selectedCourseId);
    }
  }

  Future<void> _loadLecturersForCourse(String? courseId) async {
    setState(() {
      _loadingLecturers = true;
      _selectedLecturerId = null;
      _selectedLecturerName = null;
      _useCustomLecturer = false;
      _customLecturerCtrl.clear();
    });
    if (courseId == null || courseId.trim().isEmpty) {
      setState(() => _loadingLecturers = false);
      return;
    }
    final lecturers = await _fetchLecturersForCourseDoc(courseId);
    setState(() {
      // Keep widget-provided fallback if Firestore returns nothing
      if (lecturers.isNotEmpty) {
        _lecturers = lecturers;
      }
      if (widget.initialLecturer != null) {
        final match = _lecturers.indexWhere(
          (t) =>
              t['name']!.toLowerCase() == widget.initialLecturer!.toLowerCase(),
        );
        if (match >= 0) {
          _selectedLecturerId = _lecturers[match]['id'];
          _selectedLecturerName = _lecturers[match]['name'];
          _useCustomLecturer = false;
        }
      }
      if (_lecturers.isEmpty && widget.lecturers.isEmpty) {
        _useCustomLecturer = true;
      }
      _loadingLecturers = false;
    });
  }

  void _onCoursePickedByUser(Map<String, String>? course) {
    if (course == null) {
      setState(() {
        _selectedCourseId = null;
        _selectedCourseName = null;
      });
      return;
    }
    setState(() {
      _selectedCourseId = course['id'];
      _selectedCourseName = course['name'];
      _useCustomCourse = false;
      _courseCustomCtrl.clear();
    });
    if (_selectedCourseId != null && _selectedCourseId!.isNotEmpty) {
      _loadLecturersForCourse(_selectedCourseId);
    }
  }

  // ---------- Save / Clear ----------

  void _save() {
    final course = _useCustomCourse
        ? _courseCustomCtrl.text.trim()
        : (_selectedCourseName ?? '').trim();
    final lecturer = _useCustomLecturer
        ? _customLecturerCtrl.text.trim()
        : (_selectedLecturerName ?? '').trim();

    if (course.isEmpty && lecturer.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter a course or lecturer, or press Clear to remove the cell.',
          ),
        ),
      );
      return;
    }

    final cellText = course.isEmpty
        ? lecturer
        : (lecturer.isEmpty ? course : '$course\n$lecturer');
    Navigator.of(context).pop(TimetableCellEditResult(cellText: cellText));
  }

  void _clear() {
    Navigator.of(context).pop(TimetableCellEditResult(cellText: ''));
  }

  // ---------- Build UI ----------

  @override
  Widget build(BuildContext context) {
    // prepare dropdown items: show name but use id as value when available
    final courseEntries = _courses
        .map((c) {
          final id = (c['id'] ?? '').trim();
          final name = (c['name'] ?? '').trim();
          return MapEntry(id.isNotEmpty ? id : name, name);
        })
        .where((e) => e.value.trim().isNotEmpty)
        .toList();
    final lecturerEntries = _lecturers
        .map((t) {
          final id = (t['id'] ?? '').trim();
          final name = (t['name'] ?? '').trim();
          return MapEntry(id.isNotEmpty ? id : name, name);
        })
        .where((e) => e.value.trim().isNotEmpty)
        .toList();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = Theme.of(context).extension<SuperAdminColors>();
    return AlertDialog(
      backgroundColor: isDark
          ? (palette?.surfaceHigh ?? const Color(0xFF323746))
          : null,
      title: Text(
        'Edit Timetable Cell',
        style: isDark ? TextStyle(color: palette?.textPrimary) : null,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Course field
            Row(
              children: [
                Expanded(
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Course',
                      isDense: true,
                      border: const OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: isDark
                              ? (palette?.border ?? const Color(0xFF3A404E))
                              : const Color(0xFFE5E7EB),
                        ),
                      ),
                      focusedBorder: isDark
                          ? OutlineInputBorder(
                              borderSide: BorderSide(
                                color:
                                    palette?.accent ?? const Color(0xFF0A1E90),
                              ),
                            )
                          : null,
                      filled: isDark,
                      fillColor: isDark
                          ? (palette?.inputFill ?? const Color(0xFF2B303D))
                          : null,
                    ),
                    child: _loadingCourses
                        ? const SizedBox(
                            height: 40,
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              dropdownColor: isDark
                                  ? (palette?.surface ??
                                        const Color(0xFF262C3A))
                                  : null,
                              value:
                                  (_selectedCourseId != null &&
                                      _selectedCourseId!.trim().isNotEmpty)
                                  ? _selectedCourseId
                                  : ((_selectedCourseName != null &&
                                            _selectedCourseName!
                                                .trim()
                                                .isNotEmpty)
                                        ? _selectedCourseName
                                        : null),
                              hint: Text(
                                _selectedCourseName ?? 'Select course',
                                style: isDark
                                    ? TextStyle(color: palette?.textSecondary)
                                    : null,
                              ),
                              items: courseEntries
                                  .map(
                                    (e) => DropdownMenuItem<String>(
                                      value: e.key,
                                      child: Text(
                                        e.value,
                                        style: isDark
                                            ? TextStyle(
                                                color: palette?.textPrimary,
                                              )
                                            : null,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (id) {
                                if (id == null) {
                                  _onCoursePickedByUser(null);
                                  return;
                                }
                                final picked = _courses.firstWhere((c) {
                                  final cid = (c['id'] ?? '').trim();
                                  final cname = (c['name'] ?? '').trim();
                                  return cid == id || cname == id;
                                }, orElse: () => {'id': '', 'name': id});
                                _onCoursePickedByUser(
                                  picked.map(
                                    (k, v) => MapEntry(k, v.toString()),
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Lecturer field
            Row(
              children: [
                Expanded(
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Lecturer',
                      isDense: true,
                      border: const OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: isDark
                              ? (palette?.border ?? const Color(0xFF3A404E))
                              : const Color(0xFFE5E7EB),
                        ),
                      ),
                      focusedBorder: isDark
                          ? OutlineInputBorder(
                              borderSide: BorderSide(
                                color:
                                    palette?.accent ?? const Color(0xFF0A1E90),
                              ),
                            )
                          : null,
                      filled: isDark,
                      fillColor: isDark
                          ? (palette?.inputFill ?? const Color(0xFF2B303D))
                          : null,
                    ),
                    child: _useCustomLecturer
                        ? TextFormField(
                            controller: _customLecturerCtrl,
                            decoration: InputDecoration(
                              hintText: 'Enter lecturer name',
                              border: InputBorder.none,
                              isDense: true,
                              hintStyle: isDark
                                  ? TextStyle(color: palette?.textSecondary)
                                  : null,
                            ),
                          )
                        : _loadingLecturers
                        ? const SizedBox(
                            height: 40,
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              dropdownColor: isDark
                                  ? (palette?.surface ??
                                        const Color(0xFF262C3A))
                                  : null,
                              value:
                                  (_selectedLecturerId != null &&
                                      _selectedLecturerId!.trim().isNotEmpty)
                                  ? _selectedLecturerId
                                  : ((_selectedLecturerName != null &&
                                            _selectedLecturerName!
                                                .trim()
                                                .isNotEmpty)
                                        ? _selectedLecturerName
                                        : null),
                              hint: Text(
                                _selectedLecturerName ?? 'Select lecturer',
                                style: isDark
                                    ? TextStyle(color: palette?.textSecondary)
                                    : null,
                              ),
                              items: lecturerEntries
                                  .map(
                                    (e) => DropdownMenuItem<String>(
                                      value: e.key,
                                      child: Text(
                                        e.value,
                                        style: isDark
                                            ? TextStyle(
                                                color: palette?.textPrimary,
                                              )
                                            : null,
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (id) {
                                if (id == null) return;
                                final picked = _lecturers.firstWhere((t) {
                                  final tid = (t['id'] ?? '').trim();
                                  final tname = (t['name'] ?? '').trim();
                                  return tid == id || tname == id;
                                }, orElse: () => {'id': '', 'name': id});
                                setState(() {
                                  _selectedLecturerId = (picked['id'] ?? '')
                                      .toString();
                                  _selectedLecturerName = (picked['name'] ?? '')
                                      .toString();
                                  _useCustomLecturer = false;
                                  _customLecturerCtrl.clear();
                                });
                              },
                            ),
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Save to set cell. Clear to empty the cell. Cancel to keep unchanged.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDark ? palette?.textSecondary : null,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          style: isDark
              ? TextButton.styleFrom(foregroundColor: palette?.textSecondary)
              : null,
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _clear,
          style: isDark
              ? TextButton.styleFrom(foregroundColor: palette?.accent)
              : null,
          child: const Text('Clear'),
        ),
        ElevatedButton(
          onPressed: _save,
          style: isDark
              ? ElevatedButton.styleFrom(
                  backgroundColor: palette?.accent,
                  foregroundColor: palette?.textPrimary,
                )
              : null,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
