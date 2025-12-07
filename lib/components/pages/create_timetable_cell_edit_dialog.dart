// TimetableCellEditDialog — revised & fixed (type-corrected)
// - Courses and lecturers are stored as lists of maps {id,name} when loaded from Firestore.
// - UI uses ids for Dropdown value but displays names.
// - Handles missing fields and errors safely.
// - Returns TimetableCellEditResult(cellText: null) on Cancel, '' on Clear, and "Course\nLecturer" on Save.

import '../../hooks/use_timetable.dart';
import 'package:flutter/material.dart';

class TimetableCellEditResult {
  final String? cellText;
  final String? courseId; // uuid if available
  final String? lecturerId; // uuid if available

  TimetableCellEditResult({
    required this.cellText,
    this.courseId,
    this.lecturerId,
  });
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
  _selectedCourseId; // the Firestore/Supabase doc id of the selected course (if we loaded docs)
  String? _selectedCourseName; // display name shown in dropdown
  bool _useCustomCourse = false;
  final TextEditingController _courseCustomCtrl = TextEditingController();

  String? _selectedLecturerId; // optional if we load teachers by id
  String? _selectedLecturerName;
  // manual lecturer override removed — lecturer is auto-assigned from course
  final TextEditingController _customLecturerCtrl = TextEditingController();

  // loaded lists (id + display)
  List<Map<String, String>> _courses = []; // [{'id': id, 'name': name}, ...]
  List<Map<String, String>> _lecturers = []; // [{'id': id, 'name': name}, ...]

  bool _loadingCourses = false;
  bool _loadingLecturers = false;

