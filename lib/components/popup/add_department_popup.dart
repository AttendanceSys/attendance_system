import 'package:flutter/material.dart';

class AddDepartmentPopupDemoPage extends StatelessWidget {
  const AddDepartmentPopupDemoPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Department Popup Demo')),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final result = await showDialog(
              context: context,
              builder: (context) => AddDepartmentPopup(
                statuses: ["Active", "Inactive"],
              ),
            );
            if (result != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    "Department Added: ${result['departmentName']} (${result['departmentCode']})",
                  ),
                ),
              );
            }
          },
          child: const Text('Show Add Department Popup'),
        ),
      ),
    );
  }
}

class AddDepartmentPopup extends StatefulWidget {
  final List<String> statuses;

  const AddDepartmentPopup({
    super.key,
    required this.statuses,
  });

  @override
  State<AddDepartmentPopup> createState() => _AddDepartmentPopupState();
}

class _AddDepartmentPopupState extends State<AddDepartmentPopup> {
  final _formKey = GlobalKey<FormState>();
  String? _departmentName;
  String? _departmentCode;
  String? _headOfDepartment;
  String? _selectedStatus;

  @override
  Widget build(BuildContext context) {
    final double dialogWidth = MediaQuery.of(context).size.width > 600 ? 400 : double.infinity;

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
              crossAxisAlignment: CrossAxisAlignment.start, // Left align title
              children: [
                const Text(
                  "Add Department",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.left,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  decoration: const InputDecoration(
                    hintText: "Department Name",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => _departmentName = val,
                  validator: (val) =>
                      val == null || val.isEmpty ? "Enter department name" : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(
                    hintText: "Department Code",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => _departmentCode = val,
                  validator: (val) =>
                      val == null || val.isEmpty ? "Enter department code" : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  decoration: const InputDecoration(
                    hintText: "Head of Department",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => _headOfDepartment = val,
                  validator: (val) =>
                      val == null || val.isEmpty ? "Enter head of department" : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    hintText: "Status",
                    border: OutlineInputBorder(),
                  ),
                  items: widget.statuses
                      .map((status) => DropdownMenuItem(
                            value: status,
                            child: Text(status),
                          ))
                      .toList(),
                  onChanged: (val) => _selectedStatus = val,
                  validator: (val) =>
                      val == null ? "Select status" : null,
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
                            Navigator.of(context).pop({
                              "departmentName": _departmentName,
                              "departmentCode": _departmentCode,
                              "headOfDepartment": _headOfDepartment,
                              "status": _selectedStatus,
                            });
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