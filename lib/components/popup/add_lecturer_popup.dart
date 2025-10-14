import 'package:flutter/material.dart';
import '../../models/lecturer.dart';

class AddLecturerPopup extends StatefulWidget {
  final Lecturer? lecturer;

  const AddLecturerPopup({super.key, this.lecturer});

  @override
  State<AddLecturerPopup> createState() => _AddLecturerPopupState();
}

class _AddLecturerPopupState extends State<AddLecturerPopup> {
  final _formKey = GlobalKey<FormState>();
  String? _lecturerName;
  String? _lecturerId;
  String? _password;

  @override
  void initState() {
    super.initState();
    _lecturerName = widget.lecturer?.name;
    _lecturerId = widget.lecturer?.id;
    _password = widget.lecturer?.password;
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
                  widget.lecturer == null ? "Add Lecturer" : "Edit Lecturer",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  initialValue: _lecturerId,
                  decoration: const InputDecoration(
                    hintText: "Lecturer ID",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => _lecturerId = val,
                  validator: (val) =>
                      val == null || val.isEmpty ? "Enter lecturer ID" : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: _lecturerName,
                  decoration: const InputDecoration(
                    hintText: "Lecturer Name",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => _lecturerName = val,
                  validator: (val) =>
                      val == null || val.isEmpty ? "Enter lecturer name" : null,
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
                              Lecturer(
                                id: _lecturerId!,
                                name: _lecturerName!,
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
    );
  }
}
