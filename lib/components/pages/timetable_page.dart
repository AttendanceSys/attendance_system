// TimetablePage — full updated implementation
// - Reads/writes timetables using "<department display name>_<class display name>" document ids.
// - Resolves display names from department/class caches or fetches docs as fallback.
// - Loads classes and class courses similar to CreateTimetableDialog.
// - Robust lookup of in-memory cache under multiple aliases so UI selection (ids or names) finds loaded data.
// - Safe cell editing that avoids null-derefs and persists edits to Firestore.
// - Replace your existing lib/components/pages/timetable_page.dart with this file.

import 'dart:convert';

// TimetablePage — full updated implementation
// - Reads/writes timetables using "<department display name>_<class display name>" document ids.
// - Resolves display names from department/class caches or fetches docs as fallback.
// - Loads classes and class courses similar to CreateTimetableDialog.
// - Robust lookup of in-memory cache under multiple aliases so UI selection (ids or names) finds loaded data.
// - Safe cell editing that avoids null-derefs and persists edits to Firestore.
// - Replace your existing lib/components/pages/timetable_page.dart with this file.

import 'dart:convert';
import '../cards/searchBar.dart';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import 'create_timetable_dialog.dart';
import 'create_timetable_cell_edit_dialog.dart';
import '../../services/session.dart';

class TimetableSlot {
  final String day;
  final String periodLabel;
  final String course;
  final String className;
  final String department;
  final String lecturer;

  const TimetableSlot({
    required this.day,
    required this.periodLabel,
    required this.course,
    required this.className,
    required this.department,
    required this.lecturer,
  });
}

class TimetablePage extends StatefulWidget {
  const TimetablePage({super.key});

  @override
  State<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage> {
  String searchText = '';

  // Dropdown raw values (ids)
  String? selectedDepartment;
  String? selectedClass;
  String? selectedLecturer;
  String? selectedCourse;

  bool editingEnabled = false;
  _UndoState? _lastUndo;

  final List<String> seedPeriods = const [
    "7:30 - 9:20",
    "9:20 - 11:10",
    "11:10 - 11:40 (Break)",
    "11:40 - 1:30",
  ];

  // caches keyed by display names (and aliases are added on load)
  final Map<String, Map<String, List<List<String>>>> timetableData = {};
  final Map<String, Map<String, List<String>>> classPeriods = {};
  final Map<String, Map<String, List<Map<String, int>>>> spans = {};

  // dropdown/data caches
  List<Map<String, dynamic>> _departments = []; // {id, name, ref}
  List<Map<String, dynamic>> _classes = []; // {id, name, raw, ref}
  List<Map<String, dynamic>> _teachers = []; // {id, name}
  List<Map<String, dynamic>> _coursesForSelectedClass =
      []; // {id, course_name, raw, ref}

  bool _loadingDeps = false;
  bool _loadingClasses = false;
  bool _loadingTeachers = false;
  bool _loadingCourses = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CollectionReference timetablesCollection = FirebaseFirestore.instance
      .collection('timetables');

  List<String> get days => ["Sat", "Sun", "Mon", "Tue", "Wed", "Thu"];

  @override
  void initState() {
    super.initState();
    // Load departments and teachers. Teachers will be filtered by session faculty
    // when a faculty is set in Session.facultyRef.
    _loadDepartments();
    _loadTeachers();
  }

  // -------------------- Helpers --------------------

  // Sanitize display name into doc id segment (lowercase, spaces->underscore, strip unsafe)
  bool _isDepartmentActive(Map<String, dynamic> data) {
    final status = data['status'];
    if (status is bool) return status;
    if (status is String) {
      final s = status.toLowerCase();
      return s == 'active' || s == 'true';
    }
    return true;
  }

  String _sanitizeForId(String input) {
    var s = input.trim().toLowerCase();
    s = s.replaceAll(RegExp(r'\s+'), '_');
    s = s.replaceAll(RegExp(r'[^\w\-]'), '');
    return s;
  }

  String _docIdFromDisplayNames(String deptDisplay, String classDisplay) {
    final d = _sanitizeForId(deptDisplay);
    final c = _sanitizeForId(classDisplay);
    return '${d}_$c';
  }

  // Resolve department display name from cache or fetch once if needed
  Future<String> _resolveDepartmentDisplayName(String depIdOrName) async {
    final s = depIdOrName.trim();
    try {
      final found = _departments.firstWhere(
        (d) => (d['id']?.toString() ?? '') == s,
        orElse: () => <String, dynamic>{},
      );
      if (found is Map && found.isNotEmpty) {
        final n = (found['name']?.toString() ?? '').trim();
        if (n.isNotEmpty) return n;
      }
    } catch (_) {}
    if (s.isNotEmpty && !s.contains(' ') && s.length > 6) {
      try {
        final doc = await _firestore.collection('departments').doc(s).get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data() as Map<String, dynamic>;
          final name =
              (data['name'] ?? data['department_name'] ?? data['displayName'])
                  ?.toString() ??
              '';
          if (name.trim().isNotEmpty) return name.trim();
        }
      } catch (_) {}
    }
    return s;
  }

  Future<String> _resolveClassDisplayName(String classIdOrName) async {
    final s = classIdOrName.trim();
    try {
      final found = _classes.firstWhere(
        (c) => (c['id']?.toString() ?? '') == s,
        orElse: () => <String, dynamic>{},
      );
      if (found is Map && found.isNotEmpty) {
        final n = (found['name']?.toString() ?? '').trim();
        if (n.isNotEmpty) return n;
      }
    } catch (_) {}
    if (s.isNotEmpty && !s.contains(' ') && s.length > 6) {
      try {
        final doc = await _firestore.collection('classes').doc(s).get();
        if (doc.exists && doc.data() != null) {
          final data = doc.data() as Map<String, dynamic>;
          final name = (data['class_name'] ?? data['name'])?.toString() ?? '';
          if (name.trim().isNotEmpty) return name.trim();
        }
      } catch (_) {}
    }
    return s;
  }

  // Synchronous cached getters (no network)
  String _displayNameForDeptCached(String depIdOrName) {
    final s = depIdOrName.trim();
    try {
      final found = _departments.firstWhere(
        (d) => (d['id']?.toString() ?? '') == s,
        orElse: () => <String, dynamic>{},
      );
      if (found is Map && found.isNotEmpty) {
        final n = (found['name']?.toString() ?? '').trim();
        if (n.isNotEmpty) return n;
      }
    } catch (_) {}
    return s;
  }

  String _displayNameForClassCached(String classIdOrName) {
    final s = classIdOrName.trim();
    try {
      final found = _classes.firstWhere(
        (c) => (c['id']?.toString() ?? '') == s,
        orElse: () => <String, dynamic>{},
      );
      if (found is Map && found.isNotEmpty) {
        final n = (found['name']?.toString() ?? '').trim();
        if (n.isNotEmpty) return n;
      }
    } catch (_) {}
    return s;
  }

  Future<String> _docIdFromSelected(
    String depIdOrName,
    String classIdOrName,
  ) async {
    final dept = await _resolveDepartmentDisplayName(depIdOrName);
    final cls = await _resolveClassDisplayName(classIdOrName);
    return _docIdFromDisplayNames(dept, cls);
  }

  // -------------------- Dropdown & related loaders --------------------

  Future<void> _loadDepartments() async {
    setState(() => _loadingDeps = true);
    try {
      // If Session.facultyRef is set (faculty-admin), limit departments to that faculty.
      Query depQuery = _firestore.collection('departments');
      if (Session.facultyRef != null) {
        depQuery = depQuery.where('faculty_ref', isEqualTo: Session.facultyRef);
      }
      final snap = await depQuery.get();
      _departments = snap.docs
          .map((d) {
            final data = d.data() as Map<String, dynamic>;
            if (!_isDepartmentActive(data)) return null;
            final name =
                (data['name'] ??
                        data['department_name'] ??
                        data['displayName'] ??
                        data['title'] ??
                        '')
                    .toString();
            return {'id': d.id, 'name': name, 'ref': d.reference};
          })
          .whereType<Map<String, dynamic>>()
          .toList();
      _departments.sort(
        (a, b) => a['name'].toString().compareTo(b['name'].toString()),
      );

      // If the session is scoped to a faculty try to auto-select its department
      // (useful for faculty-admins). We look for a department whose ref or id
      // matches the facultyRef id.
      if (Session.facultyRef != null && _departments.isNotEmpty) {
        try {
          final candidate = _departments.firstWhere((d) {
            try {
              if (d['ref'] is DocumentReference &&
                  (d['ref'] as DocumentReference) == Session.facultyRef) {
                return true;
              }
            } catch (_) {}
            try {
              if (d['id'] == (Session.facultyRef?.id ?? '')) return true;
            } catch (_) {}
            return false;
          }, orElse: () => <String, dynamic>{});

          if (candidate is Map && candidate.isNotEmpty) {
            // set selected department and load its classes automatically
            setState(() {
              selectedDepartment = candidate['id'] as String?;
              selectedClass = null;
              _classes = [];
              // clear previous lecturer selection when department changes
              selectedLecturer = null;
              _teachers = [];
            });
            dynamic loaderArg = candidate['ref'] is DocumentReference
                ? candidate['ref']
                : candidate['id'];
            await _loadClassesForDepartment(loaderArg);
            await _loadTeachers();
            await _handleSelectionChangeSafe();
          }
        } catch (_) {}
      }
    } catch (e, st) {
      debugPrint('loadDepartments error: $e\n$st');
    } finally {
      setState(() => _loadingDeps = false);
    }
  }

