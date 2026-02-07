import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../theme/super_admin_theme.dart';

class AddUserPopup extends StatefulWidget {
  const AddUserPopup({super.key});

  @override
  State<AddUserPopup> createState() => _AddUserPopupState();
}

class _AddUserPopupState extends State<AddUserPopup> {
  final _formKey = GlobalKey<FormState>();
  String? _username;
  String? _password;
  String? _role;
  String? _facultyId;
  String? _status;

  @override
  Widget build(BuildContext context) {
    final double dialogWidth = MediaQuery.of(context).size.width > 600
        ? 400
        : double.infinity;

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

    InputDecoration input(String hint) => InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: inputFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      hintStyle: TextStyle(color: textPrimary.withOpacity(0.65)),
      labelStyle: TextStyle(color: textPrimary.withOpacity(0.85)),
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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Add User",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  decoration: input("Username"),
                  validator: (val) =>
                      val == null || val.isEmpty ? "Enter username" : null,
                  onChanged: (val) => _username = val,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: input("Password"),
                  validator: (val) =>
                      val == null || val.isEmpty ? "Enter password" : null,
                  obscureText: true,
                  onChanged: (val) => _password = val,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: input("Role"),
                  dropdownColor: surface,
                  style: TextStyle(color: textPrimary),
                  items: ['teacher', 'admin', 'student', 'super_admin']
                      .map(
                        (role) =>
                            DropdownMenuItem(value: role, child: Text(role)),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => _role = val),
                  validator: (val) =>
                      val == null || val.isEmpty ? "Select role" : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: input("Status"),
                  dropdownColor: surface,
                  style: TextStyle(color: textPrimary),
                  items: ['active', 'inactive', 'disabled']
                      .map(
                        (status) => DropdownMenuItem(
                          value: status,
                          child: Text(status),
                        ),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => _status = val),
                  validator: (val) =>
                      val == null || val.isEmpty ? "Select status" : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: input("Faculty ID (optional)"),
                  onChanged: (val) => _facultyId = val,
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
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            Navigator.of(context).pop(
                              AppUser(
                                id: '',
                                username: _username!,
                                role: _role!,
                                password: _password!,
                                facultyId: _facultyId ?? '',
                                status: _status!,
                                createdAt: DateTime.now(),
                                updatedAt: DateTime.now(),
                              ),
                            );
                          }
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
