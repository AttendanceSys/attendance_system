import 'package:flutter/material.dart';
import '../../models/user_model.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final saveButtonBg = isDark
        ? const Color(0xFF4234A4)
        : const Color(0xFF8372FE);

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
                const Text(
                  "Edit Users",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  initialValue: _username,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
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
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    final value = val ?? '';
                    if (value.isEmpty) return "Enter password";
                    if (value.length < 6) return "min password 6 characters";
                    return null;
                  },
                  obscureText: true,
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
                          side: const BorderSide(color: Colors.black54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
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
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            Navigator.of(context).pop(
                              AppUser(
                                username: _username,
                                role: widget.user.role,
                                password: _password,
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