  Future<void> _loadTeachers() async {
    // Populate lecturers from timetables of the selected department.
    if (selectedDepartment == null) {
      setState(() {
        _teachers = [];
        _loadingTeachers = false;
      });
      return;
    }

    setState(() => _loadingTeachers = true);
    try {
      final depId = selectedDepartment!.trim();
      final depDisplay = _displayNameForDeptCached(depId);
      final Set<String> names = {};

      List<QueryDocumentSnapshot> docs = [];
      try {
        QuerySnapshot snap = await timetablesCollection
            .where('department', isEqualTo: depDisplay)
            .get();
        docs = snap.docs;
        if (docs.isEmpty) {
          snap = await timetablesCollection
              .where('department_id', isEqualTo: depId)
              .get();
          docs = snap.docs;
        }
      } catch (_) {}

      // Fallback to all timetables then client-filter if needed.
      if (docs.isEmpty) {
        try {
          final snap = await timetablesCollection.get();
          docs = snap.docs;
        } catch (_) {}
      }

      for (final d in docs) {
        final data = d.data() as Map<String, dynamic>? ?? {};
        final depCand = (data['department'] ?? data['department_id'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

        bool matchesDep;
        if (depCand.isEmpty) {
          matchesDep = true;
        } else {
          final depDisplaySan = depDisplay.toLowerCase().replaceAll(' ', '');
          final depIdSan = depId.toLowerCase().replaceAll(' ', '');
          final depCandSan = depCand.replaceAll(' ', '');
          matchesDep =
              depCand == depDisplay.toLowerCase() ||
              depCand == depId.toLowerCase() ||
              depCandSan == depDisplaySan ||
              depCandSan == depIdSan ||
              depCandSan.contains(depDisplaySan) ||
              depDisplaySan.contains(depCandSan);
        }
        if (!matchesDep) continue;

        final gridMeta = data['grid_meta'];
        final gridRaw = data['grid'];

        if (gridMeta is List && gridMeta.isNotEmpty) {
          for (final rowObj in gridMeta) {
            if (rowObj is Map && rowObj['cells'] is List) {
              for (final cell in (rowObj['cells'] as List)) {
                if (cell is Map && cell['lecturer'] != null) {
                  final name = cell['lecturer'].toString().trim();
                  if (name.isNotEmpty) names.add(name);
                }
              }
            }
          }
        } else if (gridRaw is List && gridRaw.isNotEmpty) {
          for (final rowObj in gridRaw) {
            List<dynamic> cells = [];
            if (rowObj is Map && rowObj['cells'] is List) {
              cells = rowObj['cells'] as List;
            } else if (rowObj is List) {
              cells = rowObj;
            }
            for (final cell in cells) {
              final raw = cell?.toString() ?? '';
              if (raw.isEmpty) continue;
              final parts = raw.split('\n');
              if (parts.length > 1) {
                final lect = parts.sublist(1).join(' ').trim();
                if (lect.isNotEmpty) names.add(lect);
              }
            }
          }
        }
      }

      final list = names.toList()..sort((a, b) => a.compareTo(b));
      _teachers = list.map((n) => {'id': n, 'name': n}).toList();
    } catch (e, st) {
      debugPrint('loadTeachers error: $e\n$st');
      setState(() => _teachers = []);
    } finally {
      setState(() => _loadingTeachers = false);
    }
  }

  Future<void> _loadClassesForDepartment(dynamic depArg) async {
    if (!mounted) return;
    setState(() {
      _loadingClasses = true;
      _classes = [];
      _coursesForSelectedClass = [];
      selectedClass = null;
    });

    try {
      Query query = _firestore.collection('classes');
      final String? depIdStr = depArg == null ? null : depArg.toString();
      final String? depRefId = depArg is DocumentReference ? depArg.id : null;
      final String? depRefPath = depArg is DocumentReference
          ? depArg.path
          : null;
      if (depArg is DocumentReference) {
        query = query.where('department', isEqualTo: depArg);
      } else if (depIdStr != null) {
        query = query.where('department_id', isEqualTo: depIdStr);
      }

      QuerySnapshot snap;
      try {
        snap = await query.get();
      } catch (_) {
        snap = await _firestore.collection('classes').get();
      }

      List<QueryDocumentSnapshot> docs = snap.docs;

      // If nothing matched by server-side filters, pull all and client-filter with relaxed matching.
      if (docs.isEmpty && depIdStr != null) {
        try {
          final allSnap = await _firestore.collection('classes').get();
          docs = allSnap.docs;
        } catch (_) {}
      }

      final depDisplay = depIdStr != null
          ? _displayNameForDeptCached(depIdStr)
          : '';

      String norm(String v) =>
          v.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      bool matchesDep(Map<String, dynamic> data) {
        if (depIdStr == null) return true;
        final targets = <String>{
          norm(depIdStr),
          norm(depDisplay),
          norm(_sanitizeForId(depIdStr)),
          norm(_sanitizeForId(depDisplay)),
          if (depRefId != null) norm(depRefId),
          if (depRefPath != null) norm(depRefPath),
        }..removeWhere((e) => e.isEmpty);

        final candidates = <String>{};
        for (final key in [
          'department',
          'department_id',
          'department_ref',
          'departmentName',
          'department_name',
          'dept',
          'dept_id',
          'dep_id',
          'dep_ref',
        ]) {
          final v = data[key];
          if (v == null) continue;
          candidates.add(v.toString());
        }

        for (final c in candidates) {
          final n = norm(c);
          if (targets.contains(n)) return true;
          for (final t in targets) {
            if (n.contains(t) || t.contains(n)) return true;
          }
        }
        return targets.isEmpty;
      }

      final classes = docs
          .map((d) {
            final data = d.data() as Map<String, dynamic>? ?? {};
            if (!matchesDep(data)) return null;
            final name = (data['class_name'] ?? data['name'] ?? d.id)
                .toString()
                .trim();
            return {
              'id': d.id,
              'name': name.isNotEmpty ? name : d.id,
              'raw': data,
              'ref': d.reference,
            };
          })
          .whereType<Map<String, dynamic>>()
          .toList();

      classes.sort(
        (a, b) => a['name'].toString().compareTo(b['name'].toString()),
      );

      if (mounted) setState(() => _classes = classes);
    } catch (e, st) {
      debugPrint('loadClassesForDepartment error: $e\n$st');
      if (mounted) setState(() => _classes = []);
    } finally {
      if (mounted) setState(() => _loadingClasses = false);
    }
  }

  Future<void> _loadCoursesForClass(dynamic classArg) async {
    if (!mounted) return;
    setState(() {
      _loadingCourses = true;
      _coursesForSelectedClass = [];
    });

    try {
      Query query = _firestore.collection('courses');
      if (classArg is DocumentReference) {
        query = query.where('class', isEqualTo: classArg);
      } else if (classArg != null) {
        final clsId = classArg.toString();
        query = query.where('class_id', isEqualTo: clsId);
      }

      QuerySnapshot snap;
      try {
        snap = await query.get();
      } catch (_) {
        snap = await _firestore.collection('courses').get();
      }

      var courses = snap.docs.map((d) {
        final data = d.data() as Map<String, dynamic>? ?? {};
        final name = (data['course_name'] ?? data['name'] ?? d.id)
            .toString()
            .trim();
        return {
          'id': d.id,
          'course_name': name.isNotEmpty ? name : d.id,
          'raw': data,
          'ref': d.reference,
        };
      }).toList();

      courses.sort(
        (a, b) =>
            a['course_name'].toString().compareTo(b['course_name'].toString()),
      );

      if (mounted) setState(() => _coursesForSelectedClass = courses);
    } catch (e, st) {
      debugPrint('loadCoursesForClass error: $e\n$st');
      if (mounted) setState(() => _coursesForSelectedClass = []);
    } finally {
      if (mounted) setState(() => _loadingCourses = false);
    }
  }

  Future<void> _loadTimetableDoc() async {
    if (selectedDepartment == null || selectedClass == null) return;

    final depId = selectedDepartment!.trim();
    final clsId = selectedClass!.trim();
    final docId = await _docIdFromSelected(depId, clsId);
    final deptDisplay = await _resolveDepartmentDisplayName(depId);
    final classDisplay = await _resolveClassDisplayName(clsId);

    try {
      final docRef = timetablesCollection.doc(docId);
      final doc = await docRef.get();

      if (doc.exists && doc.data() != null) {
        await _applyTimetableDataFromSnapshot(
          doc.data() as Map<String, dynamic>,
          deptDisplay,
          classDisplay,
        );
      } else {
        Query query = timetablesCollection
            .where('department', isEqualTo: deptDisplay)
            .where('className', isEqualTo: classDisplay)
            .limit(1);
        QuerySnapshot qSnap = await query.get();

        if (qSnap.docs.isEmpty) {
          query = timetablesCollection
              .where('department', isEqualTo: deptDisplay)
              .where('classKey', isEqualTo: clsId)
              .limit(1);
          qSnap = await query.get();
        }
        if (qSnap.docs.isEmpty) {
          query = timetablesCollection
              .where('department_id', isEqualTo: depId)
              .where('classKey', isEqualTo: clsId)
              .limit(1);
          qSnap = await query.get();
        }
        if (qSnap.docs.isEmpty) {
          query = timetablesCollection
              .where('department_id', isEqualTo: depId)
              .where('className', isEqualTo: classDisplay)
              .limit(1);
          qSnap = await query.get();
        }

        if (qSnap.docs.isNotEmpty) {
          final doc = qSnap.docs.first;
          debugPrint('Found timetable document by query: ${doc.id}');
          final data = doc.data() as Map<String, dynamic>;
          final depFromDoc = (data['department'] as String?) ?? deptDisplay;
          final classFromDoc = (data['className'] as String?) ?? classDisplay;
          await _applyTimetableDataFromSnapshot(
            doc.data() as Map<String, dynamic>,
            depFromDoc,
            classFromDoc,
          );
        } else {
          // Fallback: scan all timetables with relaxed matching so class selection still loads.
          DocumentSnapshot? matchedDoc;
          try {
            final allSnap = await timetablesCollection.get();
            String norm(String v) =>
                v.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

            bool matchesAny(Set<String> targets, String candidate) {
              final c = norm(candidate);
              if (c.isEmpty) return false;
              for (final t in targets) {
                if (c == t) return true;
                if (c.contains(t) || t.contains(c)) return true;
              }
              return false;
            }

            final depTargets = <String>{
              norm(depId),
              norm(deptDisplay),
              norm(_sanitizeForId(depId)),
              norm(_sanitizeForId(deptDisplay)),
            }..removeWhere((e) => e.isEmpty);

            final classTargets = <String>{
              norm(clsId),
              norm(classDisplay),
              norm(_sanitizeForId(clsId)),
              norm(_sanitizeForId(classDisplay)),
            }..removeWhere((e) => e.isEmpty);

            for (final d in allSnap.docs) {
              final data = d.data() as Map<String, dynamic>? ?? {};
              final depCand =
                  (data['department'] ?? data['department_id'] ?? '')
                      .toString();
              if (depTargets.isNotEmpty &&
                  depCand.toString().trim().isNotEmpty &&
                  !matchesAny(depTargets, depCand)) {
                continue;
              }

              final classCand = (data['className'] ?? data['classKey'] ?? '')
                  .toString();
              final idParts = d.id.split('_');
              final altClass = idParts.length >= 2
                  ? idParts.sublist(1).join('_')
                  : '';
              final classCandidates = <String>{classCand, altClass}
                ..removeWhere((e) => e.trim().isEmpty);

              bool classMatch = false;
              for (final c in classCandidates) {
                if (matchesAny(classTargets, c)) {
                  classMatch = true;
                  break;
                }
              }
              if (!classMatch) continue;

              matchedDoc = d;
              break;
            }
          } catch (_) {}

          if (matchedDoc != null && matchedDoc.data() != null) {
            debugPrint('Found timetable via relaxed match: ${matchedDoc.id}');
            final data = matchedDoc.data() as Map<String, dynamic>;
            final depFromDoc = (data['department'] as String?) ?? deptDisplay;
            final classFromDoc = (data['className'] as String?) ?? classDisplay;
            await _applyTimetableDataFromSnapshot(
              data,
              depFromDoc,
              classFromDoc,
            );
          } else {
            // nothing found — show message only
            debugPrint('No timetable found in timetables for $docId');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No timetable found in this class')),
            );
          }
        }
      }
    } catch (e, st) {
      debugPrint('Error loading timetable doc (timetables): $e\n$st');
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading timetable: $e')));
    }

    // Load courses for the selected class for edit dialog dropdowns
    try {
      if (_classes.isNotEmpty) {
        final classMap = _classes.firstWhere(
          (c) => (c['id']?.toString() ?? '') == clsId,
          orElse: () => <String, dynamic>{},
        );
        if (classMap is Map && classMap.isNotEmpty) {
          await _loadCoursesForClass(classMap['id']);
        } else {
          await _loadCoursesForClass(classDisplay);
        }
      } else {
        await _loadCoursesForClass(clsId);
      }
    } catch (_) {}
  }

  Future<void> _applyTimetableDataFromSnapshot(
    Map<String, dynamic> data,
    String depDisplayName,
    String classDisplayName,
  ) async {
    // Parse periods
    List<String> periods;
    try {
      final rawPeriods = data['periods'];
      if (rawPeriods is List)
        periods = rawPeriods.map((e) => e?.toString() ?? '').toList();
      else
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
        grid = (gridRaw as List)
            .map<List<String>>(
              (r) => (r as List).map((c) => c?.toString() ?? '').toList(),
            )
            .toList();
      } else if (gridRaw is List && gridRaw.every((e) => e is String)) {
        try {
          grid = (gridRaw as List).map<List<String>>((s) {
            final parsed = jsonDecode(s as String);
            return (parsed as List).map((c) => c.toString()).toList();
          }).toList();
        } catch (_) {}
      }
    } catch (e, st) {
      debugPrint('Grid parse error: $e\n$st');
    }

    // Prepare aliases and store under multiple keys
    final depKeyDisplay = depDisplayName;
    final classKeyDisplay = classDisplayName;
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

    debugPrint(
      'Timetable loaded for $depKeyDisplay / $classKeyDisplay (periods=${periods.length})',
    );
  }