  final UseTimetable _svc = UseTimetable.instance;

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
      } else {
        _customLecturerCtrl.text = _selectedLecturerName!;
      }
    }

    // If a classId is provided, fetch courses (and optionally lecturers later) from the Supabase-backed service.
    if (widget.classId != null && widget.classId!.trim().isNotEmpty) {
      _loadCoursesAndClearSelection(widget.classId!.trim());
    } else {
      // If we have a selected course id/name from static list, attempt to load lecturers
      // for that course if it has an id (best-effort).
      if (_selectedCourseId != null && _selectedCourseId!.trim().isNotEmpty) {
        // schedule to avoid calling setState during init
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _loadLecturersForCourse(_selectedCourseId);
        });
      }
    }
  }

  @override
  void dispose() {
    _courseCustomCtrl.dispose();
    _customLecturerCtrl.dispose();
    super.dispose();
  }

  // ---------- Supabase (UseTimetable) lookups ----------

  // Fetch course records for a class id using UseTimetable. Returns list of maps {id,name}.
  Future<List<Map<String, String>>> _fetchCoursesForClass(
    String classId,
  ) async {
    try {
      await _svc.loadCoursesForClass(classId);
      final rows = _svc.courses; // {id, name, raw}
      return rows
          .map((r) => {'id': r['id'].toString(), 'name': r['name'].toString()})
          .toList();
    } catch (e, st) {
      debugPrint('fetchCoursesForClass (supabase) error: $e\n$st');
      return [];
    }
  }

  // Fetch lecturers for a course id using UseTimetable. Returns list of maps {id,name}.
  // Note: lecturers are now auto-assigned from course via UseTimetable.autoAssignTeacher

  // ---------- UI actions ----------

  Future<void> _loadCoursesAndClearSelection(String? classId) async {
    setState(() {
      _loadingCourses = true;
      _courses = [];
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
      _courses = courses;
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
          // IMPORTANT: when we select a course that has an id, immediately
          // load the lecturer(s) for that course. This picks up teacher_assigned
          // automatically per the database's teacher_assigned field.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _loadLecturersForCourse(_selectedCourseId);
          });
        }
      }
      if (_courses.isEmpty && (widget.courses.isEmpty)) _useCustomCourse = true;
      _loadingCourses = false;
    });
  }

  Future<void> _loadLecturersForCourse(String? courseId) async {
    setState(() {
      _loadingLecturers = true;
      _lecturers = [];
      _selectedLecturerId = null;
      _selectedLecturerName = null;
      _customLecturerCtrl.clear();
    });
    if (courseId == null || courseId.trim().isEmpty) {
      setState(() => _loadingLecturers = false);
      return;
    }

    // Use service autoAssignTeacher to strictly obtain assigned teacher.
    try {
      final auto = await _svc.autoAssignTeacher(courseId);
      if (auto != null && auto['id'] != null) {
        setState(() {
          _selectedLecturerId = auto['id'];
          _selectedLecturerName = auto['name'] ?? auto['id'];
          _lecturers = [
            {
              'id': _selectedLecturerId ?? '',
              'name': _selectedLecturerName ?? '',
            },
          ];

          _loadingLecturers = false;
        });
      } else {
        // No assigned teacher found — keep empty and let save show error
        setState(() {
          _lecturers = [];
          _selectedLecturerId = null;
          _selectedLecturerName = null;
          _loadingLecturers = false;
        });
      }
    } catch (e, st) {
      debugPrint('autoAssignTeacher fetch error: $e\\n$st');
      setState(() => _loadingLecturers = false);
    }
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
    // Require a selected course with an assigned teacher (no manual lecturer selection)
    if (_useCustomCourse ||
        _selectedCourseId == null ||
        _selectedCourseId!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a course from the list')),
      );
      return;
    }

    if (_selectedLecturerId == null || _selectedLecturerId!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Course has no teacher assigned')),
      );
      return;
    }

    final course = (_selectedCourseName ?? '').trim();
    final lecturer = (_selectedLecturerName ?? '').trim();
    final cellText = course.isEmpty
        ? lecturer
        : (lecturer.isEmpty ? course : '$course\n$lecturer');
    Navigator.of(context).pop(
      TimetableCellEditResult(
        cellText: cellText,
        courseId: (_selectedCourseId != null && _selectedCourseId!.isNotEmpty)
            ? _selectedCourseId
            : null,
        lecturerId:
            (_selectedLecturerId != null && _selectedLecturerId!.isNotEmpty)
            ? _selectedLecturerId
            : null,
      ),
    );
  }

  void _clear() {
    Navigator.of(context).pop(TimetableCellEditResult(cellText: ''));
  }

  // ---------- Build UI ----------

  @override
  Widget build(BuildContext context) {
    // prepare dropdown items: show name but use id as value when available
    final courseEntries = _courses
        .map((c) => MapEntry(c['id'] ?? '', c['name'] ?? ''))
        .toList();
    // lecturerEntries intentionally not used — lecturer is readonly/auto-assigned

    return AlertDialog(
      title: const Text('Edit Timetable Cell'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Course field
            Row(
              children: [
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Course',
                      border: OutlineInputBorder(),
                      isDense: true,
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
                              value:
                                  (_selectedCourseId != null &&
                                      _selectedCourseId!.isNotEmpty)
                                  ? _selectedCourseId
                                  : null,
                              hint: Text(
                                _selectedCourseName ?? 'Select course',
                              ),
                              items: courseEntries
                                  .map(
                                    (e) => DropdownMenuItem<String>(
                                      value: e.key,
                                      child: Text(e.value),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (id) {
                                Map<String, String>? picked;
                                for (final c in _courses) {
                                  try {
                                    if (c['id'] == id) {
                                      picked = c;
                                      break;
                                    }
                                  } catch (_) {}
                                }
                                picked ??= {'id': id ?? '', 'name': id ?? ''};
                                _onCoursePickedByUser(picked);
                              },
                            ),
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Lecturer field — readonly (auto-assigned). No manual selection.
            Row(
              children: [
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Lecturer',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    child: _loadingLecturers
                        ? const SizedBox(
                            height: 40,
                            child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : Text(
                            _selectedLecturerName ??
                                'Course has no teacher assigned',
                            style: const TextStyle(fontSize: 14),
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
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _clear, child: const Text('Clear')),
        ElevatedButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
