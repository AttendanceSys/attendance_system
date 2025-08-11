import 'package:flutter/material.dart';

class AddCoursePopupDemoPage extends StatelessWidget {
  const AddCoursePopupDemoPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Course Popup Demo')),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final result = await showDialog(
              context: context,
              builder: (context) => AddCoursePopup(
                teachers: ["Mr. Smith", "Ms. Johnson", "Dr. Lee"],
                classes: ["Class 1", "Class 2", "Class 3"],
                semesters: ["Semester 1", "Semester 2", "Semester 3"],
              ),
            );
            if (result != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    "Course Added: ${result['subjectCode']} - ${result['subjectName']}",
                  ),
                ),
              );
            }
          },
          child: const Text('Show Add Course Popup'),
        ),
      ),
    );
  }
}

class AddCoursePopup extends StatefulWidget {
  final List<String> teachers;
  final List<String> classes;
  final List<String> semesters;

  const AddCoursePopup({
    super.key,
    required this.teachers,
    required this.classes,
    required this.semesters,
  });

  @override
  State<AddCoursePopup> createState() => _AddCoursePopupState();
}

class _AddCoursePopupState extends State<AddCoursePopup> {
  final _formKey = GlobalKey<FormState>();
  String? _subjectCode;
  String? _subjectName;
  String? _selectedTeacher;
  String? _selectedClass;
  String? _selectedSemester;

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
                      "Add Course",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.left,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      decoration: const InputDecoration(
                        hintText: "Subject Code",
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) => _subjectCode = val,
                      validator: (val) => val == null || val.isEmpty ? "Enter subject code" : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      decoration: const InputDecoration(
                        hintText: "Subject Name",
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (val) => _subjectName = val,
                      validator: (val) => val == null || val.isEmpty ? "Enter subject name" : null,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        hintText: "Teacher Assigned(optional)",
                        border: OutlineInputBorder(),
                      ),
                      items: widget.teachers
                          .map((teacher) => DropdownMenuItem(
                                value: teacher,
                                child: Text(teacher),
                              ))
                          .toList(),
                      onChanged: (val) => _selectedTeacher = val,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        hintText: "Select Class",
                        border: OutlineInputBorder(),
                      ),
                      items: widget.classes
                          .map((clazz) => DropdownMenuItem(
                                value: clazz,
                                child: Text(clazz),
                              ))
                          .toList(),
                      onChanged: (val) => _selectedClass = val,
                      validator: (val) => val == null ? "Select class" : null,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        hintText: "Semester",
                        border: OutlineInputBorder(),
                      ),
                      items: widget.semesters
                          .map((sem) => DropdownMenuItem(
                                value: sem,
                                child: Text(sem),
                              ))
                          .toList(),
                      onChanged: (val) => _selectedSemester = val,
                      validator: (val) => val == null ? "Select semester" : null,
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
                                  "subjectCode": _subjectCode,
                                  "subjectName": _subjectName,
                                  "teacher": _selectedTeacher,
                                  "class": _selectedClass,
                                  "semester": _selectedSemester,
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