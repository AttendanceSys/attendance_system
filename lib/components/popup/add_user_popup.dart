import 'package:flutter/material.dart';
import '../../models/user.dart';

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
                  "Add User",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  decoration: const InputDecoration(
                    hintText: "Username",
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) =>
                      val == null || val.isEmpty ? "Enter username" : null,
                  onChanged: (val) => _username = val,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(
                    hintText: "Password",
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) =>
                      val == null || val.isEmpty ? "Enter password" : null,
                  obscureText: true,
                  onChanged: (val) => _password = val,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    hintText: "Role",
                    border: OutlineInputBorder(),
                  ),
                  items: ['teacher', 'admin', 'student', 'super_admin']
                      .map((role) =>
                          DropdownMenuItem(value: role, child: Text(role)))
                      .toList(),
                  onChanged: (val) => setState(() => _role = val),
                  validator: (val) =>
                      val == null || val.isEmpty ? "Select role" : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    hintText: "Status",
                    border: OutlineInputBorder(),
                  ),
                  items: ['active', 'inactive', 'disabled']
                      .map((status) =>
                          DropdownMenuItem(value: status, child: Text(status)))
                      .toList(),
                  onChanged: (val) => setState(() => _status = val),
                  validator: (val) =>
                      val == null || val.isEmpty ? "Select status" : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(
                    hintText: "Faculty ID (optional)",
                    border: OutlineInputBorder(),
                  ),
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