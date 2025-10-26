import 'package:flutter/material.dart';
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
  String? _fullName;
  String? _facultyId;
  String? _password;
  String? _username;

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
                  widget.admin == null ? "Add Admin" : "Edit Admin",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  initialValue: _fullName,
                  decoration: const InputDecoration(
                    hintText: "Full Name",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => _fullName = val,
                  validator: (val) =>
                      val == null || val.isEmpty ? "Enter full name" : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _facultyId,
                  decoration: const InputDecoration(
                    hintText: "Faculty Name",
                    border: OutlineInputBorder(),
                  ),
                  items: widget.facultyNames.map(
                    (name) =>
                        DropdownMenuItem(value: name, child: Text(name)),
                  ).toList(),
                  onChanged: (val) => setState(() => _facultyId = val),
                  validator: (val) =>
                      val == null || val.isEmpty ? "Select faculty name" : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: _password,
                  decoration: const InputDecoration(
                    hintText: "Password",
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  onChanged: (val) => _password = val,
                  validator: (val) =>
                      val == null || val.isEmpty ? "Enter password" : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: _username,
                  decoration: const InputDecoration(
                    hintText: "Username",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => _username = val,
                  validator: (val) =>
                      val == null || val.isEmpty ? "Enter username" : null,
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
                              Admin(
                                id: widget.admin?.id ?? '',
                                fullName: _fullName!,
                                facultyId: _facultyId!,
                                password: _password!,
                                username: _username!,
                                createdAt: DateTime.now(),
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