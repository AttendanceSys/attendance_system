import 'package:flutter/material.dart';
import '../../theme/super_admin_theme.dart';

class AddEditAttendancePopup extends StatefulWidget {
  final Map<String, dynamic>? attendance;

  const AddEditAttendancePopup({super.key, this.attendance});

  @override
  State<AddEditAttendancePopup> createState() => _AddEditAttendancePopupState();
}

class _AddEditAttendancePopupState extends State<AddEditAttendancePopup> {
  final _formKey = GlobalKey<FormState>();
  String? _studentName;
  String? _department;
  String? _className;
  bool _status = true;

  @override
  void initState() {
    super.initState();
    if (widget.attendance != null) {
      _studentName = widget.attendance!['name'];
      _department = widget.attendance!['department'];
      _className = widget.attendance!['class'];
      _status = widget.attendance!['status'];
    }
  }

  @override
  Widget build(BuildContext context) {
    final double dialogWidth = MediaQuery.of(context).size.width > 600
        ? 400
        : MediaQuery.of(context).size.width * 0.95;

    final palette = Theme.of(context).extension<SuperAdminColors>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface =
        palette?.surface ?? (isDark ? const Color(0xFF262C3A) : Colors.white);
    final border =
        palette?.border ??
        (isDark ? const Color(0xFF3A404E) : Colors.blue[100]!);
    final textPrimary =
        palette?.textPrimary ?? (isDark ? Colors.white : Colors.black87);
    final accent =
        palette?.accent ??
        (isDark ? const Color(0xFF0A1E90) : Colors.blue[900]!);
    final inputFill =
        palette?.inputFill ?? (isDark ? const Color(0xFF2B303D) : Colors.white);

    InputDecoration _input(String hint) => InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: inputFill,
      border: OutlineInputBorder(borderSide: BorderSide(color: border)),
      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: border)),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: accent, width: 1.4),
      ),
    );

    return Dialog(
      elevation: 8,
      backgroundColor: Colors.transparent,
      child: Center(
        child: Container(
          width: dialogWidth,
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border, width: 2),
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
                  widget.attendance == null
                      ? "Add Attendance"
                      : "Edit Attendance",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  initialValue: _studentName,
                  decoration: _input("Student Name"),
                  onChanged: (val) => _studentName = val,
                  validator: (val) =>
                      val == null || val.isEmpty ? "Enter student name" : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: _department,
                  decoration: _input("Department"),
                  onChanged: (val) => _department = val,
                  validator: (val) =>
                      val == null || val.isEmpty ? "Enter department" : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: _className,
                  decoration: _input("Class"),
                  onChanged: (val) => _className = val,
                  validator: (val) =>
                      val == null || val.isEmpty ? "Enter class" : null,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text("Status:"),
                    const SizedBox(width: 12),
                    Switch(
                      value: _status,
                      onChanged: (val) => setState(() => _status = val),
                      activeColor: accent,
                      inactiveThumbColor: border,
                    ),
                  ],
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
                          side: BorderSide(color: border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          minimumSize: const Size(90, 40),
                        ),
                        child: Text(
                          "Cancel",
                          style: TextStyle(
                            color: textPrimary,
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
                              'name': _studentName,
                              'department': _department,
                              'class': _className,
                              'status': _status,
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
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
