import 'package:flutter/material.dart';

// Faculty Model
class Faculty {
  final String code;
  final String name;
  final DateTime createdAt;

  Faculty({required this.code, required this.name, required this.createdAt});

  Faculty copyWith({String? code, String? name, DateTime? createdAt}) {
    return Faculty(
      code: code ?? this.code,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

// Add/Edit Faculty Popup
class AddFacultyPopup extends StatefulWidget {
  final Faculty? faculty;

  const AddFacultyPopup({Key? key, this.faculty}) : super(key: key);

  @override
  State<AddFacultyPopup> createState() => _AddFacultyPopupState();
}

class _AddFacultyPopupState extends State<AddFacultyPopup> {
  final _formKey = GlobalKey<FormState>();
  late String _facultyCode;
  late String _facultyName;
  DateTime? _establishmentDate;

  @override
  void initState() {
    super.initState();
    _facultyCode = widget.faculty?.code ?? '';
    _facultyName = widget.faculty?.name ?? '';
    _establishmentDate = widget.faculty?.createdAt;
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
                  widget.faculty == null ? "Add Faculty" : "Edit Faculty",
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.left,
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
                            : "${_establishmentDate!.day.toString().padLeft(2, '0')} "
                              "${_monthString(_establishmentDate!.month)} "
                              "${_establishmentDate!.year}",
                      ),
                      validator: (val) =>
                          _establishmentDate == null ? "Select establishment date" : null,
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
                                code: _facultyCode,
                                name: _facultyName,
                                createdAt: _establishmentDate!,
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

  String _monthString(int month) {
    const months = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ];
    return months[month - 1];
  }
}

class FacultiesPage extends StatefulWidget {
  const FacultiesPage({Key? key}) : super(key: key);

  @override
  State<FacultiesPage> createState() => _FacultiesPageState();
}

class _FacultiesPageState extends State<FacultiesPage> {
  final List<Faculty> _faculties = [
    Faculty(code: 'SCI', name: 'Science', createdAt: DateTime(2023, 6, 12)),
    Faculty(code: 'MED', name: 'Medicine', createdAt: DateTime(2023, 6, 12)),
    Faculty(code: 'EDU', name: 'Education', createdAt: DateTime(2023, 6, 12)),
    Faculty(code: 'ENG', name: 'Engineering', createdAt: DateTime(2023, 6, 12)),
  ];

  String _searchText = '';

  List<Faculty> get _filteredFaculties => _faculties
      .where((faculty) =>
          faculty.code.toLowerCase().contains(_searchText.toLowerCase()) ||
          faculty.name.toLowerCase().contains(_searchText.toLowerCase()))
      .toList();

  Future<void> _showAddFacultyPopup() async {
    final result = await showDialog<Faculty>(
      context: context,
      builder: (context) => const AddFacultyPopup(),
    );
    if (result != null) {
      setState(() {
        _faculties.add(result);
      });
    }
  }

  Future<void> _showEditFacultyPopup(int index) async {
    final faculty = _filteredFaculties[index];
    final result = await showDialog<Faculty>(
      context: context,
      builder: (context) => AddFacultyPopup(faculty: faculty),
    );
    if (result != null) {
      int mainIndex = _faculties.indexOf(faculty);
      setState(() {
        _faculties[mainIndex] = result;
      });
    }
  }

  Future<void> _confirmDeleteFaculty(int index) async {
    final faculty = _filteredFaculties[index];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Faculty"),
        content: Text("Are you sure you want to delete '${faculty.name}'?"),
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
        _faculties.remove(faculty);
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
            "Faculties",
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
                    hintText: "Search Faculty...",
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
                  onPressed: _showAddFacultyPopup,
                  child: const Text(
                    "+ Add Faculty",
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
                            "Faculty Code",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          )),
                          DataColumn(
                              label: Text(
                            "Faculty Name",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          )),
                          DataColumn(
                              label: Text(
                            "Created At",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          )),
                          DataColumn(label: Text("")),
                        ],
                        rows: List.generate(_filteredFaculties.length, (index) {
                          final faculty = _filteredFaculties[index];
                          return DataRow(cells: [
                            DataCell(Text('${index + 1}')),
                            DataCell(Text(faculty.code)),
                            DataCell(Text(faculty.name)),
                            DataCell(Text(
                              "${faculty.createdAt.day.toString().padLeft(2, '0')} "
                              "${_monthString(faculty.createdAt.month)} "
                              "${faculty.createdAt.year}",
                            )),
                            DataCell(
                              Row(
                                children: [
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      minimumSize: const Size(32, 28),
                                      padding: const EdgeInsets.symmetric(horizontal: 6),
                                    ),
                                    onPressed: () => _showEditFacultyPopup(index),
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
                                    onPressed: () => _confirmDeleteFaculty(index),
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
                            "Faculty Code",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          )),
                          DataColumn(
                              label: Text(
                            "Faculty Name",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          )),
                          DataColumn(
                              label: Text(
                            "Created At",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          )),
                          DataColumn(label: Text("")),
                        ],
                        rows: List.generate(_filteredFaculties.length, (index) {
                          final faculty = _filteredFaculties[index];
                          return DataRow(cells: [
                            DataCell(Text('${index + 1}')),
                            DataCell(Text(faculty.code)),
                            DataCell(Text(faculty.name)),
                            DataCell(Text(
                              "${faculty.createdAt.day.toString().padLeft(2, '0')} "
                              "${_monthString(faculty.createdAt.month)} "
                              "${faculty.createdAt.year}",
                            )),
                            DataCell(
                              Row(
                                children: [
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      minimumSize: const Size(32, 28),
                                      padding: const EdgeInsets.symmetric(horizontal: 6),
                                    ),
                                    onPressed: () => _showEditFacultyPopup(index),
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
                                    onPressed: () => _confirmDeleteFaculty(index),
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

  String _monthString(int month) {
    const months = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ];
    return months[month - 1];
  }
}