import 'package:flutter/material.dart';

class AddStudentPopupDemoPage extends StatelessWidget {
  const AddStudentPopupDemoPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Student Popup Demo')),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final result = await showDialog(
              context: context,
              builder: (context) => AddStudentPopup(
                genders: ["Male", "Female"],
                departments: ["Science", "Arts", "Commerce"],
                classes: ["Class 1", "Class 2", "Class 3"],
              ),
            );
            if (result != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    "Student Added: ${result['fullName']} (${result['id']})",
                  ),
                ),
              );
            }
          },
          child: const Text('Show Add Student Popup'),
        ),
      ),
    );
  }
}

class AddStudentPopup extends StatefulWidget {
  final List<String> genders;
  final List<String> departments;
  final List<String> classes;

  const AddStudentPopup({
    super.key,
    required this.genders,
    required this.departments,
    required this.classes,
  });

  @override
  State<AddStudentPopup> createState() => _AddStudentPopupState();
}

class _AddStudentPopupState extends State<AddStudentPopup> {
  final _formKey = GlobalKey<FormState>();
  String? _fullName;
  String? _id;
  String? _selectedGender;
  String? _selectedDepartment;
  String? _selectedClass;
  String? _password;

  @override
  Widget build(BuildContext context) {
    final double dialogWidth = MediaQuery.of(context).size.width > 600 ? 400 : MediaQuery.of(context).size.width * 0.95;
    final double maxDialogHeight = MediaQuery.of(context).size.height * 0.9;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
      elevation: 8,
      backgroundColor: Colors.transparent,
      child: Align(
        alignment: Alignment.center,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: maxDialogHeight,
            maxWidth: dialogWidth,
          ),
          child: SingleChildScrollView(
            // Scrolls entire dialog if keyboard covers it
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
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
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Add Student",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.left,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: "Full Name",
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) => _fullName = val,
                      validator: (val) =>
                          val == null || val.isEmpty ? "Enter full name" : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      decoration: const InputDecoration(
                        hintText: "ID",
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) => _id = val,
                      validator: (val) =>
                          val == null || val.isEmpty ? "Enter ID" : null,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              hintText: "Gender",
                              border: OutlineInputBorder(),
                            ),
                            items: widget.genders
                                .map((gender) => DropdownMenuItem(
                                      value: gender,
                                      child: Text(gender),
                                    ))
                                .toList(),
                            onChanged: (val) => _selectedGender = val,
                            validator: (val) =>
                                val == null ? "Select gender" : null,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              hintText: "Department",
                              border: OutlineInputBorder(),
                            ),
                            items: widget.departments
                                .map((dep) => DropdownMenuItem(
                                      value: dep,
                                      child: Text(dep),
                                    ))
                                .toList(),
                            onChanged: (val) => _selectedDepartment = val,
                            validator: (val) =>
                                val == null ? "Select department" : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        hintText: "Class",
                        border: OutlineInputBorder(),
                      ),
                      items: widget.classes
                          .map((clazz) => DropdownMenuItem(
                                value: clazz,
                                child: Text(clazz),
                              ))
                          .toList(),
                      onChanged: (val) => _selectedClass = val,
                      validator: (val) =>
                          val == null ? "Select class" : null,
                    ),
                    const SizedBox(height: 10),
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
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SizedBox(
                          height: 36,
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(context).pop(),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.black54),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              minimumSize: const Size(80, 36),
                            ),
                            child: const Text(
                              "Cancel",
                              style: TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: 36,
                          child: ElevatedButton(
                            onPressed: () {
                              if (_formKey.currentState!.validate()) {
                                Navigator.of(context).pop({
                                  "fullName": _fullName,
                                  "id": _id,
                                  "gender": _selectedGender,
                                  "department": _selectedDepartment,
                                  "class": _selectedClass,
                                  "password": _password,
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue[900],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              minimumSize: const Size(80, 36),
                            ),
                            child: const Text(
                              "Save",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
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
        ),
      ),
    );
  }
}