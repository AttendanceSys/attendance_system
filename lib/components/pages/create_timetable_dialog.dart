// Full corrected CreateTimetableDialog implementation
// - Fixed missing braces and misplaced helper class definitions
// - Ensures _recomputeTeachingIndices exists and _AddPeriodResult / TimeSpan are top-level
// - Loads classes exactly like TimetablePage and clears class selection when department changes
//
// Save as: lib/components/pages/create_timetable_dialog.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../theme/super_admin_theme.dart';
import 'package:flutter/services.dart';

/// A single session result (one timetable cell)
class CreateTimetableTimeResult {
  final String department; // department display name (now)
  final String classKey; // class display name (now)
  final int dayIndex;
  final int startMinutes;
  final int endMinutes;
  final String cellText;

  CreateTimetableTimeResult({
    required this.department,
    required this.classKey,
    required this.dayIndex,
    required this.startMinutes,
    required this.endMinutes,
    required this.cellText,
  });
}

/// Dialog payload returned to parent
class CreateTimetableTimePayload {
  final List<CreateTimetableTimeResult> results;
  final List<String>? periodsOverride;

  CreateTimetableTimePayload({required this.results, this.periodsOverride});
}

/// Prefill data for existing timetable sessions
class PrefilledSession {
  final int dayIndex;
  final String periodLabel;
  final String? course;
  final String? lecturer;

  PrefilledSession({
    required this.dayIndex,
    required this.periodLabel,
    this.course,
    this.lecturer,
  });
}

class CreateTimetableDialog extends StatefulWidget {
  final List<String> departments; // display names list (UI only)
  final Map<String, List<String>> departmentClasses; // fallback mapping
  final List<String> lecturers;
  final List<String> days;
  final List<String>? courses;

  final String? initialDepartment; // display name (optional)
  final String? initialClass; // display name or id (optional)

  // departmentArg: DocumentReference or department id string (preferred for querying)
  final dynamic departmentArg;

  final List<String>? preconfiguredLabels; // optional periods passed in
  final List<PrefilledSession>? prefilledSessions; // optional existing sessions

  const CreateTimetableDialog({
    super.key,
    required this.departments,
    required this.departmentClasses,
    required this.lecturers,
    required this.days,
    this.courses,
    this.initialDepartment,
    this.initialClass,
    this.preconfiguredLabels,
    this.prefilledSessions,
    this.departmentArg,
  });

  @override
  State<CreateTimetableDialog> createState() => _CreateTimetableDialogState();
}

class _CreateTimetableDialogState extends State<CreateTimetableDialog> {
  String? _department; // display name selected by user
  String? _classKey; // display name shown in dropdown (class name)
  String?
  _classIdForSave; // class document id used for loading courses (not used in payload)
  String? _lecturer;
  bool _useCustomLecturer = false;
  final TextEditingController _lecturerCustomCtrl = TextEditingController();
  String? _course;

  // Keep all prefilled sessions so we can filter them by course selection.
  List<PrefilledSession> _allPrefilledSessions = [];

  final List<_SessionRow> _sessions = [_SessionRow()];

  List<String> _labels = [];
  List<(int, int)> _spans = [];
  List<int> _teachingIndices = [];
  int? _inferredPeriodMinutes;

  List<Map<String, dynamic>> _loadedClasses = []; // {id,name,raw,ref}
  List<Map<String, dynamic>> _loadedCourses = []; // {id,course_name,raw,ref}
  bool _loadingClasses = false;
  bool _loadingCourses = false;
  // local copy of lecturers so we can add/auto-select class/course assigned teacher
  List<String> _availableLecturers = [];

  List<String> get _courseList => (_loadedCourses.isNotEmpty)
      ? _loadedCourses
            .map((c) => c['course_name']?.toString() ?? c['id'].toString())
            .toList()
      : [];

  bool get _configured =>
      _labels.isNotEmpty &&
      _spans.length == _labels.length &&
      _teachingIndices.isNotEmpty;

  final RegExp _timeLabelRegex = RegExp(
    r'^\s*(\d{1,2}):([0-5]\d)\s*-\s*(\d{1,2}):([0-5]\d)(?:\s*\(break\))?\s*$',
    caseSensitive: false,
  );

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _department = widget.initialDepartment;
    _classKey = widget.initialClass;
    _classIdForSave = null;

    _availableLecturers = List<String>.from(widget.lecturers);

    _allPrefilledSessions = List<PrefilledSession>.from(
      widget.prefilledSessions ?? const <PrefilledSession>[],
    );

    if (widget.preconfiguredLabels != null &&
        widget.preconfiguredLabels!.isNotEmpty) {
      _loadPreconfigured(widget.preconfiguredLabels!);
    }

