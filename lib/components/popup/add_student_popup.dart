import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/student.dart';
import '../../services/session.dart';
import '../../theme/super_admin_theme.dart';

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
  String? _gender;
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

  bool _isDepartmentActive(Map<String, dynamic> data) {
    final status = data['status'];
    if (status is bool) return status;
    if (status is String) return status.toLowerCase() == 'active';
    return true;
  }

  bool _isClassActive(Map<String, dynamic> data) {
    final status = data['status'];
    if (status is bool) return status; // true = active, false = inactive
    if (status is String) {
      final s = status.trim().toLowerCase();
      // Treat common inactive variants as inactive; allow only explicit active/true
      if (s == 'inactive' || s == 'in active' || s == 'false') return false;
      if (s == 'active' || s == 'true') return true;
    }
    // Default to active if status is missing/unknown to avoid over-filtering
    return true;
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
        // Only list active departments; inactive ones stay hidden.
        final isActive = _isDepartmentActive(data);
        if (!isActive) continue;
        final id = d.id;
        final name = (data['department_name'] ?? data['name'] ?? '') as String;
        items.add({'id': id, 'name': name});
      }
      if (mounted) {
        setState(() {
          _departments = items;
          if (_departmentId != null &&
              _departments.every((d) => d['id'] != _departmentId)) {
            _departmentId = null;
          }
        });
      }
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
      bool editingClassInactive = false;
      for (final d in docs) {
        final data = d.data() as Map<String, dynamic>;
        if (!_docMatchesSessionFaculty(data)) continue;
        // Include only active classes normally, but always include the
        // student's existing class when editing to avoid popup errors.
        final isActive = _isClassActive(data);
        final name = (data['class_name'] ?? data['name'] ?? '') as String;
        final dep = data['department_ref'] is DocumentReference
            ? (data['department_ref'] as DocumentReference).id
            : (data['department_ref']?.toString() ?? '');
        final id = d.id;
        final isEditingExistingClass =
            widget.student?.classRef != null && widget.student!.classRef == id;
        if (isActive || isEditingExistingClass) {
          items.add({'id': id, 'name': name, 'department': dep});
          if (isEditingExistingClass && !isActive) {
            editingClassInactive = true;
          }
        }
      }
      // If editing and the student's class wasn't captured due to scoping,
      // fetch and include it to keep the dropdown value valid.
      if (widget.student?.classRef != null &&
          items.every((e) => e['id'] != widget.student!.classRef)) {
        try {
          final cDoc = await FirebaseFirestore.instance
              .collection('classes')
              .doc(widget.student!.classRef)
              .get();
          if (cDoc.exists) {
            final data = cDoc.data() as Map<String, dynamic>;
            final name = (data['class_name'] ?? data['name'] ?? '').toString();
            final dep = data['department_ref'] is DocumentReference
                ? (data['department_ref'] as DocumentReference).id
                : (data['department_ref']?.toString() ?? '');
            items.add({'id': cDoc.id, 'name': name, 'department': dep});
            if (!editingClassInactive && !_isClassActive(data)) {
              editingClassInactive = true;
            }
          }
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _classes = items;
          if (editingClassInactive) {
            _departmentId = null;
          }
        });
        if (editingClassInactive) {
          await _fetchDepartments();
        }
      }
    } catch (e) {
      if (mounted) setState(() => _classes = []);
      // print('Error fetching classes: $e');
    }
  }

  List<Map<String, String>> get _filteredClassesByDepartment {
    if (_departmentId == null) return _classes;
    return _classes.where((c) => c['department'] == _departmentId).toList();
  }

  List<String> _missingRequiredFields() {
    final missing = <String>[];
    if ((_username ?? '').trim().isEmpty) missing.add('Username');
    if ((_fullname ?? '').trim().isEmpty) missing.add('Full name');
    if ((_password ?? '').trim().isEmpty) missing.add('Password');
    if ((_gender ?? '').trim().isEmpty) missing.add('Gender');
    if ((_departmentId ?? '').trim().isEmpty) missing.add('Department');
    if ((_classId ?? '').trim().isEmpty) missing.add('Class');
    return missing;
  }

  Future<void> _showMissingFieldsDialog(List<String> missingFields) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Missing required fields'),
        content: Text(
          'Please fill the following: ${missingFields.join(', ')}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final missing = _missingRequiredFields();
    if (missing.isNotEmpty) {
      _formKey.currentState?.validate();
      await _showMissingFieldsDialog(missing);
      return;
    }

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
          final data = dep.data();
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
      gender: _gender ?? 'Male',
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

    final palette = Theme.of(context).extension<SuperAdminColors>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface =
        palette?.surface ?? (isDark ? const Color(0xFF262C3A) : Colors.white);
    final border =
        palette?.border ??
        (isDark ? const Color(0xFF3A404E) : Colors.blue[100]!);
    final textPrimary =
        palette?.textPrimary ?? (isDark ? Colors.white : Colors.black87);
    final accent =
        palette?.accent ??
        (isDark ? const Color(0xFF0A1E90) : Colors.blue[900]!);
    final saveButtonBg = isDark
        ? const Color(0xFF4234A4)
        : const Color(0xFF8372FE);
    final inputFill =
        palette?.inputFill ?? (isDark ? const Color(0xFF2B303D) : Colors.white);

    final fieldRadius = BorderRadius.circular(10);

    const double fieldFontSize = 16;

    InputDecoration input(String hint) => InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: inputFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: TextStyle(
        color: textPrimary.withOpacity(0.65),
        fontSize: fieldFontSize,
      ),
      labelStyle: TextStyle(
        color: textPrimary.withOpacity(0.85),
        fontSize: fieldFontSize,
      ),
      border: OutlineInputBorder(
        borderRadius: fieldRadius,
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: fieldRadius,
        borderSide: BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: fieldRadius,
        borderSide: BorderSide(color: accent, width: 1.4),
      ),
    );
    return Dialog(
      elevation: 8,
      backgroundColor: Colors.transparent,
      child: Center(
        child: Container(
          width: dialogWidth,
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border, width: 2),
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
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Row: Username | Full name
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: _username,
                          decoration: input('').copyWith(labelText: 'Username'),
                          onChanged: (v) => setState(() => _username = v),
                          validator: (v) {
                            final value = v?.trim() ?? '';
                            if (value.isEmpty) return 'Enter username';
                            final regex = RegExp(r'^[a-zA-Z0-9]{3,20}$');
                            if (!regex.hasMatch(value)) {
                              return 'min 3 characters, no spaces';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          initialValue: _fullname,
                          decoration: input(
                            '',
                          ).copyWith(labelText: 'Full name'),
                          onChanged: (v) => setState(() => _fullname = v),
                          validator: (v) {
                            final value = v?.trim() ?? '';
                            if (value.isEmpty) return 'Enter full name';
                            if (value.length < 3 || value.length > 100) {
                              return 'Please enter a valid name (letters only).';
                            }
                            final regex = RegExp(r'^[A-Za-z ]+$');
                            if (!regex.hasMatch(value)) {
                              return 'Please enter a valid name (letters only).';
                            }
                            return null;
                          },
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
                          decoration: input('').copyWith(labelText: 'Gender'),
                          dropdownColor: surface,
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: fieldFontSize,
                          ),
                          items: ['Male', 'Female']
                              .map(
                                (g) =>
                                    DropdownMenuItem(
                                      value: g,
                                      child: Text(
                                        g,
                                        style: TextStyle(
                                          color: textPrimary,
                                          fontSize: fieldFontSize,
                                        ),
                                      ),
                                    ),
                              )
                              .toList(),
                          onChanged: (v) => setState(() => _gender = v),
                          validator: (v) =>
                              v == null || v.isEmpty ? 'Select gender' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _departmentId,
                          decoration:
                              input('').copyWith(labelText: 'Department'),
                          isExpanded: true,
                          dropdownColor: surface,
                          style: TextStyle(
                            color: textPrimary,
                            fontSize: fieldFontSize,
                          ),
                          items: _departments
                              .map(
                                (d) => DropdownMenuItem(
                                  value: d['id'],
                                  child: Text(
                                    d['name'] ?? '',
                                    style: TextStyle(
                                      color: textPrimary,
                                      fontSize: fieldFontSize,
                                    ),
                                  ),
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
                    decoration: input('').copyWith(labelText: 'Class'),
                    dropdownColor: surface,
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: fieldFontSize,
                    ),
                    items: _filteredClassesByDepartment
                        .map(
                          (c) => DropdownMenuItem(
                            value: c['id'],
                            child: Text(
                              c['name'] ?? '',
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: fieldFontSize,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _classId = v),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Select class' : null,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    initialValue: _password,
                    obscureText: _obscurePassword,
                    decoration: input('').copyWith(
                      labelText: 'Password',
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
                    validator: (v) {
                      final value = v ?? '';
                      if (value.isEmpty) return 'Enter password';
                      if (value.length < 6) return 'min password 6 characters';
                      return null;
                    },
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
                            side: BorderSide(color: border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            minimumSize: const Size(90, 40),
                          ),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: textPrimary,
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
                            backgroundColor: saveButtonBg,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
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
