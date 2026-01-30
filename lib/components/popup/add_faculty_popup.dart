//add faculty

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/faculty.dart';
import '../../theme/super_admin_theme.dart';

class AddFacultyPopup extends StatefulWidget {
  final Faculty? faculty;
  const AddFacultyPopup({super.key, this.faculty});

  @override
  State<AddFacultyPopup> createState() => _AddFacultyPopupState();
}

class _AddFacultyPopupState extends State<AddFacultyPopup> {
  final _formKey = GlobalKey<FormState>();
  final CollectionReference _facultiesCollection = FirebaseFirestore.instance
      .collection('faculties');
  String? _facultyCode;
  String? _facultyName;
  DateTime? _establishmentDate;
  String? _codeError;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    _facultyCode = widget.faculty?.code;
    _facultyName = widget.faculty?.name;
    _establishmentDate = widget.faculty?.establishmentDate;
  }

  @override
  Widget build(BuildContext context) {
    final double dialogWidth = MediaQuery.of(context).size.width > 600
        ? 400
        : double.infinity;

    final palette = Theme.of(context).extension<SuperAdminColors>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final containerBg =
        palette?.surface ?? (isDark ? const Color(0xFF262C3A) : Colors.white);
    final borderColor =
        palette?.border ??
        (isDark ? const Color(0xFF3A404E) : Colors.blue[100]!);
    final titleColor =
        palette?.textPrimary ??
        (isDark ? const Color(0xFFE6EAF1) : Colors.black87);
    final cancelTextColor =
        palette?.textPrimary ??
        (isDark ? const Color(0xFFE6EAF1) : Colors.black87);
    final cancelBorderColor =
        palette?.border ?? (isDark ? const Color(0xFFE6EAF1) : Colors.black54);
    final saveBg =
        palette?.accent ??
        (isDark ? const Color(0xFF0A1E90) : Colors.blue[900]!);
    final inputFill =
        palette?.inputFill ?? (isDark ? const Color(0xFF2B303D) : Colors.white);

    InputDecoration input(String hint) => InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: inputFill,
      border: OutlineInputBorder(borderSide: BorderSide(color: borderColor)),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: saveBg, width: 1.4),
      ),
    );

    return Dialog(
      elevation: 8,
      backgroundColor: Colors.transparent,
      child: Center(
        child: Container(
          width: dialogWidth,
          decoration: BoxDecoration(
            color: containerBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: 2),
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
                  widget.faculty == null ? "Add Faculty" : "Edit Faculty",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  initialValue: _facultyCode,
                  decoration: input('').copyWith(labelText: 'Faculty Code'),
                  onChanged: (val) {
                    setState(() => _codeError = null);
                    _facultyCode = val.trim();
                  },
                  validator: (val) {
                    final raw = val?.trim() ?? '';
                    if (raw.isEmpty) return "Enter faculty code";
                    final upper = raw.toUpperCase();
                    final regex = RegExp(r'^(?![0-9]+$)[A-Z0-9]{3,8}$');
                    if (!regex.hasMatch(upper)) {
                      return "Invalid faculty code. Use uppercase, no spaces.";
                    }
                    _facultyCode = upper;
                    return null;
                  },
                ),
                if (_codeError != null) ...[
                  const SizedBox(height: 8),
                  Text(_codeError!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: _facultyName,
                  decoration: input('').copyWith(labelText: 'Faculty Name'),
                  onChanged: (val) {
                    setState(() => _nameError = null);
                    _facultyName = val.trim();
                  },
                  validator: (val) {
                    final value = val?.trim() ?? '';
                    if (value.isEmpty) return "Enter faculty name";
                    if (value.length < 3 || value.length > 100) {
                      return "Please enter a valid faculty name.";
                    }
                    final regex = RegExp(r'^[A-Za-z &-]+$');
                    if (!regex.hasMatch(value)) {
                      return "Please enter a valid faculty name.";
                    }
                    return null;
                  },
                ),
                if (_nameError != null) ...[
                  const SizedBox(height: 8),
                  Text(_nameError!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () async {
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: _establishmentDate ?? DateTime.now(),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (pickedDate != null) {
                      setState(() {
                        _establishmentDate = pickedDate;
                      });
                    }
                  },
                  child: AbsorbPointer(
                    child: TextFormField(
                      decoration: InputDecoration(
                        hintText: "Establishment Date",
                        filled: true,
                        fillColor: inputFill,
                        border: OutlineInputBorder(
                          borderSide: BorderSide(color: borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: saveBg, width: 1.4),
                        ),
                        suffixIcon: const Icon(Icons.calendar_today),
                      ),
                      controller: TextEditingController(
                        text: _establishmentDate == null
                            ? ""
                            : "${_establishmentDate!.year}-${_establishmentDate!.month.toString().padLeft(2, '0')}-${_establishmentDate!.day.toString().padLeft(2, '0')}",
                      ),
                      validator: (val) => _establishmentDate == null
                          ? "Select establishment date"
                          : null,
                    ),
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
                          side: BorderSide(color: cancelBorderColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          minimumSize: const Size(90, 40),
                        ),
                        child: Text(
                          "Cancel",
                          style: TextStyle(
                            color: cancelTextColor,
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
                          final code = _facultyCode!.trim().toUpperCase();
                          final name = _facultyName!.trim();
                          final excludeId = widget.faculty?.id;

                          final codeSnap = await _facultiesCollection
                              .where('faculty_code', isEqualTo: code)
                              .get();
                          final nameSnap = await _facultiesCollection
                              .where('faculty_name', isEqualTo: name)
                              .get();

                          final codeExists = codeSnap.docs.any(
                            (d) => d.id != excludeId,
                          );
                          final nameExists = nameSnap.docs.any(
                            (d) => d.id != excludeId,
                          );

                          if (codeExists || nameExists) {
                            setState(() {
                              _codeError = codeExists
                                  ? 'Faculty code already exists'
                                  : null;
                              _nameError = nameExists
                                  ? 'Faculty name already exists'
                                  : null;
                            });
                            return;
                          }

                          setState(() {
                            _codeError = null;
                            _nameError = null;
                          });
                          Navigator.of(context).pop(
                            Faculty(
                              id: widget.faculty?.id ?? '',
                              code: code,
                              name: name,
                              createdAt: DateTime.now(),
                              establishmentDate: _establishmentDate!,
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: saveBg,
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
