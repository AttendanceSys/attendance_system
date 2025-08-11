import 'package:flutter/material.dart';

class AddAdminPopupDemoPage extends StatelessWidget {
  const AddAdminPopupDemoPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Admin Popup Demo')),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final result = await showDialog(
              context: context,
              builder: (context) => AddAdminPopup(
                faculties: ["Science", "Arts", "Commerce", "Engineering"],
              ),
            );
            if (result != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    "Admin Added: ${result['adminId']} (${result['fullName']})",
                  ),
                ),
              );
            }
          },
          child: const Text('Show Add Admin Popup'),
        ),
      ),
    );
  }
}

class AddAdminPopup extends StatefulWidget {
  final List<String> faculties;

  const AddAdminPopup({
    super.key,
    required this.faculties,
  });

  @override
  State<AddAdminPopup> createState() => _AddAdminPopupState();
}

class _AddAdminPopupState extends State<AddAdminPopup> {
  final _formKey = GlobalKey<FormState>();
  String? _adminId;
  String? _fullName;
  String? _selectedFaculty;
  String? _password;

  @override
  Widget build(BuildContext context) {
    final double dialogWidth = MediaQuery.of(context).size.width > 600 ? 400 : double.infinity;

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
              crossAxisAlignment: CrossAxisAlignment.start, // Left align title
              children: [
                const Text(
                  "Add Admin",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.left,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  decoration: const InputDecoration(
                    hintText: "Admin ID",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => _adminId = val,
                  validator: (val) =>
                      val == null || val.isEmpty ? "Enter Admin ID" : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
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
                  decoration: const InputDecoration(
                    hintText: "Faculty  Name",
                    border: OutlineInputBorder(),
                  ),
                  items: widget.faculties
                      .map((faculty) => DropdownMenuItem(
                            value: faculty,
                            child: Text(faculty),
                          ))
                      .toList(),
                  onChanged: (val) => _selectedFaculty = val,
                  validator: (val) =>
                      val == null ? "Select faculty" : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(
                    hintText: "Password",
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  onChanged: (val) => _password = val,
                  validator: (val) =>
                      val == null || val.isEmpty ? "Enter password" : null,
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
                            Navigator.of(context).pop({
                              "adminId": _adminId,
                              "fullName": _fullName,
                              "faculty": _selectedFaculty,
                              "password": _password,
                            });
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