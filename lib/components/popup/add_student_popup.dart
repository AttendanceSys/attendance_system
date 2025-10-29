import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/student.dart';
import '../../services/session.dart';

class AddStudentPopup extends StatefulWidget {
  final Student? student;
  const AddStudentPopup({super.key, this.student});

  @override
  State<AddStudentPopup> createState() => _AddStudentPopupState();
}

class _AddStudentPopupState extends State<AddStudentPopup> {
  final _formKey = GlobalKey<FormState>();
  String? _fullname;
  String? _username;
  String? _password;
  bool _obscurePassword = true;
  String _gender = 'Male';
  String? _departmentId;
  String? _classId;

  List<Map<String, String>> _departments = [];
  List<Map<String, String>> _classes = [];

  @override
  void initState() {
    super.initState();
    if (widget.student != null) {
      _fullname = widget.student!.fullname;
      _username = widget.student!.username;
      _password = widget.student!.password;
      _gender = widget.student!.gender;
      _departmentId = widget.student!.departmentRef;
      _classId = widget.student!.classRef;
    }
    _fetchDepartments();
    _fetchAllClasses();
  }

  String _extractId(dynamic cand) {
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

  Future<void> _fetchDepartments() async {
    try {
      Query dq = FirebaseFirestore.instance.collection('departments');
      if (Session.facultyRef != null) {
        try {
          dq = dq.where('faculty_ref', isEqualTo: Session.facultyRef);
        } catch (_) {
          // server-side filter may not apply if DB stores strings — we'll filter client-side below
        }
      }
      final snap = await dq.get();
      final docs = snap.docs;
      final items = <Map<String, String>>[];
      for (final d in docs) {
        final data = d.data() as Map<String, dynamic>;
        if (!_docMatchesSessionFaculty(data)) continue;
        final name = (data['department_name'] ?? data['name'] ?? '') as String;
        items.add({'id': d.id, 'name': name});
      }
      if (mounted) setState(() => _departments = items);
    } catch (e) {
      if (mounted) setState(() => _departments = []);
      // ignore errors but log
      // print('Error fetching departments: $e');
    }
  }

  Future<void> _fetchAllClasses() async {
    try {
      Query cq = FirebaseFirestore.instance.collection('classes');
      if (Session.facultyRef != null) {
        try {
          cq = cq.where('faculty_ref', isEqualTo: Session.facultyRef);
        } catch (_) {
          // fall back to client-side filtering
        }
      }
      final snap = await cq.get();
      final docs = snap.docs;
      final items = <Map<String, String>>[];
      for (final d in docs) {
        final data = d.data() as Map<String, dynamic>;
        if (!_docMatchesSessionFaculty(data)) continue;
        final name = (data['class_name'] ?? data['name'] ?? '') as String;
        final dep = data['department_ref'] is DocumentReference
            ? (data['department_ref'] as DocumentReference).id
            : (data['department_ref']?.toString() ?? '');
        items.add({'id': d.id, 'name': name, 'department': dep});
      }
      if (mounted) setState(() => _classes = items);
    } catch (e) {
      if (mounted) setState(() => _classes = []);
      // print('Error fetching classes: $e');
    }
  }

  List<Map<String, String>> get _filteredClassesByDepartment {
    if (_departmentId == null) return _classes;
    return _classes.where((c) => c['department'] == _departmentId).toList();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    String facultyId = widget.student?.facultyRef ?? '';
    if (Session.facultyRef != null) {
      facultyId = Session.facultyRef!.id;
    } else if (facultyId.isEmpty &&
        _departmentId != null &&
        _departmentId!.isNotEmpty) {
      try {
        final dep = await FirebaseFirestore.instance
            .collection('departments')
            .doc(_departmentId)
            .get();
        if (dep.exists) {
          final data = dep.data() as Map<String, dynamic>?;
          final cand = data == null
              ? null
              : (data['faculty_ref'] ??
                    data['faculty_id'] ??
                    data['faculty'] ??
                    data['facultyId']);
          if (cand != null) facultyId = _extractId(cand);
        }
      } catch (e) {
        // print('Error inferring faculty for student: $e');
      }
    }

    final student = Student(
      id: widget.student?.id,
      fullname: (_fullname ?? '').trim(),
      username: (_username ?? '').trim(),
      password: _password ?? '',
      gender: _gender,
      departmentRef: _departmentId,
      classRef: _classId,
      facultyRef: facultyId.isEmpty ? null : facultyId,
      createdAt: widget.student?.createdAt,
    );
    if (mounted) Navigator.of(context).pop(student);
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
                    widget.student == null ? 'Add Student' : 'Edit Student',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Row: Full name | Username
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: _fullname,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Full name',
                          ),
                          onChanged: (v) => setState(() => _fullname = v),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Enter full name'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          initialValue: _username,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Username',
                          ),
                          onChanged: (v) => setState(() => _username = v),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Enter username'
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Row: Gender | Department
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _gender,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            hintText: 'Gender',
                          ),
                          items: ['Male', 'Female']
                              .map(
                                (g) =>
                                    DropdownMenuItem(value: g, child: Text(g)),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _gender = v ?? 'Male'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
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
                            _classId = null;
                          }),
                          validator: (v) => v == null || v.isEmpty
                              ? 'Select department'
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<String>(
                    value: _classId,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Class',
                    ),
                    items: _filteredClassesByDepartment
                        .map(
                          (c) => DropdownMenuItem(
                            value: c['id'],
                            child: Text(c['name'] ?? ''),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _classId = v),
                    validator: (v) => null,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    initialValue: _password,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      hintText: 'Password',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                      ),
                    ),
                    onChanged: (v) => setState(() => _password = v),
                    validator: (v) =>
                        widget.student == null && (v == null || v.isEmpty)
                        ? 'Enter password'
                        : null,
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
                          onPressed: () async {
                            if (_formKey.currentState!.validate())
                              await _save();
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
      ),
    );
  }
}
