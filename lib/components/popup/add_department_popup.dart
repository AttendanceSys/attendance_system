import 'package:flutter/material.dart';
import '../../models/department.dart';
import '../../hooks/use_lectureres.dart';

class AddDepartmentPopup extends StatefulWidget {
  final Department? department;
  final List<String> statusOptions;

  const AddDepartmentPopup({
    super.key,
    this.department,
    required this.statusOptions,
  });

  @override
  State<AddDepartmentPopup> createState() => _AddDepartmentPopupState();
}

class _AddDepartmentPopupState extends State<AddDepartmentPopup> {
  final _formKey = GlobalKey<FormState>();
  String? _name;
  String? _code;
  String? _headDisplay; // shown in dropdown
  String? _headId; // teacher id stored for DB
  // status removed from popup; keep department.status unchanged when saving

  final UseTeachers _teachersService = UseTeachers();
  List<Teacher> _teachers = [];

  @override
  void initState() {
    super.initState();
    _name = widget.department?.name;
    _code = widget.department?.code;
    // if widget.department.head contains an id, we will try to map to display name after loading teachers
    _headId = widget.department?.head;
    _loadTeachers();
  }

  Future<void> _loadTeachers() async {
    final list = await _teachersService.fetchTeachers();
    if (!mounted) return;
    setState(() {
      _teachers = list;
      if (_headId != null && _headId!.isNotEmpty) {
        final matched = _teachers.firstWhere(
          (t) => t.id == _headId,
          orElse: () => _teachers.isNotEmpty
              ? _teachers.first
              : Teacher(id: '', username: '', teacherName: '', password: ''),
        );
        _headDisplay = matched.teacherName ?? matched.username ?? matched.id;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final double dialogWidth = MediaQuery.of(context).size.width > 600
        ? 400
        : MediaQuery.of(context).size.width * 0.95;

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
                  widget.department == null
                      ? 'Add Department'
                      : 'Edit Department',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  initialValue: _name,
                  decoration: const InputDecoration(
                    hintText: 'Department Name',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => _name = val,
                  validator: (val) => val == null || val.isEmpty
                      ? 'Enter department name'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: _code,
                  decoration: const InputDecoration(
                    hintText: 'Department Code',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => _code = val,
                  validator: (val) => val == null || val.isEmpty
                      ? 'Enter department code'
                      : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _headDisplay,
                  decoration: const InputDecoration(
                    hintText: 'Head of Department',
                    border: OutlineInputBorder(),
                  ),
                  items: _teachers
                      .map(
                        (t) => DropdownMenuItem(
                          value: t.teacherName ?? t.username ?? t.id,
                          child: Text(t.teacherName ?? t.username ?? t.id),
                        ),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val == null) return;
                    final selected = _teachers.firstWhere(
                      (t) => (t.teacherName ?? t.username ?? t.id) == val,
                      orElse: () => _teachers.isNotEmpty
                          ? _teachers.first
                          : Teacher(
                              id: '',
                              username: '',
                              teacherName: '',
                              password: '',
                            ),
                    );
                    setState(() {
                      _headDisplay =
                          selected.teacherName ??
                          selected.username ??
                          selected.id;
                      _headId = selected.id;
                    });
                  },
                  validator: (val) => val == null || val.isEmpty
                      ? 'Select head of department'
                      : null,
                ),
                const SizedBox(height: 16),
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
                          'Cancel',
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
                            // store head as id (if available) so DB receives teacher id
                            Navigator.of(context).pop(
                              Department(
                                code: _code ?? '',
                                name: _name ?? '',
                                head: _headId ?? _headDisplay ?? '',
                                status:
                                    widget.department?.status ?? 'in active',
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
                          'Save',
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
