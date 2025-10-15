import 'package:flutter/material.dart';
import '../../models/classes.dart';

class AddClassPopup extends StatefulWidget {
  final SchoolClass? schoolClass;
  final List<String> departments;
  final List<String> sections;
  const AddClassPopup({
    super.key,
    this.schoolClass,
    required this.departments,
    required this.sections,
  });

  @override
  State<AddClassPopup> createState() => _AddClassPopupState();
}

class _AddClassPopupState extends State<AddClassPopup> {
  final _formKey = GlobalKey<FormState>();
  String? _baseName;
  String? _department;
  String? _section;

  String get _combinedClassName {
    if ((_baseName ?? '').isEmpty) return '';
    if (_section != null && _section!.isNotEmpty) {
      return "${_baseName!} ${_section!}";
    }
    return _baseName!;
  }

  @override
  void initState() {
    super.initState();
    // If editing, split class name into base and section if possible
    if (widget.schoolClass != null) {
      final parts = widget.schoolClass!.name.split(' ');
      if (parts.length > 1 && widget.sections.contains(parts.last)) {
        _baseName = parts.sublist(0, parts.length - 1).join(' ');
        _section = parts.last;
      } else {
        _baseName = widget.schoolClass!.name;
        _section = widget.schoolClass!.section;
      }
      _department = widget.schoolClass!.department;
    }
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      Navigator.of(context).pop(
        SchoolClass(
          name: _combinedClassName,
          department: _department!,
          section: _section ?? '',
          isActive: widget.schoolClass?.isActive ?? true,
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
                  onChanged: (val) => setState(() => _baseName = val),
                  validator: (val) =>
                      val == null || val.isEmpty ? "Enter base class name" : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _department,
                  decoration: const InputDecoration(
                    hintText: "Department",
                    border: OutlineInputBorder(),
                  ),
                  items: widget.departments
                      .map((dep) => DropdownMenuItem(
                            value: dep,
                            child: Text(dep),
                          ))
                      .toList(),
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
                  items: widget.sections
                      .map((sec) => DropdownMenuItem(
                            value: sec,
                            child: Text(sec.isNotEmpty ? sec : "(none)"),
                          ))
                      .toList(),
                  onChanged: (val) => setState(() => _section = val),
                  validator: (val) =>
                      val == null ? "Select section" : null,
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