// TimetablePage — adapted to use UseTimetable (Supabase) instead of Firebase/Firestore.
//
// This file is a near drop-in replacement for your previous timetable_page.dart but
// wired to UseTimetable service defined in use_timetable.dart. It keeps the same UI
// structure and behavior (CreateTimetableDialog, edit dialog, PDF export, etc.)
//
// Make sure to import and register supabase in your app (Supabase.initialize).
//
// Save as lib/components/pages/timetable_page.dart

import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import 'create_timetable_dialog.dart';
import 'create_timetable_cell_edit_dialog.dart';
import '../../hooks/use_timetable.dart';

/// Simple value object representing a single scheduled slot in the
/// timetable. Contains human-friendly display values used by the UI and
/// PDF export (day name, period label, course, class, department and
/// lecturer name).
class TimetableSlot {
  final String day;
  final String periodLabel;
  final String course;
  final String className;
  final String department;
  final String lecturer;

  TimetableSlot({
    required this.day,
    required this.periodLabel,
    required this.course,
    required this.className,
    required this.department,
    required this.lecturer,
  });
}

/// Top-level page widget that displays and edits class timetables.
///
/// This widget wires to `UseTimetable` (a Supabase-backed service)
/// to load/save timetables, teachers, classes and courses. It exposes
/// UI for creating timetables, editing cells, exporting PDFs and
/// filtering by lecturer or search text.
class TimetablePage extends StatefulWidget {
  const TimetablePage({super.key});

  @override
  State<TimetablePage> createState() => _TimetablePageState();
}

/// State for `TimetablePage` that holds UI state, caches and all
/// timetable manipulation logic. The class is intentionally large to
/// keep the UI code in one place; helper methods are grouped by
/// responsibility (loaders, persistence, resolvers, UI wiring).
class _TimetablePageState extends State<TimetablePage> {
  String searchText = '';

  // Dropdown raw values (ids)
  String? selectedDepartment;
  String? selectedClass;
  String? selectedLecturer;

  bool editingEnabled = false;
  final UseTimetable svc = UseTimetable.instance;

  // Undo state currently unused; keep type available for future but remove field to silence analyzer

  final List<String> seedPeriods = const [
    "7:30 - 9:20",
    "9:20 - 11:10",
    "11:10 - 11:40 (Break)",
    "11:40 - 1:30",
  ];

  // in-memory caches (kept mostly as before)
  final Map<String, Map<String, List<List<String>>>> timetableData = {};
  final Map<String, Map<String, List<String>>> classPeriods = {};
  final Map<String, Map<String, List<Map<String, int>>>> spans = {};

  // dropdown/data caches
  List<Map<String, dynamic>> _departments = []; // {id, name}
  List<Map<String, dynamic>> _classes = []; // {id, name, raw}
  List<Map<String, dynamic>> _teachers = []; // {id, name}
  List<Map<String, dynamic>> _coursesForSelectedClass =
      []; // {id, course_name, raw}

  // flattened schedule rows for a selected teacher (day, time, course, className, department)
  List<Map<String, dynamic>> _teacherSchedule = [];

  // loading state for fetching a teacher's flattened schedule
  bool _loadingTeacherSchedule = false;

  // track pending teacher fetches to avoid duplicate background requests
  final Set<String> _pendingTeacherFetches = <String>{};
  // track pending course fetches to avoid duplicate background requests
  final Set<String> _pendingCourseFetches = <String>{};

  bool _loadingDeps = false;
  bool _loadingClasses = false;
  bool _loadingTeachers = false;
  bool _loadingTimetable = false;
  // when true, suppress showing any existing timetable while switching classes
  bool _suppressOldGrid = false;
  // ignore: unused_field
  bool _loadingCourses = false;

  List<String> get days => ["Sat", "Sun", "Mon", "Tue", "Wed", "Thu"];

  @override
  void initState() {
    super.initState();
    _loadDepartments();
    _loadTeachers();
  }

  /// Initialize state: load departments and teachers at startup so the
  /// dropdowns are populated as soon as the page appears.

  // -------------------- Loaders (via UseTimetable svc) --------------------

  Future<void> _loadDepartments() async {
    /// Load department list into the local `_departments` cache.
    ///
    /// Uses `UseTimetable` service as the primary source and falls back to a
    /// direct Supabase query when the service returns an empty result. Also
    /// attempts to select a sensible default department/class and triggers
    /// a selection-change flow so the UI loads an initial timetable.
    setState(() => _loadingDeps = true);
    try {
      await svc.loadDepartments();
      _departments = svc.departments;
      // Fallback: if service returned nothing (faculty scoping), try a direct
      // supabase query to load departments so the UI dropdown isn't permanently
      // disabled. This is a safe best-effort fallback for development/testing
      // when the current user/faculty cannot be resolved. It preserves the
      // primary secure path in UseTimetable but makes the page usable.
      if ((_departments.isEmpty)) {
        try {
          final dynamic raw = await svc.supabase
              .from('departments')
              .select()
              .order('created_at', ascending: false);
          dynamic data;
          if (raw is Map && raw.containsKey('data')) {
            data = raw['data'];
          } else {
            data = raw;
          }
          if (data is List && data.isNotEmpty) {
            _departments = data.map<Map<String, dynamic>>((r) {
              final name =
                  (r['department_name'] ??
                          r['department_code'] ??
                          r['name'] ??
                          r['id'])
                      ?.toString() ??
                  '';
              return {
                'id': r['id']?.toString() ?? name,
                'name': name,
                'raw': r,
              };
            }).toList();
          }
        } catch (e) {
          debugPrint('Fallback departments query failed: $e');
        }
      }
      // Intentionally do NOT auto-select the first department/class here.
      // Keep `selectedDepartment` null so the dropdown shows the "Select Department"
      // hint until the user explicitly chooses a department. This avoids
      // accidentally showing timetables from other departments when the user
      // has not made a selection.
      //
      // If you want an opt-in behavior (for dev), add a flag that allows
      // auto-selection (e.g. `allowAutoSelect`) and check it here.
    } catch (e, st) {
      debugPrint('loadDepartments error: $e\n$st');
    } finally {
      if (mounted) setState(() => _loadingDeps = false);
    }
  }

  Future<void> _loadTeachers() async {
    /// Load teacher/lecturer list into `_teachers` cache.
    ///
    /// Prefers `UseTimetable.loadTeachers()` but includes a fallback
    /// Supabase query when the service returns no results.
    setState(() => _loadingTeachers = true);
    try {
      await svc.loadTeachers();
      _teachers = svc.teachers;
      // fallback: try direct query if svc returned empty
      if ((_teachers.isEmpty)) {
        try {
          final dynamic raw = await svc.supabase.from('teachers').select();
          dynamic data;
          if (raw is Map && raw.containsKey('data')) {
            data = raw['data'];
          } else {
            data = raw;
          }
          if (data is List && data.isNotEmpty) {
            _teachers = data.map<Map<String, dynamic>>((r) {
              final name =
                  (r['teacher_name'] ??
                          r['name'] ??
                          r['full_name'] ??
                          r['username'] ??
                          r['id'])
                      ?.toString() ??
                  '';
              return {
                'id': r['id']?.toString() ?? name,
                'name': name,
                'raw': r,
              };
            }).toList();
          }
        } catch (e) {
          debugPrint('Fallback teachers query failed: $e');
        }
      }
    } catch (e) {
      debugPrint('loadTeachers error: $e');
    } finally {
      setState(() => _loadingTeachers = false);
    }
  }

  Future<void> _loadClassesForDepartment(dynamic depIdOrRef) async {
    /// Load classes for a given department into `_classes`.
    ///
    /// `depIdOrRef` may be an id or a display name; the service is called
    /// first and a direct Supabase fallback is attempted when necessary.
    setState(() => _loadingClasses = true);
    try {
      await svc.loadClassesForDepartment(depIdOrRef);
      _classes = svc.classes;
      // Fallback: if no classes (faculty scoping), try a direct query for this
      // department id/name. This makes the dropdown responsive even when
      // UseTimetable couldn't resolve faculty scoping.
      // if ((_classes.isEmpty) && depIdOrRef != null) {
      //   try {
      //     final q = svc.supabase.from('classes').select();
      //     dynamic raw;
      //     if (depIdOrRef is String) {
      //       // try common fields
      //       raw = await q
      //           .or('department.eq.$depIdOrRef,department_id.eq.$depIdOrRef')
      //           .order('created_at', ascending: false);
      //     } else {
      //       raw = await q.order('created_at', ascending: false);
      //     }
      //     dynamic data;
      //     if (raw is Map && raw.containsKey('data')) {
      //       data = raw['data'];
      //     } else {
      //       data = raw;
      //     }
      //     if (data is List && data.isNotEmpty) {
      //       _classes = data.map<Map<String, dynamic>>((r) {
      //         final name =
      //             (r['class_name'] ?? r['name'] ?? r['title'] ?? r['id'])
      //                 ?.toString() ??
      //             '';
      //         return {
      //           'id': r['id']?.toString() ?? name,
      //           'name': name,
      //           'raw': r,
      //         };
      //       }).toList();
      //     }
      //   } catch (e) {
      //     debugPrint('Fallback classes query failed: $e');
      //   }
      // }
    } catch (e) {
      debugPrint('loadClassesForDepartment error: $e');
      _classes = [];
    } finally {
      setState(() => _loadingClasses = false);
    }
  }

  Future<void> _loadCoursesForClass(dynamic classIdOrName) async {
    /// Load courses associated with a class into `_coursesForSelectedClass`.
    ///
    /// Accepts either a class id or class display name. Uses the service
    /// and falls back to a direct Supabase query when needed.
    setState(() => _loadingCourses = true);
    try {
      await svc.loadCoursesForClass(classIdOrName);
      _coursesForSelectedClass = svc.courses;
      // fallback: try direct query if service returned empty
      if ((_coursesForSelectedClass.isEmpty) && classIdOrName != null) {
        try {
          final dynamic raw = await svc.supabase
              .from('courses')
              .select()
              .or('class.eq.$classIdOrName,class_id.eq.$classIdOrName')
              .order('created_at', ascending: false);
          dynamic data;
          if (raw is Map && raw.containsKey('data')) {
            data = raw['data'];
          } else {
            data = raw;
          }
          if (data is List && data.isNotEmpty) {
            _coursesForSelectedClass = data.map<Map<String, dynamic>>((r) {
              final name =
                  (r['course_name'] ??
                          r['title'] ??
                          r['course_code'] ??
                          r['id'])
                      ?.toString() ??
                  '';
              return {
                'id': r['id']?.toString() ?? name,
                'name': name,
                'raw': r,
              };
            }).toList();
          }
        } catch (e) {
          debugPrint('Fallback courses query failed: $e');
        }
      }
    } catch (e) {
      debugPrint('loadCoursesForClass error: $e');
      _coursesForSelectedClass = [];
    } finally {
      setState(() => _loadingCourses = false);
    }
  }

  // -------------------- Timetable read/write (via svc) --------------------

  String _sanitizeForId(String input) {
    /// Create a sanitized key from a human string suitable for use as a
    /// map/document id. Lowercases, trims, replaces whitespace with
    /// underscores and drops non-word characters. Used to create friendly
    /// alias keys for timetable documents.
    var s = input.trim().toLowerCase();
    s = s.replaceAll(RegExp(r'\s+'), '_');
    s = s.replaceAll(RegExp(r'[^\w\-]'), '');
    return s;
  }

  String _docIdFromDisplayNames(String deptDisplay, String classDisplay) {
    /// Compute a sanitized document id from department and class display
    /// names. This helps locate timetable documents stored under a
    /// concatenated key like `<dept>_<class>`.
    final d = _sanitizeForId(deptDisplay);
    final c = _sanitizeForId(classDisplay);
    return '${d}_$c';
  }

  Future<String> _resolveDepartmentDisplayName(String depIdOrName) async {
    /// Resolve a department id or name into a display name.
    ///
    /// First attempts a lookup in the in-memory `_departments` cache and
    /// falls back to the `UseTimetable` service when not found.
    final s = depIdOrName.trim();
    try {
      Map<String, dynamic>? found;
      for (final d in _departments) {
        final idStr = (d['id']?.toString() ?? '');
        if (idStr == s) {
          found = d;
          break;
        }
      }
      if (found != null && found.isNotEmpty) {
        final n = (found['name']?.toString() ?? '').trim();
        if (n.isNotEmpty) return n;
      }
    } catch (_) {}
    return await svc.resolveDepartmentDisplayName(s);
  }

  Future<String> _resolveClassDisplayName(String classIdOrName) async {
    /// Resolve a class id or name into the human display name.
    ///
    /// Uses the `_classes` cache first then delegates to the service.
    final s = classIdOrName.trim();
    try {
      Map<String, dynamic>? found;
      for (final c in _classes) {
        final idStr = (c['id']?.toString() ?? '');
        if (idStr == s) {
          found = c;
          break;
        }
      }
      if (found != null && found.isNotEmpty) {
        final n = (found['name']?.toString() ?? '').trim();
        if (n.isNotEmpty) return n;
      }
    } catch (_) {}
    return await svc.resolveClassDisplayName(s);
  }

