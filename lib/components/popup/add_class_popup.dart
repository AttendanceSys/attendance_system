import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/classes.dart';
import '../../services/session.dart';
import '../../theme/super_admin_theme.dart';

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
  final List<String> _sections = ['A', 'B', 'C', 'D', 'Custom', 'NONE'];
  String? _customSection;

  String get _combinedClassName {
    if ((_baseName ?? '').isEmpty) return '';
    // Do not append the section when the user selected 'NONE'
    if (_section != null && _section!.isNotEmpty && _section != 'NONE') {
      if (_section == 'Custom' &&
          _customSection != null &&
          _customSection!.isNotEmpty) {
        return "${_baseName!} ${_customSection!}";
      }
      return "${_baseName!} ${_section!}";
    }
    return _baseName!;
  }

  @override
  void initState() {
    super.initState();
    // If editing, split class name into base and section if possible
    if (widget.schoolClass != null) {
      // Prefer explicit section field if present
      final existingSection = widget.schoolClass!.section.trim() ?? '';
      if (existingSection.isNotEmpty) {
        if (_sections.contains(existingSection)) {
          _section = existingSection;
        } else {
          _section = 'Custom';
          _customSection = existingSection;
        }
        // derive base name from className by removing last token if it matches section
        final parts = widget.schoolClass!.className.split(' ');
        if (parts.length > 1) {
          final last = parts.last;
          if (last == existingSection || _sections.contains(last)) {
            _baseName = parts.sublist(0, parts.length - 1).join(' ');
          } else {
            _baseName = widget.schoolClass!.className;
          }
        } else {
          _baseName = widget.schoolClass!.className;
        }
      } else {
        final parts = widget.schoolClass!.className.split(' ');
        if (parts.length > 1 && _sections.contains(parts.last)) {
          _baseName = parts.sublist(0, parts.length - 1).join(' ');
          _section = parts.last;
        } else if (parts.length > 1) {
          // treat trailing token as custom section
          _baseName = parts.sublist(0, parts.length - 1).join(' ');
          _section = 'Custom';
          _customSection = parts.last;
        } else {
          _baseName = widget.schoolClass!.className;
        }
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
          section: (_section == 'Custom')
              ? (_customSection ?? 'NONE')
              : (_section ?? 'NONE'),
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

    final palette = Theme.of(context).extension<SuperAdminColors>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface =
        palette?.surface ?? (isDark ? const Color(0xFF262C3A) : Colors.white);
    final border =
        palette?.border ??
        (isDark ? const Color(0xFF3A404E) : Colors.blue[100]!);
    final textPrimary =
        palette?.textPrimary ?? (isDark ? Colors.white : Colors.black87);
    final textSecondary =
        palette?.textSecondary ??
        (isDark ? const Color(0xFFB5BDCB) : Colors.black54);
    final accent =
        palette?.accent ??
        (isDark ? const Color(0xFF0A1E90) : Colors.blue[900]!);
    final saveButtonBg = isDark
        ? const Color(0xFF4234A4)
        : const Color(0xFF8372FE);
    final inputFill =
        palette?.inputFill ?? (isDark ? const Color(0xFF2B303D) : Colors.white);

    InputDecoration input(String hint) {
      return InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: inputFill,
        border: OutlineInputBorder(borderSide: BorderSide(color: border)),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: accent, width: 1.4),
        ),
      );
    }

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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.schoolClass == null ? "Add Class" : "Edit Class",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  initialValue: _baseName,
                  decoration: input(
                    '',
                  ).copyWith(labelText: 'Base Class Name (e.g. B3SC)'),
                  onChanged: (val) {
                    final upper = val.toUpperCase();
                    setState(() => _baseName = upper);
                  },
                  validator: (val) {
                    final value = (val ?? '').trim();
                    if (value.isEmpty) return "Enter base class name";
                    String sectionSuffix = '';
                    if (_section != null &&
                        _section!.isNotEmpty &&
                        _section != 'NONE') {
                      if (_section == 'Custom') {
                        sectionSuffix =
                            _customSection != null && _customSection!.isNotEmpty
                            ? ' ${_customSection!}'
                            : '';
                      } else {
                        sectionSuffix = ' ${_section!}';
                      }
                    }
                    final combined = value.toUpperCase() + sectionSuffix;
                    final regex = RegExp(r'^[A-Z0-9]{3,10}( [A-Z0-9]{1,5})?$');
                    if (!regex.hasMatch(combined)) {
                      return "Invalid class name. Use uppercase letters/numbers and optional section.";
                    }
                    // If custom section selected, ensure custom value is provided
                    if (_section == 'Custom') {
                      final cs = (_customSection ?? '').trim().toUpperCase();
                      if (cs.isEmpty) return 'Enter custom section value';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _department,
                  decoration: input("Department"),
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
                  decoration: input("Section"),
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
                const SizedBox(height: 8),
                if (_section == 'Custom')
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        initialValue: _customSection,
                        decoration: input('Custom section (e.g. X)'),
                        onChanged: (v) =>
                            setState(() => _customSection = v.toUpperCase()),
                        validator: (v) {
                          if (_section != 'Custom') return null;
                          final s = (v ?? '').trim();
                          if (s.isEmpty) return 'Enter custom section';
                          final creg = RegExp(r'^[A-Z0-9]{1,5}$');
                          if (!creg.hasMatch(s.toUpperCase())) {
                            return 'Invalid section format';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                const SizedBox(height: 12),
                // Preview field
                if (_combinedClassName.isNotEmpty)
                  Text(
                    "Class Name: $_combinedClassName",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: textSecondary,
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
                          side: BorderSide(color: border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          minimumSize: const Size(90, 40),
                        ),
                        child: Text(
                          "Cancel",
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                            color: textPrimary,
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
