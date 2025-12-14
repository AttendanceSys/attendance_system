import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/classes.dart';
import '../../services/session.dart';

class AddClassPopup extends StatefulWidget {
  final SchoolClass? schoolClass;
  const AddClassPopup({super.key, this.schoolClass});

  @override
  State<AddClassPopup> createState() => _AddClassPopupState();
}

class _AddClassPopupState extends State<AddClassPopup> {
  final _formKey = GlobalKey<FormState>();
  String? _baseName;
  String? _department; // stores department doc id
  String? _section;
  List<Map<String, String>> _departments = []; // {id, name}
  final List<String> _sections = ['A', 'B', 'C', 'D', 'NONE'];

  String get _combinedClassName {
    if ((_baseName ?? '').isEmpty) return '';
    // Do not append the section when the user selected 'NONE'
    if (_section != null && _section!.isNotEmpty && _section != 'NONE') {
      return "${_baseName!} ${_section!}";
    }
    return _baseName!;
  }

  @override
  void initState() {
    super.initState();
    // If editing, split class name into base and section if possible
    if (widget.schoolClass != null) {
      final parts = widget.schoolClass!.className.split(' ');
      if (parts.length > 1 && _sections.contains(parts.last)) {
        _baseName = parts.sublist(0, parts.length - 1).join(' ');
        _section = parts.last;
      } else {
        _baseName = widget.schoolClass!.className;
        _section = widget.schoolClass!.section;
      }
      _department = widget.schoolClass!.departmentRef;
    }
    _fetchDepartments();
  }

  Future<void> _fetchDepartments() async {
    try {
      Query q = FirebaseFirestore.instance.collection('departments');
      if (Session.facultyRef != null) {
        q = q.where('faculty_ref', isEqualTo: Session.facultyRef);
      }
      final snapshot = await q.get();
      setState(() {
        _departments = snapshot.docs
            .map((doc) {
              final data = doc.data() as Map<String, dynamic>?;
              final status = data?['status'];
              final isActive = status is bool
                  ? status
                  : status is String
                  ? status.toLowerCase() == 'active'
                  : true;
              if (!isActive) return null;
              final name =
                  (data?['department_name'] ?? data?['name'] ?? '') as String;
              return {'id': doc.id, 'name': name};
            })
            .whereType<Map<String, String>>()
            .toList();
        // Try to resolve existing department value (if editing)
        if (widget.schoolClass != null && _department != null) {
          final exists = _departments.any((d) => d['id'] == _department);
          if (!exists) {
            // leave null so user selects a valid department
            _department = null;
          }
        }
      });
    } catch (e) {
      print('Error fetching departments: $e');
    }
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop(
        SchoolClass(
          id: widget.schoolClass?.id,
          className: _combinedClassName,
          departmentRef: _department!,
          section: _section ?? 'NONE',
          status: widget.schoolClass?.status ?? true,
          createdAt: widget.schoolClass?.createdAt,
        ),
      );
    }
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
                  widget.schoolClass == null ? "Add Class" : "Edit Class",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  initialValue: _baseName,
                  decoration: const InputDecoration(
                    hintText: "Base Class Name (e.g. B3SC)",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                    final upper = val.toUpperCase();
                    setState(() => _baseName = upper);
                  },
                  validator: (val) {
                    final value = (val ?? '').trim();
                    if (value.isEmpty) return "Enter base class name";
                    final sectionSuffix =
                        (_section != null &&
                            _section!.isNotEmpty &&
                            _section != 'NONE')
                        ? " ${_section!}"
                        : '';
                    final combined = value.toUpperCase() + sectionSuffix;
                    final regex = RegExp(r'^[A-Z0-9]{3,10}( [A-Z])?$');
                    if (!regex.hasMatch(combined)) {
                      return "Invalid class name. Use uppercase and numbers only.";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _department,
                  decoration: const InputDecoration(
                    hintText: "Department",
                    border: OutlineInputBorder(),
                  ),
                  items: _departments.map((d) {
                    return DropdownMenuItem(
                      value: d['id'],
                      child: Text(d['name'] ?? ''),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _department = val),
                  validator: (val) =>
                      val == null || val.isEmpty ? "Select department" : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _section,
                  decoration: const InputDecoration(
                    hintText: "Section",
                    border: OutlineInputBorder(),
                  ),
                  items: _sections
                      .map(
                        (sec) => DropdownMenuItem(
                          value: sec,
                          child: Text(sec == 'NONE' ? '(none)' : sec),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => _section = val),
                  validator: (val) => val == null ? "Select section" : null,
                ),
                const SizedBox(height: 12),
                // Preview field
                if (_combinedClassName.isNotEmpty)
                  Text(
                    "Class Name: $_combinedClassName",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
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
                          "Cancel",
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
                          "Save",
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
