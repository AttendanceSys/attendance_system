import 'package:flutter/material.dart';

// Lecturer Model
class Lecturer {
  final String id;
  final String name;
  final String password;

  Lecturer({required this.id, required this.name, required this.password});

  Lecturer copyWith({String? id, String? name, String? password}) {
    return Lecturer(
      id: id ?? this.id,
      name: name ?? this.name,
      password: password ?? this.password,
    );
  }
}

// Add/Edit Lecturer Popup
class AddLecturerPopup extends StatefulWidget {
  final Lecturer? lecturer;

  const AddLecturerPopup({Key? key, this.lecturer}) : super(key: key);

  @override
  State<AddLecturerPopup> createState() => _AddLecturerPopupState();
}

class _AddLecturerPopupState extends State<AddLecturerPopup> {
  final _formKey = GlobalKey<FormState>();
  String? _lecturerName;
  String? _lecturerId;
  String? _password;

  @override
  void initState() {
    super.initState();
    _lecturerName = widget.lecturer?.name;
    _lecturerId = widget.lecturer?.id;
    _password = widget.lecturer?.password;
  }

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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.lecturer == null ? "Add Lecturer" : "Edit Lecturer",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  initialValue: _lecturerName,
                  decoration: const InputDecoration(
                    hintText: "Lecturer Name",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => _lecturerName = val,
                  validator: (val) => val == null || val.isEmpty ? "Enter lecturer name" : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: _lecturerId,
                  decoration: const InputDecoration(
                    hintText: "Lecturer ID",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => _lecturerId = val,
                  validator: (val) => val == null || val.isEmpty ? "Enter lecturer ID" : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  initialValue: _password,
                  decoration: const InputDecoration(
                    hintText: "Password",
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  onChanged: (val) => _password = val,
                  validator: (val) => val == null || val.isEmpty ? "Enter password" : null,
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
                              Lecturer(
                                id: _lecturerId!,
                                name: _lecturerName!,
                                password: _password!,
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

class LecturersPage extends StatefulWidget {
  const LecturersPage({Key? key}) : super(key: key);

  @override
  State<LecturersPage> createState() => _LecturersPageState();
}

class _LecturersPageState extends State<LecturersPage> {
  final List<Lecturer> _lecturers = [
    Lecturer(id: 'SNU1234', name: 'Cali', password: '*******'),
    Lecturer(id: 'SNU5678', name: 'Amina', password: '*******'),
    Lecturer(id: 'SNU9101', name: 'Yusuf', password: '*******'),
    Lecturer(id: 'SNU1121', name: 'Fatima', password: '*******'),
  ];

  String _searchText = '';

  List<Lecturer> get _filteredLecturers => _lecturers
      .where((lecturer) =>
          lecturer.id.toLowerCase().contains(_searchText.toLowerCase()) ||
          lecturer.name.toLowerCase().contains(_searchText.toLowerCase()))
      .toList();

  Future<void> _showAddLecturerPopup() async {
    final result = await showDialog<Lecturer>(
      context: context,
      builder: (context) => const AddLecturerPopup(),
    );
    if (result != null) {
      setState(() {
        _lecturers.add(result);
      });
    }
  }

  Future<void> _showEditLecturerPopup(int index) async {
    final lecturer = _filteredLecturers[index];
    final result = await showDialog<Lecturer>(
      context: context,
      builder: (context) => AddLecturerPopup(lecturer: lecturer),
    );
    if (result != null) {
      int mainIndex = _lecturers.indexOf(lecturer);
      setState(() {
        _lecturers[mainIndex] = result;
      });
    }
  }

  Future<void> _confirmDeleteLecturer(int index) async {
    final lecturer = _filteredLecturers[index];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Lecturer"),
        content: Text("Are you sure you want to delete '${lecturer.name}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
    if (confirm == true) {
      setState(() {
        _lecturers.remove(lecturer);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.of(context).size.width < 600;

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const Text(
            "Lecturers",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    hintText: "Search Lecturer...",
                    hintStyle: const TextStyle(color: Colors.grey),
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) => setState(() => _searchText = value),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(
                height: 42,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B4B9B),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                  ),
                  onPressed: _showAddLecturerPopup,
                  child: const Text(
                    "+ Add Lecturer",
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              width: double.infinity,
              color: Colors.transparent,
              child: isMobile
                  // On mobile, allow horizontal scroll for overflow
                  ? SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columnSpacing: 24,
                        headingRowHeight: 48,
                        dataRowHeight: 44,
                        columns: const [
                          DataColumn(
                              label: Text(
                            "No",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          )),
                          DataColumn(
                              label: Text(
                            "Lecturer ID",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          )),
                          DataColumn(
                              label: Text(
                            "Lecturer Name",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          )),
                          DataColumn(
                              label: Text(
                            "Password",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          )),
                          DataColumn(label: Text("")),
                        ],
                        rows: List.generate(_filteredLecturers.length, (index) {
                          final lecturer = _filteredLecturers[index];
                          return DataRow(cells: [
                            DataCell(Text('${index + 1}')),
                            DataCell(Text(lecturer.id)),
                            DataCell(Text(lecturer.name)),
                            DataCell(Text(lecturer.password)),
                            DataCell(
                              Row(
                                children: [
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      minimumSize: const Size(32, 28),
                                      padding: const EdgeInsets.symmetric(horizontal: 6),
                                    ),
                                    onPressed: () => _showEditLecturerPopup(index),
                                    child: const Text(
                                      "Edit",
                                      style: TextStyle(fontSize: 13, color: Colors.white),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      minimumSize: const Size(32, 28),
                                      padding: const EdgeInsets.symmetric(horizontal: 6),
                                    ),
                                    onPressed: () => _confirmDeleteLecturer(index),
                                    child: const Text(
                                      "Delete",
                                      style: TextStyle(fontSize: 13, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ]);
                        }),
                      ),
                    )
                  // On web/desktop, use vertical scroll only (no horizontal scroll)
                  : SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: DataTable(
                        columnSpacing: 24,
                        headingRowHeight: 48,
                        dataRowHeight: 44,
                        columns: const [
                          DataColumn(
                              label: Text(
                            "No",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          )),
                          DataColumn(
                              label: Text(
                            "Lecturer ID",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          )),
                          DataColumn(
                              label: Text(
                            "Lecturer Name",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          )),
                          DataColumn(
                              label: Text(
                            "Password",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          )),
                          DataColumn(label: Text("")),
                        ],
                        rows: List.generate(_filteredLecturers.length, (index) {
                          final lecturer = _filteredLecturers[index];
                          return DataRow(cells: [
                            DataCell(Text('${index + 1}')),
                            DataCell(Text(lecturer.id)),
                            DataCell(Text(lecturer.name)),
                            DataCell(Text(lecturer.password)),
                            DataCell(
                              Row(
                                children: [
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      minimumSize: const Size(32, 28),
                                      padding: const EdgeInsets.symmetric(horizontal: 6),
                                    ),
                                    onPressed: () => _showEditLecturerPopup(index),
                                    child: const Text(
                                      "Edit",
                                      style: TextStyle(fontSize: 13, color: Colors.white),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      minimumSize: const Size(32, 28),
                                      padding: const EdgeInsets.symmetric(horizontal: 6),
                                    ),
                                    onPressed: () => _confirmDeleteLecturer(index),
                                    child: const Text(
                                      "Delete",
                                      style: TextStyle(fontSize: 13, color: Colors.white),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ]);
                        }),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}