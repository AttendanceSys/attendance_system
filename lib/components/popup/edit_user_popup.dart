//edit user popup
import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../theme/super_admin_theme.dart';

class EditUserPopup extends StatefulWidget {
  final AppUser user;
  const EditUserPopup({super.key, required this.user});

  @override
  State<EditUserPopup> createState() => _EditUserPopupState();
}

class _EditUserPopupState extends State<EditUserPopup> {
  final _formKey = GlobalKey<FormState>();
  late String _username;
  late String _password;
  bool _isPasswordHidden = true;

  @override
  void initState() {
    super.initState();
    _username = widget.user.username;
    _password = widget.user.password;
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
                  "Edit User",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  initialValue: _username,
                  decoration: input("Username"),
                  validator: (val) {
                    final value = val?.trim() ?? '';
                    if (value.isEmpty) return "Enter username";
                    final regex = RegExp(r'^[a-zA-Z0-9]{3,20}$');
                    if (!regex.hasMatch(value)) {
                      return "min 3 characters, no spaces";
                    }
                    return null;
                  },
                  onChanged: (val) => _username = val,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: _password,
                  decoration: InputDecoration(
                    hintText: "Password",
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
                  validator: (val) {
                    final value = val ?? '';
                    if (value.isEmpty) return "Enter password";
                    if (value.length < 6) return "min password 6 characters";
                    return null;
                  },
                  obscureText: _isPasswordHidden,
                  onChanged: (val) => _password = val,
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
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            Navigator.of(context).pop(
                              AppUser(
                                id: widget.user.id,
                                username: _username,
                                role: widget.user.role,
                                password: _password,
                                facultyId: widget.user.facultyId,
                                status:
                                    widget.user.status, // Retain current status
                                createdAt: widget.user.createdAt,
                                updatedAt: DateTime.now(), // Updated timestamp
                              ),
                            );
                          }
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