    // Apply prefilled sessions when labels are known; filtering happens per course.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyPrefilledSessionsForCourse(_course);
    });

    if (widget.departmentArg != null) {
      _loadClassesForDepartment(
        widget.departmentArg,
        preserveInitialClass: true,
      );
    } else if (_department != null && _department!.isNotEmpty) {
      _loadClassesForDepartment(_department, preserveInitialClass: true);
    }

    if (_classKey != null && _classKey!.isNotEmpty) {
      _safeLoadCoursesForClass(_classIdForSave ?? _classKey);
    }
  }

  @override
  void dispose() {
    _lecturerCustomCtrl.dispose();
    super.dispose();
  }

  // ---------------- Loaders ----------------

  Future<void> _loadClassesForDepartment(
    dynamic depIdOrRef, {
    bool preserveInitialClass = false,
  }) async {
    setState(() {
      _loadingClasses = true;
      _loadedClasses = [];
      _loadedCourses = [];
      if (!preserveInitialClass) {
        _classKey = null;
        _classIdForSave = null;
      }
      _course = null;
    });

    try {
      debugPrint('CreateDialog: loading classes for $depIdOrRef');
      final classesCol = _firestore.collection('classes');

      Future<List<QueryDocumentSnapshot>> tryQuery(Query q, String tag) async {
        try {
          final snap = await q.get();
          debugPrint(
            'CreateDialog classes query [$tag] -> ${snap.docs.length} docs',
          );
          if (snap.docs.isNotEmpty) {
            debugPrint(
              'CreateDialog classes [$tag] first doc: ${snap.docs.first.data()}',
            );
          }
          return snap.docs;
        } catch (e, st) {
          debugPrint('CreateDialog classes query [$tag] failed: $e\n$st');
          return <QueryDocumentSnapshot>[];
        }
      }

      List<QueryDocumentSnapshot> docs = [];

      if (depIdOrRef is DocumentReference) {
        docs = await tryQuery(
          classesCol.where('department_ref', isEqualTo: depIdOrRef),
          'department_ref==DocumentReference',
        );
        if (docs.isEmpty) {
          docs = await tryQuery(
            classesCol.where('department_ref', isEqualTo: depIdOrRef.id),
            'department_ref==DocumentReference.id',
          );
        }
      } else if (depIdOrRef is String) {
        docs = await tryQuery(
          classesCol.where('department_ref', isEqualTo: depIdOrRef),
          'department_ref==String',
        );
        if (docs.isEmpty) {
          docs = await tryQuery(
            classesCol.where('department_id', isEqualTo: depIdOrRef),
            'department_id==String',
          );
        }
        if (docs.isEmpty) {
          docs = await tryQuery(
            classesCol.where('department', isEqualTo: depIdOrRef),
            'department==String',
          );
        }
        if (docs.isEmpty) {
          docs = await tryQuery(
            classesCol.where('department_name', isEqualTo: depIdOrRef),
            'department_name==String',
          );
        }
      }

      final classes = docs.map((d) {
        final data = d.data() as Map<String, dynamic>;
        final name = (data['class_name'] ?? data['name'] ?? d.id).toString();
        return {'id': d.id, 'name': name, 'raw': data, 'ref': d.reference};
      }).toList();

      classes.sort(
        (a, b) => a['name'].toString().compareTo(b['name'].toString()),
      );

      setState(() {
        _loadedClasses = classes;
      });

      if (_loadedClasses.isNotEmpty &&
          preserveInitialClass &&
          widget.initialClass != null &&
          widget.initialClass!.isNotEmpty) {
        final init = widget.initialClass!;
        Map<String, dynamic> byId = {};
        for (final c in _loadedClasses) {
          if ((c['id']?.toString() ?? '') == init) {
            byId = Map<String, dynamic>.from(c);
            break;
          }
        }
        if (byId.isNotEmpty) {
          setState(() {
            _classKey = byId['name']?.toString();
            _classIdForSave = byId['id']?.toString();
          });
          await _loadCoursesForClass(_classIdForSave);
          return;
        }

        Map<String, dynamic> byName = {};
        for (final c in _loadedClasses) {
          if ((c['name']?.toString() ?? '') == init) {
            byName = Map<String, dynamic>.from(c);
            break;
          }
        }
        if (byName.isNotEmpty) {
          setState(() {
            _classKey = byName['name']?.toString();
            _classIdForSave = byName['id']?.toString();
          });
          await _loadCoursesForClass(_classIdForSave);
          return;
        }
      }

      // Do NOT auto-select the first class when classes load. The user must
      // explicitly pick a class. Preserve only the initialClass behavior above.

      if (_loadedClasses.isEmpty) {
        debugPrint('CreateDialog: no classes found for $depIdOrRef');
        setState(() {
          _classKey = null;
          _classIdForSave = null;
        });
      }
    } catch (e, st) {
      debugPrint('CreateDialog loadClasses error: $e\n$st');
      setState(() {
        _loadedClasses = [];
        _classKey = null;
        _classIdForSave = null;
      });
    } finally {
      setState(() => _loadingClasses = false);
    }
  }

  void _safeLoadCoursesForClass(String? classId) {
    if (classId == null) return;
    _loadCoursesForClass(classId);
  }

  Future<void> _loadCoursesForClass(String? classId) async {
    if (classId == null) return;
    setState(() {
      _loadingCourses = true;
      _loadedCourses = [];
      _course = null;
    });

    try {
      final coursesCol = _firestore.collection('courses');

      // Helper that attempts a where query for multiple possible stored shapes.
      Future<QuerySnapshot> tryQ(String field, dynamic value) async {
        try {
          return await coursesCol.where(field, isEqualTo: value).get();
        } catch (e) {
          return await coursesCol.where(field, isEqualTo: value).get();
        }
      }

      // Many projects store the class reference either as the document id (String)
      // or as a DocumentReference. Try both shapes for the likely fields.
      final classRef = _firestore.collection('classes').doc(classId);

      QuerySnapshot snap = await tryQ('class', classId);
      if (snap.docs.isEmpty) snap = await tryQ('class', classRef);
      if (snap.docs.isEmpty) snap = await tryQ('class_id', classId);
      if (snap.docs.isEmpty) snap = await tryQ('class_ref', classRef);
      if (snap.docs.isEmpty) snap = await tryQ('class_ref', classId);
      if (snap.docs.isEmpty) snap = await tryQ('class_name', classId);

      if (snap.docs.isEmpty) {
        debugPrint('CreateDialog: no courses found for classId=$classId');
        setState(() {
          _loadedCourses = [];
          _course = null;
        });
        return;
      }

      final courses = snap.docs.map((d) {
        final data = d.data() as Map<String, dynamic>;
        final name =
            (data['course_name'] ??
                    data['title'] ??
                    data['course_code'] ??
                    d.id)
                .toString();
        return {
          'id': d.id,
          'course_name': name,
          'raw': data,
          'ref': d.reference,
        };
      }).toList();

      courses.sort(
        (a, b) =>
            a['course_name'].toString().compareTo(b['course_name'].toString()),
      );

      setState(() {
        _loadedCourses = courses;
        // Do NOT auto-select a course; user must explicitly pick the course.
        _course = null;
      });
    } catch (e, st) {
      debugPrint('CreateDialog loadCourses error: $e\n$st');
      setState(() {
        _loadedCourses = [];
        _course = null;
      });
    } finally {
      setState(() => _loadingCourses = false);
    }
  }

  // ---------------- Helpers & UI logic ----------------

  Future<bool> _confirm({
    required String title,
    required String content,
    String confirmText = 'Yes',
    String cancelText = 'No',
    bool destructive = false,
  }) async {
    final palette = Theme.of(context).extension<SuperAdminColors>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final res = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: isDark
                ? TextButton.styleFrom(foregroundColor: palette?.textSecondary)
                : null,
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: destructive
                  ? Colors.red
                  : (isDark
                        ? (palette?.accent ??
                              Theme.of(context).colorScheme.primary)
                        : Theme.of(context).colorScheme.primary),
              foregroundColor: isDark
                  ? (palette?.textPrimary ?? Colors.white)
                  : Colors.white,
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return res == true;
  }

  void _loadPreconfigured(List<String> labels) {
    final newSpans = <(int, int)>[];
    final teachingIdx = <int>[];
    int? inferredLen;

    for (int i = 0; i < labels.length; i++) {
      final l = labels[i];
      final m = _timeLabelRegex.firstMatch(l);
      if (m == null) {
        debugPrint('Skipping unparsable existing label: $l');
        return;
      }
      final sh = int.parse(m.group(1)!);
      final sm = int.parse(m.group(2)!);
      final eh = int.parse(m.group(3)!);
      final em = int.parse(m.group(4)!);
      final start = sh * 60 + sm;
      final end = eh * 60 + em;
      if (end <= start) {
        debugPrint('Invalid range in existing label: $l');
        return;
      }
      newSpans.add((start, end));
      final isBreak = (l.toLowerCase().contains('break'));
      if (!isBreak) {
        final len = end - start;
        inferredLen ??= len;
        if (inferredLen != len) inferredLen = null;
        teachingIdx.add(i);
      }
    }

    setState(() {
      _labels = List<String>.from(labels);
      _spans = newSpans;
      _teachingIndices = teachingIdx;
      _inferredPeriodMinutes = inferredLen;
      for (final s in _sessions) {
        s.dayIndex ??= 0;
        s.periodDropdownIndex = null;
      }
    });
  }

  void _applyPrefilledSessionsForCourse(String? courseName) {
    if (_labels.isEmpty) return; // need labels to map periods

    final target = courseName?.trim().toLowerCase() ?? '';
    final sessions = target.isEmpty
        ? <PrefilledSession>[]
        : _allPrefilledSessions.where((s) {
            final c = s.course?.trim().toLowerCase() ?? '';
            return c == target;
          }).toList();

    setState(() {
      if (sessions.isEmpty) {
        _sessions
          ..clear()
          ..add(_SessionRow());
        _lecturer = null;
        _useCustomLecturer = false;
        _lecturerCustomCtrl.clear();
        return;
      }

      _sessions
        ..clear()
        ..addAll(List.generate(sessions.length, (_) => _SessionRow()));

      String? firstLecturer;

      for (int i = 0; i < sessions.length; i++) {
        final src = sessions[i];
        final dst = _sessions[i];
        dst.dayIndex = src.dayIndex;

        final idx = _labels.indexWhere(
          (l) => l.toLowerCase().trim() == src.periodLabel.toLowerCase().trim(),
        );
        if (idx >= 0) {
          final teachingIdx = _teachingIndices.indexOf(idx);
          if (teachingIdx >= 0) dst.periodDropdownIndex = teachingIdx;
        }

        firstLecturer ??= src.lecturer?.trim().isNotEmpty == true
            ? src.lecturer!.trim()
            : null;
      }

      if (firstLecturer != null) {
        if (_availableLecturers.contains(firstLecturer)) {
          _lecturer = firstLecturer;
          _useCustomLecturer = false;
        } else {
          _useCustomLecturer = true;
          _lecturerCustomCtrl.text = firstLecturer;
        }
      } else {
        _lecturer = null;
        _useCustomLecturer = false;
        _lecturerCustomCtrl.clear();
      }
    });
  }

  void _recomputeTeachingIndices() {
    _teachingIndices.clear();
    int? periodLen;
    bool consistent = true;
    for (int i = 0; i < _labels.length; i++) {
      final isBreak = _labels[i].toLowerCase().contains('break');
      if (!isBreak) {
        final span = _spans[i];
        final len = span.$2 - span.$1;
        periodLen ??= len;
        if (periodLen != len) consistent = false;
        _teachingIndices.add(i);
      }
    }
    _inferredPeriodMinutes = consistent ? periodLen : null;
  }

  // ---------------- Period generator & append ----------------

  Future<void> _openFullGenerator() async {
    if (_configured) {
      final ok = await _confirm(
        title: 'Replace period structure?',
        content:
            'You are about to reconfigure periods. Existing period selections in sessions will be reset.',
        confirmText: 'Replace',
        destructive: true,
      );
      if (!ok) return;
    }

    final result = await showDialog<_GeneratedScheduleResult>(
      context: context,
      builder: (ctx) => _PeriodGeneratorDialog(
        existingLabels: _labels,
        existingSpans: _spans,
        existingTeachingIndices: _teachingIndices,
      ),
    );
    if (result == null) return;

    setState(() {
      _labels = result.labels;
      _spans = result.spans;
      _teachingIndices = result.teachingIndices;
      _recomputeTeachingIndices();
      for (final s in _sessions) {
        s.periodDropdownIndex = null;
      }
    });
  }

  Future<void> _appendPeriodOrBreak() async {
    if (!_configured) {
      _snack('Configure or load periods first');
      return;
    }

    final res = await showDialog<_AddPeriodResult>(
      context: context,
      builder: (_) => _AddPeriodDialog(
        existingSpans: List<(int, int)>.from(_spans),
        existingLabels: List<String>.from(_labels),
        periodMinutes: _inferredPeriodMinutes,
      ),
    );
    if (res == null) return;

    final start = res.start;
    final end = res.end;
    final label =
        '${_fmt(start)} - ${_fmt(end)}${res.isBreak ? ' (Break)' : ''}';

    final ok = await _confirm(
      title: 'Add ${res.isBreak ? 'Break' : 'Period'}?',
      content:
          'You are adding:\n$label\n\nThis will be inserted into the current schedule in time order.',
      confirmText: 'Add',
    );
    if (!ok) return;

    int insertAt = 0;
    while (insertAt < _spans.length && _spans[insertAt].$1 < start) {
      insertAt++;
    }

    setState(() {
      _spans.insert(insertAt, (start, end));
      _labels.insert(insertAt, label);
      _recomputeTeachingIndices();
    });

    if (_inferredPeriodMinutes == null && !res.isBreak) {
      _snack(
        'Note: Teaching period length is now inconsistent. Consider reconfiguring.',
      );
    }
  }

  // ---------------- Sessions ----------------

  void _addSession() => setState(() => _sessions.add(_SessionRow()));

  void _removeSession(int i) async {
    if (i == 0) return;
    final ok = await _confirm(
      title: 'Remove session?',
      content: 'Do you want to remove session #${i + 1} from this list?',
      confirmText: 'Remove',
      destructive: true,
    );
    if (!ok) return;
    setState(() => _sessions.removeAt(i));
  }

  List<String> get _teachingLabels =>
      _teachingIndices.map((i) => _labels[i]).toList();

  Future<void> _clearGenerated() async {
    final ok = await _confirm(
      title: 'Clear period structure?',
      content:
          'This will remove all period labels and break labels from this dialog. Sessions will keep their Day but lose the selected Start period.',
      confirmText: 'Clear',
      destructive: true,
    );
    if (!ok) return;
    setState(() {
      _labels.clear();
      _spans.clear();
      _teachingIndices.clear();
      _inferredPeriodMinutes = null;
      for (final s in _sessions) {
        s.periodDropdownIndex = null;
      }
    });
  }

  // ---------------- Save ----------------

  Future<void> _save() async {
    if (_department == null || (_classKey == null && _classIdForSave == null)) {
      _snack('Please select Department and Class');
      return;
    }
    if ((_course ?? '').trim().isEmpty) {
      _snack('Please choose a Course');
      return;
    }
    if (!_configured) {
      _snack('Configure or load periods first');
      return;
    }
    _assertIntegrity();
    if (!_configured) {
      _snack('Schedule integrity failed; please reconfigure.');
      return;
    }

    final lecturerName = _useCustomLecturer
        ? _lecturerCustomCtrl.text.trim()
        : (_lecturer ?? '').trim();
    final cellText = lecturerName.isEmpty
        ? _course!.trim()
        : '${_course!.trim()}\n$lecturerName';

    final results = <CreateTimetableTimeResult>[];
    final seenPairs = <String>{};

    for (int i = 0; i < _sessions.length; i++) {
      final s = _sessions[i];
      if (s.dayIndex == null) {
        _snack('Session ${i + 1}: choose Day');
        return;
      }
      if (s.periodDropdownIndex == null) {
        _snack('Session ${i + 1}: choose Start period');
        return;
      }
      if (s.periodDropdownIndex! < 0 ||
          s.periodDropdownIndex! >= _teachingIndices.length) {
        _snack('Session ${i + 1}: invalid period selection');
        return;
      }
      final labelIdx = _teachingIndices[s.periodDropdownIndex!];
      if (labelIdx >= _spans.length) {
        _snack('Session ${i + 1}: internal span index error');
        return;
      }

      final key = '${s.dayIndex}-$labelIdx';
      if (seenPairs.contains(key)) {
        final proceed = await _confirm(
          title: 'Duplicate session?',
          content:
              'You have more than one session on ${widget.days[s.dayIndex!]} at "${_labels[labelIdx]}".\nDo you want to continue?',
          confirmText: 'Continue',
        );
        if (!proceed) return;
      } else {
        seenPairs.add(key);
      }

      final span = _spans[labelIdx];

      final returnedDeptName = _department!.trim();
      final returnedClassName = _classKey!.trim();

      results.add(
        CreateTimetableTimeResult(
          department: returnedDeptName,
          classKey: returnedClassName,
          dayIndex: s.dayIndex!,
          startMinutes: span.$1,
          endMinutes: span.$2,
          cellText: cellText,
        ),
      );
    }

    if (results.isEmpty) {
      _snack('Nothing to save');
      return;
    }

    final summary = results
        .map((r) {
          final d = widget.days[r.dayIndex];
          final t = '${_fmt(r.startMinutes)} - ${_fmt(r.endMinutes)}';
          return '- $d  $t  • ${_course!.trim()}${lecturerName.isNotEmpty ? ' • $lecturerName' : ''}';
        })
        .join('\n');

    final ok = await _confirm(
      title: 'Save timetable entries?',
      content:
          'Department: ${_department!}\nClass: ${_classKey ?? _classIdForSave}\n\nEntries:\n$summary',
      confirmText: 'Save',
    );
    if (!ok) return;

    Navigator.of(context).pop(
      CreateTimetableTimePayload(
        results: results,
        periodsOverride: List<String>.from(_labels),
      ),
    );
  }

  // ---------------- UI utils & helpers ----------------

  String _fmt(int minutes) =>
      '${minutes ~/ 60}:${(minutes % 60).toString().padLeft(2, '0')}';

  void _snack(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  void _assertIntegrity() {
    if (_labels.length != _spans.length) {
      _labels.clear();
      _spans.clear();
      _teachingIndices.clear();
      _inferredPeriodMinutes = null;
    }
  }

  List<String> _classesForDepartmentKey(String? dept) {
    if (dept == null || dept.trim().isEmpty) return [];
    final lower = dept.toLowerCase();
    if (widget.departmentClasses.containsKey(dept)) {
      return widget.departmentClasses[dept]!;
    }
    final matchKey = widget.departmentClasses.keys.firstWhere(
      (k) => k.toLowerCase() == lower,
      orElse: () => '',
    );
    if (matchKey.isNotEmpty) return widget.departmentClasses[matchKey] ?? [];
    return [];
  }

  List<String> get _classesForDepartment {
    if (_loadedClasses.isNotEmpty) {
      return _loadedClasses
          .map((c) => c['name']?.toString() ?? c['id'].toString())
          .toList();
    }
    final list = _classesForDepartmentKey(_department);
    if (list.isNotEmpty) return list;
    return widget.departmentClasses.values.expand((e) => e).toList();
  }

  Widget _dropdownBox<T>({
    required String hint,
    required T? value,
    required List<T> items,
    ValueChanged<T?>? onChanged,
    Widget Function(T)? builder,
  }) {
    final palette = Theme.of(context).extension<SuperAdminColors>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InputDecorator(
      decoration: InputDecoration(
        border: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          borderSide: BorderSide(
            color: isDark
                ? (palette?.border ?? const Color(0xFF3A3F4A))
                : const Color(0xFFE5E7EB),
          ),
        ),
        focusedBorder: isDark
            ? OutlineInputBorder(
                borderRadius: const BorderRadius.all(Radius.circular(8)),
                borderSide: BorderSide(
                  color: palette?.accent ?? const Color(0xFF7C3AED),
                ),
              )
            : null,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        filled: true,
        fillColor: isDark
            ? (palette?.inputFill ?? const Color(0xFF2A2F3A))
            : Colors.white,
      ).copyWith(hintText: hint),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          dropdownColor: isDark
              ? (palette?.surface ?? const Color(0xFF1F2430))
              : null,
          style: isDark
              ? TextStyle(color: palette?.textPrimary ?? Colors.white)
              : null,
          hint: isDark
              ? Text(hint, style: TextStyle(color: palette?.textSecondary))
              : Text(hint),
          items: items
              .map(
                (e) => DropdownMenuItem<T>(
                  value: e,
                  child: builder != null
                      ? builder(e)
                      : Text(
                          e.toString(),
                          style: isDark
                              ? TextStyle(color: palette?.textPrimary)
                              : null,
                        ),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _wrapFields(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double maxW = constraints.maxWidth;
        final double itemMax = maxW < 420
            ? maxW
            : (maxW < 720 ? (maxW - 12) / 2 : 280);
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: children
              .map(
                (c) => ConstrainedBox(
                  constraints: BoxConstraints(minWidth: 180, maxWidth: itemMax),
                  child: c,
                ),
              )
              .toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final teachingLabels = _teachingLabels;

    final palette = Theme.of(context).extension<SuperAdminColors>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      backgroundColor: isDark
          ? (palette?.surfaceHigh ?? const Color(0xFF1F2430))
          : null,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Create Time Table Entry',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark ? palette?.textPrimary : null,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.close,
                          color: isDark ? palette?.iconColor : null,
                        ),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Dept / Class
                  _wrapFields([
                    _dropdownBox<String>(
                      hint: 'Department',
                      value: _department,
                      items: widget.departments,
                      onChanged: (v) async {
                        setState(() {
                          _department = v;
                          _classKey = null;
                          _classIdForSave = null;
                          _loadedClasses = [];
                          _loadedCourses = [];
                          _course = null;
                        });

                        try {
                          dynamic depArg = widget.departmentArg;
                          bool matchedParentArg = false;
                          if (v != null && depArg is DocumentReference) {
                            try {
                              final doc = await depArg.get();
                              final data = doc.data() as Map<String, dynamic>?;
                              final name = data != null
                                  ? (data['name'] ??
                                            data['department_name'] ??
                                            data['displayName'])
                                        ?.toString()
                                  : null;
                              if (name != null &&
                                  name.toLowerCase() == v.toLowerCase()) {
                                matchedParentArg = true;
                              }
                            } catch (_) {
                              matchedParentArg = false;
                            }
                          }

                          if (!matchedParentArg && v != null) {
                            try {
                              final deptCol = _firestore.collection(
                                'departments',
                              );
                              QuerySnapshot snap = await deptCol
                                  .where('name', isEqualTo: v)
                                  .get();
                              if (snap.docs.isEmpty) {
                                snap = await deptCol
                                    .where('department_name', isEqualTo: v)
                                    .get();
                              }
                              if (snap.docs.isEmpty) {
                                snap = await deptCol
                                    .where('displayName', isEqualTo: v)
                                    .get();
                              }
                              if (snap.docs.isNotEmpty) {
                                depArg = snap.docs.first.reference;
                              } else {
                                depArg = v;
                              }
                            } catch (e, st) {
                              debugPrint(
                                'Error resolving department name to doc: $e\n$st',
                              );
                              depArg = v;
                            }
                          }

                          if (depArg != null) {
                            await _loadClassesForDepartment(
                              depArg,
                              preserveInitialClass: false,
                            );
                          }
                        } catch (err, st) {
                          debugPrint(
                            'CreateDialog department change error: $err\n$st',
                          );
                        }
                      },
                    ),
                    _dropdownBox<String>(
                      hint: _loadingClasses ? 'Loading classes...' : 'Class',
                      value: _classKey,
                      items: _classesForDepartment.isNotEmpty
                          ? _classesForDepartment
                          : widget.departmentClasses.values
                                .expand((e) => e)
                                .toList(),
                      onChanged: (v) async {
                        setState(() {
                          _classKey = v;
                          _loadedCourses = [];
                          _course = null;
                          _classIdForSave = null;
                        });

                        if (v == null) return;

                        try {
                          String? classDocId;
                          Map<String, dynamic>? classRaw;

                          // Try to find class doc from loaded classes (match id or name, case-insensitive)
                          if (_loadedClasses.isNotEmpty) {
                            Map<String, dynamic> found = {};
                            for (final c in _loadedClasses) {
                              final name = (c['name']?.toString() ?? '')
                                  .toLowerCase();
                              final val = v.toLowerCase();
                              final id = (c['id']?.toString() ?? '');
                              if (name == val || id == v || id == val) {
                                found = Map<String, dynamic>.from(c);
                                break;
                              }
                            }
                            if (found.isNotEmpty) {
                              classDocId = found['id']?.toString();
                              classRaw = Map<String, dynamic>.from(
                                found['raw'] ?? {},
                              );
                            }
                          }

                          // Fallback: try to query classes collection by name/id
                          if (classDocId == null) {
                            final classesCol = _firestore.collection('classes');
                            QuerySnapshot csnap = await classesCol
                                .where('class_name', isEqualTo: v)
                                .get();
                            if (csnap.docs.isEmpty) {
                              csnap = await classesCol
                                  .where('name', isEqualTo: v)
                                  .get();
                            }
                            if (csnap.docs.isEmpty) {
                              csnap = await classesCol
                                  .where('class_id', isEqualTo: v)
                                  .get();
                            }
                            if (csnap.docs.isEmpty) {
                              csnap = await classesCol
                                  .where('department_ref', isEqualTo: v)
                                  .get();
                            }
                            if (csnap.docs.isNotEmpty) {
                              final d = csnap.docs.first;
                              classDocId = d.id;
                              classRaw = d.data() as Map<String, dynamic>?;
                            }
                          }

                          if (classDocId != null) {
                            setState(() => _classIdForSave = classDocId);
                            await _loadCoursesForClass(_classIdForSave);

                            // If class doc has an assigned teacher, resolve and auto-select it
                            try {
                              if (classRaw != null && classRaw.isNotEmpty) {
                                final candidateKeys = [
                                  'teacher',
                                  'teacher_assigned',
                                  'teacher_id',
                                  'teacher_ref',
                                  'assigned_teacher',
                                  'teacherAssigned',
                                ];
                                dynamic teacherVal;
                                for (final k in candidateKeys) {
                                  if (classRaw.containsKey(k) &&
                                      classRaw[k] != null) {
                                    teacherVal = classRaw[k];
                                    break;
                                  }
                                }
                                if (teacherVal != null) {
                                  DocumentReference? tref;
                                  if (teacherVal is DocumentReference) {
                                    tref = teacherVal;
                                  } else if (teacherVal is String) {
                                    final s = teacherVal.trim();
                                    try {
                                      tref = s.contains('/')
                                          ? _firestore.doc(s)
                                          : _firestore
                                                .collection('teachers')
                                                .doc(s);
                                    } catch (_) {
                                      tref = _firestore
                                          .collection('teachers')
                                          .doc(s);
                                    }
                                  }
                                  if (tref != null) {
                                    final tdoc = await tref.get();
                                    if (tdoc.exists) {
                                      final data =
                                          tdoc.data() as Map<String, dynamic>?;
                                      final name =
                                          (data?['teacher_name'] ??
                                                  data?['name'] ??
                                                  data?['displayName'] ??
                                                  data?['username'] ??
                                                  tdoc.id)
                                              .toString();
                                      if (mounted) {
                                        setState(() {
                                          if (!_availableLecturers.contains(
                                            name,
                                          )) {
                                            _availableLecturers.add(name);
                                          }
                                          _lecturer = name;
                                        });
                                      }
                                    }
                                  }
                                }
                              }
                            } catch (e, st) {
                              debugPrint(
                                'CreateDialog: error resolving class teacher: $e\n$st',
                              );
                            }
                          }
                        } catch (err, st) {
                          debugPrint(
                            'CreateDialog class change loadCourses error: $err\n$st',
                          );
                        }
                      },
                    ),
                  ]),

                  const SizedBox(height: 12),

                  // Lecturer / Course
                  _wrapFields([
                    !_useCustomLecturer
                        ? InputDecorator(
                            isEmpty:
                                (_lecturer == null ||
                                _lecturer!.trim().isEmpty),
                            decoration: InputDecoration(
                              border: const OutlineInputBorder(
                                borderRadius: BorderRadius.all(
                                  Radius.circular(8),
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: const BorderRadius.all(
                                  Radius.circular(8),
                                ),
                                borderSide: BorderSide(
                                  color: isDark
                                      ? (palette?.border ??
                                            const Color(0xFF3A3F4A))
                                      : const Color(0xFFE5E7EB),
                                ),
                              ),
                              focusedBorder: isDark
                                  ? OutlineInputBorder(
                                      borderRadius: const BorderRadius.all(
                                        Radius.circular(8),
                                      ),
                                      borderSide: BorderSide(
                                        color:
                                            palette?.accent ??
                                            const Color(0xFF7C3AED),
                                      ),
                                    )
                                  : null,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 22,
                              ),
                              filled: true,
                              fillColor: isDark
                                  ? (palette?.inputFill ??
                                        const Color(0xFF2A2F3A))
                                  : Colors.white,
                            ).copyWith(hintText: 'Lecturer'),
                            child:
                                (_lecturer != null &&
                                    _lecturer!.trim().isNotEmpty)
                                ? Text(
                                    _lecturer!,
                                    style: TextStyle(
                                      fontSize: 17,
                                      color: isDark
                                          ? (palette?.textPrimary ??
                                                Colors.white)
                                          : Colors.black,
                                    ),
                                  )
                                : const SizedBox.shrink(),
                          )
                        : TextFormField(
                            controller: _lecturerCustomCtrl,
                            decoration: InputDecoration(
                              hintText: 'Lecturer',
                              border: const OutlineInputBorder(),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              filled: true,
                              fillColor: isDark
                                  ? (palette?.inputFill ??
                                        const Color(0xFF2A2F3A))
                                  : Colors.white,
                            ),
                          ),
                    _dropdownBox<String>(
                      hint: _loadingCourses ? 'Loading courses...' : 'Course',
                      value: _course,
                      items: _courseList,
                      onChanged: (v) async {
                        setState(() {
                          _course = v;
                        });

                        // When a course is chosen, show only its existing sessions (if any).
                        _applyPrefilledSessionsForCourse(v);

                        if (v == null) return;

                        try {
                          Map<String, dynamic>? found;
                          if (_loadedCourses.isNotEmpty) {
                            Map<String, dynamic> f = {};
                            for (final c in _loadedCourses) {
                              if ((c['course_name']?.toString() ?? '') == v ||
                                  (c['id']?.toString() ?? '') == v) {
                                f = Map<String, dynamic>.from(c);
                                break;
                              }
                            }
                            if (f.isNotEmpty) {
                              found = Map<String, dynamic>.from(f['raw'] ?? {});
                            }
                          }

                          if (found == null) return;

                          final candidateKeys = [
                            'teacher_assigned',
                            'teacher',
                            'teacher_id',
                            'teacher_ref',
                            'assigned_teacher',
                            'teacherAssigned',
                          ];

                          dynamic teacherVal;
                          for (final k in candidateKeys) {
                            if (found.containsKey(k) && found[k] != null) {
                              teacherVal = found[k];
                              break;
                            }
                          }

                          if (teacherVal == null) return;

                          DocumentReference? tref;
                          if (teacherVal is DocumentReference) {
                            tref = teacherVal;
                          } else if (teacherVal is String) {
                            final s = teacherVal.trim();
                            try {
                              if (s.contains('/')) {
                                tref = _firestore.doc(s);
                              } else {
                                tref = _firestore.collection('teachers').doc(s);
                              }
                            } catch (_) {
                              tref = _firestore.collection('teachers').doc(s);
                            }
                          }

                          if (tref == null) return;

                          final doc = await tref.get();
                          if (!doc.exists) return;
                          final data = doc.data() as Map<String, dynamic>?;
                          final name =
                              (data?['teacher_name'] ??
                                      data?['name'] ??
                                      data?['displayName'] ??
                                      data?['username'] ??
                                      doc.id)
                                  .toString();

                          if (mounted) {
                            setState(() {
                              if (!_availableLecturers.contains(name)) {
                                _availableLecturers.add(name);
                              }
                              _lecturer = name;
                            });
                          }
                        } catch (e, st) {
                          debugPrint(
                            'CreateDialog: error resolving course teacher: $e\n$st',
                          );
                        }
                      },
                    ),
                  ]),

                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Switch(
                        value: _useCustomLecturer,
                        onChanged: (v) =>
                            setState(() => _useCustomLecturer = v),
                      ),
                      const SizedBox(width: 6),
                      const Text('Custom lecturer'),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Schedule controls
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: _openFullGenerator,
                        icon: Icon(
                          Icons.settings,
                          color: isDark
                              ? (palette?.iconColor ?? Colors.white)
                              : null,
                        ),
                        label: Text(
                          _configured
                              ? 'Reconfigure periods'
                              : 'Configure periods',
                          style: TextStyle(
                            color: isDark ? palette?.textPrimary : null,
                          ),
                        ),
                      ),
                      if (_configured)
                        OutlinedButton(
                          onPressed: _appendPeriodOrBreak,
                          child: Text(
                            'Append period / break',
                            style: TextStyle(
                              color: isDark ? palette?.textPrimary : null,
                            ),
                          ),
                        ),
                      if (_configured)
                        OutlinedButton(
                          onPressed: _clearGenerated,
                          child: Text(
                            'Clear structure',
                            style: TextStyle(
                              color: isDark ? palette?.textPrimary : null,
                            ),
                          ),
                        ),
                    ],
                  ),

                  if (_configured) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: List.generate(_labels.length, (i) {
                        final l = _labels[i];
                        final isBreak = l.toLowerCase().contains('break');
                        return Chip(
                          label: Text(
                            l,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? (palette?.textPrimary ?? Colors.white)
                                  : null,
                            ),
                          ),
                          backgroundColor: isDark
                              ? (isBreak
                                    ? (palette?.overlay ??
                                          const Color(0xFF2A2F3A))
                                    : (palette?.highlight ??
                                          const Color(0xFF2E2152)))
                              : (isBreak
                                    ? Colors.grey.shade200
                                    : Colors.blue.shade50),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        );
                      }),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Ends at ${_fmt(_spans.last.$2)} • Teaching: ${_teachingTotalHours()} • Breaks: ${_totalBreakMinutes()}m${_inferredPeriodMinutes != null ? ' • Period=${_inferredPeriodMinutes}m' : ''}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],

                  if (!_configured)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isDark
                            ? (palette?.overlay ?? const Color(0xFF2A2F3A))
                            : Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark
                              ? (palette?.border ?? const Color(0xFF3A3F4A))
                              : Colors.amber.shade200,
                        ),
                      ),
                      child: const Text(
                        'Configure (or rely on an existing schedule) before adding sessions. You can later append new periods or breaks without recreating everything.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Sessions
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Sessions',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? palette?.textPrimary : null,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _configured ? _addSession : null,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Session'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  if (_configured)
                    Column(
                      children: List.generate(_sessions.length, (i) {
                        final s = _sessions[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: _wrapFields([
                            _dropdownBox<int>(
                              hint: 'Day',
                              value: s.dayIndex,
                              items: List<int>.generate(
                                widget.days.length,
                                (d) => d,
                              ),
                              onChanged: (v) => setState(() => s.dayIndex = v),
                              builder: (d) => Text(widget.days[d]),
                            ),
                            _dropdownBox<int>(
                              hint: 'Start period',
                              value: s.periodDropdownIndex,
                              items: List<int>.generate(
                                teachingLabels.length,
                                (p) => p,
                              ),
                              onChanged: (v) =>
                                  setState(() => s.periodDropdownIndex = v),
                              builder: (p) => Text(teachingLabels[p]),
                            ),
                            Row(
                              children: [
                                if (i > 0)
                                  IconButton(
                                    tooltip: 'Remove',
                                    onPressed: () => _removeSession(i),
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.redAccent,
                                    ),
                                  )
                                else
                                  const SizedBox(width: 48),
                              ],
                            ),
                          ]),
                        );
                      }),
                    ),

                  const SizedBox(height: 16),

                  // Footer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: isDark
                            ? TextButton.styleFrom(
                                foregroundColor: palette?.textSecondary,
                              )
                            : null,
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
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
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _teachingTotalHours() {
    int sum = 0;
    for (final idx in _teachingIndices) {
      final sp = _spans[idx];
      sum += sp.$2 - sp.$1;
    }
    final h = sum ~/ 60;
    final m = sum % 60;
    return '${h}h ${m}m';
  }

  int _totalBreakMinutes() {
    int total = 0;
    for (int i = 0; i < _labels.length; i++) {
      if (_labels[i].toLowerCase().contains('break')) {
        final sp = _spans[i];
        total += sp.$2 - sp.$1;
      }
    }
    return total;
  }
}