  Future<void> _saveTimetableDocToFirestore(
    String depIdOrName,
    String classIdOrName,
  ) async {
    // Resolve display names and ensure consistent keys
    final deptDisplay = await _resolveDepartmentDisplayName(depIdOrName);
    final classDisplay = await _resolveClassDisplayName(classIdOrName);
    final sanitizedDocId = _docIdFromDisplayNames(deptDisplay, classDisplay);

    // Check for existing document
    String docId = sanitizedDocId;
    final query = timetablesCollection
        .where('department', isEqualTo: deptDisplay)
        .where('className', isEqualTo: classDisplay)
        .limit(1);
    final querySnapshot = await query.get();

    if (querySnapshot.docs.isNotEmpty) {
      docId = querySnapshot.docs.first.id; // Use existing document ID
      debugPrint('Existing document found: $docId');
    } else {
      debugPrint(
        'No existing document found, using sanitized docId: $sanitizedDocId',
      );
    }

    final ref = timetablesCollection.doc(docId);

    final depKey =
        _findKeyIgnoreCase(timetableData, deptDisplay) ?? deptDisplay;
    final clsKey =
        _findKeyIgnoreCase(timetableData[depKey] ?? {}, classDisplay) ??
        classDisplay;

    // Debugging: Log resolved keys and document ID
    debugPrint(
      'Saving timetable: docId=$docId, depKey=$depKey, clsKey=$clsKey',
    );

    final periods =
        classPeriods[depKey]?[clsKey] ?? List<String>.from(seedPeriods);
    final grid =
        timetableData[depKey]?[clsKey] ??
        List.generate(
          days.length,
          (_) => List<String>.filled(periods.length, ''),
        );

    final gridAsMaps = <Map<String, dynamic>>[];
    final gridMetaAsMaps = <Map<String, dynamic>>[];
    for (int r = 0; r < grid.length; r++) {
      final rowCells = List<String>.from(grid[r]);
      gridAsMaps.add({'r': r, 'cells': rowCells});

      // Build per-cell meta so courses and lecturers are stored separately
      final metaCells = rowCells.map((c) {
        final parts = c.toString().split('\n');
        final course = parts.isNotEmpty ? parts[0].trim() : '';
        final lecturer = parts.length > 1
            ? parts.sublist(1).join(' ').trim()
            : '';
        return {'course': course, 'lecturer': lecturer};
      }).toList();
      gridMetaAsMaps.add({'r': r, 'cells': metaCells});
    }

    final computedSpans =
        spans[depKey]?[clsKey] ?? _tryComputeSpansFromLabels(periods);

    final data = {
      'department': deptDisplay,
      'department_id': depIdOrName,
      'classKey': classIdOrName,
      'className': classDisplay,
      'periods': periods,
      'spans': computedSpans
          .map((m) => {'start': m['start'] ?? 0, 'end': m['end'] ?? 0})
          .toList(),
      'grid': gridAsMaps,
      // grid_meta contains structured cell data: {r:..., cells:[{course,lecturer}, ...]}
      'grid_meta': gridMetaAsMaps,
      'updated_at': FieldValue.serverTimestamp(),
      'created_at': FieldValue.serverTimestamp(),
    };

    try {
      await ref.set(data, SetOptions(merge: true));
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Timetable saved')));
    } catch (e, st) {
      debugPrint('Error saving timetable: $e\n$st');
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving timetable: $e')));
    }
  }

