import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/department.dart';
import '../../services/session.dart';

class AddDepartmentPopup extends StatefulWidget {
  final Department? department;
  final List<String> statusOptions;

  const AddDepartmentPopup({
    super.key,
    this.department,
    required this.statusOptions,
  });

  @override
  State<AddDepartmentPopup> createState() => _AddDepartmentPopupState();
}

class _AddDepartmentPopupState extends State<AddDepartmentPopup> {
  final _formKey = GlobalKey<FormState>();
  final CollectionReference _departmentsCollection = FirebaseFirestore.instance
      .collection('departments');
  String? _name;
  String? _code;
  String? _head;
  List<Map<String, String>> _teachers = []; // {id, name}
  String? _codeError;
  String? _nameError;
  String? _headError;

  @override
  void initState() {
    super.initState();
    _name = widget.department?.name;
    _code = widget.department?.code;
    _head = widget.department?.head;
    _fetchTeachers();
  }

  Future<void> _fetchTeachers() async {
    final coll = FirebaseFirestore.instance.collection('teachers');
    List<QueryDocumentSnapshot> docs = [];

    try {
      if (Session.facultyRef == null) {
        // super-admin: return all teachers
        final snapshot = await coll.get();
        docs = snapshot.docs;
      } else {
        final sessionId = Session.facultyRef!.id;
        final sessionPath = '/${Session.facultyRef!.path}';

        // Run several equality queries to match various legacy shapes
        final qResults = await Future.wait([
          coll.where('faculty_ref', isEqualTo: Session.facultyRef).get(),
          coll.where('faculty_id', isEqualTo: sessionId).get(),
          // match faculty_id stored as path string '/faculties/xxx'
          coll.where('faculty_id', isEqualTo: sessionPath).get(),
          coll.where('faculty', isEqualTo: sessionPath).get(),
          coll.where('faculty', isEqualTo: sessionId).get(),
        ]);

        final seen = <String>{};
        for (final snap in qResults) {
          for (final d in snap.docs) {
            if (seen.add(d.id)) docs.add(d);
          }
        }
        // If our targeted queries returned nothing, fall back to fetching all
        // teachers and filter client-side using the existing heuristics.
        if (docs.isEmpty) {
          final fallback = await coll.get();
          docs = fallback.docs.where((doc) {
            final data = (doc.data() as Map<String, dynamic>?) ?? {};
            // reuse the same matching logic as before by constructing the
            // Session-aware checks inline (this file doesn't have the
            // _docMatchesSessionFaculty helper). We'll approximate by
            // checking faculty_ref/faculty_id/faculty fields for id/path.
            final sessionId = Session.facultyRef!.id;
            final sessionPath = '/${Session.facultyRef!.path}';
            final cand =
                data['faculty_ref'] ?? data['faculty_id'] ?? data['faculty'];
            if (cand == null) return false;
            if (cand is DocumentReference) return cand.id == sessionId;
            if (cand is String) {
              if (cand == sessionId) return true;
              if (cand == sessionPath) return true;
              if (cand.startsWith('/') && cand == sessionPath) return true;
              final parts = cand.split('/').where((p) => p.isNotEmpty).toList();
              if (parts.isNotEmpty && parts.last == sessionId) return true;
            }
            return false;
          }).toList();
        }
      }
    } catch (e, st) {
      // ensure we still update the UI even on error
      // ignore: avoid_print
      print('Error fetching teachers in AddDepartmentPopup: $e\n$st');
      docs = [];
    }

    // Update UI from the fetched/filtered docs
    setState(() {
      _teachers = docs.map((doc) {
        final data = (doc.data() as Map<String, dynamic>?) ?? {};
        return {
          'id': doc.id,
          'name': (data['teacher_name'] ?? data['name'] ?? '') as String,
        };
      }).toList();

      // If editing and existing head is a name, try to resolve to id
      final existingHead = widget.department?.head;
      if (existingHead != null && existingHead.isNotEmpty) {
        if (_teachers.any((t) => t['id'] == existingHead)) {
          _head = existingHead;
        } else {
          final match = _teachers.firstWhere(
            (t) =>
                (t['name'] ?? '').toLowerCase() == existingHead.toLowerCase(),
            orElse: () => <String, String>{},
          );
          if (match.isNotEmpty) _head = match['id'];
        }
      }
    });
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.department == null
                      ? 'Add Department'
                      : 'Edit Department',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  initialValue: _code,
                  decoration: const InputDecoration(
                    hintText: 'Department Code',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                    setState(() => _codeError = null);
                    _code = val;
                  },
                  validator: (val) {
                    final raw = val?.trim() ?? '';
                    if (raw.isEmpty) return 'Enter department code';
                    final upper = raw.toUpperCase();
                    final regex = RegExp(r'^(?![0-9]+$)[A-Z0-9]{3,8}$');
                    if (!regex.hasMatch(upper)) {
                      return 'Invalid department code. Use uppercase, no spaces.';
                    }
                    _code = upper;
                    return null;
                  },
                ),
                if (_codeError != null) ...[
                  const SizedBox(height: 8),
                  Text(_codeError!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: _name,
                  decoration: const InputDecoration(
                    hintText: 'Department Name',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                    setState(() => _nameError = null);
                    _name = val;
                  },
                  validator: (val) {
                    final value = val?.trim() ?? '';
                    if (value.isEmpty) return 'Enter department name';
                    if (value.length < 3 || value.length > 100) {
                      return 'Invalid department name. Use letters only';
                    }
                    final regex = RegExp(r"^[A-Za-z .\-'&]+$");
                    if (!regex.hasMatch(value)) {
                      return 'Invalid department name. Use letters only';
                    }
                    _name = value;
                    return null;
                  },
                ),
                if (_nameError != null) ...[
                  const SizedBox(height: 8),
                  Text(_nameError!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 16),
                _teachers.isEmpty
                    ? DropdownButtonFormField<String>(
                        value: null,
                        decoration: const InputDecoration(
                          hintText: 'Head of Department',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: '',
                            enabled: false,
                            child: Text(
                              Session.facultyRef == null
                                  ? 'No teachers available'
                                  : 'No teachers found for your faculty',
                            ),
                          ),
                        ],
                        onChanged: null,
                        validator: (val) => val == null || val.isEmpty
                            ? 'Select head of department'
                            : null,
                      )
                    : DropdownButtonFormField<String>(
                        value: _head,
                        decoration: const InputDecoration(
                          hintText: 'Head of Department',
                          border: OutlineInputBorder(),
                        ),
                        items: _teachers.map((t) {
                          final id = t['id'] ?? '';
                          final name = t['name'] ?? '';
                          return DropdownMenuItem(value: id, child: Text(name));
                        }).toList(),
                        onChanged: (val) => setState(() {
                          _headError = null;
                          _head = val;
                        }),
                        validator: (val) => val == null || val.isEmpty
                            ? 'Select head of department'
                            : null,
                      ),
                if (_headError != null) ...[
                  const SizedBox(height: 8),
                  Text(_headError!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 16),
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
                        onPressed: () async {
                          if (!_formKey.currentState!.validate()) return;

                          final code = (_code ?? '').trim().toUpperCase();
                          final name = (_name ?? '').trim();
                          final head = (_head ?? '').trim();
                          final excludeId = widget.department?.id;

                          Query query = _departmentsCollection.where(
                            'department_code',
                            isEqualTo: code,
                          );
                          Query altQuery = _departmentsCollection.where(
                            'code',
                            isEqualTo: code,
                          );
                          Query nameQuery = _departmentsCollection.where(
                            'department_name',
                            isEqualTo: name,
                          );
                          Query altNameQuery = _departmentsCollection.where(
                            'name',
                            isEqualTo: name,
                          );
                          Query headQuery = _departmentsCollection.where(
                            'head_of_department',
                            isEqualTo: head,
                          );
                          Query altHeadQuery = _departmentsCollection.where(
                            'head',
                            isEqualTo: head,
                          );
                          if (Session.facultyRef != null) {
                            query = query.where(
                              'faculty_ref',
                              isEqualTo: Session.facultyRef,
                            );
                            altQuery = altQuery.where(
                              'faculty_ref',
                              isEqualTo: Session.facultyRef,
                            );
                            nameQuery = nameQuery.where(
                              'faculty_ref',
                              isEqualTo: Session.facultyRef,
                            );
                            altNameQuery = altNameQuery.where(
                              'faculty_ref',
                              isEqualTo: Session.facultyRef,
                            );
                            headQuery = headQuery.where(
                              'faculty_ref',
                              isEqualTo: Session.facultyRef,
                            );
                            altHeadQuery = altHeadQuery.where(
                              'faculty_ref',
                              isEqualTo: Session.facultyRef,
                            );
                          }

                          final results = await Future.wait([
                            query.get(),
                            altQuery.get(),
                            nameQuery.get(),
                            altNameQuery.get(),
                            headQuery.get(),
                            altHeadQuery.get(),
                          ]);

                          final codeExists =
                              results[0].docs.any((d) => d.id != excludeId) ||
                              results[1].docs.any((d) => d.id != excludeId);

                          final nameExists =
                              results[2].docs.any((d) => d.id != excludeId) ||
                              results[3].docs.any((d) => d.id != excludeId);

                          final headExists =
                              results[4].docs.any((d) => d.id != excludeId) ||
                              results[5].docs.any((d) => d.id != excludeId);

                          if (codeExists || nameExists || headExists) {
                            setState(() {
                              _codeError = codeExists
                                  ? 'Department code already exists'
                                  : null;
                              _nameError = nameExists
                                  ? 'Department name already exists'
                                  : null;
                              _headError = headExists
                                  ? 'This lecturer is already head of another department.'
                                  : null;
                            });
                            return;
                          }

                          setState(() {
                            _codeError = null;
                            _nameError = null;
                            _headError = null;
                          });

                          Navigator.of(context).pop(
                            Department(
                              code: code,
                              name: _name!,
                              head: _head!,
                              status: widget.department?.status ?? 'Active',
                            ),
                          );
                        },
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
    );
  }
}
