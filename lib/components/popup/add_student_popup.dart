import 'package:flutter/material.dart';
import '../../models/student.dart';

class AddStudentPopup extends StatefulWidget {
  final Student? student;
  final List<String> genders;
  final List<String> departments;
  final List<String> classes;

  const AddStudentPopup({
    super.key,
    this.student,
    required this.genders,
    required this.departments,
    required this.classes,
  });

  @override
  State<AddStudentPopup> createState() => _AddStudentPopupState();
}

class _AddStudentPopupState extends State<AddStudentPopup> {
  final _formKey = GlobalKey<FormState>();
  String? _id;
  String? _fullName;
  String? _gender;
  String? _department;
  String? _className;
  String? _password;

  @override
  void initState() {
    super.initState();
    _id = widget.student?.id;
    _fullName = widget.student?.fullName;
    _gender = widget.student?.gender;
    _department = widget.student?.department;
    _className = widget.student?.className;
    _password = widget.student?.password;
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;
    final double dialogWidth = isMobile ? screenWidth * 0.95 : 400;

    return Dialog(
      elevation: 8,
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 4 : 40,
        vertical: isMobile ? 8 : 24,
      ),
      child: Center(
        child: SingleChildScrollView(
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
                    widget.student == null ? "Add Student" : "Edit Student",
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
                  TextFormField(
                    initialValue: _id,
                    decoration: const InputDecoration(
                      hintText: "ID",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) => _id = val,
                    validator: (val) =>
                        val == null || val.isEmpty ? "Enter student ID" : null,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _gender,
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
                          onChanged: (val) => setState(() => _gender = val),
                          validator: (val) =>
                              val == null || val.isEmpty ? "Select gender" : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _department,
                          decoration: const InputDecoration(
                            hintText: "Department",
                            border: OutlineInputBorder(),
                          ),
                          items: widget.departments
                              .map((dept) => DropdownMenuItem(
                                    value: dept,
                                    child: Text(dept),
                                  ))
                              .toList(),
                          onChanged: (val) => setState(() => _department = val),
                          validator: (val) => val == null || val.isEmpty
                              ? "Select department"
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _className,
                    decoration: const InputDecoration(
                      hintText: "Class",
                      border: OutlineInputBorder(),
                    ),
                    items: widget.classes
                        .map((cl) => DropdownMenuItem(
                              value: cl,
                              child: Text(cl),
                            ))
                        .toList(),
                    onChanged: (val) => setState(() => _className = val),
                    validator: (val) =>
                        val == null || val.isEmpty ? "Select class" : null,
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
                                Student(
                                  id: _id!,
                                  fullName: _fullName!,
                                  gender: _gender!,
                                  department: _department!,
                                  className: _className!,
                                  password: _password!,
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
      ),
    );
  }
}