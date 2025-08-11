import 'package:flutter/material.dart';

class AddClassPopupDemoPage extends StatelessWidget {
  const AddClassPopupDemoPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Class Popup Demo')),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            final result = await showDialog(
              context: context,
              builder: (context) => AddClassPopup(
                departments: ["Science", "Arts", "Commerce"],
                sections: ["A", "B", "C"],
              ),
            );
            if (result != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("Class Added: ${result['className']} (${result['department']}, ${result['section']})")),
              );
            }
          },
          child: const Text('Show Add Class Popup'),
        ),
      ),
    );
  }
}

class AddClassPopup extends StatefulWidget {
  final List<String> departments;
  final List<String> sections;

  const AddClassPopup({
    super.key,
    required this.departments,
    required this.sections,
  });

  @override
  State<AddClassPopup> createState() => _AddClassPopupState();
}

class _AddClassPopupState extends State<AddClassPopup> {
  final _formKey = GlobalKey<FormState>();
  String? _className;
  String? _selectedDepartment;
  String? _selectedSection;

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
            borderRadius: BorderRadius.circular(16),
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
                  "Add Class",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.left,
                ),
                const SizedBox(height: 24),
                TextFormField(
                  decoration: const InputDecoration(
                    hintText: "Class Name",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => _className = val,
                  validator: (val) =>
                      val == null || val.isEmpty ? "Enter class name" : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    hintText: "Department",
                    border: OutlineInputBorder(),
                  ),
                  items: widget.departments
                      .map((dep) => DropdownMenuItem(
                            value: dep,
                            child: Text(dep),
                          ))
                      .toList(),
                  onChanged: (val) => _selectedDepartment = val,
                  validator: (val) =>
                      val == null ? "Select department" : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    hintText: "Section",
                    border: OutlineInputBorder(),
                  ),
                  items: widget.sections
                      .map((sec) => DropdownMenuItem(
                            value: sec,
                            child: Text(sec),
                          ))
                      .toList(),
                  onChanged: (val) => _selectedSection = val,
                  validator: (val) =>
                      val == null ? "Select section" : null,
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
                              "className": _className,
                              "department": _selectedDepartment,
                              "section": _selectedSection,
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
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