/// Session row model
class _SessionRow {
  int? dayIndex;
  int? periodDropdownIndex;
}

/// Result from full generator
class _GeneratedScheduleResult {
  final List<String> labels;
  final List<(int, int)> spans;
  final List<int> teachingIndices;
  _GeneratedScheduleResult({
    required this.labels,
    required this.spans,
    required this.teachingIndices,
  });
}

/// Period generator dialog
class _PeriodGeneratorDialog extends StatefulWidget {
  final List<String> existingLabels;
  final List<(int, int)> existingSpans;
  final List<int> existingTeachingIndices;

  const _PeriodGeneratorDialog({
    required this.existingLabels,
    required this.existingSpans,
    required this.existingTeachingIndices,
  });

  @override
  State<_PeriodGeneratorDialog> createState() => _PeriodGeneratorDialogState();
}

class _PeriodGeneratorDialogState extends State<_PeriodGeneratorDialog> {
  static const List<int> _presetDurations = [30, 45, 50, 60, 75, 90, 110, 120];

  int _dayStart = 8 * 60;
  int _periodMinutes = 110;
  int _periodCount = 4;
  bool _useCustom = false;
  int _customDuration = 110;
  final List<_BreakConfig> _breaks = [];

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  void _hydrate() {
    if (widget.existingLabels.isNotEmpty &&
        widget.existingSpans.length == widget.existingLabels.length &&
        widget.existingTeachingIndices.isNotEmpty) {
      final firstTeach = widget.existingTeachingIndices.first;
      final span = widget.existingSpans[firstTeach];
      _dayStart = span.$1;
      final len = span.$2 - span.$1;
      _periodMinutes = len;
      if (!_presetDurations.contains(len)) {
        _useCustom = true;
        _customDuration = len;
      }
      _periodCount = widget.existingTeachingIndices.length;

      _breaks.clear();
      int teachingSeen = 0;
      for (int i = 0; i < widget.existingLabels.length; i++) {
        final isBreak = widget.existingLabels[i].toLowerCase().contains(
          'break',
        );
        if (isBreak) {
          final sp = widget.existingSpans[i];
          final mins = sp.$2 - sp.$1;
          _breaks.add(_BreakConfig(after: teachingSeen, minutes: mins));
        } else {
          teachingSeen++;
        }
      }
      if (_breaks.isEmpty) _breaks.add(_BreakConfig());
    } else {
      _breaks.add(_BreakConfig());
    }
  }

