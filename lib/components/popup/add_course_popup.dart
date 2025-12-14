import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/course.dart';
import '../../services/session.dart';

class AddCoursePopup extends StatefulWidget {
  final Course? course;
  const AddCoursePopup({super.key, this.course});

  @override
  State<AddCoursePopup> createState() => _AddCoursePopupState();
}

class _AddCoursePopupState extends State<AddCoursePopup> {
  final _formKey = GlobalKey<FormState>();
  String? _courseCode;
  String? _courseName;
  String? _departmentId;
  String? _lecturerId;
  String? _classId;
  String? _semester;
  bool _editingClassInactive = false;

  List<Map<String, String>> _teachers = [];
  List<Map<String, String>> _classes = []; // each entry: {id,name,department}
  List<Map<String, String>> _departments = [];
  String? _conflictMessage;

  @override
  void initState() {
    super.initState();
    if (widget.course != null) {
      _courseCode = widget.course!.courseCode;
      _courseName = widget.course!.courseName;
      _lecturerId = widget.course!.teacherRef;
      _classId = widget.course!.classRef;
      _semester = widget.course!.semester;
    }
    _fetchLookups();
  }

  bool _docMatchesSessionFaculty(Map<String, dynamic> data) {
    if (Session.facultyRef == null) return true;
    final sessionId = Session.facultyRef!.id;
    final sessionPath = '/${Session.facultyRef!.path}';

    final cand =
        data['faculty_ref'] ??
        data['faculty_id'] ??
        data['faculty'] ??
        data['facultyId'];
    if (cand == null) return false;
    if (cand is DocumentReference) return cand.id == sessionId;
    if (cand is String) {
      if (cand == sessionId) return true;
      if (cand == sessionPath) return true;
      final normalized = cand.startsWith('/') ? cand : '/$cand';
      if (normalized == sessionPath) return true;
      final parts = cand.split('/').where((p) => p.isNotEmpty).toList();
      if (parts.isNotEmpty && parts.last == sessionId) return true;
    }
    return false;
  }

