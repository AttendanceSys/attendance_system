import 'package:flutter/material.dart';
import '../../models/lecturer.dart';

class AddTeacherPopup extends StatefulWidget {
  final Teacher? teacher;
  final List<String> facultyNames;

  const AddTeacherPopup({super.key, this.teacher, required this.facultyNames});

  @override
  State<AddTeacherPopup> createState() => _AddTeacherPopupState();
}

class _AddTeacherPopupState extends State<AddTeacherPopup> {
  final _formKey = GlobalKey<FormState>();
  String? _teacherName;
  String? _username;
  String? _password;
  String? _facultyId;

  @override
  void initState() {
    super.initState();
    _teacherName = widget.teacher?.teacherName;
    _username = widget.teacher?.username;
    _password = widget.teacher?.password;
    _facultyId = widget.teacher?.facultyId;
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
                  widget.teacher == null ? "Add Teacher" : "Edit Teacher",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
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
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: _teacherName,
                  decoration: const InputDecoration(
                    hintText: "Teacher Name",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => _teacherName = val,
                  validator: (val) =>
                      val == null || val.isEmpty ? "Enter teacher name" : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _facultyId,
                  decoration: const InputDecoration(
                    hintText: "Faculty",
                    border: OutlineInputBorder(),
                  ),
                  items: widget.facultyNames
                      .map(
                        (name) =>
                            DropdownMenuItem(value: name, child: Text(name)),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => _facultyId = val),
                  validator: (val) =>
                      val == null || val.isEmpty ? "Select faculty" : null,
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
                              Teacher(
                                id: widget.teacher?.id ?? '',
                                teacherName: _teacherName!,
                                username: _username!,
                                password: _password!,
                                facultyId: _facultyId!,
                                createdAt:
                                    widget.teacher?.createdAt ?? DateTime.now(),
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
