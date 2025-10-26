import 'package:flutter/material.dart';
import '../../models/faculty.dart';

class AddFacultyPopup extends StatefulWidget {
  final Faculty? faculty;
  const AddFacultyPopup({super.key, this.faculty});

  @override
  State<AddFacultyPopup> createState() => _AddFacultyPopupState();
}

class _AddFacultyPopupState extends State<AddFacultyPopup> {
  final _formKey = GlobalKey<FormState>();
  String? _facultyCode;
  String? _facultyName;
  DateTime? _establishmentDate;

  @override
  void initState() {
    super.initState();
    _facultyCode = widget.faculty?.code;
    _facultyName = widget.faculty?.name;
    _establishmentDate = widget.faculty?.establishmentDate;
  }

  @override
  Widget build(BuildContext context) {
    final double dialogWidth = MediaQuery.of(context).size.width > 600
        ? 400
        : double.infinity;

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
                  widget.faculty == null ? "Add Faculty" : "Edit Faculty",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  initialValue: _facultyCode,
                  decoration: const InputDecoration(
                    hintText: "Faculty Code",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => _facultyCode = val,
                  validator: (val) =>
                      val == null || val.isEmpty ? "Enter faculty code" : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: _facultyName,
                  decoration: const InputDecoration(
                    hintText: "Faculty Name",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => _facultyName = val,
                  validator: (val) =>
                      val == null || val.isEmpty ? "Enter faculty name" : null,
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () async {
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: _establishmentDate ?? DateTime.now(),
                      firstDate: DateTime(1900),
                      lastDate: DateTime.now(),
                    );
                    if (pickedDate != null) {
                      setState(() {
                        _establishmentDate = pickedDate;
                      });
                    }
                  },
                  child: AbsorbPointer(
                    child: TextFormField(
                      decoration: InputDecoration(
                        hintText: "Establishment Date",
                        border: const OutlineInputBorder(),
                        suffixIcon: const Icon(Icons.calendar_today),
                      ),
                      controller: TextEditingController(
                        text: _establishmentDate == null
                            ? ""
                            : "${_establishmentDate!.year}-${_establishmentDate!.month.toString().padLeft(2, '0')}-${_establishmentDate!.day.toString().padLeft(2, '0')}",
                      ),
                      validator: (val) => _establishmentDate == null
                          ? "Select establishment date"
                          : null,
                    ),
                  ),
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
                              Faculty(
                                id: widget.faculty?.id ?? '',
                                code: _facultyCode!,
                                name: _facultyName!,
                                createdAt: DateTime.now(),
                                establishmentDate: _establishmentDate!,
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