  Future<void> _fetchLookups() async {
    try {
      final cq = FirebaseFirestore.instance.collection('classes');
      final dq = FirebaseFirestore.instance.collection('departments');

      // Fetch teachers and lookups. Prefer server-side filtered queries
      // when we have a Session.facultyRef to avoid returning all teachers.
      final teachersColl = FirebaseFirestore.instance.collection('teachers');
      List<QueryDocumentSnapshot> tDocs = [];

      if (Session.facultyRef == null) {
        final tSnap = await teachersColl.get();
        tDocs = tSnap.docs;
      } else {
        final sessionId = Session.facultyRef!.id;
        final sessionPath = '/${Session.facultyRef!.path}';

        // Run several equality queries to match the various shapes stored
        // in legacy data: DocumentReference, id string, or path string.
        final qResults = await Future.wait([
          // teachers where faculty_ref is stored as a DocumentReference
          teachersColl
              .where('faculty_ref', isEqualTo: Session.facultyRef)
              .get(),
          // teachers where faculty_id (or similar) stored as id string
          teachersColl.where('faculty_id', isEqualTo: sessionId).get(),
          // teachers where faculty_id stored as path string like '/faculties/xxx'
          teachersColl.where('faculty_id', isEqualTo: sessionPath).get(),
          // teachers where faculty stored as a path string like '/faculties/xxx'
          teachersColl.where('faculty', isEqualTo: sessionPath).get(),
          // teachers where faculty stored as the id string under 'faculty'
          teachersColl.where('faculty', isEqualTo: sessionId).get(),
        ]);

        final seen = <String>{};
        for (final snap in qResults) {
          for (final d in snap.docs) {
            if (seen.add(d.id)) tDocs.add(d);
          }
        }
        // If nothing matched the targeted queries, fall back to fetching all
        // teachers and applying the robust client-side matcher. This helps
        // when data uses unexpected field names or formats.
        if (tDocs.isEmpty) {
          final fallbackSnap = await teachersColl.get();
          tDocs = fallbackSnap.docs.where((d) {
            final data = d.data() as Map<String, dynamic>? ?? {};
            return _docMatchesSessionFaculty(data);
          }).toList();
        }
      }
      final cSnap = await cq.get();
      final dSnap = await dq.get();

      setState(() {
        // Build filtered departments first
        final allowedDepartments = dSnap.docs
            .map((d) => MapEntry(d.id, d.data() as Map<String, dynamic>? ?? {}))
            .where((entry) => _docMatchesSessionFaculty(entry.value))
            .where((entry) {
              final status = entry.value['status'];
              if (status is bool) return status;
              if (status is String) return status.toLowerCase() == 'active';
              return true;
            })
            .map(
              (entry) => {
                'id': entry.key,
                'name':
                    (entry.value['department_name'] ??
                            entry.value['name'] ??
                            '')
                        as String,
              },
            )
            .toList();

        final allowedDeptIds = allowedDepartments.map((d) => d['id']!).toSet();

        // Teachers: include only those matching the session faculty
        _teachers = tDocs.map((d) {
          final data = d.data() as Map<String, dynamic>? ?? {};
          final name = (data['teacher_name'] ?? data['name'] ?? '') as String;
          return {'id': d.id, 'name': name};
        }).toList();

        // Classes: include only classes that either declare the same faculty or belong to an allowed department
        bool editingClassInactive = false;
        _classes = cSnap.docs
            .map((d) {
              final data = d.data() as Map<String, dynamic>? ?? {};
              final status = data['status'];
              final isActive = () {
                if (status is bool) return status;
                if (status is String) {
                  final lowered = status.toLowerCase();
                  return lowered == 'true' || lowered == 'active';
                }
                return true;
              }();
              final name = (data['class_name'] ?? data['name'] ?? '') as String;
              final depRaw = data['department_ref'] is DocumentReference
                  ? (data['department_ref'] as DocumentReference).id
                  : (data['department_ref']?.toString() ?? '');
              final depId = depRaw.contains('/')
                  ? depRaw.split('/').where((p) => p.isNotEmpty).toList().last
                  : depRaw;
              final classMatchesFaculty = _docMatchesSessionFaculty(data);
              final isEditingExistingClass =
                  widget.course?.classRef != null &&
                  widget.course!.classRef == d.id;
              if (!classMatchesFaculty && !allowedDeptIds.contains(depId))
                return null;
              if (!isActive && !isEditingExistingClass) return null;
              if (isEditingExistingClass && !isActive) {
                editingClassInactive = true;
              }
              return {'id': d.id, 'name': name, 'department': depId};
            })
            .whereType<Map<String, String>>()
            .toList();

        // If editing, preselect department based on the existing class
        if (widget.course != null &&
            _departmentId == null &&
            _classId != null) {
          final match = _classes.firstWhere(
            (c) => c['id'] == _classId,
            orElse: () => {},
          );
          if (match.isNotEmpty) _departmentId = match['department'];
        }

        _departments = allowedDepartments;
        _editingClassInactive = editingClassInactive;
        if (_editingClassInactive) {
          // If the existing class is inactive, clear department selection
          // so the dropdown starts empty and shows only active departments.
          if (_departmentId != null &&
              _departments.every((d) => d['id'] != _departmentId)) {
            _departmentId = null;
          }
        } else {
          // Also clear if preselected department is not among active ones.
          if (_departmentId != null &&
              _departments.every((d) => d['id'] != _departmentId)) {
            _departmentId = null;
          }
        }
      });
    } catch (e) {
      print('Error fetching course lookups: $e');
    }
  }

  Future<void> _save() async {
    setState(() => _conflictMessage = null);
    if (!_formKey.currentState!.validate()) return;

    final normalizedCode = _courseCode!.trim().toUpperCase();
    final classId = _classId ?? '';
    if (classId.isNotEmpty) {
      try {
        final q = await FirebaseFirestore.instance
            .collection('courses')
            .where('course_code', isEqualTo: normalizedCode)
            .where('class', isEqualTo: classId)
            .get();
        final hasConflict = q.docs.any((d) => d.id != (widget.course?.id));
        if (hasConflict) {
          setState(() {
            _conflictMessage =
                'A lecturer is already assigned to this class for the same course code.';
          });
          return;
        }
      } catch (e) {
        // ignore
      }
    }

    final course = Course(
      id: widget.course?.id,
      courseCode: normalizedCode,
      courseName: _courseName!.trim(),
      teacherRef: _lecturerId,
      classRef: _classId,
      facultyRef: widget.course?.facultyRef,
      semester: _semester,
      createdAt: widget.course?.createdAt,
    );
    Navigator.of(context).pop(course);
  }

