// TimetablePage — full updated implementation
// - Reads/writes timetables using "<department display name>_<class display name>" document ids.
// - Resolves display names from department/class caches or fetches docs as fallback.
// - Loads classes and class courses similar to CreateTimetableDialog.
// - Robust lookup of in-memory cache under multiple aliases so UI selection (ids or names) finds loaded data.
// - Safe cell editing that avoids null-derefs and persists edits to Firestore.
// - Replace your existing lib/components/pages/timetable_page.dart with this file.

import 'dart:convert';


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

  TimetableSlot({
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
      _departments = snap.docs.map((d) {
        final data = d.data() as Map<String, dynamic>;
        final name =
            (data['name'] ??
                    data['department_name'] ??
                    data['displayName'] ??
                    data['title'] ??
                    '')
                .toString();
        return {'id': d.id, 'name': name, 'ref': d.reference};
      }).toList();
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
    // If department or class is not selected we intentionally keep the
    // lecturer list empty. Teachers should only appear when both are chosen.
    if (selectedDepartment == null || selectedClass == null) {
      setState(() {
        _teachers = [];
        _loadingTeachers = false;
      });
      return;
    }

    setState(() => _loadingTeachers = true);
    try {
      final teachersCol = _firestore.collection('teachers');

      // Helper to normalize a teacher id from various stored shapes
      String _normalizeId(dynamic cand) {
        if (cand == null) return '';
        if (cand is DocumentReference) return cand.id;
        if (cand is String) {
          final s = cand;
          if (s.contains('/')) {
            final parts = s.split('/').where((p) => p.isNotEmpty).toList();
            return parts.isNotEmpty ? parts.last : s;
          }
          return s;
        }
        return cand.toString();
      }

      // Resolve selected department ref/id if available from cache
      dynamic selectedDeptRef;
      String? selectedDeptId;
      if (selectedDepartment != null) {
        try {
          final found = _departments.firstWhere(
            (d) => d['id'] == selectedDepartment,
            orElse: () => <String, dynamic>{},
          );
          if (found is Map && found.isNotEmpty) {
            selectedDeptRef = found['ref'];
            selectedDeptId = (found['id']?.toString() ?? selectedDepartment);
          } else {
            selectedDeptId = selectedDepartment;
          }
        } catch (_) {
          selectedDeptId = selectedDepartment;
        }
      }

      // If a class is selected, collect teacher ids assigned to that class via courses
      // and from the class document itself. Try both String ids and DocumentReference
      // shapes when querying courses (some docs store refs as strings or refs).
      final Set<String> teacherIdsForClass = {};
      if (selectedClass != null) {
        try {
          final coursesCol = _firestore.collection('courses');
          final classRef = _firestore.collection('classes').doc(selectedClass);

          // try both shapes for queries
          QuerySnapshot snap = await coursesCol
              .where('class', isEqualTo: selectedClass)
              .get();
          if (snap.docs.isEmpty)
            snap = await coursesCol.where('class', isEqualTo: classRef).get();
          if (snap.docs.isEmpty)
            snap = await coursesCol
                .where('class_id', isEqualTo: selectedClass)
                .get();
          if (snap.docs.isEmpty)
            snap = await coursesCol
                .where('class_ref', isEqualTo: classRef)
                .get();
          if (snap.docs.isEmpty)
            snap = await coursesCol
                .where('class_ref', isEqualTo: selectedClass)
                .get();
          if (snap.docs.isEmpty)
            snap = await coursesCol
                .where('className', isEqualTo: selectedClass)
                .get();

          for (final d in snap.docs) {
            final data = d.data() as Map<String, dynamic>? ?? {};
            final teacherCandidates = [
              'teacher_assigned',
              'teacher_ref',
              'teacher',
              'teacherRef',
              'teacher_id',
              'lecturer',
              'lecturer_id',
            ];
            for (final k in teacherCandidates) {
              if (!data.containsKey(k) || data[k] == null) continue;
              final id = _normalizeId(data[k]);
              if (id.isNotEmpty) teacherIdsForClass.add(id);
            }
          }

          // Also inspect the class document for assigned teacher fields
          try {
            final clsDoc = await classRef.get();
            if (clsDoc.exists) {
              final cdata = clsDoc.data() as Map<String, dynamic>? ?? {};
              final classTeacherKeys = [
                'teacher',
                'teacher_assigned',
                'teacher_id',
                'teacher_ref',
                'assigned_teacher',
                'lecturer',
              ];
              for (final k in classTeacherKeys) {
                if (!cdata.containsKey(k) || cdata[k] == null) continue;
                final id = _normalizeId(cdata[k]);
                if (id.isNotEmpty) teacherIdsForClass.add(id);
              }
            }
          } catch (_) {}
        } catch (e, st) {
          debugPrint(
            'Error fetching courses for class when loading teachers: $e\n$st',
          );
        }
      }

      // Helper to fetch teacher docs by ids (supports >10 by batching)
      Future<List<Map<String, dynamic>>> _fetchTeachersByIds(
        List<String> ids,
      ) async {
        final out = <Map<String, dynamic>>[];
        if (ids.isEmpty) return out;
        try {
          // Firestore whereIn limit is 10; batch if necessary
          if (ids.length <= 10) {
            final snap = await teachersCol
                .where(FieldPath.documentId, whereIn: ids)
                .get();
            for (final d in snap.docs) out.add({'id': d.id, 'data': d.data()});
          } else {
            final batches = <List<String>>[];
            for (var i = 0; i < ids.length; i += 10) {
              batches.add(
                ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10),
              );
            }
            for (final b in batches) {
              final snap = await teachersCol
                  .where(FieldPath.documentId, whereIn: b)
                  .get();
              for (final d in snap.docs)
                out.add({'id': d.id, 'data': d.data()});
            }
          }
        } catch (e, st) {
          debugPrint('Error fetching teachers by ids: $e\n$st');
        }
        return out;
      }

      List<Map<String, dynamic>> fetched = [];

      // If we discovered teacher ids for the selected class, prefer those.
      // Do NOT further filter them by department — if a teacher is assigned to
      // the class we want to show them regardless of department fields.
      if (teacherIdsForClass.isNotEmpty) {
        final ids = teacherIdsForClass.toList();
        fetched = await _fetchTeachersByIds(ids);
      }

      // If we didn't get any teachers from class assignment (or none matched department),
      // fall back to department-level server queries, then faculty scoping, then all teachers.
      if (fetched.isEmpty) {
        List<QueryDocumentSnapshot> docs = [];

        Future<List<QueryDocumentSnapshot>> tryQuery(
          Query q,
          String tag,
        ) async {
          try {
            final snap = await q.get();
            debugPrint(
              'teachers query [$tag] returned ${snap.docs.length} docs',
            );
            return snap.docs;
          } catch (e, st) {
            debugPrint('teachers query [$tag] failed: $e\n$st');
            return <QueryDocumentSnapshot>[];
          }
        }

        // If department selected, try to server-filter by department using many
        // possible stored shapes: DocumentReference, id string, and path strings
        if (selectedDeptRef != null ||
            (selectedDeptId != null && selectedDeptId.isNotEmpty)) {
          final List<dynamic> deptVariants = [];
          if (selectedDeptRef is DocumentReference)
            deptVariants.add(selectedDeptRef);
          if (selectedDeptId != null) {
            deptVariants.add(selectedDeptId);
            deptVariants.add('departments/${selectedDeptId}');
            deptVariants.add('/departments/${selectedDeptId}');
          }

          for (final v in deptVariants) {
            if (docs.isNotEmpty) break;
            try {
              docs = await tryQuery(
                teachersCol.where('department_ref', isEqualTo: v),
                'department_ref==${v.toString()}',
              );
            } catch (_) {}
            if (docs.isNotEmpty) break;
            try {
              docs = await tryQuery(
                teachersCol.where('department_id', isEqualTo: v),
                'department_id==${v.toString()}',
              );
            } catch (_) {}
            if (docs.isNotEmpty) break;
            try {
              docs = await tryQuery(
                teachersCol.where('department', isEqualTo: v),
                'department==${v.toString()}',
              );
            } catch (_) {}
          }
        }

        // If still empty, try faculty scoping like before
        if (docs.isEmpty && Session.facultyRef != null) {
          docs = await tryQuery(
            teachersCol.where('faculty_ref', isEqualTo: Session.facultyRef),
            'faculty_ref==DocumentReference',
          );
          if (docs.isEmpty) {
            try {
              final fid = Session.facultyRef!.id;
              docs = await tryQuery(
                teachersCol.where('faculty_id', isEqualTo: fid),
                'faculty_id==String',
              );
            } catch (_) {}
          }
          if (docs.isEmpty) {
            try {
              final fid = Session.facultyRef!.id;
              docs = await tryQuery(
                teachersCol.where('faculty', isEqualTo: fid),
                'faculty==String',
              );
            } catch (_) {}
          }
        }

        if (docs.isEmpty) {
          final snap = await teachersCol.get();
          docs = snap.docs;
        }

        fetched = docs.map((d) => {'id': d.id, 'data': d.data()}).toList();

        // If a department was selected but server queries didn't filter, perform client-side filter
        if (selectedDeptRef != null ||
            (selectedDeptId != null && selectedDeptId!.isNotEmpty)) {
          fetched = fetched.where((d) {
            final data = (d['data'] as Map<String, dynamic>?) ?? {};
            final deptCand =
                data['department_ref'] ??
                data['department_id'] ??
                data['department'];
            final candId = _normalizeId(deptCand);
            if (candId.isEmpty) return false;
            if (selectedDeptRef is DocumentReference) {
              try {
                return candId == (selectedDeptRef as DocumentReference).id ||
                    candId == selectedDeptRef.path ||
                    candId == '/${selectedDeptRef.path}';
              } catch (_) {}
            }
            if (selectedDeptId != null)
              return candId == selectedDeptId || candId == '/${selectedDeptId}';
            return true;
          }).toList();
        }
      }

      // Map to dropdown structure
      _teachers = fetched.map((d) {
        final data = (d['data'] as Map<String, dynamic>?) ?? {};
        final name =
            (data['teacher_name'] ??
                    data['name'] ??
                    data['full_name'] ??
                    data['username'] ??
                    d['id'])
                .toString();
        return {'id': d['id'] as String, 'name': name};
      }).toList();

      _teachers.sort(
        (a, b) => a['name'].toString().compareTo(b['name'].toString()),
      );
    } catch (e, st) {
      debugPrint('loadTeachers error: $e\n$st');
      setState(() => _teachers = []);
    } finally {
      setState(() => _loadingTeachers = false);
    }
  }

  Future<void> _loadClassesForDepartment(dynamic depIdOrRef) async {
    setState(() => _loadingClasses = true);
    try {
      if (depIdOrRef == null) {
        setState(() => _classes = []);
        return;
      }

      final classesCol = _firestore.collection('classes');

      Future<List<QueryDocumentSnapshot>> tryQuery(Query q, String tag) async {
        try {
          final snap = await q.get();
          debugPrint('classes query [$tag] returned ${snap.docs.length} docs');
          if (snap.docs.isNotEmpty)
            debugPrint(
              'classes query [$tag] first doc data: ${snap.docs.first.data()}',
            );
          return snap.docs;
        } catch (e, st) {
          debugPrint('classes query [$tag] failed: $e\n$st');
          return <QueryDocumentSnapshot>[];
        }
      }

      List<QueryDocumentSnapshot> docs = [];

      if (depIdOrRef is DocumentReference) {
        docs = await tryQuery(
          classesCol.where('department_ref', isEqualTo: depIdOrRef),
          'department_ref==DocumentReference',
        );
        if (docs.isEmpty)
          docs = await tryQuery(
            classesCol.where(
              'department_ref',
              isEqualTo: (depIdOrRef as DocumentReference).id,
            ),
            'department_ref==DocumentReference.id',
          );
      } else if (depIdOrRef is String) {
        docs = await tryQuery(
          classesCol.where('department_ref', isEqualTo: depIdOrRef),
          'department_ref==String',
        );
        if (docs.isEmpty)
          docs = await tryQuery(
            classesCol.where('department_id', isEqualTo: depIdOrRef),
            'department_id==String',
          );
        if (docs.isEmpty)
          docs = await tryQuery(
            classesCol.where('department', isEqualTo: depIdOrRef),
            'department==String',
          );
        if (docs.isEmpty)
          docs = await tryQuery(
            classesCol.where('department_name', isEqualTo: depIdOrRef),
            'department_name==String',
          );
      }

      final classes = docs.map((d) {
        final data = d.data() as Map<String, dynamic>;
        final name = (data['class_name'] ?? data['name'] ?? d.id).toString();
        final section = (data['section'] ?? '').toString();
        return {
          'id': d.id,
          'name': name,
          'section': section,
          'raw': data,
          'ref': d.reference,
        };
      }).toList();

      classes.sort(
        (a, b) => a['name'].toString().compareTo(b['name'].toString()),
      );

      setState(() => _classes = classes);
    } catch (e, st) {
      debugPrint('loadClassesForDepartment error: $e\n$st');
      setState(() => _classes = []);
    } finally {
      setState(() => _loadingClasses = false);
    }
  }

  Future<void> _loadCoursesForClass(dynamic classIdOrName) async {
    if (classIdOrName == null) {
      setState(() => _coursesForSelectedClass = []);
      return;
    }
    setState(() => _loadingCourses = true);
    try {
      final coursesCol = _firestore.collection('courses');

      Future<QuerySnapshot> tryQ(String field) =>
          coursesCol.where(field, isEqualTo: classIdOrName).get();

      QuerySnapshot snap = await tryQ('class');
      if (snap.docs.isEmpty) snap = await tryQ('class_id');
      if (snap.docs.isEmpty) snap = await tryQ('class_ref');
      if (snap.docs.isEmpty) snap = await tryQ('class_name');

      if (snap.docs.isEmpty) {
        debugPrint('CreateDialog: no courses found for classId=$classIdOrName');
        setState(() => _coursesForSelectedClass = []);
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
        _coursesForSelectedClass = courses;
      });
    } catch (e, st) {
      debugPrint('loadCoursesForClass error: $e\n$st');
      setState(() => _coursesForSelectedClass = []);
    } finally {
      setState(() => _loadingCourses = false);
    }
  }

  // -------------------- Timetable read/write --------------------

  Future<void> _loadTimetableDoc() async {
    if (selectedDepartment == null || selectedClass == null) return;
    final depId = selectedDepartment!.trim();
    final clsId = selectedClass!.trim();

    final docId = await _docIdFromSelected(depId, clsId);
    final deptDisplay = await _resolveDepartmentDisplayName(depId);
    final classDisplay = await _resolveClassDisplayName(clsId);

    debugPrint(
      'Loading timetable for docId="$docId" (deptDisplay="$deptDisplay" classDisplay="$classDisplay", depId="$depId" classId="$clsId")',
    );

    final docRef = timetablesCollection.doc(docId);

    try {
      final snap = await docRef.get();
      if (snap.exists && snap.data() != null) {
        debugPrint('Found timetable document by id: $docId');
        await _applyTimetableDataFromSnapshot(
          snap.data()! as Map<String, dynamic>,
          deptDisplay,
          classDisplay,
        );
      } else {
        debugPrint(
          'Doc $docId not found by id — querying timetables collection for matching document',
        );

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
          // nothing found — show message only
          debugPrint('No timetable found in timetables for $docId');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No timetable found in this class')),
          );
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

    // Check for existing document
    final query = timetablesCollection
        .where('department', isEqualTo: depDisplay)
        .where('className', isEqualTo: classDisplay)
        .limit(1);
    final querySnapshot = await query.get();

    if (querySnapshot.docs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No timetable found for the selected class'),
        ),
      );
      return;
    }

    final docId = querySnapshot.docs.first.id; // Use existing document ID

    try {
      if (deleteEntireClass) {
        // Delete the entire class document from Firestore
        await timetablesCollection.doc(docId).delete();
        debugPrint('Deleted entire class timetable: $docId');
      } else {
        // Clear all cells in the timetable grid
        await timetablesCollection.doc(docId).set({
          'grid': List.generate(
            days.length,
            (index) => {'r': index, 'cells': []},
          ),
          'grid_meta': List.generate(
            days.length,
            (index) => {'r': index, 'cells': []},
          ),
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        debugPrint('Cleared all cells in timetable: $docId');
      }

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
    final canEdit = grid != null;
    final canDelete =
        selectedDepartment != null &&
        selectedClass != null &&
        timetableData[selectedDepartment]?[selectedClass]?.isNotEmpty == true;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Time Table'),
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search Time Table...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                onChanged: (v) => setState(() => searchText = v),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                          if (depMap is Map && depMap.isNotEmpty) {
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
                          if (classMap is Map && classMap.isNotEmpty)
                            initialClassName = (classMap['name'] as String?)
                                ?.toString();
                        } catch (_) {
                          initialClassName = null;
                        }
                      }

                      final existingLabels =
                          (selectedDepartment != null &&
                              selectedClass != null &&
                              classPeriods[selectedDepartment!] != null &&
                              classPeriods[selectedDepartment!]![selectedClass!] !=
                                  null)
                          ? classPeriods[selectedDepartment!]![selectedClass!]
                          : null;

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
                      await _applyCreatePayload(payload);
                    },
                  ),
                  Row(
                    children: [
                      SizedBox(
                        width:
                            100, // Adjusted width for consistency with the delete button
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
                        width: 100, // Adjusted width for better visibility
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
                    const SizedBox(width: 8),
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
    // Validate selection first
    if (selectedDepartment == null || selectedClass == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select Department and Class first')),
      );
      return;
    }

    // Directly export the entire class timetable (no dialog)
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
          if (grid == null || periods.isEmpty)
            pw.Padding(
              padding: const pw.EdgeInsets.only(top: 16),
              child: pw.Text(
                'No timetable data',
                style: pw.TextStyle(fontSize: 14),
              ),
            )
          else
            _pdfGridTable(periods: periods, grid: grid),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name:
          'timetable_${depKey}${classKey}${dateStr.replaceAll(':', '-')}.pdf',
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
}

// ------- Small UI helper widgets -------

class _TimetableGrid extends StatelessWidget {
  final List<String> days;
  final List<String> periods;
  final List<List<String>> timetable;
  final bool editing;
  final String? selectedLecturer;
  final List<Map<String, dynamic>> teachers;
  final void Function(int dayIndex, int periodIndex)? onCellTap;

  const _TimetableGrid({
    super.key,
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
                    }).toList(),
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