  Future<void> _applyCreatePayload(CreateTimetableTimePayload payload) async {
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

    final batch = FirebaseFirestore.instance.batch();

    try {
      for (final entry in grouped.entries) {
        final docId = entry.key;
        final ref = timetablesCollection.doc(docId);
        final snap = await ref.get();

        List<String> periods = [];
        List<Map<String, int>> docSpans = [];
        List<List<String>> grid = [];

        if (snap.exists && snap.data() != null) {
          final d = snap.data()! as Map<String, dynamic>;
          periods =
              (d['periods'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              List<String>.from(seedPeriods);
          final spansRaw = (d['spans'] as List<dynamic>?) ?? [];
          docSpans = spansRaw
              .map(
                (e) => {
                  'start': (e['start'] as num?)?.toInt() ?? 0,
                  'end': (e['end'] as num?)?.toInt() ?? 0,
                },
              )
              .toList();

          final gridRaw = (d['grid'] as List<dynamic>?) ?? [];
          if (gridRaw.isNotEmpty &&
              gridRaw.first is Map &&
              gridRaw.first.containsKey('cells')) {
            grid = List.generate(
              days.length,
              (_) => List<String>.filled(periods.length, '', growable: true),
            );
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
            grid =
                (d['grid'] as List<dynamic>?)
                    ?.map<List<String>>(
                      (r) => (r as List).map((c) => c.toString()).toList(),
                    )
                    .toList() ??
                List.generate(
                  days.length,
                  (_) =>
                      List<String>.filled(periods.length, '', growable: true),
                );
          }
        } else {
          periods = entry.value.isNotEmpty
              ? (payload.periodsOverride ?? List<String>.from(seedPeriods))
              : List<String>.from(seedPeriods);
          docSpans = _tryComputeSpansFromLabels(periods);
          grid = List.generate(
            days.length,
            (_) => List<String>.filled(periods.length, '', growable: true),
          );
        }

        if (payload.periodsOverride != null &&
            payload.periodsOverride!.isNotEmpty) {
          final newPeriods = List<String>.from(payload.periodsOverride!);
          final oldSpans = List<Map<String, int>>.from(docSpans);
          final newSpans = _tryComputeSpansFromLabels(newPeriods);
          final newGrid = List<List<String>>.generate(
            days.length,
            (_) => List<String>.filled(newPeriods.length, '', growable: true),
          );

          for (int r = 0; r < grid.length; r++) {
            final oldRow = grid[r];
            for (int oldIdx = 0; oldIdx < oldRow.length; oldIdx++) {
              final oldStart = (oldIdx < oldSpans.length)
                  ? oldSpans[oldIdx]['start']
                  : null;
              int newIdx = -1;
              if (oldStart != null) {
                newIdx = newSpans.indexWhere((s) => s['start'] == oldStart);
              }
              if (newIdx >= 0 && newIdx < newGrid[r].length) {
                newGrid[r][newIdx] = oldRow[oldIdx];
              } else if (oldIdx < newGrid[r].length) {
                newGrid[r][oldIdx] = oldRow[oldIdx];
              }
            }
          }
          periods = newPeriods;
          docSpans = newSpans;
          grid = newGrid;
        }

        for (final r in entry.value) {
          int colIndex = -1;
          if (docSpans.isNotEmpty) {
            colIndex = docSpans.indexWhere((s) => s['start'] == r.startMinutes);
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
        final gridMetaAsMaps = <Map<String, dynamic>>[];
        for (int r = 0; r < grid.length; r++) {
          final rowCells = List<String>.from(grid[r]);
          gridAsMaps.add({'r': r, 'cells': rowCells});

          final metaCells = rowCells.map((c) {
            final parts = c.toString().split('\n');
            final course = parts.isNotEmpty ? parts[0].trim() : '';
            final lecturer = parts.length > 1
                ? parts.sublist(1).join(' ').trim()
                : '';
            return {'course': course, 'lecturer': lecturer};
          }).toList();
          gridMetaAsMaps.add({'r': r, 'cells': metaCells});
        }

        final parts = entry.key.split('_');
        final depPart = parts.isNotEmpty
            ? parts[0]
            : entry.value.first.department;

        batch.set(ref, {
          'department': depPart,
          'department_id': entry.value.first.department,
          'classKey': entry.value.first.classKey,
          'className': entry.value.first.classKey,
          'periods': periods,
          'spans': docSpans
              .map((m) => {'start': m['start'], 'end': m['end']})
              .toList(),
          'grid': gridAsMaps,
          'grid_meta': gridMetaAsMaps,
          'updated_at': FieldValue.serverTimestamp(),
          'created_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      await batch.commit();
      await _loadTimetableDoc();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Timetable entries applied')),
        );
    } catch (e, st) {
      debugPrint('Error applying payload: $e\n$st');
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error applying entries: $e')));
    }
  }

  // -------------------- Helpers & UI wiring --------------------

  List<TimetableSlot> _slotsFromGrid(
    List<List<String>> grid,
    List<String> periodsForClass,
  ) {
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
        final cell = (p < row.length) ? row[p].trim() : '';
        if (cell.isEmpty) continue;
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

  List<PrefilledSession> _prefillSessionsFromCurrent() {
    final grid = currentTimetable;
    if (grid == null) return [];
    final periods = currentPeriods;
    final List<PrefilledSession> out = [];
    for (int d = 0; d < days.length; d++) {
      final row = d < grid.length
          ? grid[d]
          : List<String>.filled(periods.length, '', growable: true);
      for (int p = 0; p < periods.length; p++) {
        if (p >= row.length) continue;
        final cell = row[p].trim();
        if (cell.isEmpty) continue;
        if (cell.toLowerCase().contains('break')) continue;
        final parts = cell.split('\n');
        final course = parts.isNotEmpty ? parts[0].trim() : '';
        final lecturer = parts.length > 1
            ? parts.sublist(1).join(' ').trim()
            : '';
        out.add(
          PrefilledSession(
            dayIndex: d,
            periodLabel: periods[p],
            course: course.isNotEmpty ? course : null,
            lecturer: lecturer.isNotEmpty ? lecturer : null,
          ),
        );
      }
    }
    return out;
  }

  // Robust currentTimetable: try aliases and inspect existing keys
  List<List<String>>? get currentTimetable {
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
    final depDisplay = selectedDepartment != null
        ? _displayNameForDeptCached(selectedDepartment!)
        : null;
    final clsDisplay = selectedClass != null
        ? _displayNameForClassCached(selectedClass!)
        : null;

    List<String>? _copyPeriods(List<String>? p) =>
        p == null ? null : List<String>.from(p, growable: true);

    if (depDisplay != null && clsDisplay != null) {
      final p = classPeriods[depDisplay]?[clsDisplay];
      if (p != null && p.isNotEmpty) return _copyPeriods(p)!;
    }

    if (selectedDepartment != null && clsDisplay != null) {
      final p = classPeriods[selectedDepartment!]?[clsDisplay];
      if (p != null && p.isNotEmpty) return _copyPeriods(p)!;
    }

    if (depDisplay != null && selectedClass != null) {
      final p = classPeriods[depDisplay]?[selectedClass!];
      if (p != null && p.isNotEmpty) return _copyPeriods(p)!;
    }

    if (selectedDepartment != null && selectedClass != null) {
      final p = classPeriods[selectedDepartment!]?[selectedClass!];
      if (p != null && p.isNotEmpty) return _copyPeriods(p)!;
    }

    if (depDisplay != null && clsDisplay != null) {
      final sDep = _sanitizeForId(depDisplay);
      final sCls = _sanitizeForId(clsDisplay);
      final p = classPeriods[sDep]?[sCls];
      if (p != null && p.isNotEmpty) return _copyPeriods(p)!;
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
          if (found != null) return _copyPeriods(map[found])!;
        }
        return _copyPeriods(map.values.first)!;
      }
    }

    if (classPeriods.isNotEmpty) {
      final firstDep = classPeriods.keys.first;
      final firstMap = classPeriods[firstDep]!;
      if (firstMap.isNotEmpty) return _copyPeriods(firstMap.values.first)!;
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

  // -------------------- Selection change --------------------

  Future<void> _handleSelectionChangeSafe() async {
    try {
      await _loadTimetableDoc();
      if (mounted) setState(() => editingEnabled = false);
    } catch (e, st) {
      debugPrint('Error in _handleSelectionChangeSafe: $e\n$st');
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to load timetable.')),
        );
    }
  }

  // -------------------- Cell edit (safe) --------------------

  Future<void> _openEditCellDialog({
    required int dayIndex,
    required int periodIndex,
  }) async {
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

    List<String> _buildClassCandidates(Map classesMap) {
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
      final classCandidates = _buildClassCandidates(classesMap);
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
      debugPrint(
        'Edit cell: no grid found for selection dep="$selectedDepartment" cls="$selectedClass"',
      );
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Timetable not loaded for the selected class.'),
          ),
        );
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
        classId: selectedClass, // Pass selected class doc id
        initialCourse: initialCourse, // Existing
        initialLecturer: initialLecturer, // Existing
        courses: _coursesForSelectedClass.isNotEmpty
            ? _coursesForSelectedClass
                  .map((c) => c['course_name'] as String)
                  .toList()
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
        while (grid.length <= dayIndex)
          grid.add(
            List<String>.filled(periodsForClass.length, '', growable: true),
          );
      }
      if (periodIndex >= grid[dayIndex].length) {
        grid[dayIndex].addAll(
          List<String>.filled(periodIndex - grid[dayIndex].length + 1, ''),
        );
      }
      grid[dayIndex][periodIndex] = result.cellText!.trim();

      // Persist change into multiple aliases so future lookups succeed
      final depWriteKeys = <String>{};
      if (foundDepKey != null) depWriteKeys.add(foundDepKey);
      if (selectedDepartment != null) depWriteKeys.add(selectedDepartment!);
      final depDisplayCached = selectedDepartment != null
          ? _displayNameForDeptCached(selectedDepartment!)
          : null;
      if (depDisplayCached != null && depDisplayCached.isNotEmpty)
        depWriteKeys.add(depDisplayCached);
      if (depDisplayCached != null)
        depWriteKeys.add(_sanitizeForId(depDisplayCached));

      final classWriteKeys = <String>{};
      if (foundClassKey != null) classWriteKeys.add(foundClassKey);
      if (selectedClass != null) classWriteKeys.add(selectedClass!);
      final classDisplayCached = selectedClass != null
          ? _displayNameForClassCached(selectedClass!)
          : null;
      if (classDisplayCached != null && classDisplayCached.isNotEmpty)
        classWriteKeys.add(classDisplayCached);
      if (classDisplayCached != null)
        classWriteKeys.add(_sanitizeForId(classDisplayCached));

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
        await _saveTimetableDocToFirestore(selectedDepartment!, selectedClass!);
      } catch (e, st) {
        debugPrint('Error saving timetable after edit: $e\n$st');
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error saving timetable: $e')));
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
    final classDisplay = await _resolveClassDisplayName(selectedClass!);
    final depId = selectedDepartment!;
    final classId = selectedClass!;

    Future<bool> _deleteDocById(String docId) async {
      try {
        final ref = timetablesCollection.doc(docId);
        final snap = await ref.get();
        if (!snap.exists) return false;
        await ref.delete();
        debugPrint('Deleted timetable docId=$docId');
        return true;
      } catch (e, st) {
        debugPrint('Delete docId=$docId failed: $e\n$st');
        return false;
      }
    }

    bool deleted = false;

    // 1) Try preferred doc id from display names
    final preferredId = _docIdFromDisplayNames(depDisplay, classDisplay);
    deleted = await _deleteDocById(preferredId);

    // 2) If not found, try a query with multiple field combinations
    if (!deleted) {
      final queries = <Query>[
        timetablesCollection
            .where('department', isEqualTo: depDisplay)
            .where('className', isEqualTo: classDisplay)
            .limit(1),
        timetablesCollection
            .where('department_id', isEqualTo: depId)
            .where('classKey', isEqualTo: classId)
            .limit(1),
        timetablesCollection
            .where('department_id', isEqualTo: depId)
            .where('className', isEqualTo: classDisplay)
            .limit(1),
        timetablesCollection
            .where('department', isEqualTo: depDisplay)
            .where('classKey', isEqualTo: classId)
            .limit(1),
      ];

      for (final q in queries) {
        if (deleted) break;
        try {
          final snap = await q.get();
          if (snap.docs.isNotEmpty) {
            final id = snap.docs.first.id;
            deleted = await _deleteDocById(id);
          }
        } catch (e, st) {
          debugPrint('delete query failed: $e\n$st');
        }
      }
    }

    if (!deleted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No timetable found for the selected class'),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Timetable deleted successfully')),
    );

    void _clearCacheKey(String depKey, String classKey) {
      timetableData[depKey]?.remove(classKey);
      if (timetableData[depKey]?.isEmpty == true) timetableData.remove(depKey);
      classPeriods[depKey]?.remove(classKey);
      if (classPeriods[depKey]?.isEmpty == true) classPeriods.remove(depKey);
      spans[depKey]?.remove(classKey);
      if (spans[depKey]?.isEmpty == true) spans.remove(depKey);
    }

    final depSan = _sanitizeForId(depDisplay);
    final classSan = _sanitizeForId(classDisplay);

    setState(() {
      _clearCacheKey(depDisplay, classDisplay);
      _clearCacheKey(depDisplay, classId);
      _clearCacheKey(depId, classDisplay);
      _clearCacheKey(depId, classId);
      _clearCacheKey(depSan, classSan);

      editingEnabled = false;
    });
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

  // Collect sessions for the selected lecturer across all classes in the selected department.
  Future<List<TimetableSlot>> _collectLecturerSessionsAcrossDepartment() async {
    if (selectedDepartment == null ||
        selectedLecturer == null ||
        selectedLecturer!.trim().isEmpty) {
      return [];
    }

    final lecturerKey = selectedLecturer!.trim().toLowerCase();
    final depId = selectedDepartment!.trim();
    final depDisplay = _displayNameForDeptCached(depId);

    // Fetch timetables scoped to the department by common field names.
    List<QueryDocumentSnapshot> docs = [];
    try {
      QuerySnapshot snap = await timetablesCollection
          .where('department', isEqualTo: depDisplay)
          .get();
      docs = snap.docs;
      if (docs.isEmpty) {
        snap = await timetablesCollection
            .where('department_id', isEqualTo: depId)
            .get();
        docs = snap.docs;
      }
    } catch (_) {}

    // Fallback: pull all docs and client-filter if server filters missed.
    if (docs.isEmpty) {
      try {
        final snap = await timetablesCollection.get();
        docs = snap.docs;
      } catch (_) {}
    }

    String norm(String v) =>
        v.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final depTargets = <String>{
      norm(depId),
      norm(depDisplay),
      norm(_sanitizeForId(depId)),
      norm(_sanitizeForId(depDisplay)),
    }..removeWhere((e) => e.isEmpty);

    final results = <TimetableSlot>[];
    for (final d in docs) {
      final data = d.data() as Map<String, dynamic>? ?? {};

      // Relaxed client-side department check to catch variants/refs.
      bool depMatch = depTargets.isEmpty;
      final depCandidates = <String>{
        (data['department'] ?? '').toString(),
        (data['department_id'] ?? '').toString(),
        (data['department_ref'] ?? '').toString(),
        (data['dep_ref'] ?? '').toString(),
      }..removeWhere((e) => e.trim().isEmpty);

      for (final c in depCandidates) {
        final nc = norm(c);
        if (depTargets.contains(nc)) {
          depMatch = true;
          break;
        }
        for (final t in depTargets) {
          if (nc.contains(t) || t.contains(nc)) {
            depMatch = true;
            break;
          }
        }
        if (depMatch) break;
      }

      if (!depMatch) continue;

      // Determine class display.
      String classDisplay = (data['className'] ?? data['classKey'] ?? '')
          .toString()
          .trim();
      if (classDisplay.isEmpty) {
        final parts = d.id.split('_');
        if (parts.length >= 2) classDisplay = parts.sublist(1).join('_');
      }

      // Periods.
      List<String> periods;
      try {
        final rawPeriods = data['periods'];
        if (rawPeriods is List) {
          periods = rawPeriods.map((e) => e?.toString() ?? '').toList();
        } else {
          periods = List<String>.from(seedPeriods);
        }
      } catch (_) {
        periods = List<String>.from(seedPeriods);
      }

      // Prefer grid_meta if present.
      final gridMeta = data['grid_meta'];
      List<List<String>> gridStrings = [];
      List<List<Map<String, String>>> gridStruct = [];

      if (gridMeta is List && gridMeta.isNotEmpty) {
        for (final rowObj in gridMeta) {
          if (rowObj is Map && rowObj['cells'] is List) {
            final cells = (rowObj['cells'] as List).map<Map<String, String>>((
              c,
            ) {
              if (c is Map) {
                return {
                  'course': (c['course'] ?? '').toString(),
                  'lecturer': (c['lecturer'] ?? '').toString(),
                };
              }
              return {'course': '', 'lecturer': ''};
            }).toList();
            gridStruct.add(cells);
          }
        }
      } else {
        final gridRaw = data['grid'];
        if (gridRaw is List) {
          gridStrings = gridRaw.map<List<String>>((rowObj) {
            if (rowObj is Map && rowObj['cells'] is List) {
              return (rowObj['cells'] as List)
                  .map((c) => c?.toString() ?? '')
                  .toList();
            }
            if (rowObj is List) {
              return rowObj.map((c) => c?.toString() ?? '').toList();
            }
            return <String>[];
          }).toList();
        }
      }

      for (int dIndex = 0; dIndex < days.length; dIndex++) {
        for (int pIndex = 0; pIndex < periods.length; pIndex++) {
          final label = periods[pIndex];
          if (label.toLowerCase().contains('break')) continue;

          String course = '';
          String lecturer = '';

          if (gridStruct.isNotEmpty && dIndex < gridStruct.length) {
            final row = gridStruct[dIndex];
            if (pIndex < row.length) {
              course = row[pIndex]['course']?.toString() ?? '';
              lecturer = row[pIndex]['lecturer']?.toString() ?? '';
            }
          } else if (gridStrings.isNotEmpty && dIndex < gridStrings.length) {
            final row = gridStrings[dIndex];
            if (pIndex < row.length) {
              final raw = row[pIndex].toString();
              final parts = raw.split('\n');
              course = parts.isNotEmpty ? parts[0].trim() : '';
              lecturer = parts.length > 1
                  ? parts.sublist(1).join(' ').trim()
                  : '';
            }
          }

          if (course.isEmpty && lecturer.isEmpty) continue;
          final lectKey = lecturer.trim().toLowerCase();
          if (lectKey.isEmpty) continue;
          if (!lectKey.contains(lecturerKey)) continue;

          results.add(
            TimetableSlot(
              day: days[dIndex],
              periodLabel: label,
              course: course,
              className: classDisplay,
              department: depDisplay,
              lecturer: lecturer,
            ),
          );
        }
      }
    }

    // Sort by day then period index based on periods list ordering.
    final dayOrder = ['Sat', 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
    results.sort((a, b) {
      final ai = dayOrder.indexOf(a.day);
      final bi = dayOrder.indexOf(b.day);
      if (ai != bi) return ai.compareTo(bi);
      // Period ordering: compare by start index within the original periods lists if possible.
      // Fallback to string compare.
      return a.periodLabel.compareTo(b.periodLabel);
    });

    // Apply search filter if present.
    if (searchText.trim().isNotEmpty) {
      final q = searchText.trim().toLowerCase();
      return results
          .where(
            (s) =>
                s.course.toLowerCase().contains(q) ||
                s.className.toLowerCase().contains(q) ||
                s.periodLabel.toLowerCase().contains(q) ||
                s.day.toLowerCase().contains(q),
          )
          .toList();
    }

    return results;
  }

  List<TimetableSlot> getFilteredSlotsFromGrid() {
    final grid = currentTimetable;
    if (grid == null) return [];
    final periodsForClass = currentPeriods;
    var list = _slotsFromGrid(grid, periodsForClass);

    if (selectedLecturer != null &&
        selectedLecturer!.trim().isNotEmpty &&
        selectedLecturer != 'NONE' &&
        selectedLecturer != 'All lecturers') {
      final key = selectedLecturer!.toLowerCase().trim();
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
  // NOTE: For brevity, the full rendering code (AppBar, buttons, dropdowns, grid widget)
  // should be replicated from your previous implementation and wired to the functions above.
  // Below is a minimal structure integrating core parts; adapt styling as needed.

  @override
  Widget build(BuildContext context) {
    final grid = currentTimetable;
    final periodsForClass = currentPeriods;
    final showLecturerList =
        selectedDepartment != null &&
        selectedClass == null &&
        selectedLecturer != null &&
        selectedLecturer!.trim().isNotEmpty;
    final canEdit = grid != null;
    final canDelete = grid != null;
    final canExport = canDelete || showLecturerList;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const Text(
                'Time Table',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              SearchAddBar(
                hintText: 'Search Time Table...',
                buttonText: '', // hide add button; we already have one below
                onAddPressed: () {},
                onChanged: (v) => setState(() => searchText = v),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Create Time Table'),
                    onPressed: () async {
                      // compute initial names and loaderArg (dep DocumentReference or id string)
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
                            depArg = depMap['ref'] is DocumentReference
                                ? depMap['ref']
                                : selectedDepartment;
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
                          if (classMap.isNotEmpty)
                            initialClassName = (classMap['name'] as String?)
                                ?.toString();
                        } catch (_) {
                          initialClassName = null;
                        }
                      }

                      // Keep period labels and pass existing sessions so the dialog can filter them per course.
                      List<String>? existingLabels;
                      if (currentTimetable != null) {
                        existingLabels = List<String>.from(currentPeriods);
                      }
                      final prefilledSessions = _prefillSessionsFromCurrent();

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
                              prefilledSessions: prefilledSessions,
                              departmentArg: depArg,
                            ),
                          );

                      if (payload == null) return;
                      await _applyCreatePayload(payload);
                    },
                  ),
                  SizedBox(
                    height: 36,
                    child: OutlinedButton.icon(
                      icon: const Icon(
                        Icons.refresh,
                        size: 18,
                        color: Colors.purple,
                      ),
                      label: const Text(
                        'Reload',
                        style: TextStyle(color: Colors.purple),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.purple),
                        foregroundColor: Colors.purple,
                      ),
                      onPressed: () async {
                        setState(() {
                          selectedDepartment = null;
                          selectedClass = null;
                          selectedLecturer = null;
                          selectedCourse = null;
                          _classes = [];
                          _teachers = [];
                          _coursesForSelectedClass = [];
                          timetableData.clear();
                          classPeriods.clear();
                          spans.clear();
                          editingEnabled = false;
                        });
                        await _loadDepartments();
                        // teachers/courses reload after re-selection
                      },
                    ),
                  ),
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
                                      onPressed: () => Navigator.pop(ctx, true),
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
                  IconButton(
                    tooltip: 'Export PDF',
                    onPressed: canExport ? _exportPdfFlow : null,
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
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
                          vertical: 5,
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
                              : const Text('Department'),
                          isExpanded: true,
                          value: selectedDepartment,
                          items: _departments
                              .map(
                                (d) => DropdownMenuItem<String>(
                                  value: d['id'] as String,
                                  child: Text(d['name'] as String),
                                ),
                              )
                              .toList(),
                          onChanged: (v) async {
                            setState(() {
                              selectedDepartment = v;
                              selectedClass = null;
                              _classes = [];
                              // clear previous lecturer selection when department changes
                              selectedLecturer = null;
                              _teachers = [];
                            });

                            dynamic loaderArg;
                            try {
                              final found = _departments.firstWhere(
                                (d) => d['id'] == v,
                                orElse: () => <String, dynamic>{},
                              );
                              if (found.isNotEmpty &&
                                  found['ref'] is DocumentReference)
                                loaderArg = found['ref'];
                              else
                                loaderArg = v;
                            } catch (_) {
                              loaderArg = v;
                            }

                            if (loaderArg != null)
                              await _loadClassesForDepartment(loaderArg);
                            // ensure teachers reflect current session/faculty
                            await _loadTeachers();
                            await _handleSelectionChangeSafe();
                          },
                        ),
                      ),
                    ),
                  ),
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
                          vertical: 5,
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
                              : const Text('Class'),
                          isExpanded: true,
                          value: selectedClass,
                          items: _classes
                              .map(
                                (c) => DropdownMenuItem<String>(
                                  value: c['id'] as String,
                                  child: Text(c['name'] as String),
                                ),
                              )
                              .toList(),
                          onChanged: (v) async {
                            setState(() {
                              selectedClass = v;
                            });
                            try {
                              // Ensure lecturer list refreshes after class selection
                              await _loadTeachers();
                              await _handleSelectionChangeSafe();
                            } catch (err, st) {
                              debugPrint(
                                'Error in selection change after class select: $err\n$st',
                              );
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  // Lecturer dropdown
                  Container(
                    constraints: const BoxConstraints(
                      minWidth: 130,
                      maxWidth: 240,
                    ),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 5,
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
                              : const Text('Lecturer'),
                          isExpanded: true,
                          value: selectedLecturer,
                          items: _teachers
                              .map(
                                (t) => DropdownMenuItem<String>(
                                  value: t['name'] as String,
                                  child: Text(t['name'] as String),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => selectedLecturer = v),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
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
                      ? (showLecturerList
                            ? FutureBuilder<List<TimetableSlot>>(
                                future:
                                    _collectLecturerSessionsAcrossDepartment(),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  }
                                  final slots = snapshot.data ?? [];
                                  if (slots.isEmpty) {
                                    return Center(
                                      child: Text(
                                        'No sessions found for this lecturer in the selected department.',
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    );
                                  }
                                  return _LecturerListView(slots: slots);
                                },
                              )
                            : Center(
                                child: Text(
                                  'Please select Department and Class to view the timetable.',
                                  style: TextStyle(color: Colors.grey.shade600),
                                  textAlign: TextAlign.center,
                                ),
                              ))
                      : _TimetableGrid(
                          days: days,
                          periods: periodsForClass,
                          timetable: grid,
                          editing: editingEnabled,
                          selectedLecturer: selectedLecturer,
                          teachers: _teachers,
                          onCellTap: (d, p) =>
                              _openEditCellDialog(dayIndex: d, periodIndex: p),
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
    // If we are in lecturer list mode (dept + lecturer, no class), export combined list.
    final showLecturerList =
        selectedDepartment != null &&
        selectedClass == null &&
        selectedLecturer != null &&
        selectedLecturer!.trim().isNotEmpty;

    if (showLecturerList) {
      try {
        final slots = await _collectLecturerSessionsAcrossDepartment();
        if (slots.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No sessions to export for lecturer')),
          );
          return;
        }
        await _exportLecturerListPdf(slots);
      } catch (e) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
      return;
    }

    // Class timetable export path
    if (selectedDepartment == null || selectedClass == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select Department and Class first')),
      );
      return;
    }

    await _generatePdf(_ExportChoice.entireClass);
  }

  Future<void> _generatePdf(_ExportChoice choice) async {
    final depDisplay = selectedDepartment != null
        ? _displayNameForDeptCached(selectedDepartment!)
        : '';
    final classDisplay = selectedClass != null
        ? _displayNameForClassCached(selectedClass!)
        : '';
    final depKey = depDisplay;
    final classKey = classDisplay;
    if (depKey.isEmpty || classKey.isEmpty || currentTimetable == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Class not found')));
      return;
    }

    final pdf = pw.Document();
    final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    final periods = (classPeriods[depKey]?[classKey] ?? currentPeriods);
    final grid =
        currentTimetable ??
        List.generate(
          days.length,
          (_) => List<String>.filled(periods.length, ''),
        );

    // If a lecturer is selected, filter cells to only show that lecturer
    List<List<String>> exportGrid = grid
        .map((row) => List<String>.from(row, growable: true))
        .toList(growable: true);
    if (selectedLecturer != null && selectedLecturer!.trim().isNotEmpty) {
      final key = selectedLecturer!.toLowerCase().trim();
      for (int d = 0; d < exportGrid.length; d++) {
        for (int p = 0; p < exportGrid[d].length; p++) {
          final raw = exportGrid[d][p].trim();
          if (raw.isEmpty) continue;
          if (raw.toLowerCase() == 'break' ||
              periods[p].toLowerCase().contains('break'))
            continue;
          final parts = raw.split('\n');
          final lecturer = parts.length > 1
              ? parts.sublist(1).join(' ').trim().toLowerCase()
              : '';
          if (!lecturer.contains(key)) {
            exportGrid[d][p] = '';
          }
        }
      }
    }

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
          if (periods.isEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 16),
              child: pw.Text(
                'No timetable data',
                style: pw.TextStyle(fontSize: 14),
              ),
            )
          else if (selectedLecturer != null &&
              selectedLecturer!.trim().isNotEmpty)
            _pdfLecturerSchedule(
              periods: periods,
              grid: exportGrid,
              lecturer: selectedLecturer!.trim(),
            )
          else
            _pdfGridTable(periods: periods, grid: exportGrid),
        ],
      ),
    );

    final lecturerSuffix =
        (selectedLecturer != null && selectedLecturer!.trim().isNotEmpty)
        ? '_${selectedLecturer!.trim().replaceAll(' ', '_')}'
        : '';
    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name:
          'timetable_${depKey}${classKey}${lecturerSuffix}${dateStr.replaceAll(':', '-')}.pdf',
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

  // Compact schedule view for a specific lecturer
  pw.Widget _pdfLecturerSchedule({
    required List<String> periods,
    required List<List<String>> grid,
    required String lecturer,
  }) {
    final rows = <List<pw.Widget>>[];
    for (int d = 0; d < days.length; d++) {
      final row = grid.length > d
          ? grid[d]
          : List<String>.filled(periods.length, '');
      for (int p = 0; p < periods.length; p++) {
        final label = periods[p];
        if (label.toLowerCase().contains('break')) continue;
        final raw = p < row.length ? row[p].trim() : '';
        if (raw.isEmpty) continue;
        final parts = raw.split('\n');
        final course = parts.isNotEmpty ? parts[0].trim() : '';
        final lect = parts.length > 1 ? parts.sublist(1).join(' ').trim() : '';
        if (lect.isEmpty) continue;
        if (lect.toLowerCase().contains(lecturer.toLowerCase())) {
          rows.add([
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(
                days[d],
                style: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(label, style: const pw.TextStyle(fontSize: 10)),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.all(4),
              child: pw.Text(course, style: const pw.TextStyle(fontSize: 10)),
            ),
          ]);
        }
      }
    }

    if (rows.isEmpty) {
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Lecturer: $lecturer',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'No sessions found for the selected lecturer.',
            style: pw.TextStyle(color: PdfColors.grey600),
          ),
        ],
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Lecturer: $lecturer',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.5),
          defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
          columnWidths: const {
            0: pw.FlexColumnWidth(1),
            1: pw.FlexColumnWidth(2),
            2: pw.FlexColumnWidth(3),
          },
          children: [
            pw.TableRow(
              decoration: pw.BoxDecoration(color: PdfColors.grey200),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(
                    'Day',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(
                    'Time',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(
                    'Course',
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            ...rows.map((cells) => pw.TableRow(children: cells)),
          ],
        ),
      ],
    );
  }

  // Export combined lecturer sessions list (when only department + lecturer are selected).
  Future<void> _exportLecturerListPdf(List<TimetableSlot> slots) async {
    final depDisplay = selectedDepartment != null
        ? _displayNameForDeptCached(selectedDepartment!)
        : '';
    final lecturerName = selectedLecturer ?? '';
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
        build: (ctx) {
          return [
            pw.Text(
              'Lecturer Schedule',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 4),
            pw.Text('Department: $depDisplay'),
            pw.Text('Lecturer: $lecturerName'),
            pw.Text('Exported: $dateStr'),
            pw.SizedBox(height: 12),
            _pdfLecturerTable(slots),
          ];
        },
      ),
    );

    final safeLect = lecturerName.trim().replaceAll(' ', '_');
    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name:
          'lecturer_schedule_${depDisplay.replaceAll(' ', '_')}_$safeLect.pdf',
    );
  }

  pw.Widget _pdfLecturerTable(List<TimetableSlot> slots) {
    final headers = ['Day', 'Time', 'Class', 'Course'];
    final rows = slots
        .map((s) => [s.day, s.periodLabel, s.className, s.course])
        .toList();

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.5),
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      columnWidths: const {
        0: pw.FlexColumnWidth(1),
        1: pw.FlexColumnWidth(2),
        2: pw.FlexColumnWidth(2),
        3: pw.FlexColumnWidth(3),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: PdfColors.grey200),
          children: headers
              .map(
                (h) => pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 6,
                  ),
                  child: pw.Text(
                    h,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ),
              )
              .toList(),
        ),
        ...rows.map(
          (r) => pw.TableRow(
            children: r
                .map(
                  (c) => pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                      vertical: 6,
                      horizontal: 6,
                    ),
                    child: pw.Text(c),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

// ------- Small UI helper widgets -------

class _LecturerListView extends StatelessWidget {
  final List<TimetableSlot> slots;

  const _LecturerListView({required this.slots});

  @override
  Widget build(BuildContext context) {
    final headerStyle = Theme.of(context).textTheme.labelLarge?.copyWith(
      fontWeight: FontWeight.bold,
      color: Colors.grey[700],
    );
    final cellStyle = Theme.of(context).textTheme.bodyMedium;

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: const [
              Expanded(flex: 1, child: Text('Day')),
              Expanded(flex: 2, child: Text('Time')),
              Expanded(flex: 2, child: Text('Class')),
              Expanded(flex: 3, child: Text('Course')),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: ListView.separated(
            itemCount: slots.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final s = slots[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    Expanded(flex: 1, child: Text(s.day, style: cellStyle)),
                    Expanded(
                      flex: 2,
                      child: Text(s.periodLabel, style: cellStyle),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(s.className, style: cellStyle),
                    ),
                    Expanded(flex: 3, child: Text(s.course, style: cellStyle)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TimetableGrid extends StatelessWidget {
  final List<String> days;
  final List<String> periods;
  final List<List<String>> timetable;
  final bool editing;
  final String? selectedLecturer;
  final List<Map<String, dynamic>> teachers;
  final void Function(int dayIndex, int periodIndex)? onCellTap;

  const _TimetableGrid({
    required this.days,
    required this.periods,
    required this.timetable,
    required this.editing,
    this.selectedLecturer,
    this.teachers = const [],
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

        // Build trimmed view when a lecturer filter is active: remove empty cols/rows
        List<String> displayPeriods = List<String>.from(periods);
        List<List<String>> displayGrid = timetable
            .map((r) => List<String>.from(r, growable: true))
            .toList(growable: true);
        final bool filterByLecturer =
            selectedLecturer != null &&
            selectedLecturer!.trim().isNotEmpty &&
            selectedLecturer != 'NONE' &&
            selectedLecturer != 'All lecturers';
        if (filterByLecturer) {
          final key = selectedLecturer!.toLowerCase().trim();
          // Blank non-matching cells first
          for (int d = 0; d < displayGrid.length; d++) {
            for (int p = 0; p < displayGrid[d].length; p++) {
              final label = p < displayPeriods.length ? displayPeriods[p] : '';
              if (label.toLowerCase().contains('break')) continue;
              final raw = displayGrid[d][p].trim();
              if (raw.isEmpty) continue;
              if (raw.toLowerCase() == 'break') continue;
              final parts = raw.split('\n');
              final lect = parts.length > 1
                  ? parts.sublist(1).join(' ').trim().toLowerCase()
                  : '';
              if (!lect.contains(key)) displayGrid[d][p] = '';
            }
          }

          // Determine non-empty columns
          final keepCols = <int>{};
          for (int p = 0; p < displayPeriods.length; p++) {
            final lbl = displayPeriods[p].toLowerCase();
            if (lbl.contains('break')) continue;
            bool any = false;
            for (int d = 0; d < displayGrid.length; d++) {
              final raw = (p < displayGrid[d].length) ? displayGrid[d][p] : '';
              if (raw.trim().isNotEmpty && raw.toLowerCase() != 'break') {
                any = true;
                break;
              }
            }
            if (any) keepCols.add(p);
          }

          // Rebuild periods and grid keeping only non-empty columns
          final newPeriods = <String>[];
          for (int p = 0; p < displayPeriods.length; p++) {
            if (keepCols.contains(p)) newPeriods.add(displayPeriods[p]);
          }
          final newGrid = <List<String>>[];
          for (int d = 0; d < displayGrid.length; d++) {
            final row = <String>[];
            for (int p = 0; p < displayPeriods.length; p++) {
              if (keepCols.contains(p)) {
                row.add(p < displayGrid[d].length ? displayGrid[d][p] : '');
              }
            }
            newGrid.add(row);
          }

          // Remove rows that are completely empty
          final filteredGrid = <List<String>>[];
          for (final row in newGrid) {
            final any = row.any(
              (c) => c.trim().isNotEmpty && c.toLowerCase() != 'break',
            );
            if (any) filteredGrid.add(row);
          }

          displayPeriods = newPeriods;
          displayGrid = filteredGrid.isNotEmpty ? filteredGrid : newGrid;
        }

        final totalWidth = dayColWidth + periodColWidth * displayPeriods.length;
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
                    ...displayPeriods.map((p) {
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
                    }).toList(),
                  ],
                ),
                const Divider(height: dividerHeight),
                SizedBox(
                  height: rowsAreaHeight,
                  child: ListView.builder(
                    itemCount: displayGrid.length,
                    itemBuilder: (context, rowIdx) {
                      final row = displayGrid[rowIdx];
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
                                  days[rowIdx % days.length],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              ...List.generate(displayPeriods.length, (colIdx) {
                                final cell = (colIdx < row.length)
                                    ? row[colIdx]
                                    : '';
                                final isBreak = displayPeriods[colIdx]
                                    .toLowerCase()
                                    .contains('break');
                                final tappable =
                                    editing && !isBreak && onCellTap != null;

                                // Parse cell and extract course + lecturer (if any)
                                final lines = cell.split('\n');
                                final courseOnly = lines.isNotEmpty
                                    ? lines[0].trim()
                                    : '';
                                String lecturerOnly = (lines.length > 1)
                                    ? lines.sublist(1).join(' ').trim()
                                    : '';

                                // If there's no lecturer recorded but exactly one teacher
                                // is available for this class, use that teacher's name.
                                if (lecturerOnly.isEmpty &&
                                    teachers.length == 1) {
                                  try {
                                    final t0 = teachers.first;
                                    lecturerOnly = (t0['name'] ?? '')
                                        .toString();
                                  } catch (_) {
                                    lecturerOnly = '';
                                  }
                                }

                                // Prepare default empty content; we'll override below
                                Widget content = const SizedBox.shrink();

                                // If a specific lecturer is selected, hide cells that don't match
                                if (selectedLecturer != null &&
                                    selectedLecturer!.trim().isNotEmpty &&
                                    selectedLecturer != 'NONE' &&
                                    selectedLecturer != 'All lecturers') {
                                  final key = selectedLecturer!
                                      .toLowerCase()
                                      .trim();
                                  if (!lecturerOnly.toLowerCase().contains(
                                    key,
                                  )) {
                                    // Treat as empty for display (no match)
                                    if (editing && !isBreak) {
                                      content = Opacity(
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
                                      );
                                    }
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
                                        ),
                                        foregroundDecoration:
                                            (editing && !isBreak)
                                            ? ShapeDecoration(
                                                shape: highlightShape,
                                              )
                                            : null,
                                        child: content,
                                      ),
                                    );
                                  }
                                }

                                // Build normal content for matching/visible cells
                                if (courseOnly.isEmpty) {
                                  if (editing && !isBreak) {
                                    content = Opacity(
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
                                    );
                                  } else {
                                    content = const SizedBox.shrink();
                                  }
                                } else {
                                  content = Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        courseOnly,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      if (lecturerOnly.isNotEmpty)
                                        Text(
                                          lecturerOnly,
                                          style: const TextStyle(
                                            color: Colors.black87,
                                            fontSize: 12,
                                          ),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  );
                                }

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

class _UndoState {
  final String depKey;
  final String classKey;
  final String? sectionKey;
  final Map<String, List<String>> classPeriodsCopy;
  final Map<String, List<List<String>>> timetableCopy;
  _UndoState({
    required this.depKey,
    required this.classKey,
    required this.sectionKey,
    required this.classPeriodsCopy,
    required this.timetableCopy,
  });
}
