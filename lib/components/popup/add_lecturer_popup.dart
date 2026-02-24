//addd lecturer

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/lecturer.dart';
import '../../theme/super_admin_theme.dart';

class AddTeacherPopup extends StatefulWidget {
  final Teacher? teacher;
  final Map<String, String> facultyOptions; // facultyId -> facultyName

  const AddTeacherPopup({
    super.key,
    this.teacher,
    required this.facultyOptions,
  });

  @override
  State<AddTeacherPopup> createState() => _AddTeacherPopupState();
}

class _AddTeacherPopupState extends State<AddTeacherPopup> {
  final _formKey = GlobalKey<FormState>();
  final CollectionReference _usersCollection = FirebaseFirestore.instance
      .collection('users');
  String? _teacherName;
  String? _username;
  String? _password;
  String? _facultyId;
  bool _showPassword = false;
  String? _usernameError;
  String? _nameError;

  @override
  void initState() {
    super.initState();
    _teacherName = widget.teacher?.teacherName;
    _username = widget.teacher?.username;
    _password = widget.teacher?.password;
    _facultyId = widget.teacher?.facultyId;
    // Support legacy records where facultyId stored as faculty name.
    if (_facultyId != null &&
        _facultyId!.trim().isNotEmpty &&
        !widget.facultyOptions.containsKey(_facultyId)) {
      final match = widget.facultyOptions.entries.where((e) {
        return e.value.toLowerCase().trim() == _facultyId!.toLowerCase().trim();
      });
      if (match.isNotEmpty) {
        _facultyId = match.first.key;
      } else {
        _facultyId = null;
      }
    }
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
        color: titleColor.withOpacity(0.65),
        fontSize: fieldFontSize,
      ),
      labelStyle: TextStyle(
        color: titleColor.withOpacity(0.85),
        fontSize: fieldFontSize,
      ),
      border: OutlineInputBorder(
        borderRadius: fieldRadius,
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: fieldRadius,
        borderSide: BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: fieldRadius,
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
                  widget.teacher == null ? "Add Teacher" : "Edit Teacher",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  initialValue: _username,
                  decoration: input('').copyWith(labelText: 'Username'),
                  onChanged: (val) {
                    setState(() => _usernameError = null);
                    _username = val.trim();
                  },
                  validator: (val) {
                    final value = val?.trim() ?? '';
                    if (value.isEmpty) return "Enter username";
                    final regex = RegExp(r'^[a-zA-Z0-9]{3,20}$');
                    if (!regex.hasMatch(value)) {
                      return "min 3 characters, no spaces";
                    }
                    return null;
                  },
                ),
                if (_usernameError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _usernameError!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: _teacherName,
                  decoration: input('').copyWith(labelText: 'Lecturer Name'),
                  onChanged: (val) {
                    setState(() => _nameError = null);
                    _teacherName = val.trim();
                  },
                  validator: (val) {
                    final value = val?.trim() ?? '';
                    if (value.isEmpty) return "Enter lecturer name";
                    if (value.length < 3 || value.length > 100) {
                      return "Please enter a valid lecturer name (letters only).";
                    }
                    final regex = RegExp(r'^[A-Za-z ]+$');
                    if (!regex.hasMatch(value)) {
                      return "Please enter a valid lecturer name (letters only).";
                    }
                    return null;
                  },
                ),
                if (_nameError != null) ...[
                  const SizedBox(height: 8),
                  Text(_nameError!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _facultyId,
                  decoration: input('').copyWith(labelText: 'Faculty'),
                  dropdownColor: containerBg,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: fieldFontSize,
                  ),
                  items: widget.facultyOptions.entries
                      .map(
                        (entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(
                            entry.value,
                            style: TextStyle(
                              color: titleColor,
                              fontSize: fieldFontSize,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => _facultyId = val),
                  validator: (val) =>
                      val == null || val.isEmpty ? "Select faculty" : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: _password,
                  decoration: input('').copyWith(
                    labelText: 'Password',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showPassword ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () => setState(() {
                        _showPassword = !_showPassword;
                      }),
                    ),
                  ),
                  obscureText: !_showPassword,
                  onChanged: (val) => _password = val,
                  validator: (val) {
                    if (val == null || val.isEmpty) return "Enter password";
                    if (val.length < 6) return "min password 6 characters";
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
                          side: BorderSide(color: cancelBorderColor),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
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

                          final newUsername = _username!.trim();
                          final oldUsername = widget.teacher?.username;

                          if (oldUsername != newUsername) {
                            final existing = await _usersCollection
                                .where('username', isEqualTo: newUsername)
                                .limit(1)
                                .get();
                            if (existing.docs.isNotEmpty) {
                              setState(
                                () =>
                                    _usernameError = 'Username already exists',
                              );
                              return;
                            }
                          }

                          setState(() => _usernameError = null);
                          Navigator.of(context).pop(
                            Teacher(
                              id: widget.teacher?.id ?? '',
                              teacherName: _teacherName!,
                              username: newUsername,
                              password: _password!,
                              facultyId: _facultyId!,
                              createdAt:
                                  widget.teacher?.createdAt ?? DateTime.now(),
                            ),
                          );
                        },
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