  List<int> get _afterPeriodOptions => (_periodCount <= 1)
      ? const []
      : List<int>.generate(_periodCount - 1, (i) => i + 1);

  TimeOfDay _toTimeOfDay(int minutes) {
    final h = (minutes ~/ 60) % 24;
    final m = minutes % 60;
    return TimeOfDay(hour: h, minute: m);
  }

  String _fmt(int minutes) =>
      '${minutes ~/ 60}:${(minutes % 60).toString().padLeft(2, '0')}';

  void _generate() {
    if (_periodMinutes <= 0) {
      _toast('Period duration must be > 0');
      return;
    }
    if (_periodCount < 1) {
      _toast('Number of periods must be >=1');
      return;
    }
    final used = <int>{};
    for (final b in _breaks) {
      if (b.after == null) continue;
      final a = b.after!;
      if (a < 1 || a >= _periodCount) {
        _toast('Break after period must be in 1..${_periodCount - 1}');
        return;
      }
      if (used.contains(a)) {
        _toast('Duplicate break after period #$a');
        return;
      }
      if (b.minutes != null && b.minutes! <= 0) {
        _toast('Break minutes must be > 0');
        return;
      }
      used.add(a);
    }

    int t = _dayStart;
    final labels = <String>[];
    final spans = <(int, int)>[];
    final teachingIdx = <int>[];

    for (int i = 1; i <= _periodCount; i++) {
      final ps = t;
      final pe = t + _periodMinutes;
      labels.add('${_fmt(ps)} - ${_fmt(pe)}');
      spans.add((ps, pe));
      teachingIdx.add(labels.length - 1);
      t = pe;

      final b = _breaks.firstWhere(
        (x) => x.after == i,
        orElse: () => _BreakConfig(),
      );
      if (b.after == i && b.minutes != null && b.minutes! > 0) {
        final bs = t;
        final be = t + (b.minutes ?? 0);
        labels.add('${_fmt(bs)} - ${_fmt(be)} (Break)');
        spans.add((bs, be));
        t = be;
      }
    }

    Navigator.pop(
      context,
      _GeneratedScheduleResult(
        labels: labels,
        spans: spans,
        teachingIndices: teachingIdx,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<SuperAdminColors>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      backgroundColor: isDark
          ? (palette?.surfaceHigh ?? const Color(0xFF1F2430))
          : null,
      title: Text(
        'Configure Periods',
        style: isDark ? TextStyle(color: palette?.textPrimary) : null,
      ),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            children: [
              InkWell(
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _toTimeOfDay(_dayStart),
                  );
                  if (picked != null) {
                    setState(
                      () => _dayStart = picked.hour * 60 + picked.minute,
                    );
                  }
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Day start',
                    labelStyle: isDark
                        ? TextStyle(color: palette?.textSecondary)
                        : null,
                    border: const OutlineInputBorder(),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? (Theme.of(
                                    context,
                                  ).extension<SuperAdminColors>()?.border ??
                                  const Color(0xFF3A3F4A))
                            : const Color(0xFFE5E7EB),
                      ),
                    ),
                    focusedBorder:
                        Theme.of(context).brightness == Brightness.dark
                        ? OutlineInputBorder(
                            borderSide: BorderSide(
                              color:
                                  Theme.of(
                                    context,
                                  ).extension<SuperAdminColors>()?.accent ??
                                  const Color(0xFF7C3AED),
                            ),
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _fmt(_dayStart),
                        style: isDark
                            ? TextStyle(color: palette?.textPrimary)
                            : null,
                      ),
                      Icon(
                        Icons.access_time,
                        size: 18,
                        color: isDark ? palette?.iconColor : null,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Period duration',
                        labelStyle: isDark
                            ? TextStyle(color: palette?.textSecondary)
                            : null,
                        border: const OutlineInputBorder(),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                ? (Theme.of(
                                        context,
                                      ).extension<SuperAdminColors>()?.border ??
                                      const Color(0xFF3A3F4A))
                                : const Color(0xFFE5E7EB),
                          ),
                        ),
                        focusedBorder:
                            Theme.of(context).brightness == Brightness.dark
                            ? OutlineInputBorder(
                                borderSide: BorderSide(
                                  color:
                                      Theme.of(
                                        context,
                                      ).extension<SuperAdminColors>()?.accent ??
                                      const Color(0xFF7C3AED),
                                ),
                              )
                            : null,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          isExpanded: true,
                          dropdownColor: isDark
                              ? (palette?.surface ?? const Color(0xFF262C3A))
                              : null,
                          value: _useCustom
                              ? null
                              : (_presetDurations.contains(_periodMinutes)
                                    ? _periodMinutes
                                    : null),
                          hint: Text(
                            _useCustom
                                ? 'Custom (${_periodMinutes}m)'
                                : '${_periodMinutes}m',
                            style: isDark
                                ? TextStyle(color: palette?.textSecondary)
                                : null,
                          ),
                          items:
                              _presetDurations
                                  .map(
                                    (m) => DropdownMenuItem<int>(
                                      value: m,
                                      child: Text(
                                        '$m min',
                                        style: isDark
                                            ? TextStyle(
                                                color: palette?.textPrimary,
                                              )
                                            : null,
                                      ),
                                    ),
                                  )
                                  .toList()
                                ..add(
                                  const DropdownMenuItem<int>(
                                    value: -1,
                                    child: Text('Custom…'),
                                  ),
                                ),
                          onChanged: (v) {
                            if (v == null) return;
                            if (v == -1) {
                              setState(() => _useCustom = true);
                            } else {
                              setState(() {
                                _useCustom = false;
                                _periodMinutes = v;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (_useCustom)
                    Expanded(
                      child: TextFormField(
                        initialValue: _customDuration.toString(),
                        decoration: InputDecoration(
                          labelText: 'Custom minutes',
                          labelStyle: isDark
                              ? TextStyle(color: palette?.textSecondary)
                              : null,
                          border: const OutlineInputBorder(),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        style: isDark
                            ? TextStyle(color: palette?.textPrimary)
                            : null,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (v) {
                          final n = int.tryParse(v.trim());
                          if (n != null && n > 0) {
                            setState(() {
                              _customDuration = n;
                              _periodMinutes = n;
                            });
                          }
                        },
                      ),
                    ),
                  if (_useCustom) const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      initialValue: _periodCount.toString(),
                      decoration: InputDecoration(
                        labelText: 'Number of periods',
                        labelStyle: isDark
                            ? TextStyle(color: palette?.textSecondary)
                            : null,
                        border: const OutlineInputBorder(),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      style: isDark
                          ? TextStyle(color: palette?.textPrimary)
                          : null,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (v) {
                        final n = int.tryParse(v.trim());
                        if (n != null && n >= 1 && n <= 40) {
                          setState(() => _periodCount = n);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Breaks (optional)',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? palette?.textPrimary : null,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Column(
                children: List.generate(_breaks.length, (i) {
                  final b = _breaks[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'After period #',
                              labelStyle: isDark
                                  ? TextStyle(color: palette?.textSecondary)
                                  : null,
                              border: const OutlineInputBorder(),
                              enabledBorder: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? (Theme.of(context)
                                                .extension<SuperAdminColors>()
                                                ?.border ??
                                            const Color(0xFF3A3F4A))
                                      : const Color(0xFFE5E7EB),
                                ),
                              ),
                              focusedBorder:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? OutlineInputBorder(
                                      borderSide: BorderSide(
                                        color:
                                            Theme.of(context)
                                                .extension<SuperAdminColors>()
                                                ?.accent ??
                                            const Color(0xFF7C3AED),
                                      ),
                                    )
                                  : null,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                isExpanded: true,
                                value: b.after,
                                dropdownColor: isDark
                                    ? (palette?.surface ??
                                          const Color(0xFF262C3A))
                                    : null,
                                hint: Text(
                                  'Choose',
                                  style: isDark
                                      ? TextStyle(color: palette?.textSecondary)
                                      : null,
                                ),
                                items: _afterPeriodOptions
                                    .map(
                                      (n) => DropdownMenuItem<int>(
                                        value: n,
                                        child: Text(
                                          '$n',
                                          style: isDark
                                              ? TextStyle(
                                                  color: palette?.textPrimary,
                                                )
                                              : null,
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (v) => setState(() => b.after = v),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            initialValue: b.minutes?.toString() ?? '',
                            decoration: InputDecoration(
                              labelText: 'Break minutes',
                              labelStyle: isDark
                                  ? TextStyle(color: palette?.textSecondary)
                                  : null,
                              border: const OutlineInputBorder(),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                            ),
                            style: isDark
                                ? TextStyle(color: palette?.textPrimary)
                                : null,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (v) {
                              final n = int.tryParse(v.trim());
                              setState(
                                () =>
                                    b.minutes = (n != null && n > 0) ? n : null,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (i > 0)
                          IconButton(
                            onPressed: () {
                              if (_breaks.length > 1) {
                                setState(() => _breaks.removeAt(i));
                              }
                            },
                            icon: const Icon(
                              Icons.close,
                              color: Colors.redAccent,
                            ),
                          )
                        else
                          const SizedBox(width: 40),
                      ],
                    ),
                  );
                }),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _breaks.add(_BreakConfig())),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Break'),
                ),
              ),
              const SizedBox(height: 12),
              _rulesBox(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: Theme.of(context).brightness == Brightness.dark
              ? TextButton.styleFrom(
                  foregroundColor: Theme.of(
                    context,
                  ).extension<SuperAdminColors>()?.textSecondary,
                )
              : null,
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _generate,
          style: Theme.of(context).brightness == Brightness.dark
              ? ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(
                    context,
                  ).extension<SuperAdminColors>()?.accent,
                  foregroundColor: Theme.of(
                    context,
                  ).extension<SuperAdminColors>()?.textPrimary,
                )
              : null,
          child: const Text('Generate'),
        ),
      ],
    );
  }

  void _toast(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Widget _rulesBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? (Theme.of(context).extension<SuperAdminColors>()?.overlay ??
                  const Color(0xFF2A2F3A))
            : Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark
              ? (Theme.of(context).extension<SuperAdminColors>()?.border ??
                    const Color(0xFF3A3F4A))
              : Colors.blueGrey.shade100,
        ),
      ),
      child: const Text(
        'Rules:\n'
        '• Each teaching period = fixed duration.\n'
        '• Breaks can be any positive length after a period.\n'
        '• No duplicate breaks after the same period.\n'
        '• Final end time = start + (#periods × duration) + breaks.\n'
        '• Adding a period/break will be rejected if it overlaps an existing span.',
        style: TextStyle(fontSize: 12),
      ),
    );
  }
}

