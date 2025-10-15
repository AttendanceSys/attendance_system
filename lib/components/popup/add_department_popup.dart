import 'package:flutter/material.dart';
import '../../models/department.dart';

class AddDepartmentPopup extends StatefulWidget {
  final Department? department;
  final List<String> statusOptions;

  const AddDepartmentPopup({
    Key? key,
    this.department,
    required this.statusOptions,
  }) : super(key: key);

  @override
  State<AddDepartmentPopup> createState() => _AddDepartmentPopupState();
}

class _AddDepartmentPopupState extends State<AddDepartmentPopup> {
  final _formKey = GlobalKey<FormState>();
  String? _name;
  String? _code;
  String? _head;
  String? _status;

  @override
  void initState() {
    super.initState();
    _name = widget.department?.name;
    _code = widget.department?.code;
    _head = widget.department?.head;
    _status = widget.department?.status;
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
                  widget.department == null ? "Add Department" : "Edit Department",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  initialValue: _name,
                  decoration: const InputDecoration(
                    hintText: "Department Name",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => _name = val,
                  validator: (val) =>
                      val == null || val.isEmpty ? "Enter department name" : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: _code,
                  decoration: const InputDecoration(
                    hintText: "Department Code",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => _code = val,
                  validator: (val) =>
                      val == null || val.isEmpty ? "Enter department code" : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: _head,
                  decoration: const InputDecoration(
                    hintText: "Head of Department",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => _head = val,
                  validator: (val) =>
                      val == null || val.isEmpty ? "Enter head of department" : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _status,
                  decoration: const InputDecoration(
                    hintText: "Status",
                    border: OutlineInputBorder(),
                  ),
                  items: widget.statusOptions
                      .map((status) => DropdownMenuItem(
                            value: status,
                            child: Text(status),
                          ))
                      .toList(),
                  onChanged: (val) => setState(() => _status = val),
                  validator: (val) =>
                      val == null || val.isEmpty ? "Select status" : null,
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
                              Department(
                                code: _code!,
                                name: _name!,
                                head: _head!,
                                status: _status!,
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