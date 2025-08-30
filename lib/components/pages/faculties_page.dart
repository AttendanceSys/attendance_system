import 'package:flutter/material.dart';
import '../../models/faculty.dart';
import '../popup/add_faculty_popup.dart';
import '../cards/searchBar.dart';

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
      .where(
        (faculty) =>
            faculty.code.toLowerCase().contains(_searchText.toLowerCase()) ||
            faculty.name.toLowerCase().contains(_searchText.toLowerCase()),
      )
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
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

  String _monthString(int month) {
    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
    return months[month - 1];
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
          SearchAddBar(
            hintText: "Search Faculty...",
            buttonText: "Add Faculty",
            onAddPressed: _showAddFacultyPopup,
            onChanged: (value) => setState(() => _searchText = value),
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
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              "Faculty Code",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              "Faculty Name",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              "Created At",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(label: Text("")),
                        ],
                        rows: List.generate(_filteredFaculties.length, (index) {
                          final faculty = _filteredFaculties[index];
                          return DataRow(
                            cells: [
                              DataCell(Text('${index + 1}')),
                              DataCell(Text(faculty.code)),
                              DataCell(Text(faculty.name)),
                              DataCell(
                                Text(
                                  "${faculty.createdAt.day.toString().padLeft(2, '0')} "
                                  "${_monthString(faculty.createdAt.month)} "
                                  "${faculty.createdAt.year}",
                                ),
                              ),
                              DataCell(
                                Row(
                                  children: [
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        minimumSize: const Size(32, 28),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                        ),
                                      ),
                                      onPressed: () =>
                                          _showEditFacultyPopup(index),
                                      child: const Text(
                                        "Edit",
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        minimumSize: const Size(32, 28),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                        ),
                                      ),
                                      onPressed: () =>
                                          _confirmDeleteFaculty(index),
                                      child: const Text(
                                        "Delete",
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
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
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              "Faculty Code",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              "Faculty Name",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              "Created At",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(label: Text("")),
                        ],
                        rows: List.generate(_filteredFaculties.length, (index) {
                          final faculty = _filteredFaculties[index];
                          return DataRow(
                            cells: [
                              DataCell(Text('${index + 1}')),
                              DataCell(Text(faculty.code)),
                              DataCell(Text(faculty.name)),
                              DataCell(
                                Text(
                                  "${faculty.createdAt.day.toString().padLeft(2, '0')} "
                                  "${_monthString(faculty.createdAt.month)} "
                                  "${faculty.createdAt.year}",
                                ),
                              ),
                              DataCell(
                                Row(
                                  children: [
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        minimumSize: const Size(32, 28),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                        ),
                                      ),
                                      onPressed: () =>
                                          _showEditFacultyPopup(index),
                                      child: const Text(
                                        "Edit",
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        minimumSize: const Size(32, 28),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                        ),
                                      ),
                                      onPressed: () =>
                                          _confirmDeleteFaculty(index),
                                      child: const Text(
                                        "Delete",
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
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