  @override
  Widget build(BuildContext context) {
    final double dialogWidth = MediaQuery.of(context).size.width > 600
        ? 400
        : MediaQuery.of(context).size.width * 0.95;

    return Dialog(
      elevation: 8,
      backgroundColor: Colors.transparent,
      child: Center(
        child: Container(
          width: dialogWidth,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.blue[100]!, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.course == null ? 'Add Course' : 'Edit Course',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    initialValue: _courseCode,
                    decoration: const InputDecoration(
                      hintText: 'Course code (e.g. MTH101)',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) =>
                        setState(() => _courseCode = v.toUpperCase()),
                    validator: (v) {
                      final value = v?.trim().toUpperCase() ?? '';
                      if (value.isEmpty) return 'Enter course code';
                      final regex = RegExp(r'^[A-Z0-9]{3,10}$');
                      if (!regex.hasMatch(value)) {
                        return 'Use 3-10 uppercase letters/numbers (no spaces)';
                      }
                      return null;
                    },
                  ),
                  if (_conflictMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _conflictMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: _courseName,
                    decoration: const InputDecoration(
                      hintText: 'Course name',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (v) => setState(() => _courseName = v),
                    validator: (v) {
                      final value = v?.trim() ?? '';
                      if (value.isEmpty) return 'Enter course name';
                      if (value.length < 3 || value.length > 100) {
                        return 'Please enter a valid course name (letters only).';
                      }
                      final regex = RegExp(r"^[A-Za-z .&'-]+$");
                      if (!regex.hasMatch(value)) {
                        return 'Please enter a valid course name (letters only).';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // Department dropdown (replaces faculty)
                  DropdownButtonFormField<String>(
                    value: _departmentId,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Department',
                    ),
                    items: _departments
                        .map(
                          (d) => DropdownMenuItem(
                            value: d['id'],
                            child: Text(d['name'] ?? ''),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() {
                      _departmentId = v;
                      // reset class selection when department changes
                      _classId = null;
                    }),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Select department' : null,
                  ),
                  const SizedBox(height: 16),
                  // Lecturer (was Teacher)
                  _teachers.isEmpty
                      ? DropdownButtonFormField<String>(
                          value: null,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Lecturer',
                          ),
                          items: [
                            DropdownMenuItem(
                              value: '',
                              enabled: false,
                              child: Text(
                                Session.facultyRef == null
                                    ? 'No teachers available'
                                    : 'No lecturers found for your faculty',
                              ),
                            ),
                          ],
                          onChanged: null,
                        )
                      : DropdownButtonFormField<String>(
                          value: _lecturerId,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Lecturer',
                          ),
                          items: _teachers
                              .map(
                                (t) => DropdownMenuItem(
                                  value: t['id'],
                                  child: Text(t['name'] ?? ''),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _lecturerId = v),
                        ),
                  const SizedBox(height: 16),
                  // Class dropdown - filtered by selected department
                  DropdownButtonFormField<String>(
                    value: _classId,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Class',
                    ),
                    items: _classes
                        .where(
                          (c) =>
                              _departmentId == null ||
                              (c['department'] ?? '') == _departmentId,
                        )
                        .map(
                          (c) => DropdownMenuItem(
                            value: c['id'],
                            child: Text(c['name'] ?? ''),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _classId = v),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _semester,
                    decoration: const InputDecoration(
                      hintText: 'Semester',
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(15, (i) => (i + 1).toString())
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setState(() => _semester = v),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Select semester' : null,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SizedBox(
                        height: 40,
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.black54),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            minimumSize: const Size(90, 40),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        height: 40,
                        child: ElevatedButton(
                          onPressed: _save,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[900],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            minimumSize: const Size(90, 40),
                          ),
                          child: const Text(
                            'Save',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
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
}
