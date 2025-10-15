import 'package:flutter/material.dart';
import '../../models/admin.dart';
import 'success_snacbar.dart'; // <-- import your snackbar component

class AddAdminPopup extends StatefulWidget {
  final Admin? admin;
  final List<String> facultyNames;

  const AddAdminPopup({
    Key? key,
    this.admin,
    required this.facultyNames,
  }) : super(key: key);

  @override
  State<AddAdminPopup> createState() => _AddAdminPopupState();
}

class _AddAdminPopupState extends State<AddAdminPopup> {
  final _formKey = GlobalKey<FormState>();
  String? _adminId;
  String? _fullName;
  String? _facultyName;
  String? _password;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _adminId = widget.admin?.id;
    _fullName = widget.admin?.fullName;
    _facultyName = widget.admin?.facultyName;
    _password = widget.admin?.password;
  }

  @override
  Widget build(BuildContext context) {
    final double dialogWidth =
        MediaQuery.of(context).size.width > 600 ? 400 : double.infinity;

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
                  initialValue: _adminId,
                  decoration: const InputDecoration(
                    hintText: "Admin ID",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => _adminId = val,
                  validator: (val) =>
                      val == null || val.isEmpty ? "Enter admin ID" : null,
                ),
                const SizedBox(height: 16),
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
                  value: _facultyName,
                  decoration: const InputDecoration(
                    hintText: "Faculty Name",
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text("Select One"),
                    ),
                    ...widget.facultyNames.map(
                      (name) =>
                          DropdownMenuItem(value: name, child: Text(name)),
                    ),
                  ],
                  onChanged: (val) => setState(() => _facultyName = val),
                  validator: (val) =>
                      val == null || val.isEmpty ? "Select faculty name" : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: _password,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: "Password",
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                        color: Colors.grey[700],
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  onChanged: (val) => _password = val,
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return "Enter password";
                    }
                    if (val.length < 6) {
                      return "Password must be at least 6 characters";
                    }
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
                                id: _adminId!,
                                fullName: _fullName!,
                                facultyName: _facultyName!,
                                password: _password!,
                              ),
                            );
                            // Show success snackbar after saving
                            SuccessSnackbar.show(context, message: "Successfully Saved");
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