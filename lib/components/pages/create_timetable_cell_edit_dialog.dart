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
  bool _useCustomLecturer = false;
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
        _useCustomLecturer = false;
      } else {
        _useCustomLecturer = true;
        _customLecturerCtrl.text = _selectedLecturerName!;
      }
    } else if (_lecturers.isEmpty) {
      _useCustomLecturer = true;
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
  Future<List<Map<String, String>>> _fetchLecturersForCourseDoc(
    String courseDocId,
  ) async {
    try {
      // Ensure teachers cache is loaded
      if (_svc.teachers.isEmpty) await _svc.loadTeachers();

      // Try to find the course in the cached courses
      Map<String, dynamic>? course;
      for (final c in _svc.courses) {
        try {
          if (c['id'].toString() == courseDocId) {
            course = c;
            break;
          }
        } catch (_) {}
      }
      if (course != null && course.isNotEmpty) {
        final raw = course['raw'] as Map<String, dynamic>? ?? {};

        // 1) teacher_assigned string id
        if (raw.containsKey('teacher_assigned') &&
            raw['teacher_assigned'] is String) {
          final tid = (raw['teacher_assigned'] ?? '').toString();
          if (tid.isNotEmpty) {
            Map<String, dynamic>? found;
            for (final t in _svc.teachers) {
              try {
                if (t['id'].toString() == tid) {
                  found = t;
                  break;
                }
              } catch (_) {}
            }
            if (found != null && found.isNotEmpty) {
              return [
                {'id': tid, 'name': (found['name'] ?? tid).toString()},
              ];
            }
          }
        }

        // 2) embedded teacher map
        if (raw.containsKey('teacher') && raw['teacher'] is Map) {
          final t = raw['teacher'] as Map<String, dynamic>;
          final tid = (t['id'] ?? t['teacher_id'] ?? '').toString();
          final tname = (t['name'] ?? t['full_name'] ?? '').toString();
          if (tname.isNotEmpty)
            return [
              {'id': tid, 'name': tname},
            ];
        }

        // 3) teachers array of ids or maps
        if (raw.containsKey('teachers') && raw['teachers'] is List) {
          final list = raw['teachers'] as List;
          for (final item in list) {
            try {
              if (item is String) {
                Map<String, dynamic>? found;
                for (final t in _svc.teachers) {
                  try {
                    if (t['id'].toString() == item) {
                      found = t;
                      break;
                    }
                  } catch (_) {}
                }
                if (found != null && found.isNotEmpty)
                  return [
                    {'id': item, 'name': (found['name'] ?? item).toString()},
                  ];
              } else if (item is Map) {
                final tid = (item['id'] ?? item['teacher_id'] ?? '').toString();
                final tname = (item['name'] ?? item['full_name'] ?? '')
                    .toString();
                if (tname.isNotEmpty)
                  return [
                    {'id': tid, 'name': tname},
                  ];
              }
            } catch (_) {}
          }
        }
      }

      return [];
    } catch (e, st) {
      debugPrint('fetchLecturersForCourseDoc (supabase) error: $e\n$st');
      return [];
    }
  }

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
      _useCustomLecturer = false;
      _customLecturerCtrl.clear();
    });
    if (courseId == null || courseId.trim().isEmpty) {
      setState(() => _loadingLecturers = false);
      return;
    }
    final lecturers = await _fetchLecturersForCourseDoc(courseId);
    setState(() {
      _lecturers = lecturers;
      if (widget.initialLecturer != null) {
        final match = _lecturers.indexWhere(
          (t) =>
              (t['name'] ?? '').toLowerCase() ==
              widget.initialLecturer!.toLowerCase(),
        );
        if (match >= 0) {
          _selectedLecturerId = _lecturers[match]['id'];
          _selectedLecturerName = _lecturers[match]['name'];
          _useCustomLecturer = false;
        }
      } else if (_lecturers.isNotEmpty) {
        // Auto-select the first lecturer if available (this picks teacher_assigned)
        _selectedLecturerId = _lecturers.first['id'];
        _selectedLecturerName = _lecturers.first['name'];
        _useCustomLecturer = false;
      }
      if (_lecturers.isEmpty && widget.lecturers.isEmpty)
        _useCustomLecturer = true;
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
    final lecturerEntries = _lecturers
        .map((t) => MapEntry(t['id'] ?? '', t['name'] ?? ''))
        .toList();

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
            // Lecturer field
            Row(
              children: [
                Expanded(
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Lecturer',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    child: _useCustomLecturer
                        ? TextFormField(
                            controller: _customLecturerCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Enter lecturer name',
                              border: InputBorder.none,
                              isDense: true,
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
                              value:
                                  (_selectedLecturerId != null &&
                                      _selectedLecturerId!.isNotEmpty)
                                  ? _selectedLecturerId
                                  : null,
                              hint: Text(
                                _selectedLecturerName ?? 'Select lecturer',
                              ),
                              items: lecturerEntries
                                  .map(
                                    (e) => DropdownMenuItem<String>(
                                      value: e.key,
                                      child: Text(e.value),
                                    ),
                                  )
                                  .toList(),
                              onChanged:
                                  (_selectedCourseId != null &&
                                      _selectedCourseId!.isNotEmpty)
                                  ? (id) {
                                      Map<String, String>? picked;
                                      for (final t in _lecturers) {
                                        try {
                                          if (t['id'] == id) {
                                            picked = t;
                                            break;
                                          }
                                        } catch (_) {}
                                      }
                                      picked ??= {
                                        'id': id ?? '',
                                        'name': id ?? '',
                                      };
                                      final pid = picked['id'] ?? '';
                                      final pname = picked['name'] ?? '';
                                      setState(() {
                                        _selectedLecturerId = pid;
                                        _selectedLecturerName = pname;
                                        _useCustomLecturer = false;
                                        _customLecturerCtrl.clear();
                                      });
                                    }
                                  : null,
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