  Future<void> _loadTimetableDoc() async {
    /// Load the timetable document for the currently-selected
    /// `selectedDepartment` and `selectedClass`.
    ///
    /// Uses several lookup strategies: department+class lookup, sanitized
    /// doc id lookup (UUID-aware), and class-only fallbacks. When a
    /// document is found it delegates parsing to
    /// `_applyTimetableDataFromSnapshot`.
    if (selectedDepartment == null || selectedClass == null) return;
    final depId = selectedDepartment!.trim();
    final clsId = selectedClass!.trim();
    if (depId.isEmpty || clsId.isEmpty) return;

    // Enter timetable-loading state to avoid rendering intermediate UUIDs.
    if (mounted) {
      setState(() {
        _loadingTimetable = true;
        _suppressOldGrid = true;
      });
    }

    final deptDisplay = await _resolveDepartmentDisplayName(depId);
    final classDisplay = await _resolveClassDisplayName(clsId);
    final docIdSan = _docIdFromDisplayNames(deptDisplay, classDisplay);

    debugPrint(
      'Loading timetable for dept="$deptDisplay" class="$classDisplay"',
    );

    try {
      // Prefer lookup by department & class first — this works for most
      // schemas and for sanitized doc ids that are not UUIDs. Only attempt
      // an `id`-based lookup when the computed doc id actually looks like
      // a UUID (the service rejects non-UUID id lookups).
      Map<String, dynamic>? doc = await svc.findTimetableByDeptClass(
        deptDisplay,
        classDisplay,
        classKey: clsId,
        departmentId: depId,
      );

      // If not found yet, and the sanitized doc id happens to be a UUID,
      // try loading by doc id. `UseTimetable.loadTimetableByDocId` returns
      // null for non-UUID ids so avoid calling it unnecessarily.
      final uuidRe = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      );
      if (doc == null && uuidRe.hasMatch(docIdSan)) {
        doc = await svc.loadTimetableByDocId(docIdSan);
      }

      if (doc != null) {
        await _applyTimetableDataFromSnapshot(doc, deptDisplay, classDisplay);
        if (mounted) {
          setState(() {
            _loadingTimetable = false;
            _suppressOldGrid = false;
          });
        }
      } else {
        // Primary lookup returned null — log diagnostic info before fallback
        debugPrint(
          '[TimetablePage] primary lookup returned null for docId="$docIdSan"',
        );
        debugPrint('timetableData keys: ${timetableData.keys.toList()}');
        try {
          final svcKeys = svc.debugTimetableDocKeys();
          debugPrint(
            '[TimetablePage] service cached timetable doc keys: $svcKeys',
          );
        } catch (_) {}
        // Fallback: try finding any timetable rows for this class (by id or display)
        // hi
        try {
          debugPrint(
            '[TimetablePage] primary lookup failed, trying class-only fallback for classId=$clsId classDisplay=$classDisplay',
          );
          final byClass = await svc.findTimetablesByClass(clsId);
          if ((byClass).isEmpty) {
            final byClassName = await svc.findTimetablesByClass(classDisplay);
            if (byClassName.isNotEmpty) {
              await _applyTimetableDataFromSnapshot(
                byClassName.first,
                deptDisplay,
                classDisplay,
              );
            } else {
              // No timetable found for this class — clear any stale display
              if (mounted) {
                _clearTimetableForSelection(
                  depDisplay: deptDisplay,
                  classDisplay: classDisplay,
                );
                setState(() {
                  _loadingTimetable = false;
                  _suppressOldGrid = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No timetable found in this class'),
                  ),
                );
              }
            }
          } else {
            await _applyTimetableDataFromSnapshot(
              byClass.first,
              deptDisplay,
              classDisplay,
            );
          }
        } catch (e, st) {
          debugPrint('Fallback class-only lookup failed: $e\n$st');
          if (mounted) {
            _clearTimetableForSelection(
              depDisplay: deptDisplay,
              classDisplay: classDisplay,
            );
            setState(() {
              _loadingTimetable = false;
              _suppressOldGrid = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No timetable found in this class')),
            );
          }
        }
      }
    } catch (e, st) {
      debugPrint('Error loading timetable doc: $e\n$st');
      if (mounted) {
        _clearTimetableForSelection(
          depDisplay: deptDisplay,
          classDisplay: classDisplay,
        );
        setState(() {
          _loadingTimetable = false;
          _suppressOldGrid = false;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading timetable: $e')));
      }
    }

    // Load courses for selected class to help edit dialog
    try {
      if (_classes.isNotEmpty) {
        final classMap = _classes.firstWhere(
          (c) => (c['id']?.toString() ?? '') == clsId,
          orElse: () => <String, dynamic>{},
        );
        if (classMap.isNotEmpty) {
          await _loadCoursesForClass(classMap['id']);
        } else {
          await _loadCoursesForClass(classDisplay);
        }
      } else {
        await _loadCoursesForClass(clsId);
      }
    } catch (_) {}
    // ensure loading flag cleared if function completes without earlier cleanup
    if (mounted) {
      setState(() {
        _loadingTimetable = false;
        // keep _suppressOldGrid as-is; it will be controlled by caller (e.g., teacher selection)
      });
    }
  }

  Future<void> _applyTimetableDataFromSnapshot(
    Map<String, dynamic> data,
    String depDisplayName,
    String classDisplayName,
  ) async {
    /// Parse a raw timetable document snapshot and populate the in-memory
    /// caches: `timetableData`, `classPeriods` and `spans`.
    ///
    /// The function normalizes several storage formats (list/grid/json
    /// strings or embedded `sessions`) and attempts to resolve UUIDs into
    /// human-friendly names by loading teachers/courses as needed.
    /// It produces multiple alias keys so the UI selection logic can
    /// find the timetable regardless of whether the selection uses ids or
    /// display names.
    try {
      debugPrint('[TimetablePage._apply] doc=${jsonEncode(data)}');
    } catch (_) {}
    // Parse periods
    List<String> periods;
    try {
      final rawPeriods = data['periods'];
      if (rawPeriods is List) {
        periods = rawPeriods.map((e) => e?.toString() ?? '').toList();
      } else if (rawPeriods is String) {
        periods = (jsonDecode(rawPeriods) as List)
            .map((e) => e.toString())
            .toList();
      } else
        periods = List<String>.from(seedPeriods);
    } catch (_) {
      periods = List<String>.from(seedPeriods);
    }

    // Parse spans
    List<Map<String, int>> spanList = [];
    try {
      final spansRaw = data['spans'];
      if (spansRaw is List) {
        spanList = spansRaw.map<Map<String, int>>((e) {
          try {
            final s = (e?['start'] as num?)?.toInt() ?? 0;
            final en = (e?['end'] as num?)?.toInt() ?? 0;
            return {'start': s, 'end': en};
          } catch (_) {
            return {'start': 0, 'end': 0};
          }
        }).toList();
      } else if (spansRaw is String) {
        final parsed = jsonDecode(spansRaw) as List;
        spanList = parsed
            .map<Map<String, int>>(
              (e) => {
                'start': (e['start'] as num).toInt(),
                'end': (e['end'] as num).toInt(),
              },
            )
            .toList();
      }
    } catch (_) {
      spanList = <Map<String, int>>[];
    }

    // Parse grid
    List<List<String>> grid = List.generate(
      days.length,
      (_) => List<String>.filled(periods.length, '', growable: true),
    );
    try {
      final gridRaw = data['grid'];
      if (gridRaw is List &&
          gridRaw.isNotEmpty &&
          gridRaw.first is Map &&
          (gridRaw.first as Map).containsKey('cells')) {
        for (final rowObj in gridRaw) {
          if (rowObj is Map && rowObj['cells'] is List) {
            final rIndex = (rowObj['r'] is int) ? rowObj['r'] as int : null;
            final cells = (rowObj['cells'] as List)
                .map((c) => c?.toString() ?? '')
                .toList();
            if (rIndex != null && rIndex >= 0 && rIndex < grid.length) {
              grid[rIndex] = List<String>.from(cells);
              if (grid[rIndex].length < periods.length) {
                grid[rIndex].addAll(
                  List<String>.filled(periods.length - grid[rIndex].length, ''),
                );
              }
            }
          }
        }
      } else if (gridRaw is List && gridRaw.every((e) => e is List)) {
        grid = gridRaw
            .map<List<String>>(
              (r) => (r as List).map((c) => c?.toString() ?? '').toList(),
            )
            .toList();
      } else if (gridRaw is String) {
        try {
          final parsed = jsonDecode(gridRaw) as List;
          grid = parsed
              .map<List<String>>(
                (r) => (r as List).map((c) => c.toString()).toList(),
              )
              .toList();
        } catch (_) {}
      }
    } catch (e, st) {
      debugPrint('Grid parse error: $e\n$st');
    }

    // Scan existing parsed `grid` and resolve any UUIDs that may be stored
    // in cell texts (course or teacher). This ensures that even when the
    // DB stored a pre-built grid that contains IDs, the UI will show names.
    try {
      final uuidRe = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      );
      // Ensure caches are freshly loaded so UUID->name resolution can succeed.
      // We force a load and then sync local caches from the service to avoid
      // missing data due to earlier scoping or empty caches.
      try {
        await _loadTeachers();
      } catch (_) {}
      try {
        await _loadCoursesForClass(classDisplayName);
      } catch (_) {}
      // synchronize local caches from the service state
      try {
        _teachers = svc.teachers;
      } catch (_) {}
      try {
        _coursesForSelectedClass = svc.courses;
      } catch (_) {}

      for (int r = 0; r < grid.length; r++) {
        final row = grid[r];
        for (int c = 0; c < row.length; c++) {
          try {
            final raw = row[c];
            final txt = raw.toString().trim();
            if (txt.isEmpty) continue;
            if (txt.toLowerCase().contains('break')) continue;
            final parts = txt.split('\n');
            String coursePart = parts.isNotEmpty ? parts[0].trim() : '';
            String teacherPart = parts.length > 1
                ? parts.sublist(1).join(' ').trim()
                : '';
            if (coursePart.isNotEmpty && uuidRe.hasMatch(coursePart)) {
              try {
                coursePart = await _resolveCourseDisplay(
                  coursePart,
                  classDisplayName,
                );
              } catch (_) {}
            }
            if (teacherPart.isNotEmpty && uuidRe.hasMatch(teacherPart)) {
              try {
                teacherPart = await _resolveTeacherDisplay(teacherPart);
              } catch (_) {}
            }
            final newCell = teacherPart.isNotEmpty
                ? '$coursePart\n$teacherPart'
                : coursePart;
            grid[r][c] = newCell;
          } catch (_) {}
        }
      }
    } catch (_) {}

    // If the row uses `sessions` (jsonb) but doesn't provide a `grid`,
    // synthesize a simple grid from sessions so the UI can display entries.
    try {
      final hasSessions =
          data.containsKey('sessions') && data['sessions'] != null;
      final gridEmpty = grid.every((row) => row.every((c) => c.trim().isEmpty));
      if (hasSessions && gridEmpty) {
        dynamic sess = data['sessions'];
        List<dynamic> sessList = [];
        if (sess is Map && sess.containsKey('sessions')) {
          try {
            sessList = (sess['sessions'] as List).toList();
          } catch (_) {
            sessList = [];
          }
        } else if (sess is List) {
          sessList = sess;
        }

        if (sessList.isNotEmpty) {
          // Ensure caches are available so we can resolve UUIDs to names.
          try {
            if (_teachers.isEmpty) await _loadTeachers();
          } catch (_) {}
          try {
            // Ensure courses for this class are loaded so course uuids can be resolved
            if (_coursesForSelectedClass.isEmpty) {
              await _loadCoursesForClass(classDisplayName);
            }
          } catch (_) {}
          // Ensure grid has correct dimensions
          final int rowsCount = days.length;
          if (grid.length < rowsCount) {
            while (grid.length < rowsCount) {
              grid.add(List<String>.filled(periods.length, '', growable: true));
            }
          }

          for (final s in sessList) {
            try {
              final rawDay = (s['day'] is int)
                  ? s['day'] as int
                  : (int.tryParse(s['day']?.toString() ?? '') ?? 0);
              // normalize day index: accept either 0-based (0..5) or 1-based (1..6)
              int dayIndex;
              if (rawDay >= 0 && rawDay <= 5) {
                dayIndex = rawDay;
              } else if (rawDay >= 1 && rawDay <= 6) {
                dayIndex = rawDay - 1;
              } else {
                final m = rawDay % 7;
                dayIndex = (m >= 0 && m <= 5) ? m : 5;
              }
              if (dayIndex < 0 || dayIndex >= grid.length) continue;

              // Resolve text for course and teacher (use ids if names unavailable)
              String courseText = '';
              try {
                courseText = (s['course'] ?? s['course_name'] ?? '').toString();
              } catch (_) {}
              String teacherText = '';
              try {
                teacherText = (s['teacher'] ?? s['teacher_name'] ?? '')
                    .toString();
              } catch (_) {}

              // Resolve course/teacher to display names (cache then DB).
              try {
                courseText = await _resolveCourseDisplay(
                  courseText,
                  classDisplayName,
                );
              } catch (_) {}
              try {
                teacherText = await _resolveTeacherDisplay(teacherText);
              } catch (_) {}

              String cellText = courseText;
              if (teacherText.isNotEmpty) cellText = '$cellText\n$teacherText';

              // find column: prefer matching spans start -> column, else first empty
              int colIndex = -1;
              try {
                final sStart = (s['start'] is num)
                    ? (s['start'] as num).toInt()
                    : (int.tryParse(s['start']?.toString() ?? '') ?? -1);
                if (sStart >= 0 && spanList.isNotEmpty) {
                  // Prefer matching span range where start <= sStart < end
                  colIndex = spanList.indexWhere((p) {
                    final ps = (p['start'] ?? 0);
                    final pe = (p['end'] ?? 0);
                    return sStart >= ps && sStart < pe;
                  });
                }
              } catch (_) {}

              if (colIndex < 0) {
                // try to find first empty slot
                final firstEmpty = grid[dayIndex].indexWhere(
                  (c) => c.trim().isEmpty,
                );
                colIndex = firstEmpty >= 0 ? firstEmpty : 0;
              }

              // ensure column exists
              if (colIndex >= grid[dayIndex].length) {
                grid[dayIndex].addAll(
                  List<String>.filled(colIndex - grid[dayIndex].length + 1, ''),
                );
              }
              grid[dayIndex][colIndex] = cellText;
            } catch (_) {}
          }
        }
      }
    } catch (_) {}

    final depKeyDisplay = depDisplayName;
    final classKeyDisplay = classDisplayName;

    // Attempt to resolve any remaining UUIDs found in the parsed grid by
    // performing batch queries for missing teacher/course ids. This will
    // populate the in-memory caches so the synchronous resolver used during
    // rendering (_displayForCellSync) can replace UIDs with names.
    try {
      await _resolveMissingNamesFromGrid(grid, classDisplayName);
    } catch (_) {}

    // Final synchronous sweep: if any teacher UUIDs still remain in cells,
    // try to resolve them from the now-populated _teachers cache by
    // exact id match or by searching nested/raw fields. This catches cases
    // where the id was embedded in nested structures and wasn't replaced
    // earlier.
    try {
      final uuidRe = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      );
      for (int r = 0; r < grid.length; r++) {
        for (int c = 0; c < grid[r].length; c++) {
          try {
            final txt = grid[r][c].toString();
            if (txt.trim().isEmpty) continue;
            if (txt.toLowerCase().contains('break')) continue;
            final parts = txt.split('\n');
            String coursePart = parts.isNotEmpty ? parts[0].trim() : '';
            String teacherPart = parts.length > 1
                ? parts.sublist(1).join(' ').trim()
                : '';
            if (teacherPart.isNotEmpty && uuidRe.hasMatch(teacherPart)) {
              final tid = teacherPart;
              // try exact cache match
              Map<String, dynamic>? found;
              try {
                found = _teachers.firstWhere(
                  (t) => (t['id']?.toString() ?? '') == tid,
                  orElse: () => <String, dynamic>{},
                );
              } catch (_) {
                found = <String, dynamic>{};
              }
              if (found.isNotEmpty) {
                final name =
                    (found['name'] ??
                            found['teacher_name'] ??
                            found['username'] ??
                            '')
                        .toString();
                if (name.isNotEmpty) {
                  grid[r][c] = coursePart.isNotEmpty
                      ? '$coursePart\n$name'
                      : name;
                  continue;
                }
              }

              // try searching raw fields for substring match
              bool replaced = false;
              for (final t in _teachers) {
                try {
                  final raw = t['raw'];
                  if (raw != null) {
                    final rawStr = raw.toString();
                    if (rawStr.contains(tid)) {
                      final name =
                          (t['name'] ??
                                  t['teacher_name'] ??
                                  t['username'] ??
                                  '')
                              .toString();
                      if (name.isNotEmpty) {
                        grid[r][c] = coursePart.isNotEmpty
                            ? '$coursePart\n$name'
                            : name;
                        replaced = true;
                        break;
                      }
                    }
                  }
                } catch (_) {}
              }
              if (replaced) continue;
            }
          } catch (_) {}
        }
      }
    } catch (_) {}
    final depIdFromDoc = (data['department_id'] as String?)?.toString();
    final classKeyFromDoc = (data['classKey'] as String?)?.toString();

    setState(() {
      // primary display keys
      classPeriods.putIfAbsent(depKeyDisplay, () => {});
      classPeriods[depKeyDisplay]![classKeyDisplay] = List<String>.from(
        periods,
      );

      spans.putIfAbsent(depKeyDisplay, () => {});
      spans[depKeyDisplay]![classKeyDisplay] = List<Map<String, int>>.from(
        spanList,
      );

      timetableData.putIfAbsent(depKeyDisplay, () => {});
      timetableData[depKeyDisplay]![classKeyDisplay] = grid;

      // alias: department id -> class display
      if (depIdFromDoc != null && depIdFromDoc.trim().isNotEmpty) {
        final depIdKey = depIdFromDoc.trim();
        classPeriods.putIfAbsent(depIdKey, () => {});
        classPeriods[depIdKey]![classKeyDisplay] = List<String>.from(periods);

        spans.putIfAbsent(depIdKey, () => {});
        spans[depIdKey]![classKeyDisplay] = List<Map<String, int>>.from(
          spanList,
        );

        timetableData.putIfAbsent(depIdKey, () => {});
        timetableData[depIdKey]![classKeyDisplay] = grid;
      }

      // alias: class id -> under display dept
      if (classKeyFromDoc != null && classKeyFromDoc.trim().isNotEmpty) {
        final clsIdKey = classKeyFromDoc.trim();
        classPeriods.putIfAbsent(depKeyDisplay, () => {});
        classPeriods[depKeyDisplay]![clsIdKey] = List<String>.from(periods);

        spans.putIfAbsent(depKeyDisplay, () => {});
        spans[depKeyDisplay]![clsIdKey] = List<Map<String, int>>.from(spanList);

        timetableData.putIfAbsent(depKeyDisplay, () => {});
        timetableData[depKeyDisplay]![clsIdKey] = grid;

        if (depIdFromDoc != null && depIdFromDoc.trim().isNotEmpty) {
          final depIdKey = depIdFromDoc.trim();
          classPeriods.putIfAbsent(depIdKey, () => {});
          classPeriods[depIdKey]![clsIdKey] = List<String>.from(periods);

          spans.putIfAbsent(depIdKey, () => {});
          spans[depIdKey]![clsIdKey] = List<Map<String, int>>.from(spanList);

          timetableData.putIfAbsent(depIdKey, () => {});
          timetableData[depIdKey]![clsIdKey] = grid;
        }
      }

      // alias: sanitized doc id key
      final sanitizedDep = _sanitizeForId(depKeyDisplay);
      final sanitizedCls = _sanitizeForId(classKeyDisplay);
      classPeriods.putIfAbsent(sanitizedDep, () => {});
      classPeriods[sanitizedDep]![sanitizedCls] = List<String>.from(periods);

      spans.putIfAbsent(sanitizedDep, () => {});
      spans[sanitizedDep]![sanitizedCls] = List<Map<String, int>>.from(
        spanList,
      );

      timetableData.putIfAbsent(sanitizedDep, () => {});
      timetableData[sanitizedDep]![sanitizedCls] = grid;
    });

    // Also ensure mapping under the currently-selected department/class ids
    // when they refer to the same display names or ids. This helps when the
    // UI selection uses raw ids (selectedDepartment/selectedClass) but the
    // timetable document uses display names only; we create alias keys so
    // `currentTimetable` can find the grid reliably.
    try {
      final selDep = selectedDepartment;
      final selCls = selectedClass;
      if (selDep != null && selDep.trim().isNotEmpty) {
        final depMatches =
            (depIdFromDoc != null &&
                depIdFromDoc.trim().isNotEmpty &&
                depIdFromDoc.trim() == selDep) ||
            (_displayNameForDeptCached(selDep) == depKeyDisplay);
        if (depMatches) {
          final depKey = selDep.trim();
          classPeriods.putIfAbsent(depKey, () => {});
          spans.putIfAbsent(depKey, () => {});
          timetableData.putIfAbsent(depKey, () => {});
          // map by classDisplay
          classPeriods[depKey]![classKeyDisplay] = List<String>.from(periods);
          spans[depKey]![classKeyDisplay] = List<Map<String, int>>.from(
            spanList,
          );
          timetableData[depKey]![classKeyDisplay] = grid;
          // also if selectedClass id matches classKeyFromDoc or display, map under id
          if (selCls != null && selCls.trim().isNotEmpty) {
            final clsMatches =
                (classKeyFromDoc != null &&
                    classKeyFromDoc.trim().isNotEmpty &&
                    classKeyFromDoc.trim() == selCls) ||
                (_displayNameForClassCached(selCls) == classKeyDisplay);
            if (clsMatches) {
              classPeriods[depKey]![selCls] = List<String>.from(periods);
              spans[depKey]![selCls] = List<Map<String, int>>.from(spanList);
              timetableData[depKey]![selCls] = grid;
            }
          }
          debugPrint(
            '[TimetablePage] applied aliases for selected ids: dep=$depKey class=${selCls ?? classKeyDisplay}',
          );
        }
      }
    } catch (_) {}

    // Ensure a final post-frame refresh so the build picks up any caches
    // or alias keys that may have been populated asynchronously. Navigating
    // away and back previously forced this refresh; scheduling it here makes
    // the update immediate without changing selection semantics.
    try {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } catch (_) {}
  }

