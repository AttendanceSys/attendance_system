import 'package:flutter/material.dart';

class EditDepartmentPopup extends StatefulWidget {
  final String code;
  final String name;
  final String head;
  final void Function(String code, String name, String head) onEdit;
  const EditDepartmentPopup({
    super.key,
    required this.code,
    required this.name,
    required this.head,
    required this.onEdit,
  });

  @override
  State<EditDepartmentPopup> createState() => _EditDepartmentPopupState();
}

class _EditDepartmentPopupState extends State<EditDepartmentPopup> {
  late TextEditingController _codeController;
  late TextEditingController _nameController;
  late TextEditingController _headController;

  @override
  void initState() {
    super.initState();
    _codeController = TextEditingController(text: widget.code);
    _nameController = TextEditingController(text: widget.name);
    _headController = TextEditingController(text: widget.head);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final saveButtonBg =
        isDark ? const Color(0xFF4234A4) : const Color(0xFF8372FE);
    return AlertDialog(
      title: const Text('Edit Department'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _codeController,
            decoration: const InputDecoration(labelText: 'Department Code'),
          ),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Department Name'),
          ),
          TextField(
            controller: _headController,
            decoration: const InputDecoration(labelText: 'Head of Department'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: saveButtonBg),
          onPressed: () {
            widget.onEdit(
              _codeController.text.trim(),
              _nameController.text.trim(),
              _headController.text.trim(),
            );
            Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