// ---------------- Break + AddPeriod helpers (top-level classes) ----------------

class _BreakConfig {
  int? after;
  int? minutes;
  _BreakConfig({this.after, this.minutes});
}

class _AddPeriodDialog extends StatefulWidget {
  final List<(int, int)> existingSpans;
  final List<String> existingLabels;
  final int? periodMinutes;

  const _AddPeriodDialog({
    required this.existingSpans,
    required this.existingLabels,
    required this.periodMinutes,
  });

  @override
  State<_AddPeriodDialog> createState() => _AddPeriodDialogState();
}

class _AddPeriodDialogState extends State<_AddPeriodDialog> {
  bool isBreak = false;
  int? customBreakMinutes;
  TimeOfDay? startPicker;
  String? error;

  String fmt(int m) => '${m ~/ 60}:${(m % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final periodLen = widget.periodMinutes;
    return AlertDialog(
      title: const Text('Add Period / Break'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Switch(
                  value: isBreak,
                  onChanged: (v) => setState(() {
                    isBreak = v;
                    error = null;
                  }),
                ),
                Text(isBreak ? 'Adding Break' : 'Adding Teaching Period'),
              ],
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final initial = startPicker ?? inferNextStart();
                final picked = await showTimePicker(
                  context: context,
                  initialTime: initial,
                );
                if (picked != null) {
                  setState(() {
                    startPicker = picked;
                    error = null;
                  });
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Start time',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      startPicker == null
                          ? 'Tap to select'
                          : '${startPicker!.hour}:${startPicker!.minute.toString().padLeft(2, '0')}',
                    ),
                    const Icon(Icons.access_time, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (isBreak)
              TextFormField(
                initialValue: customBreakMinutes?.toString() ?? '',
                decoration: const InputDecoration(
                  labelText: 'Break minutes',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (v) {
                  final n = int.tryParse(v.trim());
                  setState(() {
                    customBreakMinutes = (n != null && n > 0) ? n : null;
                    error = null;
                  });
                },
              )
            else
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Length (minutes)',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                child: Text(
                  periodLen != null
                      ? '$periodLen (fixed)'
                      : 'Inconsistent existing periods; please reconfigure',
                ),
              ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            ],
            const SizedBox(height: 8),
            hintBox(periodLen),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: submit, child: const Text('Add')),
      ],
    );
  }

  _AddPeriodResult? buildResult() {
    if (startPicker == null) {
      error = 'Select a start time';
      return null;
    }
    final start = startPicker!.hour * 60 + startPicker!.minute;
    int? length;
    if (isBreak) {
      if (customBreakMinutes == null || customBreakMinutes! <= 0) {
        error = 'Enter break minutes';
        return null;
      }
      length = customBreakMinutes!;
    } else {
      if (widget.periodMinutes == null) {
        error = 'Period length inconsistent. Reconfigure.';
        return null;
      }
      length = widget.periodMinutes!;
    }
    final end = start + length;
    for (final sp in widget.existingSpans) {
      final s = sp.$1;
      final e = sp.$2;
      final overlap = !(end <= s || start >= e);
      if (overlap) {
        error = 'Overlaps existing ${fmt(s)}-${fmt(e)}';
        return null;
      }
    }
    return _AddPeriodResult(start: start, end: end, isBreak: isBreak);
  }

  void submit() {
    setState(() => error = null);
    final res = buildResult();
    if (res == null) {
      setState(() {});
      return;
    }
    Navigator.pop(context, res);
  }

  TimeOfDay inferNextStart() {
    if (widget.existingSpans.isEmpty) {
      final now = TimeOfDay.now();
      return TimeOfDay(hour: now.hour, minute: 0);
    }
    final lastEnd = widget.existingSpans
        .map((e) => e.$2)
        .reduce((a, b) => a > b ? a : b);
    return TimeOfDay(hour: lastEnd ~/ 60, minute: lastEnd % 60);
  }

  Widget hintBox(int? periodLen) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: Colors.blueGrey.shade50,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.blueGrey.shade100),
    ),
    child: Text(
      periodLen != null
          ? 'New teaching period will be exactly $periodLen minutes; choose a start time that does not overlap.'
          : 'Period length unknown (inconsistent). Please reconfigure.',
      style: const TextStyle(fontSize: 12),
    ),
  );
}

// Define the missing _AddPeriodResult class
class _AddPeriodResult {
  final int start;
  final int end;
  final bool isBreak;

  _AddPeriodResult({
    required this.start,
    required this.end,
    required this.isBreak,
  });
}
