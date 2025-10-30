import 'package:flutter/material.dart';
import '../../models/course.dart';

class AddCoursePopup extends StatefulWidget {
  final Course? course;
  final List<String> teachers;
  final List<String> classes;
  // departments: list of maps with keys 'id' and 'name'
  final List<Map<String, String>> departments;

  const AddCoursePopup({
    super.key,
    this.course,
    required this.teachers,
    required this.classes,
    required this.departments,
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
  String? _department;
  int? _semester;

  @override
  void initState() {
    super.initState();
    _code = widget.course?.code;
    _name = widget.course?.name;
    _teacher = widget.course?.teacher;
    _className = widget.course?.className;
    // Normalize empty department to null so DropdownButtonFormField doesn't
    // assert when the initial value isn't present in the items list.
    // The popup now expects department to be the department id (uuid) when
    // editing; the dropdown items are id->name pairs.
    final initialDept = widget.course?.department;
    _department = (initialDept != null && initialDept.trim().isNotEmpty)
        ? initialDept
        : null;
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
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[100]!, width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
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
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // --- Subject Code ---
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

                  // --- Subject Name ---
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

                  // --- Department ---
                  Builder(
                    builder: (context) {
                      final deptItems = widget.departments
                          .where((d) => (d['id'] ?? '').trim().isNotEmpty)
                          .toList();
                      final currentValue =
                          deptItems.any((d) => d['id'] == _department)
                          ? _department
                          : null;
                      return DropdownButtonFormField<String>(
                        value: currentValue,
                        decoration: const InputDecoration(
                          hintText: "Select Department",
                          border: OutlineInputBorder(),
                        ),
                        items: deptItems
                            .map(
                              (dept) => DropdownMenuItem(
                                value: dept['id'],
                                child: Text(dept['name'] ?? dept['id'] ?? ''),
                              ),
                            )
                            .toList(),
                        onChanged: (val) => setState(() => _department = val),
                        validator: (val) => val == null || val.isEmpty
                            ? "Select department"
                            : null,
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // --- Teacher ---
                  Builder(
                    builder: (context) {
                      final teacherItems = widget.teachers
                          .where((t) => t.trim().isNotEmpty)
                          .toSet()
                          .toList();
                      final currentTeacher = teacherItems.contains(_teacher)
                          ? _teacher
                          : null;
                      return DropdownButtonFormField<String>(
                        value: currentTeacher,
                        decoration: const InputDecoration(
                          hintText: "Teacher Assigned (optional)",
                          border: OutlineInputBorder(),
                        ),
                        items: teacherItems
                            .map(
                              (teacher) => DropdownMenuItem(
                                value: teacher,
                                child: Text(teacher),
                              ),
                            )
                            .toList(),
                        onChanged: (val) => setState(() => _teacher = val),
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // --- Class ---
                  Builder(
                    builder: (context) {
                      final classItems = widget.classes
                          .where((c) => c.trim().isNotEmpty)
                          .toSet()
                          .toList();
                      final currentClass = classItems.contains(_className)
                          ? _className
                          : null;
                      return DropdownButtonFormField<String>(
                        value: currentClass,
                        decoration: const InputDecoration(
                          hintText: "Select Class",
                          border: OutlineInputBorder(),
                        ),
                        items: classItems
                            .map(
                              (className) => DropdownMenuItem(
                                value: className,
                                child: Text(className),
                              ),
                            )
                            .toList(),
                        onChanged: (val) => setState(() => _className = val),
                        validator: (val) =>
                            val == null || val.isEmpty ? "Select class" : null,
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // --- Semester ---
                  DropdownButtonFormField<int>(
                    value: _semester,
                    decoration: const InputDecoration(
                      hintText: "Select Semester",
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(
                      10,
                      (i) => DropdownMenuItem(
                        value: i + 1,
                        child: Text('Semester ${i + 1}'),
                      ),
                    ),
                    onChanged: (val) => setState(() => _semester = val),
                    validator: (val) => val == null ? "Select semester" : null,
                  ),
                  const SizedBox(height: 24),

                  // --- Buttons ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton(
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
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            Navigator.of(context).pop(
                              Course(
                                code: _code ?? '',
                                name: _name ?? '',
                                teacher: _teacher ?? '',
                                className: _className ?? '',
                                department: _department ?? '',
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