  Future<void> _saveTimetableDocToSupabase(
    String depIdOrName,
    String classIdOrName, {
    String? lastEditedCourseId,
    String? lastEditedTeacherId,
  }) async {
    /// Build a payload for the currently-cached timetable for the
    /// specified department/class and persist it through `UseTimetable`.
    ///
    /// This method computes the JSON structure expected by the service
    /// (periods, spans, grid) and includes optional last-edited ids so
    /// the service can store canonical UUID references where supported.
    final deptDisplay = await _resolveDepartmentDisplayName(depIdOrName);
    final classDisplay = await _resolveClassDisplayName(classIdOrName);
    // sanitized doc id not needed here; compute only where required in service

    final depKey =
        _findKeyIgnoreCase(timetableData, deptDisplay) ?? deptDisplay;
    final clsKey =
        _findKeyIgnoreCase(timetableData[depKey] ?? {}, classDisplay) ??
        classDisplay;

    final periods =
        classPeriods[depKey]?[clsKey] ?? List<String>.from(seedPeriods);
    final grid =
        timetableData[depKey]?[clsKey] ??
        List.generate(
          days.length,
          (_) => List<String>.filled(periods.length, ''),
        );

    final gridAsMaps = <Map<String, dynamic>>[];
    for (int r = 0; r < grid.length; r++) {
      gridAsMaps.add({'r': r, 'cells': List<String>.from(grid[r])});
    }

    final computedSpans =
        spans[depKey]?[clsKey] ?? _tryComputeSpansFromLabels(periods);

    final payload = {
      'periods': periods,
      'spans': computedSpans
          .map((m) => {'start': m['start'] ?? 0, 'end': m['end'] ?? 0})
          .toList(),
      'grid': gridAsMaps,
      // extra meta
      'department': deptDisplay,
      'department_id': depIdOrName,
      'classKey': classIdOrName,
      'className': classDisplay,
    };

    // If the edit produced explicit course/teacher ids, include them so
    // `UseTimetable.saveTimetable` can persist them as UUIDs instead of names.
    if (lastEditedCourseId != null && lastEditedCourseId.isNotEmpty) {
      payload['course'] = lastEditedCourseId;
    }
    if (lastEditedTeacherId != null && lastEditedTeacherId.isNotEmpty) {
      payload['teacher'] = lastEditedTeacherId;
    }

    try {
      await svc.saveTimetable(depIdOrName, classIdOrName, payload);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Timetable saved')));
      }
    } catch (e, st) {
      debugPrint('Error saving timetable: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving timetable: $e')));
      }
    }
  }

  Future<void> _applyCreatePayload(CreateTimetableTimePayload payload) async {
    /// Apply entries produced by the `CreateTimetableDialog`.
    ///
    /// The payload may contain results spanning multiple department/class
    /// documents. This function groups results by computed doc id and
    /// either creates new timetable documents or merges entries into
    /// existing documents before saving via the service.
    if (payload.results.isEmpty) return;

    final Map<String, List<CreateTimetableTimeResult>> grouped = {};
    for (final r in payload.results) {
      final deptDisplay = await _resolveDepartmentDisplayName(r.department);
      final classDisplay = await _resolveClassDisplayName(r.classKey);
      final id = _docIdFromDisplayNames(deptDisplay, classDisplay);
      grouped
          .putIfAbsent(id, () => [])
          .add(
            CreateTimetableTimeResult(
              department: deptDisplay,
              classKey: classDisplay,
              dayIndex: r.dayIndex,
              startMinutes: r.startMinutes,
              endMinutes: r.endMinutes,
              cellText: r.cellText,
            ),
          );
    }

    try {
      for (final entry in grouped.entries) {
        final docId = entry.key;
        // attempt to load existing timetable
        Map<String, dynamic>? snap = await svc.loadTimetableByDocId(docId);
        if (snap == null) {
          // create new structure
          final periods =
              payload.periodsOverride ?? List<String>.from(seedPeriods);
          final docSpans = _tryComputeSpansFromLabels(periods);
          final grid = List.generate(
            days.length,
            (_) => List<String>.filled(periods.length, '', growable: true),
          );

          for (final r in entry.value) {
            int colIndex = docSpans.indexWhere(
              (s) => s['start'] == r.startMinutes,
            );
            if (colIndex < 0) {
              final startStr =
                  '${r.startMinutes ~/ 60}:${(r.startMinutes % 60).toString().padLeft(2, '0')}';
              colIndex = periods.indexWhere((p) => p.contains(startStr));
            }
            if (colIndex >= 0 &&
                r.dayIndex >= 0 &&
                r.dayIndex < grid.length &&
                colIndex < grid[r.dayIndex].length) {
              grid[r.dayIndex][colIndex] = r.cellText;
            }
          }

          final gridAsMaps = <Map<String, dynamic>>[];
          for (int r = 0; r < grid.length; r++) {
            gridAsMaps.add({'r': r, 'cells': List<String>.from(grid[r])});
          }

          final parts = docId.split('_');
          final depPart = parts.isNotEmpty
              ? parts[0]
              : entry.value.first.department;

          final payloadRow = {
            'department': depPart,
            'department_id': entry.value.first.department,
            'classKey': entry.value.first.classKey,
            'className': entry.value.first.classKey,
            'periods': periods,
            'spans': docSpans
                .map((m) => {'start': m['start'], 'end': m['end']})
                .toList(),
            'grid': gridAsMaps,
            'sessions': entry.value
                .map(
                  (r) => {
                    'day': r.dayIndex,
                    'start': r.startMinutes,
                    'end': r.endMinutes,
                    'cellText': r.cellText,
                    if (r.teacherId != null) 'teacher_id': r.teacherId,
                  },
                )
                .toList(),
          };

          await svc.saveTimetable(
            entry.value.first.department,
            entry.value.first.classKey,
            payloadRow,
          );
        } else {
          // existing: merge similar to original approach (skipped for brevity)
          // For simplicity update existing grid with entries
          List<String> periods = [];
          List<Map<String, int>> docSpans = [];
          List<List<String>> grid = [];

          try {
            periods = (snap['periods'] is List)
                ? (snap['periods'] as List).map((e) => e.toString()).toList()
                : List<String>.from(seedPeriods);
            final spansRaw = (snap['spans'] is List)
                ? snap['spans'] as List
                : [];
            docSpans = spansRaw
                .map(
                  (e) => {
                    'start': (e['start'] as num?)?.toInt() ?? 0,
                    'end': (e['end'] as num?)?.toInt() ?? 0,
                  },
                )
                .toList();
            final gridRaw = (snap['grid'] is List) ? snap['grid'] as List : [];
            if (gridRaw.isNotEmpty &&
                gridRaw.first is Map &&
                (gridRaw.first as Map).containsKey('cells')) {
              grid = List.generate(
                days.length,
                (_) => List<String>.filled(periods.length, '', growable: true),
              );
              for (final rowObj in gridRaw) {
                if (rowObj is Map && rowObj['cells'] is List) {
                  final rIndex = (rowObj['r'] is int)
                      ? rowObj['r'] as int
                      : null;
                  final cells = (rowObj['cells'] as List)
                      .map((c) => c?.toString() ?? '')
                      .toList();
                  if (rIndex != null && rIndex >= 0 && rIndex < grid.length) {
                    grid[rIndex] = List<String>.from(cells);
                    if (grid[rIndex].length < periods.length) {
                      grid[rIndex].addAll(
                        List<String>.filled(
                          periods.length - grid[rIndex].length,
                          '',
                        ),
                      );
                    }
                  }
                }
              }
            } else {
              grid = (snap['grid'] is String)
                  ? (jsonDecode(snap['grid']) as List)
                        .map<List<String>>(
                          (r) => (r as List).map((c) => c.toString()).toList(),
                        )
                        .toList()
                  : List.generate(
                      days.length,
                      (_) => List<String>.filled(
                        periods.length,
                        '',
                        growable: true,
                      ),
                    );
            }
          } catch (_) {
            periods = List<String>.from(seedPeriods);
            docSpans = _tryComputeSpansFromLabels(periods);
            grid = List.generate(
              days.length,
              (_) => List<String>.filled(periods.length, '', growable: true),
            );
          }

          for (final r in entry.value) {
            int colIndex = -1;
            if (docSpans.isNotEmpty) {
              colIndex = docSpans.indexWhere(
                (s) => s['start'] == r.startMinutes,
              );
            }
            if (colIndex < 0) {
              final startStr =
                  '${r.startMinutes ~/ 60}:${(r.startMinutes % 60).toString().padLeft(2, '0')}';
              colIndex = periods.indexWhere((p) => p.contains(startStr));
            }
            if (colIndex >= 0 &&
                r.dayIndex >= 0 &&
                r.dayIndex < grid.length &&
                colIndex < grid[r.dayIndex].length) {
              grid[r.dayIndex][colIndex] = r.cellText;
            }
          }

          final gridAsMaps = <Map<String, dynamic>>[];
          for (int r = 0; r < grid.length; r++) {
            gridAsMaps.add({'r': r, 'cells': List<String>.from(grid[r])});
          }

          final first = entry.value.first;
          final payloadRow = {
            'department': first.department,
            'department_id': first.department,
            'classKey': first.classKey,
            'className': first.classKey,
            'periods': periods,
            'spans': docSpans
                .map((m) => {'start': m['start'], 'end': m['end']})
                .toList(),
            'grid': gridAsMaps,
          };

          await svc.saveTimetable(first.department, first.classKey, payloadRow);
        }
      }

      await _loadTimetableDoc();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Timetable entries applied')),
        );
      }
    } catch (e, st) {
      debugPrint('Error applying payload: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error applying entries: $e')));
      }
    }
  }

  // -------------------- Helpers & UI wiring --------------------

  List<TimetableSlot> _slotsFromGrid(
    List<List<String>> grid,
    List<String> periodsForClass,
  ) {
    /// Convert a timetable `grid` into a flat list of `TimetableSlot` items
    /// used by the search/filter UI and PDF export. Skips empty cells and
    /// break rows.
    final List<TimetableSlot> slots = [];
    final depDisplay = selectedDepartment != null
        ? _displayNameForDeptCached(selectedDepartment!)
        : '';
    final classDisplay = selectedClass != null
        ? _displayNameForClassCached(selectedClass!)
        : '';
    for (var d = 0; d < days.length; d++) {
      final row = d < grid.length
          ? grid[d]
          : List<String>.filled(periodsForClass.length, "", growable: true);
      for (var p = 0; p < periodsForClass.length; p++) {
        final rawCell = (p < row.length) ? row[p] : '';
        final cell = _displayForCellSync(rawCell);
        if (cell.trim().isEmpty) continue;
        if (cell.toLowerCase().contains('break')) continue;
        final parts = cell.split('\n');
        final course = parts.isNotEmpty ? parts[0] : '';
        final lecturer = parts.length > 1
            ? parts.sublist(1).join(' ').trim()
            : '';
        slots.add(
          TimetableSlot(
            day: days[d],
            periodLabel: periodsForClass[p],
            course: course,
            className: classDisplay,
            department: depDisplay,
            lecturer: lecturer,
          ),
        );
      }
    }
    return slots;
  }

  // Synchronous resolver that prefers cached values. It does NOT perform
  // network I/O; it only uses in-memory caches (_coursesForSelectedClass and
  // _teachers). This keeps rendering synchronous and avoids build-time
  // async calls. If a matching name isn't found in caches, the raw value is
  // returned unchanged.
  String _displayForCellSync(String raw) {
    /// Synchronous renderer helper: resolve a stored cell string into a
    /// human-friendly value using in-memory caches. This function never
    /// performs network I/O; it may schedule background fetches to populate
    /// caches for future renders.
    final s = raw.toString().trim();
    if (s.isEmpty) return s;
    if (s.toLowerCase().contains('break')) return s;
    final parts = s.split('\n');
    String coursePart = parts.isNotEmpty ? parts[0].trim() : '';
    String teacherPart = parts.length > 1
        ? parts.sublist(1).join(' ').trim()
        : '';

    final uuidRe = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    // allow finding a UUID substring inside a longer string (some cells include extra text)
    final uuidFind = RegExp(
      r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
    );

    // Resolve course via cache (unchanged logic)
    try {
      if (coursePart.isNotEmpty && uuidRe.hasMatch(coursePart)) {
        final found = _coursesForSelectedClass.firstWhere(
          (c) => (c['id']?.toString() ?? '') == coursePart,
          orElse: () => <String, dynamic>{},
        );
        if (found.isNotEmpty) {
          coursePart = (found['name'] ?? found['course_name'] ?? coursePart)
              .toString();
        } else {
          // schedule background fetch to populate courses cache so display can update
          if (!_pendingCourseFetches.contains(coursePart)) {
            scheduleMicrotask(() => _fetchAndCacheCourseById(coursePart));
          }
        }
      } else if (coursePart.isNotEmpty) {
        final foundByName = _coursesForSelectedClass.firstWhere(
          (c) =>
              (c['name']?.toString().toLowerCase() ?? '') ==
              coursePart.toLowerCase(),
          orElse: () => <String, dynamic>{},
        );
        if (foundByName.isNotEmpty) {
          coursePart =
              (foundByName['name'] ?? foundByName['course_name'] ?? coursePart)
                  .toString();
        }
      }
    } catch (_) {}

    // Resolve teacher via cache and course raw data, then background fetch if needed
    try {
      if (teacherPart.isNotEmpty) {
        // If teacherPart contains a JSON-like object or Map string, try to extract name/id
        try {
          final tpTrim = teacherPart.trim();
          if ((tpTrim.startsWith('{') && tpTrim.endsWith('}')) ||
              tpTrim.contains('"id"') ||
              tpTrim.contains('\'id\'')) {
            try {
              final dynamic parsed = jsonDecode(tpTrim);
              if (parsed is Map) {
                final nm =
                    (parsed['teacher_name'] ??
                    parsed['name'] ??
                    parsed['full_name'] ??
                    parsed['username']);
                if (nm != null && nm.toString().trim().isNotEmpty) {
                  teacherPart = nm.toString();
                } else if (parsed['id'] != null) {
                  teacherPart = (parsed['id']?.toString() ?? teacherPart);
                }
              }
            } catch (_) {}
          } else if (tpTrim.startsWith('Map(') && tpTrim.contains('id:')) {
            // Map(id: abc-..., teacher_name: John)
            try {
              final idMatch = RegExp(
                r'id\s*[:=]\s*([0-9a-fA-F\-]{36})',
              ).firstMatch(tpTrim);
              if (idMatch != null) {
                teacherPart = idMatch.group(1) ?? teacherPart;
              }
              final nameMatch = RegExp(
                r'teacher_name\s*[:=]\s*([^,\)]+)',
              ).firstMatch(tpTrim);
              if (nameMatch != null) {
                final nm = nameMatch.group(1)?.trim();
                if (nm != null && nm.isNotEmpty) teacherPart = nm;
              }
            } catch (_) {}
          }
        } catch (_) {}

        // If teacherPart contains a UUID, extract it and try direct id lookup
        String? teacherId;
        if (uuidRe.hasMatch(teacherPart)) {
          teacherId = teacherPart;
        } else if (uuidFind.hasMatch(teacherPart)) {
          teacherId = uuidFind.firstMatch(teacherPart)!.group(0);
        }
        if (teacherId != null && teacherId.isNotEmpty) {
          try {
            final foundById = _teachers.firstWhere(
              (t) => (t['id']?.toString() ?? '') == teacherId,
              orElse: () => <String, dynamic>{},
            );
            if (foundById.isNotEmpty) {
              teacherPart =
                  (foundById['name'] ??
                          foundById['teacher_name'] ??
                          foundById['username'] ??
                          teacherPart)
                      .toString();
            } else {
              // Try to extract teacher name from courses cache (some course rows contain nested teacher)
              bool resolved = false;
              for (final c in _coursesForSelectedClass) {
                try {
                  final raw = c['raw'];
                  if (raw is Map) {
                    final ta =
                        raw['teacher_assigned'] ??
                        raw['teacher'] ??
                        raw['teacher_assigned:teachers'];
                    if (ta != null) {
                      if (ta is String && ta == teacherId) {
                        final name =
                            (raw['teacher_name'] ?? raw['teacher'] ?? '')
                                .toString();
                        if (name.isNotEmpty) {
                          teacherPart = name;
                          resolved = true;
                          break;
                        }
                      } else if (ta is Map) {
                        final idVal = (ta['id'] ?? '').toString();
                        if (idVal == teacherId) {
                          final name =
                              (ta['teacher_name'] ??
                                      ta['name'] ??
                                      ta['username'] ??
                                      '')
                                  .toString();
                          if (name.isNotEmpty) {
                            teacherPart = name;
                            resolved = true;
                            break;
                          }
                        }
                      }
                    }
                  }
                } catch (_) {}
              }

              // If still unresolved, try more robust matching against known teacher cache fields
              if (!resolved) {
                try {
                  for (final tEntry in _teachers) {
                    try {
                      // direct id match already attempted above, but re-check defensive
                      if ((tEntry['id']?.toString() ?? '') == teacherId) {
                        teacherPart =
                            (tEntry['name'] ??
                                    tEntry['teacher_name'] ??
                                    tEntry['username'] ??
                                    teacherPart)
                                .toString();
                        resolved = true;
                        break;
                      }
                      final rawT = tEntry['raw'];
                      if (rawT is Map) {
                        // common alternate id keys to check
                        const altKeys = [
                          'uid',
                          'user_id',
                          'teacher_id',
                          'uuid',
                          '_id',
                        ];
                        for (final k in altKeys) {
                          try {
                            final v = rawT[k];
                            if (v != null && v.toString() == teacherId) {
                              teacherPart =
                                  (tEntry['name'] ??
                                          tEntry['teacher_name'] ??
                                          tEntry['username'] ??
                                          teacherPart)
                                      .toString();
                              resolved = true;
                              break;
                            }
                          } catch (_) {}
                        }
                        if (resolved) break;

                        // fallback: inspect any string value in raw map
                        for (final v in rawT.values) {
                          try {
                            if (v != null && v.toString() == teacherId) {
                              teacherPart =
                                  (tEntry['name'] ??
                                          tEntry['teacher_name'] ??
                                          tEntry['username'] ??
                                          teacherPart)
                                      .toString();
                              resolved = true;
                              break;
                            }
                          } catch (_) {}
                        }
                        // also try contains: sometimes the id is embedded in a JSON/string
                        if (!resolved) {
                          try {
                            final rawStr = rawT.toString();
                            if (rawStr.contains(teacherId)) {
                              teacherPart =
                                  (tEntry['name'] ??
                                          tEntry['teacher_name'] ??
                                          tEntry['username'] ??
                                          teacherPart)
                                      .toString();
                              resolved = true;
                              break;
                            }
                          } catch (_) {}
                        }
                        if (resolved) break;
                      }
                    } catch (_) {}
                  }
                } catch (_) {}
              }

              // If still unresolved, schedule background fetch to populate cache
              if (!resolved && !_pendingTeacherFetches.contains(teacherId)) {
                scheduleMicrotask(() => _fetchAndCacheTeacherById(teacherId!));
              }
            }
          } catch (_) {}
        } else {
          // Not a UUID — try exact or partial name/username match in cache
          final lp = teacherPart.toLowerCase();
          final foundByName = _teachers.firstWhere((t) {
            final n = (t['name']?.toString().toLowerCase() ?? '');
            final tn = (t['teacher_name']?.toString().toLowerCase() ?? '');
            final u = (t['username']?.toString().toLowerCase() ?? '');
            return n == lp ||
                tn == lp ||
                u == lp ||
                n.contains(lp) ||
                tn.contains(lp) ||
                u.contains(lp);
          }, orElse: () => <String, dynamic>{});
          if (foundByName.isNotEmpty) {
            teacherPart =
                (foundByName['name'] ??
                        foundByName['teacher_name'] ??
                        foundByName['username'] ??
                        teacherPart)
                    .toString();
          }
        }
      }
    } catch (_) {}

    if (teacherPart.isNotEmpty) return '$coursePart\n$teacherPart';
    return coursePart;
  }

  // Background fetch a course by id and merge into local cache.
  Future<void> _fetchAndCacheCourseById(String id) async {
    /// Background fetch for a single course by id and merge it into the
    /// `_coursesForSelectedClass` cache. Called indirectly when a UUID is
    /// discovered during rendering so that subsequent renders show names.
    final cid = id.toString().trim();
    if (cid.isEmpty) return;
    if (_pendingCourseFetches.contains(cid)) return;
    _pendingCourseFetches.add(cid);
    try {
      final dynamic raw = await svc.supabase
          .from('courses')
          .select()
          .eq('id', cid)
          .limit(1);
      dynamic data;
      if (raw is Map && raw.containsKey('data')) {
        data = raw['data'];
      } else {
        data = raw;
      }
      if (data is List && data.isNotEmpty) {
        final r = data.first;
        final name =
            (r['course_name'] ??
                    r['title'] ??
                    r['course_code'] ??
                    r['name'] ??
                    r['id'])
                ?.toString() ??
            cid;
        final entry = {
          'id': r['id']?.toString() ?? cid,
          'name': name,
          'raw': r,
        };
        final existingIds = _coursesForSelectedClass
            .map((e) => (e['id']?.toString() ?? ''))
            .toSet();
        if (!existingIds.contains(entry['id'])) {
          _coursesForSelectedClass.add(entry);
          if (mounted) setState(() {});
        }
      }
    } catch (e) {
      debugPrint('fetchAndCacheCourseById failed: $e');
    } finally {
      _pendingCourseFetches.remove(cid);
    }
  }

  String _displayNameForDeptCached(String depIdOrName) {
    final s = depIdOrName.trim();
    try {
      final found = _departments.firstWhere(
        (d) => (d['id']?.toString() ?? '') == s,
        orElse: () => <String, dynamic>{},
      );
      if (found.isNotEmpty) {
        final n = (found['name']?.toString() ?? '').trim();
        if (n.isNotEmpty) return n;
      }
    } catch (_) {}
    return s;
  }

  // Resolve course display name from a value which may be a UUID or a name.
  // Prefer cached courses for the selected class, then fall back to DB lookup.
  Future<String> _resolveCourseDisplay(
    String value,
    String classDisplay,
  ) async {
    /// Resolve a course id or name to a display name. Prefers the
    /// `_coursesForSelectedClass` cache and falls back to a Supabase
    /// lookup if needed.
    final s = value.toString().trim();
    if (s.isEmpty) return s;
    final uuidRe = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    try {
      // If it looks like a UUID, try cache
      if (uuidRe.hasMatch(s)) {
        try {
          final found = _coursesForSelectedClass.firstWhere(
            (c) => (c['id']?.toString() ?? '') == s,
            orElse: () => <String, dynamic>{},
          );
          if (found.isNotEmpty) {
            return (found['name'] ?? found['course_name'] ?? s).toString();
          }
        } catch (_) {}
        // DB fallback
        try {
          dynamic res = await svc.supabase
              .from('courses')
              .select('course_name,name')
              .eq('id', s)
              .limit(1);
          dynamic d;
          if (res is Map && res.containsKey('data')) {
            d = res['data'];
          } else {
            d = res;
          }
          if (d is List && d.isNotEmpty) {
            return (d.first['course_name'] ?? d.first['name'] ?? s).toString();
          }
        } catch (_) {}
        return s;
      }

      // If not a UUID, try to match by name in cache
      try {
        final found = _coursesForSelectedClass.firstWhere(
          (c) => (c['name']?.toString().toLowerCase() ?? '') == s.toLowerCase(),
          orElse: () => <String, dynamic>{},
        );
        if (found.isNotEmpty) {
          return (found['name'] ?? found['course_name'] ?? s).toString();
        }
      } catch (_) {}

      return s;
    } catch (_) {
      return s;
    }
  }

  // Resolve teacher display name from a value which may be a UUID or a name.
  Future<String> _resolveTeacherDisplay(String value) async {
    /// Resolve a teacher id (UUID) or already-provided name into a
    /// displayable teacher name. Uses `_teachers` cache then queries the
    /// remote service as needed.
    final s = value.toString().trim();
    if (s.isEmpty) return s;
    final uuidRe = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    try {
      if (uuidRe.hasMatch(s)) {
        try {
          final found = _teachers.firstWhere(
            (t) => (t['id']?.toString() ?? '') == s,
            orElse: () => <String, dynamic>{},
          );
          if (found.isNotEmpty) {
            return (found['name'] ?? found['teacher_name'] ?? s).toString();
          }
        } catch (_) {}
        // DB fallback
        try {
          dynamic res = await svc.supabase
              .from('teachers')
              .select('teacher_name,name')
              .eq('id', s)
              .limit(1);
          dynamic d;
          if (res is Map && res.containsKey('data')) {
            d = res['data'];
          } else {
            d = res;
          }
          if (d is List && d.isNotEmpty) {
            return (d.first['teacher_name'] ?? d.first['name'] ?? s).toString();
          }
        } catch (_) {}
        return s;
      }

      // Not a UUID — assume it's already a name
      return s;
    } catch (_) {
      return s;
    }
  }

  // Background fetch a teacher by id and merge into local cache. This is
  // intentionally asynchronous and called via scheduleMicrotask from the
  // synchronous renderer so we don't perform network I/O during build.
  Future<void> _fetchAndCacheTeacherById(String id) async {
    /// Background helper that tries multiple candidate tables to find a
    /// teacher/user record by id and merges it into `_teachers`.
    final tid = id.toString().trim();
    if (tid.isEmpty) return;
    if (_pendingTeacherFetches.contains(tid)) return;
    _pendingTeacherFetches.add(tid);
    try {
      // Try multiple tables where a user/teacher record might be stored.
      final candidateTables = ['teachers', 'users', 'profiles', 'accounts'];
      List<dynamic>? foundList;
      dynamic foundRaw;
      for (final table in candidateTables) {
        try {
          final dynamic raw = await svc.supabase
              .from(table)
              .select()
              .eq('id', tid)
              .limit(1);
          dynamic data;
          if (raw is Map && raw.containsKey('data')) {
            data = raw['data'];
          } else {
            data = raw;
          }
          if (data is List && data.isNotEmpty) {
            foundList = data;
            foundRaw = data.first;
            break;
          }
        } catch (_) {}
      }

      if (foundList != null && foundRaw != null) {
        final r = foundRaw;
        String name = tid;
        try {
          name =
              (r['teacher_name'] ??
                      r['name'] ??
                      r['full_name'] ??
                      r['display_name'] ??
                      r['username'] ??
                      r['first_name'] ??
                      r['last_name'] ??
                      r['email'] ??
                      r['id'])
                  ?.toString() ??
              tid;
        } catch (_) {
          name = tid;
        }
        final entry = {
          'id': (r['id']?.toString() ?? tid),
          'name': name,
          'raw': r,
        };
        final existingIds = _teachers
            .map((e) => (e['id']?.toString() ?? ''))
            .toSet();
        if (!existingIds.contains(entry['id'])) {
          _teachers.add(entry);
          if (mounted) setState(() {});
        }
      }
    } catch (e) {
      debugPrint('fetchAndCacheTeacherById failed: $e');
    } finally {
      _pendingTeacherFetches.remove(tid);
    }
  }

  String _displayNameForClassCached(String classIdOrName) {
    final s = classIdOrName.trim();
    try {
      final found = _classes.firstWhere(
        (c) => (c['id']?.toString() ?? '') == s,
        orElse: () => <String, dynamic>{},
      );
      if (found.isNotEmpty) {
        final n = (found['name']?.toString() ?? '').trim();
        if (n.isNotEmpty) return n;
      }
    } catch (_) {}
    return s;
  }

  // Robust currentTimetable: try aliases and inspect existing keys
  List<List<String>>? get currentTimetable {
    /// Resolve and return the currently-selected timetable grid from the
    /// in-memory `timetableData` cache. This getter tries several aliases
    /// so selection by id or display name both work reliably.
    // If no class is explicitly selected, do not display any cached timetable.
    // This prevents showing a previously-displayed class timetable when the
    // user has cleared the class selector or intentionally hasn't selected one.
    if (selectedClass == null || selectedClass!.trim().isEmpty) return null;
    debugPrint(
      'currentTimetable lookup: selectedDepartment=$selectedDepartment selectedClass=$selectedClass',
    );
    debugPrint('timetableData keys: ${timetableData.keys.toList()}');

    final depCandidates = <String>[];
    if (selectedDepartment != null) {
      final sel = selectedDepartment!.trim();
      final cachedDep = _displayNameForDeptCached(sel);
      if (cachedDep.isNotEmpty) depCandidates.add(cachedDep);
      depCandidates.add(sel);
      depCandidates.add(_sanitizeForId(cachedDep));
      depCandidates.add(_sanitizeForId(sel));
    }
    depCandidates.addAll(timetableData.keys.map((k) => k.toString()));

    final seen = <String>{};
    final deps = <String>[];
    for (final d in depCandidates) {
      final dd = d.trim();
      if (dd.isEmpty) continue;
      if (seen.add(dd.toLowerCase())) deps.add(dd);
    }

    for (final depKey in deps) {
      final classesMap = timetableData[depKey];
      if (classesMap == null) continue;
      final classCandidates = <String>[];
      if (selectedClass != null) {
        final selC = selectedClass!.trim();
        final cachedCls = _displayNameForClassCached(selC);
        if (cachedCls.isNotEmpty) classCandidates.add(cachedCls);
        classCandidates.add(selC);
        classCandidates.add(_sanitizeForId(cachedCls));
        classCandidates.add(_sanitizeForId(selC));
      }
      classCandidates.addAll(classesMap.keys.map((k) => k.toString()));

      final seenC = <String>{};
      final clsList = <String>[];
      for (final c in classCandidates) {
        final cc = c.trim();
        if (cc.isEmpty) continue;
        if (seenC.add(cc.toLowerCase())) clsList.add(cc);
      }

      for (final classKey in clsList) {
        final foundKey = _findKeyIgnoreCase(classesMap, classKey);
        if (foundKey != null) {
          debugPrint(
            'currentTimetable found under depKey="$depKey" classKey="$foundKey"',
          );
          return classesMap[foundKey];
        }
      }
    }

    debugPrint(
      'currentTimetable: no matching timetable found in in-memory cache',
    );
    return null;
  }

  // Robust currentPeriods: try multiple aliases
  List<String> get currentPeriods {
    /// Return the period labels for the currently-selected department/class.
    /// Uses `classPeriods` aliases and falls back to `seedPeriods` if no
    /// configuration is available.
    final depDisplay = selectedDepartment != null
        ? _displayNameForDeptCached(selectedDepartment!)
        : null;
    final clsDisplay = selectedClass != null
        ? _displayNameForClassCached(selectedClass!)
        : null;

    List<String>? copyPeriods(List<String>? p) =>
        p == null ? null : List<String>.from(p, growable: true);

    if (depDisplay != null && clsDisplay != null) {
      final p = classPeriods[depDisplay]?[clsDisplay];
      if (p != null && p.isNotEmpty) return copyPeriods(p)!;
    }

    if (selectedDepartment != null && clsDisplay != null) {
      final p = classPeriods[selectedDepartment!]?[clsDisplay];
      if (p != null && p.isNotEmpty) return copyPeriods(p)!;
    }

    if (depDisplay != null && selectedClass != null) {
      final p = classPeriods[depDisplay]?[selectedClass!];
      if (p != null && p.isNotEmpty) return copyPeriods(p)!;
    }

    if (selectedDepartment != null && selectedClass != null) {
      final p = classPeriods[selectedDepartment!]?[selectedClass!];
      if (p != null && p.isNotEmpty) return copyPeriods(p)!;
    }

    if (depDisplay != null && clsDisplay != null) {
      final sDep = _sanitizeForId(depDisplay);
      final sCls = _sanitizeForId(clsDisplay);
      final p = classPeriods[sDep]?[sCls];
      if (p != null && p.isNotEmpty) return copyPeriods(p)!;
    }

    if (selectedDepartment != null) {
      final map = classPeriods[selectedDepartment!];
      if (map != null && map.isNotEmpty) {
        if (selectedClass != null) {
          final found =
              _findKeyIgnoreCase(
                map,
                _displayNameForClassCached(selectedClass!),
              ) ??
              _findKeyIgnoreCase(map, selectedClass);
          if (found != null) return copyPeriods(map[found])!;
        }
        return copyPeriods(map.values.first)!;
      }
    }

    if (classPeriods.isNotEmpty) {
      final firstDep = classPeriods.keys.first;
      final firstMap = classPeriods[firstDep]!;
      if (firstMap.isNotEmpty) return copyPeriods(firstMap.values.first)!;
    }

    return List<String>.from(seedPeriods, growable: true);
  }

  String? _findKeyIgnoreCase(Map map, String? key) {
    if (key == null) return null;
    final lower = key.toString().toLowerCase().trim();
    for (final k in map.keys) {
      try {
        if (k.toString().toLowerCase().trim() == lower) return k.toString();
      } catch (_) {}
    }
    return null;
  }

  // Clear any cached timetable entries for a given department/class so the
  // UI does not fall back to displaying a previously loaded timetable.
  void _clearTimetableForSelection({
    required String depDisplay,
    required String classDisplay,
  }) {
    try {
      final depCandidates = <String>{
        depDisplay,
        if (selectedDepartment != null) selectedDepartment!,
        _sanitizeForId(depDisplay),
        if (selectedDepartment != null) _sanitizeForId(selectedDepartment!),
      };

      final classCandidates = <String>{
        classDisplay,
        if (selectedClass != null) selectedClass!,
        _sanitizeForId(classDisplay),
        if (selectedClass != null) _sanitizeForId(selectedClass!),
      };

      for (final dk in depCandidates) {
        try {
          if (dk.trim().isEmpty) continue;
          // remove from main caches
          if (timetableData.containsKey(dk)) {
            for (final ck in classCandidates) {
              timetableData[dk]?.remove(ck);
              classPeriods[dk]?.remove(ck);
              spans[dk]?.remove(ck);
            }
            if (timetableData[dk]?.isEmpty ?? true) timetableData.remove(dk);
            if (classPeriods[dk]?.isEmpty ?? true) classPeriods.remove(dk);
            if (spans[dk]?.isEmpty ?? true) spans.remove(dk);
          }
        } catch (_) {}
      }
    } catch (_) {}
  }

  // -------------------- Selection change --------------------

  Future<void> _handleSelectionChangeSafe() async {
    try {
      await _loadTimetableDoc();
      if (mounted) setState(() => editingEnabled = false);
    } catch (e, st) {
      debugPrint('Error in _handleSelectionChangeSafe: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load timetable.')),
        );
      }
    }
  }

  // -------------------- Cell edit (safe) --------------------

  Future<void> _openEditCellDialog({
    required int dayIndex,
    required int periodIndex,
  }) async {
    /// Open the cell edit dialog for the given `dayIndex` and
    /// `periodIndex`. This method locates the correct grid (using the same
    /// alias strategy as `currentTimetable`), pre-fills the dialog with the
    /// current cell text and persists any changes back to Supabase.
    if (!editingEnabled) return;

    // Try to resolve grid with same alias strategy as currentTimetable
    List<List<String>>? grid;
    String? foundDepKey;
    String? foundClassKey;

    final depCandidates = <String>[];
    if (selectedDepartment != null) {
      final sel = selectedDepartment!.trim();
      final cachedDep = _displayNameForDeptCached(sel);
      if (cachedDep.isNotEmpty) depCandidates.add(cachedDep);
      depCandidates.add(sel);
      depCandidates.add(_sanitizeForId(cachedDep));
      depCandidates.add(_sanitizeForId(sel));
    }
    depCandidates.addAll(timetableData.keys.map((k) => k.toString()));

    final depSeen = <String>{};
    final depList = <String>[];
    for (final d in depCandidates) {
      final dd = d.trim();
      if (dd.isEmpty) continue;
      if (depSeen.add(dd.toLowerCase())) depList.add(dd);
    }

    List<String> buildClassCandidates(Map classesMap) {
      final candidates = <String>[];
      if (selectedClass != null) {
        final selCls = selectedClass!.trim();
        final cachedCls = _displayNameForClassCached(selCls);
        if (cachedCls.isNotEmpty) candidates.add(cachedCls);
        candidates.add(selCls);
        candidates.add(_sanitizeForId(cachedCls));
        candidates.add(_sanitizeForId(selCls));
      }
      candidates.addAll(classesMap.keys.map((k) => k.toString()));
      final seen = <String>{};
      final out = <String>[];
      for (final c in candidates) {
        final cc = c.trim();
        if (cc.isEmpty) continue;
        if (seen.add(cc.toLowerCase())) out.add(cc);
      }
      return out;
    }

    for (final depKey in depList) {
      final classesMap = timetableData[depKey];
      if (classesMap == null) continue;
      final classCandidates = buildClassCandidates(classesMap);
      for (final c in classCandidates) {
        final matched = _findKeyIgnoreCase(classesMap, c);
        if (matched != null) {
          foundDepKey = depKey;
          foundClassKey = matched;
          grid = classesMap[matched];
          break;
        }
      }
      if (grid != null) break;
    }

    if (grid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Timetable not loaded for the selected class.'),
          ),
        );
      }
      return;
    }

    final periodsForClass = currentPeriods;
    if (periodIndex < 0 || periodIndex >= periodsForClass.length) return;

    final periodLabel = periodsForClass[periodIndex];
    if (periodLabel.toLowerCase().contains('break')) return;

    if (dayIndex >= grid.length) {
      while (grid.length <= dayIndex) {
        grid.add(
          List<String>.filled(periodsForClass.length, '', growable: true),
        );
      }
    }
    if (periodIndex >= grid[dayIndex].length) {
      grid[dayIndex].addAll(
        List<String>.filled(periodIndex - grid[dayIndex].length + 1, ''),
      );
    }

    final raw = (periodIndex < grid[dayIndex].length)
        ? grid[dayIndex][periodIndex]
        : '';
    String? initialCourse;
    String? initialLecturer;
    if (raw.trim().isNotEmpty && !raw.toLowerCase().contains('break')) {
      final parts = raw.split('\n');
      initialCourse = parts.isNotEmpty ? parts[0] : null;
      if (parts.length > 1) initialLecturer = parts.sublist(1).join(' ').trim();
    }

    final result = await showDialog<TimetableCellEditResult>(
      context: context,
      builder: (ctx) => TimetableCellEditDialog(
        classId: selectedClass,
        initialCourse: initialCourse,
        initialLecturer: initialLecturer,
        courses: _coursesForSelectedClass.isNotEmpty
            ? _coursesForSelectedClass.map((c) => c['name'] as String).toList()
            : <String>[],
        lecturers: _teachers.isNotEmpty
            ? _teachers.map((t) => t['name'] as String).toList()
            : <String>[],
      ),
    );

    if (result == null) return;
    if (result.cellText == null) return;

    setState(() {
      if (dayIndex >= grid!.length) {
        while (grid.length <= dayIndex) {
          grid.add(
            List<String>.filled(periodsForClass.length, '', growable: true),
          );
        }
      }
      if (periodIndex >= grid[dayIndex].length) {
        grid[dayIndex].addAll(
          List<String>.filled(periodIndex - grid[dayIndex].length + 1, ''),
        );
      }
      grid[dayIndex][periodIndex] = result.cellText!.trim();

      final depWriteKeys = <String>{};
      if (foundDepKey != null) depWriteKeys.add(foundDepKey);
      if (selectedDepartment != null) depWriteKeys.add(selectedDepartment!);
      final depDisplayCached = selectedDepartment != null
          ? _displayNameForDeptCached(selectedDepartment!)
          : null;
      if (depDisplayCached != null && depDisplayCached.isNotEmpty) {
        depWriteKeys.add(depDisplayCached);
      }
      if (depDisplayCached != null) {
        depWriteKeys.add(_sanitizeForId(depDisplayCached));
      }

      final classWriteKeys = <String>{};
      if (foundClassKey != null) classWriteKeys.add(foundClassKey);
      if (selectedClass != null) classWriteKeys.add(selectedClass!);
      final classDisplayCached = selectedClass != null
          ? _displayNameForClassCached(selectedClass!)
          : null;
      if (classDisplayCached != null && classDisplayCached.isNotEmpty) {
        classWriteKeys.add(classDisplayCached);
      }
      if (classDisplayCached != null) {
        classWriteKeys.add(_sanitizeForId(classDisplayCached));
      }

      for (final dk in depWriteKeys) {
        timetableData.putIfAbsent(dk, () => {});
        for (final ck in classWriteKeys) {
          timetableData[dk]!.putIfAbsent(
            ck,
            () => List.generate(
              days.length,
              (_) => List<String>.filled(
                periodsForClass.length,
                '',
                growable: true,
              ),
            ),
          );
          timetableData[dk]![ck] = grid
              .map((r) => List<String>.from(r, growable: true))
              .toList(growable: true);

          classPeriods.putIfAbsent(dk, () => {});
          classPeriods[dk]![ck] = List<String>.from(
            periodsForClass,
            growable: true,
          );

          spans.putIfAbsent(dk, () => {});
          spans[dk]![ck] =
              spans[dk]![ck] ?? _tryComputeSpansFromLabels(periodsForClass);
        }
      }
    });

    if (selectedDepartment != null && selectedClass != null) {
      try {
        await _saveTimetableDocToSupabase(
          selectedDepartment!,
          selectedClass!,
          lastEditedCourseId: result.courseId,
          lastEditedTeacherId: result.lecturerId,
        );
      } catch (e, st) {
        debugPrint('Error saving timetable after edit: $e\n$st');
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error saving timetable: $e')));
        }
      }
    }
  }

  Future<void> _reloadTimetable() async {
    if (selectedDepartment == null || selectedClass == null) return;
    if (mounted) {
      setState(() {
        _loadingTimetable = true;
        _suppressOldGrid = true;
      });
    }
    try {
      await _loadTimetableDoc();
    } catch (e) {
      debugPrint('reloadTimetable failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loadingTimetable = false;
          _suppressOldGrid = false;
        });
      }
    }
  }

  void _deleteTimetable({required bool deleteEntireClass}) async {
    if (selectedDepartment == null || selectedClass == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select Department and Class first')),
      );
      return;
    }

    final depDisplay = await _resolveDepartmentDisplayName(selectedDepartment!);

    try {
      await svc.deleteTimetableByDeptClass(
        selectedDepartment!,
        selectedClass!,
        deleteEntireClass: deleteEntireClass,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Timetable updated successfully')),
      );
      setState(() {
        timetableData.remove(depDisplay);
        classPeriods.remove(depDisplay);
        spans.remove(depDisplay);
      });
    } catch (e, st) {
      debugPrint('Error deleting timetable: $e\n$st');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting timetable: $e')));
    }
  }

  // -------------------- Utilities --------------------

  List<Map<String, int>> _tryComputeSpansFromLabels(List<String> labels) {
    final List<Map<String, int>> out = [];
    for (final label in labels) {
      final match = RegExp(
        r'^(\d{1,2}):(\d{2})\s*-\s*(\d{1,2}):(\d{2})',
      ).firstMatch(label);
      if (match != null) {
        final sh = int.parse(match.group(1)!);
        final sm = int.parse(match.group(2)!);
        final eh = int.parse(match.group(3)!);
        final em = int.parse(match.group(4)!);
        out.add({'start': sh * 60 + sm, 'end': eh * 60 + em});
      } else {
        out.add({'start': 0, 'end': 0});
      }
    }
    return out;
  }

  // Helper wrappers required by deliverables
  Future<void> createPeriodConfigurationWrapper(
    String classId,
    String departmentId,
    List<String> periods,
    List<Map<String, int>> spansList,
  ) async {
    await svc.createPeriodConfiguration(
      classId,
      departmentId,
      periods,
      spansList,
    );
  }

  Future<List<String>?> getPeriodConfigurationWrapper(String classId) async {
    return await svc.getPeriodConfiguration(classId);
  }

  Future<Map<String, String>?> autoAssignTeacherWrapper(String courseId) async {
    return await svc.autoAssignTeacher(courseId);
  }

  // Assign a course to a period index (dayIndex, periodIndex) and persist.
  Future<void> assignCourseToPeriod(
    String courseId,
    int dayIndex,
    int periodIndex,
  ) async {
    if (selectedDepartment == null || selectedClass == null) return;
    final depKey = selectedDepartment!;
    final clsKey = selectedClass!;
    final periodsForClass =
        classPeriods[depKey]?[clsKey] ?? classPeriods[depKey]?[clsKey] ?? [];
    final spansForClass =
        spans[depKey]?[clsKey] ?? _tryComputeSpansFromLabels(periodsForClass);
    if (periodIndex < 0 || periodIndex >= spansForClass.length) return;

    // Resolve course display name
    String courseName = courseId;
    try {
      final found = _coursesForSelectedClass.firstWhere(
        (c) => (c['id']?.toString() ?? '') == courseId,
        orElse: () => <String, dynamic>{},
      );
      if (found.isNotEmpty) {
        courseName = (found['name'] ?? found['course_name'] ?? courseId)
            .toString();
      }
    } catch (_) {}

    // auto-assign teacher id & name
    String? teacherId;
    String? teacherName;
    try {
      final auto = await svc.autoAssignTeacher(courseId);
      if (auto != null) {
        teacherId = auto['id'];
        teacherName = auto['name'];
      }
    } catch (_) {}

    if (teacherId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Course has no teacher assigned')),
        );
      }
      return;
    }

    final cellText = teacherName != null
        ? '$courseName\n$teacherName'
        : courseName;

    // ensure grid exists and set value
    setState(() {
      timetableData.putIfAbsent(depKey, () => {});
      timetableData[depKey]!.putIfAbsent(
        clsKey,
        () => List.generate(
          days.length,
          (_) =>
              List<String>.filled(periodsForClass.length, '', growable: true),
        ),
      );
      final grid = timetableData[depKey]![clsKey]!;
      if (dayIndex >= grid.length) {
        while (grid.length <= dayIndex) {
          grid.add(
            List<String>.filled(periodsForClass.length, '', growable: true),
          );
        }
      }
      if (periodIndex >= grid[dayIndex].length) {
        grid[dayIndex].addAll(
          List<String>.filled(periodIndex - grid[dayIndex].length + 1, ''),
        );
      }
      grid[dayIndex][periodIndex] = cellText;
      classPeriods.putIfAbsent(depKey, () => {});
      classPeriods[depKey]![clsKey] = periodsForClass;
      spans.putIfAbsent(depKey, () => {});
      spans[depKey]![clsKey] = spansForClass;
    });

    // persist change
    try {
      await _saveTimetableDocToSupabase(
        selectedDepartment!,
        selectedClass!,
        lastEditedCourseId: courseId,
        lastEditedTeacherId: teacherId,
      );
    } catch (e) {
      debugPrint('assignCourseToPeriod save error: $e');
    }
  }

  // Render periods with breaks: returns list of label -> span maps
  List<Map<String, dynamic>> renderPeriodsWithBreaks(
    List<String> labels,
    List<Map<String, int>> spansList,
  ) {
    final out = <Map<String, dynamic>>[];
    for (int i = 0; i < labels.length; i++) {
      out.add({
        'label': labels[i],
        'start': spansList[i]['start'] ?? 0,
        'end': spansList[i]['end'] ?? 0,
        'isBreak': labels[i].toLowerCase().contains('break'),
      });
    }
    return out;
  }

  // Place sessions into grid columns using spans (matches start minutes to span start)
  List<List<String>> displaySessionsInCorrectSlots(
    List<Map<String, dynamic>> sessions,
    List<Map<String, int>> spansList, {
    int rows = 6,
  }) {
    final grid = List.generate(
      rows,
      (_) => List<String>.filled(spansList.length, '', growable: true),
    );
    for (final s in sessions) {
      try {
        final rawDay = (s['day'] is int)
            ? s['day'] as int
            : int.tryParse(s['day']?.toString() ?? '') ?? 0;
        int dayIndex;
        if (rawDay >= 0 && rawDay <= 5) {
          dayIndex = rawDay;
        } else if (rawDay >= 1 && rawDay <= 6) {
          dayIndex = rawDay - 1;
        } else {
          final m = rawDay % 7;
          dayIndex = (m >= 0 && m <= 5) ? m : 5;
        }
        final start = (s['start'] is int)
            ? s['start'] as int
            : int.tryParse(s['start']?.toString() ?? '') ?? 0;
        // find span where start falls inside span's interval (inclusive start, exclusive end)
        int col = spansList.indexWhere((p) {
          final ps = (p['start'] ?? 0);
          final pe = (p['end'] ?? 0);
          return start >= ps && start < pe;
        });
        if (col < 0) col = 0;
        if (dayIndex >= 0 && dayIndex < grid.length) {
          if (col >= grid[dayIndex].length) {
            grid[dayIndex].addAll(
              List<String>.filled(col - grid[dayIndex].length + 1, ''),
            );
          }
          grid[dayIndex][col] =
              (s['course_name'] ?? s['course'] ?? '').toString() +
              ((s['teacher_name'] ?? s['teacher'] ?? '')
                          ?.toString()
                          .isNotEmpty ==
                      true
                  ? '\n' + (s['teacher_name'] ?? s['teacher'] ?? '')
                  : '');
        }
      } catch (_) {}
    }
    return grid;
  }

  // Batch-resolve missing teacher/course UUIDs found in a parsed grid.
  // This performs at-most-two supabase queries (courses and teachers) and
  // updates the local caches so the synchronous display resolver can use
  // human-friendly names. `classDisplay` is used to scope/append courses
  // into `_coursesForSelectedClass` when appropriate.
  Future<void> _resolveMissingNamesFromGrid(
    List<List<String>> grid,
    String classDisplay,
  ) async {
    try {
      final uuidRe = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      );
      final missingCourseIds = <String>{};
      final missingTeacherIds = <String>{};

      for (final row in grid) {
        for (final c in row) {
          try {
            final txt = c.toString().trim();
            if (txt.isEmpty) continue;
            if (txt.toLowerCase().contains('break')) continue;
            final parts = txt.split('\n');
            final coursePart = parts.isNotEmpty ? parts[0].trim() : '';
            final teacherPart = parts.length > 1
                ? parts.sublist(1).join(' ').trim()
                : '';
            if (coursePart.isNotEmpty && uuidRe.hasMatch(coursePart)) {
              final found = _coursesForSelectedClass.firstWhere(
                (cc) => (cc['id']?.toString() ?? '') == coursePart,
                orElse: () => <String, dynamic>{},
              );
              if (found.isEmpty) missingCourseIds.add(coursePart);
            }
            if (teacherPart.isNotEmpty && uuidRe.hasMatch(teacherPart)) {
              final found = _teachers.firstWhere(
                (t) => (t['id']?.toString() ?? '') == teacherPart,
                orElse: () => <String, dynamic>{},
              );
              if (found.isEmpty) missingTeacherIds.add(teacherPart);
            }
          } catch (_) {}
        }
      }

      // Batch query courses
      if (missingCourseIds.isNotEmpty) {
        try {
          // use repository-style 'filter' with 'in' to match other hooks in the project
          final dynamic raw = await svc.supabase
              .from('courses')
              .select()
              .filter('id', 'in', missingCourseIds.toList());
          dynamic data;
          if (raw is Map && raw.containsKey('data')) {
            data = raw['data'];
          } else {
            data = raw;
          }
          if (data is List && data.isNotEmpty) {
            final added = data.map<Map<String, dynamic>>((r) {
              final name =
                  (r['course_name'] ??
                          r['title'] ??
                          r['course_code'] ??
                          r['name'] ??
                          r['id'])
                      ?.toString() ??
                  '';
              return {
                'id': r['id']?.toString() ?? name,
                'name': name,
                'raw': r,
              };
            }).toList();
            // merge into courses cache (avoid duplicates)
            final existingIds = _coursesForSelectedClass
                .map((e) => (e['id']?.toString() ?? ''))
                .toSet();
            for (final a in added) {
              if (!existingIds.contains(a['id'])) {
                _coursesForSelectedClass.add(a);
              }
            }
          }
        } catch (e) {
          debugPrint('resolveMissingNamesFromGrid: courses query failed: $e');
        }
      }

      // Batch query teachers
      if (missingTeacherIds.isNotEmpty) {
        try {
          // use 'filter' with 'in' to fetch multiple teachers by id
          final dynamic raw = await svc.supabase
              .from('teachers')
              .select()
              .filter('id', 'in', missingTeacherIds.toList());
          dynamic data;
          if (raw is Map && raw.containsKey('data')) {
            data = raw['data'];
          } else {
            data = raw;
          }
          if (data is List && data.isNotEmpty) {
            final added = data.map<Map<String, dynamic>>((r) {
              final name =
                  (r['teacher_name'] ??
                          r['name'] ??
                          r['full_name'] ??
                          r['username'] ??
                          r['id'])
                      ?.toString() ??
                  '';
              return {
                'id': r['id']?.toString() ?? name,
                'name': name,
                'raw': r,
              };
            }).toList();
            final existingIds = _teachers
                .map((e) => (e['id']?.toString() ?? ''))
                .toSet();
            for (final a in added) {
              if (!existingIds.contains(a['id'])) _teachers.add(a);
            }
          }
        } catch (e) {
          debugPrint('resolveMissingNamesFromGrid: teachers query failed: $e');
        }
      }

      if (missingCourseIds.isNotEmpty || missingTeacherIds.isNotEmpty) {
        if (mounted) setState(() {});
      }
    } catch (e) {
      debugPrint('resolveMissingNamesFromGrid error: $e');
    }
  }

  List<TimetableSlot> getFilteredSlotsFromGrid() {
    final grid = _suppressOldGrid ? null : currentTimetable;
    if (grid == null) return [];
    final periodsForClass = currentPeriods;
    var list = _slotsFromGrid(grid, periodsForClass);

    if (selectedLecturer != null &&
        selectedLecturer!.trim().isNotEmpty &&
        selectedLecturer != 'NONE' &&
        selectedLecturer != 'All lecturers') {
      // selectedLecturer now typically holds the teacher id; resolve to name
      String key = selectedLecturer!.toLowerCase().trim();
      try {
        final found = _teachers.firstWhere(
          (t) => (t['id']?.toString() ?? '') == selectedLecturer!,
          orElse: () => <String, dynamic>{},
        );
        if (found.isNotEmpty) {
          final n = (found['name']?.toString() ?? '').trim();
          if (n.isNotEmpty) key = n.toLowerCase();
        }
      } catch (_) {}
      list = list.where((s) => s.lecturer.toLowerCase().contains(key)).toList();
    }
    if (searchText.trim().isNotEmpty) {
      final q = searchText.toLowerCase().trim();
      list = list.where((s) {
        return s.course.toLowerCase().contains(q) ||
            s.lecturer.toLowerCase().contains(q) ||
            s.className.toLowerCase().contains(q) ||
            s.department.toLowerCase().contains(q) ||
            s.day.toLowerCase().contains(q) ||
            s.periodLabel.toLowerCase().contains(q);
      }).toList();
    }
    final daysOrder = ['Sat', 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
    list.sort((a, b) {
      final ai = daysOrder.indexOf(a.day);
      final bi = daysOrder.indexOf(b.day);
      if (ai != bi) return ai.compareTo(bi);
      final pi = periodsForClass.indexOf(a.periodLabel);
      final pj = periodsForClass.indexOf(b.periodLabel);
      return pi.compareTo(pj);
    });
    return list;
  }

  // -------------------- UI (render) --------------------

  @override
  Widget build(BuildContext context) {
    final grid = currentTimetable;
    final periodsForClass = currentPeriods;
    final canEdit = grid != null;
    final canDelete =
        selectedDepartment != null &&
        selectedClass != null &&
        timetableData[selectedDepartment]?[selectedClass]?.isNotEmpty == true;

    // create a display grid where UUIDs (if present) are replaced by cached names
    final displayGrid = grid
        ?.map<List<String>>(
          (r) => r.map((c) => _displayForCellSync(c)).toList(),
        )
        .toList();

    // Prepare safe items and selected values for dropdowns to avoid Flutter's
    // "exactly one item with DropdownButton's value" assertion when the
    // selected value isn't present or when duplicate/empty ids exist.
    final deptItems = _departments
        .where((d) => (d['id']?.toString() ?? '').isNotEmpty)
        .map(
          (d) => DropdownMenuItem<String>(
            value: d['id']?.toString() ?? '',
            child: Text(d['name']?.toString() ?? ''),
          ),
        )
        .toList();

    final classItems = _classes
        .where((c) => (c['id']?.toString() ?? '').isNotEmpty)
        .map(
          (c) => DropdownMenuItem<String>(
            value: c['id']?.toString() ?? '',
            child: Text(c['name']?.toString() ?? ''),
          ),
        )
        .toList();

    // Build unique teacher items keyed by id to avoid duplicate DropdownMenuItem values
    final Map<String, String> teacherMap = <String, String>{};
    for (final t in _teachers) {
      try {
        final id = (t['id']?.toString() ?? '').trim();
        if (id.isEmpty) continue;
        final name = (t['name']?.toString() ?? '').trim();
        teacherMap.putIfAbsent(id, () => name.isNotEmpty ? name : id);
      } catch (_) {}
    }
    final teacherItems = teacherMap.entries
        .map(
          (e) => DropdownMenuItem<String>(value: e.key, child: Text(e.value)),
        )
        .toList();

    // Ensure unique ids in items (defensive)
    String? deptValue =
        (selectedDepartment != null &&
            deptItems.any((it) => it.value == selectedDepartment))
        ? selectedDepartment
        : null;
    String? classValue =
        (selectedClass != null &&
            classItems.any((it) => it.value == selectedClass))
        ? selectedClass
        : null;
    String? lecturerValue =
        (selectedLecturer != null &&
            teacherItems.any((it) => it.value == selectedLecturer))
        ? selectedLecturer
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF8EEF6),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 68,
        title: const Text(
          'Time Table',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        foregroundColor: Colors.black,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // subtle purple loading bar like the design
              if (_loadingDeps || _loadingClasses || _loadingTeachers)
                Container(
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: LinearProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(Colors.purple.shade400),
                    backgroundColor: Colors.transparent,
                  ),
                ),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search Time Table...',
                  hintStyle: TextStyle(color: Colors.grey[600]),
                  prefixIcon: const Icon(
                    Icons.search,
                    size: 20,
                    color: Colors.grey,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                ),
                onChanged: (v) => setState(() => searchText = v),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple.shade400,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Create Time Table'),
                    onPressed: () async {
                      String? initialDepName;
                      String? initialClassName;
                      dynamic depArg;
                      if (selectedDepartment != null) {
                        try {
                          final depMap = _departments.firstWhere(
                            (d) => d['id'] == selectedDepartment,
                            orElse: () => <String, dynamic>{},
                          );
                          if (depMap.isNotEmpty) {
                            initialDepName = (depMap['name'] as String?)
                                ?.toString();
                            depArg = depMap['id'] as String;
                          }
                        } catch (_) {
                          initialDepName = null;
                          depArg = selectedDepartment;
                        }
                      }
                      if (selectedClass != null) {
                        try {
                          final classMap = _classes.firstWhere(
                            (c) => c['id'] == selectedClass,
                            orElse: () => <String, dynamic>{},
                          );
                          if (classMap.isNotEmpty) {
                            initialClassName = (classMap['name'] as String?)
                                ?.toString();
                          }
                        } catch (_) {
                          initialClassName = null;
                        }
                      }

                      // Try to fetch any existing period structure for this
                      // class from in-memory `classPeriods` cache first. If
                      // missing, ask the service for a persisted per-class
                      // period configuration (`class_period_configs`) so the
                      // UI auto-loads previous configurations.
                      List<String>? existingLabels;
                      if (selectedDepartment != null &&
                          selectedClass != null &&
                          classPeriods[selectedDepartment!] != null &&
                          classPeriods[selectedDepartment!]![selectedClass!] !=
                              null) {
                        existingLabels =
                            classPeriods[selectedDepartment!]![selectedClass!];
                      } else if (selectedClass != null) {
                        try {
                          final cfg = await svc.getPeriodConfiguration(
                            selectedClass!,
                          );
                          if (cfg != null && cfg.isNotEmpty) {
                            existingLabels = cfg;
                          }
                        } catch (_) {}
                        // Fallback: if no dedicated class_period_configs entry,
                        // try to read any existing timetable row for this class
                        // and use its `periods` field if present. This helps when
                        // older timetables stored periods inside the timetable
                        // document but the class_period_configs table is missing
                        // or wasn't used.
                        if (existingLabels == null || existingLabels.isEmpty) {
                          try {
                            final rows = await svc.findTimetablesByClass(
                              selectedClass!,
                            );
                            if (rows.isNotEmpty) {
                              final r = rows.first;
                              if (r.containsKey('periods') &&
                                  r['periods'] != null) {
                                final pRaw = r['periods'];
                                if (pRaw is List && pRaw.isNotEmpty) {
                                  existingLabels = pRaw
                                      .map((e) => e.toString())
                                      .toList();
                                } else if (pRaw is String) {
                                  try {
                                    final parsed = jsonDecode(pRaw) as List;
                                    existingLabels = parsed
                                        .map((e) => e.toString())
                                        .toList();
                                  } catch (_) {}
                                }
                              }
                            }
                          } catch (_) {}
                        }
                      }

                      final payload =
                          await showDialog<CreateTimetableTimePayload>(
                            context: context,
                            builder: (_) => CreateTimetableDialog(
                              departments: _departments
                                  .map((d) => d['name'] as String)
                                  .toList(),
                              departmentClasses: {},
                              lecturers: _teachers
                                  .map((t) => t['name'] as String)
                                  .toList(),
                              days: days,
                              courses: const [],
                              initialDepartment: initialDepName,
                              initialClass: initialClassName,
                              preconfiguredLabels: existingLabels,
                              departmentArg: depArg,
                            ),
                          );

                      if (payload == null) return;
                      // If the dialog returned a periods override, persist it
                      // as the canonical per-class configuration so it will
                      // be auto-loaded next time (and used by the UI).
                      try {
                        if (payload.periodsOverride != null &&
                            payload.periodsOverride!.isNotEmpty) {
                          // compute spans for storage
                          final spansForClass = _tryComputeSpansFromLabels(
                            payload.periodsOverride!,
                          );
                          if (selectedClass != null) {
                            await svc.createPeriodConfiguration(
                              selectedClass!,
                              selectedDepartment ?? '',
                              payload.periodsOverride!,
                              spansForClass,
                            );
                            // also keep in-memory cache in sync
                            final depKey =
                                selectedDepartment ?? selectedDepartment ?? '';
                            classPeriods.putIfAbsent(depKey, () => {});
                            classPeriods[depKey]![selectedClass!] =
                                List<String>.from(payload.periodsOverride!);
                            spans.putIfAbsent(depKey, () => {});
                            spans[depKey]![selectedClass!] = spansForClass;
                          }
                        }
                      } catch (e, st) {
                        debugPrint(
                          'Error saving period configuration: $e\n$st',
                        );
                      }

                      await _applyCreatePayload(payload);
                    },
                  ),
                  const SizedBox(width: 8),
                  // Reload button (reload timetable for selected dept/class)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.purple.shade700,
                      side: BorderSide(color: Colors.purple.shade100),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Reload'),
                    onPressed: () async {
                      await _reloadTimetable();
                    },
                  ),
                  Row(
                    children: [
                      SizedBox(
                        width: 100,
                        height: 36,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          onPressed: !canEdit
                              ? null
                              : () => setState(
                                  () => editingEnabled = !editingEnabled,
                                ),
                          child: Text(
                            editingEnabled ? "Done" : "Edit",
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 100,
                        height: 36,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          onPressed: selectedClass == null
                              ? null
                              : () async {
                                  final classDisplayName =
                                      await _resolveClassDisplayName(
                                        selectedClass!,
                                      );
                                  final confirmDelete = await showDialog<bool>(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Delete Timetable'),
                                      content: Text(
                                        'Are you sure you want to delete the timetable for class "$classDisplayName"?',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirmDelete == true) {
                                    _deleteTimetable(deleteEntireClass: true);
                                  }
                                },
                          child: const Text(
                            "Delete",
                            style: TextStyle(fontSize: 15, color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Export PDF',
                        onPressed: canDelete ? _exportPdfFlow : null,
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    // Department dropdown
                    Container(
                      constraints: const BoxConstraints(
                        minWidth: 130,
                        maxWidth: 240,
                      ),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          isDense: true,
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            hint: _loadingDeps
                                ? const Text('Loading...')
                                : const Text('Select Department'),
                            isExpanded: true,
                            value: deptValue,
                            items: deptItems,
                            onChanged: (v) async {
                              setState(() {
                                selectedDepartment = v;
                                selectedClass = null;
                                _classes = [];
                              });

                              dynamic loaderArg = v;
                              if (v != null) loaderArg = v;
                              if (loaderArg != null) {
                                await _loadClassesForDepartment(loaderArg);
                              }
                              await _handleSelectionChangeSafe();
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Class dropdown
                    Container(
                      constraints: const BoxConstraints(
                        minWidth: 130,
                        maxWidth: 240,
                      ),
                      child: InputDecorator(
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          isDense: true,
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            hint: _loadingClasses
                                ? const Text('Loading...')
                                : const Text('Select Class'),
                            isExpanded: true,
                            value: classValue,
                            items: classItems,
                            onChanged: (v) async {
                              setState(() {
                                selectedClass = v;
                                // clear course cache so we reload for the new class
                                _coursesForSelectedClass = [];
                                // hide any previously rendered grid while we load the new one
                                _suppressOldGrid = true;
                              });
                              try {
                                // proactively load courses for the newly selected class
                                if (v != null) await _loadCoursesForClass(v);
                                // refresh teacher cache as well (ensures names resolve)
                                await _loadTeachers();
                                await _handleSelectionChangeSafe();
                              } catch (err, st) {
                                debugPrint(
                                  'Error in selection change after class select: $err\n$st',
                                );
                              } finally {
                                if (mounted) {
                                  // Only clear suppression here if we're not in the middle
                                  // of a timetable load; _loadTimetableDoc controls the
                                  // suppression when it is running.
                                  if (!_loadingTimetable) {
                                    setState(() => _suppressOldGrid = false);
                                    // Extra post-frame rebuild to ensure freshly-loaded
                                    // courses/teachers and timetable entries are used
                                    // by the synchronous render logic immediately.
                                    try {
                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            if (mounted) setState(() {});
                                          });
                                    } catch (_) {}
                                  }
                                }
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Lecturer dropdown + quick "load by lecturer" action
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          constraints: const BoxConstraints(
                            minWidth: 130,
                            maxWidth: 240,
                          ),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              isDense: true,
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                hint: _loadingTeachers
                                    ? const Text('Loading...')
                                    : const Text('select Lecturer'),
                                isExpanded: true,
                                value: lecturerValue,
                                items: teacherItems,
                                onChanged: (v) async {
                                  // Immediately set selection and enter the
                                  // teacher-loading state so the UI doesn't
                                  // render any intermediate timetable grid.
                                  setState(() {
                                    selectedLecturer = v;
                                    _suppressOldGrid = true;
                                    _loadingTeacherSchedule = true;
                                    _teacherSchedule = [];
                                  });

                                  if (v == null ||
                                      v.toString().trim().isEmpty) {
                                    // Nothing to load; clear loading/suppression.
                                    if (mounted) {
                                      setState(() {
                                        _loadingTeacherSchedule = false;
                                        _suppressOldGrid = false;
                                      });
                                    }
                                    return;
                                  }

                                  try {
                                    // v is teacher id (UUID) when available or name otherwise
                                    final results = await svc
                                        .findTimetablesByTeacher(
                                          v.toString().trim(),
                                        );
                                    if (results.isEmpty) {
                                      // No schedule for this teacher — clear
                                      // loading state and restore the main grid.
                                      if (mounted) {
                                        setState(() {
                                          _loadingTeacherSchedule = false;
                                          _suppressOldGrid = false;
                                        });
                                        ScaffoldMessenger.of(
                                          // ignore: use_build_context_synchronously
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Macalinkaas jadwal ma laha',
                                            ),
                                          ),
                                        );
                                      }
                                      return;
                                    }

                                    final doc = results.first;
                                    try {
                                      debugPrint(
                                        '[TimetablePage] findTimetablesByTeacher -> first doc=${jsonEncode(doc)}',
                                      );
                                    } catch (_) {}

                                    final depCandidate =
                                        (doc['department_id'] ??
                                                doc['department'] ??
                                                '')
                                            ?.toString() ??
                                        '';
                                    final clsCandidate =
                                        (doc['class'] ??
                                                doc['classKey'] ??
                                                doc['className'] ??
                                                '')
                                            ?.toString() ??
                                        '';

                                    await _resolveDepartmentDisplayName(
                                      depCandidate.isNotEmpty
                                          ? depCandidate
                                          : (selectedDepartment ?? ''),
                                    );
                                    await _resolveClassDisplayName(
                                      clsCandidate.isNotEmpty
                                          ? clsCandidate
                                          : (selectedClass ?? ''),
                                    );

                                    // Update selectedDepartment (prefer ids). Defer setting selectedClass
                                    // until we have loaded classes for the department to avoid
                                    // Dropdown value-not-in-items assertion.
                                    // not using selection changes here

                                    // Do not attempt to change the selected department/class
                                    // based on the teacher's timetable document; leave
                                    // the user's current selection as-is.

                                    // Do NOT change the UI-selected department or class
                                    // when loading a teacher schedule. The teacher may
                                    // have entries across multiple departments/classes
                                    // and forcing a selection change confuses the user
                                    // and can cause period/column mismatches.

                                    // Do not apply the full timetable snapshot here —
                                    // applying it will populate the main timetable grid
                                    // and cause the UI to flash the full class timetable
                                    // before the teacher-specific schedule is displayed.
                                    // We only use `doc` to resolve department/class
                                    // selection and later load the teacher schedule.
                                    // Also fetch flattened teacher schedule for UI display.
                                    // Show a loading state until we've resolved display names
                                    try {
                                      if (mounted) {
                                        setState(() {
                                          _loadingTeacherSchedule = true;
                                          _teacherSchedule = [];
                                          _suppressOldGrid = true;
                                        });
                                      }

                                      final sched = await svc
                                          .getTeacherSchedule(
                                            v.toString().trim(),
                                          );

                                      // Resolve course/class/department display names before showing.
                                      final resolved = <Map<String, dynamic>>[];
                                      for (final row in sched) {
                                        try {
                                          final cloned =
                                              Map<String, dynamic>.from(row);
                                          // Resolve course
                                          try {
                                            final rawCourse =
                                                (row['course'] ??
                                                        row['course_name'] ??
                                                        '')
                                                    .toString();
                                            if (rawCourse.isNotEmpty) {
                                              final cd = await svc
                                                  .resolveCourseDisplayName(
                                                    rawCourse,
                                                  );
                                              if (cd.isNotEmpty) {
                                                cloned['course'] = cd;
                                              }
                                            }
                                          } catch (_) {}
                                          // Resolve className
                                          try {
                                            final rawClass =
                                                (row['className'] ?? '')
                                                    .toString();
                                            if (rawClass.isNotEmpty) {
                                              final cn = await svc
                                                  .resolveClassDisplayName(
                                                    rawClass,
                                                  );
                                              if (cn.isNotEmpty) {
                                                cloned['className'] = cn;
                                              }
                                            }
                                          } catch (_) {}
                                          // Resolve department
                                          try {
                                            final rawDept =
                                                (row['department'] ?? '')
                                                    .toString();
                                            if (rawDept.isNotEmpty) {
                                              final dn = await svc
                                                  .resolveDepartmentDisplayName(
                                                    rawDept,
                                                  );
                                              if (dn.isNotEmpty) {
                                                cloned['department'] = dn;
                                              }
                                            }
                                          } catch (_) {}
                                          resolved.add(cloned);
                                        } catch (_) {}
                                      }

                                      if (mounted) {
                                        setState(() {
                                          _teacherSchedule = resolved;
                                          _loadingTeacherSchedule = false;
                                          _suppressOldGrid = true;
                                        });
                                      }
                                    } catch (e) {
                                      debugPrint(
                                        'getTeacherSchedule failed: $e',
                                      );
                                      if (mounted) {
                                        setState(() {
                                          _loadingTeacherSchedule = false;
                                          _suppressOldGrid = false;
                                        });
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Error loading teacher schedule: $e',
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                    if (mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Timetable loaded for lecturer',
                                          ),
                                        ),
                                      );
                                    }
                                  } catch (e, st) {
                                    debugPrint(
                                      'Error loading by lecturer: $e\n$st',
                                    );
                                    if (mounted) {
                                      setState(() {
                                        _loadingTeacherSchedule = false;
                                        _suppressOldGrid = false;
                                      });
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Error loading by lecturer: $e',
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // If we're currently loading the teacher schedule show a loader,
              // otherwise show the resolved schedule table when available.
              if (_loadingTeacherSchedule)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_teacherSchedule.isNotEmpty)
                Card(
                  color: Colors.white, // ensure white background per request
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columns: const [
                          DataColumn(
                            label: Text(
                              'Day',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Time',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Course',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Class',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              'Departments',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                        rows: _teacherSchedule.map((row) {
                          final dayName = (row['dayName'] ?? row['day'] ?? '')
                              .toString();
                          final time =
                              (row['time'] ??
                                      '${row['start'] ?? ''}-${row['end'] ?? ''}')
                                  .toString();
                          final course = (row['course'] ?? '').toString();
                          final className = (row['className'] ?? '').toString();
                          final dept = (row['department'] ?? '').toString();
                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  dayName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  time,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  course,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  className,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  dept,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              // If teacher schedule exists, hide the lower timetable grid (as requested).
              // Otherwise show the timetable grid as before. While a timetable
              // is loading, display a spinner so UUIDs/names aren't shown briefly.
              if (_teacherSchedule.isNotEmpty)
                const SizedBox.shrink()
              else if (_loadingTimetable)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: (grid == null)
                        ? Center(
                            child: Text(
                              'Please select Department and Class to view the timetable.',
                              style: TextStyle(color: Colors.grey.shade600),
                              textAlign: TextAlign.center,
                            ),
                          )
                        : _TimetableGrid(
                            days: days,
                            periods: periodsForClass,
                            timetable: displayGrid!,
                            editing: editingEnabled,
                            onCellTap: (d, p) => _openEditCellDialog(
                              dayIndex: d,
                              periodIndex: p,
                            ),
                          ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportPdfFlow() async {
    /// Entry point for exporting the current view to PDF. If a lecturer
    /// schedule is visible it exports that, otherwise it exports the
    /// selected class timetable.
    // If we have a teacher schedule visible, export that instead of the class timetable.
    if (_teacherSchedule.isNotEmpty) {
      await _generateTeacherSchedulePdf();
      return;
    }

    if (selectedDepartment == null || selectedClass == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select Department and Class first')),
      );
      return;
    }
    await _generatePdf(_ExportChoice.entireClass);
  }

  Future<void> _generatePdf(_ExportChoice choice) async {
    /// Generate and display a PDF for the selected class timetable.
    /// Builds a simple table with day rows and period columns and uses
    /// `_displayForCellSync` so UUIDs are shown as names when possible.
    final depDisplay = selectedDepartment != null
        ? _displayNameForDeptCached(selectedDepartment!)
        : '';
    final classDisplay = selectedClass != null
        ? _displayNameForClassCached(selectedClass!)
        : '';
    final depKey = depDisplay;
    final classKey = classDisplay;
    if (depKey.isEmpty || classKey.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Class not found')));
      return;
    }

    final pdf = pw.Document();
    final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    final periods = (classPeriods[depKey]?[classKey] ?? <String>[]);
    final grid =
        timetableData[depKey]?[classKey] ??
        List.generate(
          days.length,
          (_) => List<String>.filled(periods.length, ''),
        );
    // convert to display values using cached names (sync)
    final pdfGrid = grid
        .map<List<String>>((r) => r.map((c) => _displayForCellSync(c)).toList())
        .toList();

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.all(24),
          theme: pw.ThemeData.withFont(
            base: pw.Font.helvetica(),
            bold: pw.Font.helveticaBold(),
          ),
        ),
        build: (ctx) => [
          _pdfHeader(depKey, classKey, dateStr),
          pw.SizedBox(height: 8),
          if (periods.isEmpty)
            pw.Text(
              'No period structure configured.',
              style: pw.TextStyle(color: PdfColors.grey600),
            ),
          if (periods.isEmpty || pdfGrid.isEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 16),
              child: pw.Text(
                'No timetable data',
                style: pw.TextStyle(fontSize: 14),
              ),
            )
          else
            _pdfGridTable(periods: periods, grid: pdfGrid),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name:
          'timetable_${depKey}_${classKey}_${dateStr.replaceAll(':', '-')}.pdf',
    );
  }

  // New: generate PDF for teacher schedule (exports only teacher schedule)
  Future<void> _generateTeacherSchedulePdf() async {
    /// Create a PDF containing the flattened teacher schedule currently
    /// stored in `_teacherSchedule` and trigger a print/Save dialog.
    if (_teacherSchedule.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No teacher schedule to export')),
      );
      return;
    }
    final pdf = pw.Document();
    final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.all(24),
          theme: pw.ThemeData.withFont(
            base: pw.Font.helvetica(),
            bold: pw.Font.helveticaBold(),
          ),
        ),
        build: (ctx) => [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Teacher Schedule',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 6),
              pw.Text('Exported: $dateStr'),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Table.fromTextArray(
            headers: ['Day', 'Time', 'Course', 'Class', 'Department'],
            data: _teacherSchedule.map((row) {
              final dayName = (row['dayName'] ?? row['day'] ?? '').toString();
              final time =
                  (row['time'] ?? '${row['start'] ?? ''}-${row['end'] ?? ''}')
                      .toString();
              final course = (row['course'] ?? '').toString();
              final className = (row['className'] ?? '').toString();
              final dept = (row['department'] ?? '').toString();
              return [dayName, time, course, className, dept];
            }).toList(),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            ),
            cellStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
            ),
            cellAlignment: pw.Alignment.centerLeft,
            headerDecoration: pw.BoxDecoration(color: PdfColors.grey300),
            cellPadding: const pw.EdgeInsets.all(6),
            columnWidths: {
              0: const pw.FixedColumnWidth(60),
              1: const pw.FixedColumnWidth(80),
              2: const pw.FlexColumnWidth(),
              3: const pw.FixedColumnWidth(80),
              4: const pw.FixedColumnWidth(80),
            },
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'teacher_schedule_${dateStr.replaceAll(':', '-')}.pdf',
    );
  }

  pw.Widget _pdfHeader(String dep, String cls, String dateStr) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Class Timetable',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text('Department: $dep   Class: $cls'),
        pw.Text('Exported: $dateStr'),
      ],
    );
  }

  pw.Widget _pdfGridTable({
    required List<String> periods,
    required List<List<String>> grid,
  }) {
    /// Build a PDF table widget for a timetable `grid` with `periods`
    /// as column headers. Highlights break periods and ensures consistent
    /// column widths for readability.
    final headerColor = PdfColors.grey200;
    final breakFill = PdfColors.grey300;

    final tableHeaders = ['Day', ...periods];
    final dataRows = <List<pw.Widget>>[];

    for (int d = 0; d < days.length; d++) {
      final row = grid.length > d
          ? grid[d]
          : List<String>.filled(periods.length, '');
      final cells = <pw.Widget>[
        pw.Container(
          width: 40,
          padding: const pw.EdgeInsets.all(4),
          child: pw.Text(
            days[d],
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ),
      ];
      for (int p = 0; p < periods.length; p++) {
        final label = periods[p];
        final isBreak = label.toLowerCase().contains('break');
        final raw = p < row.length ? row[p] : '';
        final display = raw.trim().isEmpty || raw.toLowerCase() == 'break'
            ? (isBreak ? 'Break' : '')
            : raw;
        cells.add(
          pw.Container(
            padding: const pw.EdgeInsets.all(4),
            decoration: pw.BoxDecoration(
              color: isBreak ? breakFill : null,
              border: pw.Border.all(color: PdfColors.grey400, width: 0.3),
            ),
            child: pw.Text(display, style: pw.TextStyle(fontSize: 9)),
          ),
        );
      }
      dataRows.add(cells);
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.5),
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      columnWidths: {
        0: pw.FixedColumnWidth(42),
        for (int i = 1; i < tableHeaders.length; i++) i: pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: headerColor),
          children: tableHeaders
              .map(
                (h) => pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(
                    h,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 9,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        ...dataRows.map((cells) => pw.TableRow(children: cells)),
      ],
    );
  }
}

// ------- Small UI helper widgets -------
// Reuse the same grid widget from your pasted implementation:

/// Lightweight, scrollable grid widget that renders the timetable rows
/// and period columns. Supports an `editing` mode which changes the
/// visual affordances and enables tapping cells to edit via the
/// `onCellTap` callback.
class _TimetableGrid extends StatelessWidget {
  final List<String> days;
  final List<String> periods;
  final List<List<String>> timetable;
  final bool editing;
  final void Function(int dayIndex, int periodIndex)? onCellTap;

  const _TimetableGrid({
    required this.days,
    required this.periods,
    required this.timetable,
    required this.editing,
    this.onCellTap,
  });

  double _periodWidthFor(BoxConstraints c) {
    if (c.maxWidth <= 420) return 140;
    if (c.maxWidth <= 600) return 160;
    if (c.maxWidth <= 900) return 200;
    return 260;
  }

  @override
  Widget build(BuildContext context) {
    const double headerHeight = 50.0;
    const double dividerHeight = 1.0;

    final highlightShape = RoundedRectangleBorder(
      side: BorderSide(
        color: editing ? const Color(0xFF3B4B9B) : Colors.transparent,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final periodColWidth = _periodWidthFor(constraints);
        final dayColWidth = periodColWidth * 0.5;

        final totalWidth = dayColWidth + periodColWidth * periods.length;
        final childWidth = totalWidth > constraints.maxWidth
            ? totalWidth
            : constraints.maxWidth;

        double rowsAreaHeight =
            constraints.maxHeight - headerHeight - dividerHeight;
        if (rowsAreaHeight < 120) rowsAreaHeight = 220;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: childWidth,
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: dayColWidth,
                      height: headerHeight,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      alignment: Alignment.centerLeft,
                      child: const Text(
                        'Day',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    ...periods.map((p) {
                      final isBreak = p.toLowerCase().contains('break');
                      return Container(
                        width: periodColWidth,
                        height: headerHeight,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(color: Colors.grey.shade300),
                          ),
                          color: isBreak ? Colors.grey.shade100 : null,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          p,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }),
                  ],
                ),
                const Divider(height: dividerHeight),
                SizedBox(
                  height: rowsAreaHeight,
                  child: ListView.builder(
                    itemCount: days.length,
                    itemBuilder: (context, rowIdx) {
                      final row = rowIdx < timetable.length
                          ? timetable[rowIdx]
                          : List<String>.filled(
                              periods.length,
                              '',
                              growable: true,
                            );
                      return Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: dayColWidth,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 12,
                                ),
                                child: Text(
                                  days[rowIdx],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              ...List.generate(periods.length, (colIdx) {
                                final cell = (colIdx < row.length)
                                    ? row[colIdx]
                                    : '';
                                final isBreak = periods[colIdx]
                                    .toLowerCase()
                                    .contains('break');
                                final tappable =
                                    editing && !isBreak && onCellTap != null;

                                Widget content = cell.trim().isEmpty
                                    ? (editing && !isBreak
                                          ? Opacity(
                                              opacity: 0.5,
                                              child: Text(
                                                'Tap to add',
                                                style: TextStyle(
                                                  fontStyle: FontStyle.italic,
                                                  color: Colors.grey.shade600,
                                                  fontSize: 12,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            )
                                          : const SizedBox.shrink())
                                    : Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            cell.split('\n').first,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          if (cell.split('\n').length > 1)
                                            Text(
                                              cell
                                                  .split('\n')
                                                  .skip(1)
                                                  .join(' — '),
                                              style: const TextStyle(
                                                color: Colors.black87,
                                                fontSize: 12,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                        ],
                                      );

                                return InkWell(
                                  onTap: tappable
                                      ? () => onCellTap!(rowIdx, colIdx)
                                      : null,
                                  child: Container(
                                    width: periodColWidth,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        left: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      color: isBreak
                                          ? Colors.grey.shade100
                                          : null,
                                      boxShadow: (editing && !isBreak)
                                          ? [
                                              BoxShadow(
                                                color: Colors.blue.withOpacity(
                                                  0.05,
                                                ),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    foregroundDecoration: (editing && !isBreak)
                                        ? ShapeDecoration(shape: highlightShape)
                                        : null,
                                    child: content,
                                  ),
                                );
                              }),
                            ],
                          ),
                          const Divider(height: 1),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// -------------------- Small types --------------------

enum _ExportChoice { entireClass }
