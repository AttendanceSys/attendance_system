//add admin

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/admin.dart';

class AddAdminPopup extends StatefulWidget {
  final Admin? admin;
  final List<String> facultyNames;

  const AddAdminPopup({super.key, this.admin, required this.facultyNames});

  @override
  State<AddAdminPopup> createState() => _AddAdminPopupState();
}

class _AddAdminPopupState extends State<AddAdminPopup> {
  final _formKey = GlobalKey<FormState>();
  final CollectionReference _usersCollection = FirebaseFirestore.instance
      .collection('users');
  String? _fullName;
  String? _facultyId;
  String? _password;
  String? _username;
  bool _isPasswordHidden = true;
  String? _usernameError;
  String? _fullNameError;

  @override
  void initState() {
    super.initState();
    _fullName = widget.admin?.fullName;
    _facultyId = widget.admin?.facultyId;
    _password = widget.admin?.password;
    _username = widget.admin?.username;
  }

  @override
  Widget build(BuildContext context) {
    final double dialogWidth = MediaQuery.of(context).size.width > 600
        ? 400
        : double.infinity;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final containerBg = isDark ? const Color(0xFF262C3A) : Colors.white;
    final borderColor = isDark ? const Color(0xFF3A404E) : Colors.blue[100]!;
    final titleColor = isDark ? const Color(0xFFE6EAF1) : null;
    final cancelTextColor = isDark ? const Color(0xFFE6EAF1) : Colors.black87;
    final cancelBorderColor = isDark ? const Color(0xFFE6EAF1) : Colors.black54;
    final saveBg = isDark ? const Color(0xFF0A1E90) : Colors.blue[900]!;

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
                  widget.admin == null ? "Add Admin" : "Edit Admin",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  initialValue: _username,
                  decoration: InputDecoration(
                    hintText: "Username",
                    border: isDark ? null : const OutlineInputBorder(),
                  ),
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
                const SizedBox(height: 24),
                TextFormField(
                  initialValue: _fullName,
                  decoration: InputDecoration(
                    hintText: "Full Name",
                    border: isDark ? null : const OutlineInputBorder(),
                  ),
                  onChanged: (val) {
                    setState(() => _fullNameError = null);
                    _fullName = val.trim();
                  },
                  validator: (val) {
                    final value = val?.trim() ?? '';
                    if (value.isEmpty) return "Enter full name";
                    if (value.length < 3 || value.length > 100) {
                      return "Please enter a valid admin name (letters only).";
                    }
                    final regex = RegExp(r'^[A-Za-z ]+$');
                    if (!regex.hasMatch(value)) {
                      return "Please enter a valid admin name (letters only).";
                    }
                    return null;
                  },
                ),
                if (_fullNameError != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _fullNameError!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _facultyId,
                  decoration: InputDecoration(
                    hintText: "Faculty Name",
                    border: isDark ? null : const OutlineInputBorder(),
                  ),
                  items: widget.facultyNames
                      .map(
                        (name) =>
                            DropdownMenuItem(value: name, child: Text(name)),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => _facultyId = val),
                  validator: (val) =>
                      val == null || val.isEmpty ? "Select faculty name" : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: _password,
                  decoration: InputDecoration(
                    hintText: "Password",
                    border: isDark ? null : const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordHidden
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () => setState(
                        () => _isPasswordHidden = !_isPasswordHidden,
                      ),
                    ),
                  ),
                  obscureText: _isPasswordHidden,
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

                          final newUsername = _username!.trim();
                          final oldUsername = widget.admin?.username;

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
                            Admin(
                              id: widget.admin?.id ?? '',
                              fullName: _fullName!,
                              facultyId: _facultyId!,
                              password: _password!,
                              username: newUsername,
                              createdAt: DateTime.now(),
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
