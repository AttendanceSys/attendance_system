//faculty page

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/faculty.dart';
import '../popup/add_faculty_popup.dart';
import '../cards/searchBar.dart';
import 'package:flutter/material.dart';

class FacultiesPage extends StatefulWidget {
  const FacultiesPage({super.key});

  @override
  State<FacultiesPage> createState() => _FacultiesPageState();
}

class _FacultiesPageState extends State<FacultiesPage> {
  final CollectionReference facultiesCollection = FirebaseFirestore.instance
      .collection('faculties');

  List<Faculty> _faculties = [];
  String _searchText = '';
  int? _selectedIndex;

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blueGrey.shade800,
      ),
    );
  }

  List<Faculty> get _filteredFaculties {
    final query = _searchText.trim().toLowerCase();
    if (query.isEmpty) return _faculties;
    return _faculties
        .where(
          (faculty) =>
              faculty.name.toLowerCase().startsWith(query) ||
              faculty.code.toLowerCase().startsWith(query),
        )
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _fetchFaculties();
  }

  Future<bool> _facultyExists({
    required String code,
    required String name,
    String? excludeId,
  }) async {
    final trimmedCode = code.trim();
    final trimmedName = name.trim();

    final codeSnap = await facultiesCollection
        .where('faculty_code', isEqualTo: trimmedCode)
        .get();
    final nameSnap = await facultiesCollection
        .where('faculty_name', isEqualTo: trimmedName)
        .get();

    final hasCode = codeSnap.docs.any((d) => d.id != excludeId);
    final hasName = nameSnap.docs.any((d) => d.id != excludeId);
    return hasCode || hasName;
  }

  Future<void> _fetchFaculties() async {
    try {
      final snapshot = await facultiesCollection.get();

      if (snapshot.docs.isEmpty) {
        print("No faculties found");
      } else {
        print("Fetched ${snapshot.docs.length} faculties");
      }

      setState(() {
        _faculties = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return Faculty(
            id: doc.id,
            code: data['faculty_code'] ?? 'N/A',
            name: data['faculty_name'] ?? 'N/A',
            createdAt:
                (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
            establishmentDate: DateTime.parse(
              data['establishment_date'] ?? DateTime.now().toIso8601String(),
            ),
          );
        }).toList();
      });
    } catch (e) {
      print("Error fetching faculties: $e");
    }
  }

  Future<void> _addFaculty(Faculty faculty) async {
    final code = faculty.code.trim();
    final name = faculty.name.trim();

    final exists = await _facultyExists(code: code, name: name);
    if (exists) {
      _showSnack('Faculty code or name already exists');
      return;
    }

    await facultiesCollection.add({
      'faculty_code': code,
      'faculty_name': name,
      'created_at': FieldValue.serverTimestamp(),
      'establishment_date': faculty.establishmentDate.toIso8601String(),
    });
    _fetchFaculties();
    _showSnack('Faculty added successfully');
  }

  Future<void> _updateFaculty(Faculty faculty) async {
    final code = faculty.code.trim();
    final name = faculty.name.trim();

    final exists = await _facultyExists(
      code: code,
      name: name,
      excludeId: faculty.id,
    );
    if (exists) {
      _showSnack('Faculty code or name already exists');
      return;
    }

    await facultiesCollection.doc(faculty.id).update({
      'faculty_code': code,
      'faculty_name': name,
      'created_at': FieldValue.serverTimestamp(),
      'establishment_date': faculty.establishmentDate.toIso8601String(),
    });
    _fetchFaculties();
    _showSnack('Faculty updated successfully');
  }

  Future<void> _deleteFaculty(Faculty faculty) async {
    await facultiesCollection.doc(faculty.id).delete();
    _fetchFaculties();
    _showSnack('Faculty deleted successfully');
  }

  Future<void> _showAddFacultyPopup() async {
    final result = await showDialog<Faculty>(
      context: context,
      builder: (context) => const AddFacultyPopup(),
    );
    if (result != null) {
      _addFaculty(result);
    }
  }

  Future<void> _showEditFacultyPopup() async {
    if (_selectedIndex == null) return;
    final faculty = _filteredFaculties[_selectedIndex!];
    final result = await showDialog<Faculty>(
      context: context,
      builder: (context) => AddFacultyPopup(faculty: faculty),
    );
    if (result != null) {
      _updateFaculty(result);
    }
  }

  Future<void> _confirmDeleteFaculty() async {
    if (_selectedIndex == null) return;
    final faculty = _filteredFaculties[_selectedIndex!];
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
      _deleteFaculty(faculty);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final highlight = isDark ? const Color(0xFF2E3545) : Colors.blue.shade50;

    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth > 800;

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const Text(
            "Faculties",
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SearchAddBar(
                      hintText: "Search Faculty...",
                      buttonText: "Add Faculty",
                      onAddPressed: _showAddFacultyPopup,
                      onChanged: (value) {
                        setState(() {
                          _searchText = value;
                          _selectedIndex = null;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SizedBox(
                          width: 80,
                          height: 36,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 0,
                                horizontal: 0,
                              ),
                            ),
                            onPressed: _selectedIndex == null
                                ? null
                                : _showEditFacultyPopup,
                            child: const Text(
                              "Edit",
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 80,
                          height: 36,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 0,
                                horizontal: 0,
                              ),
                            ),
                            onPressed: _selectedIndex == null
                                ? null
                                : _confirmDeleteFaculty,
                            child: const Text(
                              "Delete",
                              style: TextStyle(
                                fontSize: 15,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              width: double.infinity,
              color: Colors.transparent,
              child: isDesktop
                  ? SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: _buildDesktopTable(),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: _buildMobileTable(),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final highlight = isDark ? const Color(0xFF2E3545) : Colors.blue.shade50;

    return Table(
      columnWidths: const {
        0: FixedColumnWidth(64), // No
        1: FixedColumnWidth(120), // Faculty Code
        2: FixedColumnWidth(180), // Faculty Name
        3: FixedColumnWidth(130), // Created At
      },
      border: TableBorder(
        horizontalInside: BorderSide(color: Colors.grey.shade300),
      ),
      children: [
        TableRow(
          children: [
            _tableHeaderCell("No"),
            _tableHeaderCell("Faculty Code"),
            _tableHeaderCell("Faculty Name"),
            _tableHeaderCell("Establishment Date"),
          ],
        ),
        for (int index = 0; index < _filteredFaculties.length; index++)
          TableRow(
            decoration: BoxDecoration(
              color: _selectedIndex == index ? highlight : Colors.transparent,
            ),
            children: [
              _tableBodyCell('${index + 1}', onTap: () => _handleRowTap(index)),
              _tableBodyCell(
                _filteredFaculties[index].code,
                onTap: () => _handleRowTap(index),
              ),
              _tableBodyCell(
                _filteredFaculties[index].name,
                onTap: () => _handleRowTap(index),
              ),
              _tableBodyCell(
                "${_filteredFaculties[index].establishmentDate.day.toString().padLeft(2, '0')} "
                "${_monthString(_filteredFaculties[index].establishmentDate.month)} "
                "${_filteredFaculties[index].establishmentDate.year}",
                onTap: () => _handleRowTap(index),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildMobileTable() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final highlight = isDark ? const Color(0xFF2E3545) : Colors.blue.shade50;

    return Table(
      defaultColumnWidth: const IntrinsicColumnWidth(),
      border: TableBorder(
        horizontalInside: BorderSide(color: Colors.grey.shade300),
      ),
      children: [
        TableRow(
          children: [
            _tableHeaderCell("No"),
            _tableHeaderCell("Faculty Code"),
            _tableHeaderCell("Faculty Name"),
            _tableHeaderCell("Created At"),
          ],
        ),
        for (int index = 0; index < _filteredFaculties.length; index++)
          TableRow(
            decoration: BoxDecoration(
              color: _selectedIndex == index ? highlight : Colors.transparent,
            ),
            children: [
              _tableBodyCell('${index + 1}', onTap: () => _handleRowTap(index)),
              _tableBodyCell(
                _filteredFaculties[index].code,
                onTap: () => _handleRowTap(index),
              ),
              _tableBodyCell(
                _filteredFaculties[index].name,
                onTap: () => _handleRowTap(index),
              ),
              _tableBodyCell(
                "${_filteredFaculties[index].establishmentDate.day.toString().padLeft(2, '0')} "
                "${_monthString(_filteredFaculties[index].establishmentDate.month)} "
                "${_filteredFaculties[index].establishmentDate.year}",
                onTap: () => _handleRowTap(index),
              ),
            ],
          ),
      ],
    );
  }

  Widget _tableHeaderCell(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold),
        textAlign: TextAlign.left,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _tableBodyCell(String text, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Text(text, overflow: TextOverflow.ellipsis),
      ),
    );
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

  void _handleRowTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
}
