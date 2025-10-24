import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/faculty.dart';

final supabase = Supabase.instance.client;

class AddFacultyPopupDemoPage extends StatelessWidget {
  final String currentUsername; // username of logged-in user
  const AddFacultyPopupDemoPage({super.key, required this.currentUsername});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Faculty Popup Demo')),
      body: Center(
        child: ElevatedButton(
          onPressed: () async {
            // Show popup; the popup itself will perform the RPC (create/update)
            await showDialog<Faculty>(
              context: context,
              builder: (context) =>
                  AddFacultyPopup(currentUsername: currentUsername),
            );
          },
          child: const Text('Show Add Faculty Popup'),
        ),
      ),
    );
  }
}

class AddFacultyPopup extends StatefulWidget {
  final Faculty? faculty;
  final String currentUsername;
  const AddFacultyPopup({
    super.key,
    this.faculty,
    required this.currentUsername,
  });

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
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text("Cancel"),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
                          final facultyToSave = Faculty(
                            code: _facultyCode!,
                            name: _facultyName!,
                            establishmentDate: _establishmentDate!,
                            createdAt: DateTime.now(),
                          );

                          final messenger = ScaffoldMessenger.of(context);
                          Navigator.of(context).pop(facultyToSave);

                          try {
                            if (widget.faculty == null) {
                              // 🔹 Add new faculty
                              await supabase.rpc(
                                'create_faculty',
                                params: {
                                  'p_code': facultyToSave.code,
                                  'p_name': facultyToSave.name,
                                  'p_establishment_date': facultyToSave
                                      .establishmentDate
                                      .toIso8601String(),
                                  'p_created_by': widget.currentUsername,
                                },
                              );
                            } else {
                              // 🔹 Update existing faculty
                              await supabase.rpc(
                                'update_faculty',
                                params: {
                                  'p_code': widget.faculty!.code, // old code
                                  'p_new_code': facultyToSave.code,
                                  'p_new_name': facultyToSave.name,
                                  'p_new_establishment_date': facultyToSave
                                      .establishmentDate
                                      .toIso8601String(),
                                  'p_updated_by': widget.currentUsername,
                                },
                              );
                            }

                            messenger.showSnackBar(
                              const SnackBar(
                                content: Text("✅ Faculty saved successfully"),
                              ),
                            );
                          } catch (e) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text("❌ Failed to save faculty: $e"),
                              ),
                            );
                          }
                        }
                      },
                      child: const Text("Save"),
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
