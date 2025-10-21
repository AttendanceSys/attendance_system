import 'package:flutter/material.dart';
import '../../models/course.dart';

class AddCoursePopup extends StatefulWidget {
  final Course? course;
  final List<String> teachers;
  final List<String> classes;

  const AddCoursePopup({
    super.key,
    this.course,
    required this.teachers,
    required this.classes,
  });

  @override
  State<AddCoursePopup> createState() => _AddCoursePopupState();
}

class _AddCoursePopupState extends State<AddCoursePopup> {
  final _formKey = GlobalKey<FormState>();
  String? _code;
  String? _name;
  String? _teacher;
  String? _className;
  int? _semester;

  @override
  void initState() {
    super.initState();
    _code = widget.course?.code;
    _name = widget.course?.name;
    _teacher = widget.course?.teacher;
    _className = widget.course?.className;
  _semester = widget.course?.semester;
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
                    widget.course == null ? "Add Course" : "Edit Course",
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextFormField(
                    initialValue: _code,
                    decoration: const InputDecoration(
                      hintText: "Subject Code",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) => _code = val,
                    validator: (val) => val == null || val.isEmpty
                        ? "Enter subject code"
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: _name,
                    decoration: const InputDecoration(
                      hintText: "Subject Name",
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (val) => _name = val,
                    validator: (val) => val == null || val.isEmpty
                        ? "Enter subject name"
                        : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _teacher,
                    decoration: const InputDecoration(
                      hintText: "Teacher Assigned (optional)",
                      border: OutlineInputBorder(),
                    ),
                    items: () {
                      final List<String> unique = widget.teachers
                          .where((t) => t.trim().isNotEmpty)
                          .toSet()
                          .toList();
                      // If editing and current teacher missing from list, include it
                      if (_teacher != null &&
                          _teacher!.trim().isNotEmpty &&
                          !unique.contains(_teacher)) {
                        unique.insert(0, _teacher!);
                      }
                      return unique
                          .map(
                            (teacher) => DropdownMenuItem(
                              value: teacher,
                              child: Text(teacher),
                            ),
                          )
                          .toList();
                    }(),
                    onChanged: (val) => setState(() => _teacher = val),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _className,
                    decoration: const InputDecoration(
                      hintText: "Select Class",
                      border: OutlineInputBorder(),
                    ),
                    items: () {
                      final List<String> unique = widget.classes
                          .where((c) => c.trim().isNotEmpty)
                          .toSet()
                          .toList();
                      if (_className != null &&
                          _className!.trim().isNotEmpty &&
                          !unique.contains(_className)) {
                        unique.insert(0, _className!);
                      }
                      return unique
                          .map(
                            (className) => DropdownMenuItem(
                              value: className,
                              child: Text(className),
                            ),
                          )
                          .toList();
                    }(),
                    onChanged: (val) => setState(() => _className = val),
                    validator: (val) =>
                        val == null || val.isEmpty ? "Select class" : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    value: _semester,
                    decoration: const InputDecoration(
                      hintText: "Select Semester",
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(10, (i) => DropdownMenuItem(
                      value: i + 1,
                      child: Text('Semester ${i + 1}'),
                    )),
                    onChanged: (val) => setState(() => _semester = val),
                    validator: (val) => val == null ? "Select semester" : null,
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
                                Course(
                                  code: _code ?? '',
                                  name: _name ?? '',
                                  teacher: _teacher ?? '',
                                  className: _className ?? '',
                                  semester: _semester ?? 1,
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
