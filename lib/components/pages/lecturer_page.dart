import 'package:flutter/material.dart';
import '../cards/searchBar.dart';
import '../../models/lecturer.dart';
import '../popup/add_lecturer_popup.dart';

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
          SearchAddBar(
            hintText: "Search Lecturer...",
            buttonText: "Add Lecturer",
            onAddPressed: _showAddLecturerPopup,
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