import 'package:flutter/material.dart';
import '../../models/student.dart';
import '../../models/department.dart';
import '../../models/classes.dart';

class AddStudentPopup extends StatefulWidget {
  final Student? student;
  final List<String> genders;
  final List<Department> departments;
  final List<SchoolClass> classes;
  final String? facultyId;

  const AddStudentPopup({
    super.key,
    this.student,
    required this.genders,
    required this.departments,
    required this.classes,
    this.facultyId,
  });

  @override
  State<AddStudentPopup> createState() => _AddStudentPopupState();
}

class _AddStudentPopupState extends State<AddStudentPopup> {
  final _formKey = GlobalKey<FormState>();

  // Controllers & focus nodes
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  final _fullNameFocus = FocusNode();
  final _idFocus = FocusNode();
  final _genderFocus = FocusNode();
  final _deptFocus = FocusNode();
  final _classFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _obscurePassword = true;
  // Keep original DB id when editing so we show username but preserve id
  String? _originalId;

  String? _gender;
  String? _department; // display name
  String? _className; // display name
  String? _departmentId;
  String? _classId;

  @override
  void initState() {
    super.initState();
    _fullNameController.text = widget.student?.fullName ?? '';
    // show username in the ID input when editing; keep original DB id separately
    _originalId = widget.student?.id;
    _usernameController.text = widget.student?.username ?? '';
    _passwordController.text = widget.student?.password ?? '';
    _gender = widget.student?.gender;
    _department = widget.student?.department;
    _className = widget.student?.className;
    _departmentId = widget.student?.departmentId;
    _classId = widget.student?.classId;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _fullNameFocus.dispose();
    _idFocus.dispose();
    _genderFocus.dispose();
    _deptFocus.dispose();
    _classFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  void _saveStudent() {
    if (_formKey.currentState!.validate()) {
      final idToUse =
          _originalId ??
          _usernameController.text.trim(); // preserve DB id when editing
      Navigator.of(context).pop(
        Student(
          id: idToUse,
          fullName: _fullNameController.text.trim(),
          username: _usernameController.text.trim(),
          gender: _gender ?? '',
          department: _department ?? '',
          className: _className ?? '',
          facultyId: widget.facultyId ?? '',
          departmentId: _departmentId ?? '',
          classId: _classId ?? '',
          password: _passwordController.text,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isMobile = screenWidth < 600;
    final double dialogWidth = isMobile ? screenWidth * 0.95 : 420;

    return Dialog(
      elevation: 8,
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isMobile ? 8 : 40,
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
            padding: const EdgeInsets.all(20),
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
                  const SizedBox(height: 20),

                  // Full Name
                  TextFormField(
                    controller: _fullNameController,
                    focusNode: _fullNameFocus,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) =>
                        FocusScope.of(context).requestFocus(_idFocus),
                    decoration: const InputDecoration(
                      hintText: "Full Name",
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (val) =>
                        val == null || val.isEmpty ? "Enter full name" : null,
                  ),
                  const SizedBox(height: 14),

                  // Student ID / Username
                  TextFormField(
                    controller: _usernameController,
                    focusNode: _idFocus,
                    textInputAction: TextInputAction.next,
                    onFieldSubmitted: (_) =>
                        FocusScope.of(context).requestFocus(_genderFocus),
                    decoration: const InputDecoration(
                      hintText: "Username",
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    validator: (val) =>
                        val == null || val.isEmpty ? "Enter username" : null,
                  ),
                  const SizedBox(height: 14),

                  // Gender + Department (two columns)
                  Row(
                    children: [
                      Flexible(
                        flex: 1,
                        child: DropdownButtonFormField<String>(
                          focusNode: _genderFocus,
                          // normalize empty string -> null so DropdownButton doesn't
                          // fail when the current value is an empty string not
                          // present in the items list.
                          value: (_gender == null || _gender!.isEmpty)
                              ? null
                              : _gender,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            hintText: "Gender",
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: widget.genders
                              .map(
                                (gender) => DropdownMenuItem(
                                  value: gender,
                                  child: Text(gender),
                                ),
                              )
                              .toList(),
                          onChanged: (val) => setState(() => _gender = val),
                          validator: (val) => val == null || val.isEmpty
                              ? "Select gender"
                              : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        flex: 1,
                        child: DropdownButtonFormField<String>(
                          focusNode: _deptFocus,
                          value: (_department == null || _department!.isEmpty)
                              ? null
                              : _department,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            hintText: "Department",
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: widget.departments
                              .map(
                                (dept) => DropdownMenuItem(
                                  value: dept.name,
                                  child: Text(dept.name),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val == null) return;
                            final selected = widget.departments.firstWhere(
                              (d) => d.name == val,
                              orElse: () => Department(
                                id: '',
                                code: '',
                                name: val,
                                head: '',
                                status: '',
                              ),
                            );
                            setState(() {
                              _department = selected.name;
                              _departmentId = selected.id;
                            });
                          },
                          validator: (val) => val == null || val.isEmpty
                              ? "Select department"
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Class
                  DropdownButtonFormField<String>(
                    focusNode: _classFocus,
                    value: (_className == null || _className!.isEmpty)
                        ? null
                        : _className,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      hintText: "Class",
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: widget.classes
                        .map(
                          (cl) => DropdownMenuItem(
                            value: cl.name,
                            child: Text(cl.name),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val == null) return;
                      final selected = widget.classes.firstWhere(
                        (c) => c.name == val,
                        orElse: () => SchoolClass(
                          id: '',
                          name: val,
                          department: '',
                          section: '',
                        ),
                      );
                      setState(() {
                        _className = selected.name;
                        _classId = selected.id;
                      });
                    },
                    validator: (val) =>
                        val == null || val.isEmpty ? "Select class" : null,
                  ),
                  const SizedBox(height: 14),

                  // Password
                  TextFormField(
                    controller: _passwordController,
                    focusNode: _passwordFocus,
                    textInputAction: TextInputAction.done,
                    obscureText: _obscurePassword,
                    onFieldSubmitted: (_) => _saveStudent(),
                    decoration: InputDecoration(
                      hintText: "Password",
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    validator: (val) =>
                        val == null || val.isEmpty ? "Enter password" : null,
                  ),
                  const SizedBox(height: 20),

                  // Buttons
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
                          onPressed: _saveStudent,
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
