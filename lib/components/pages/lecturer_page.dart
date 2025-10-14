import 'package:flutter/material.dart';
import '../cards/searchBar.dart';
import '../../models/lecturer.dart';
import '../popup/add_lecturer_popup.dart';

class LecturersPage extends StatefulWidget {
  const LecturersPage({super.key});

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
  int? _selectedIndex;

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
        _selectedIndex = null;
      });
    }
  }

  Future<void> _showEditLecturerPopup() async {
    if (_selectedIndex == null) return;
    final lecturer = _filteredLecturers[_selectedIndex!];
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

  Future<void> _confirmDeleteLecturer() async {
    if (_selectedIndex == null) return;
    final lecturer = _filteredLecturers[_selectedIndex!];
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );
    if (confirm == true) {
      setState(() {
        _lecturers.remove(lecturer);
        _selectedIndex = null;
      });
    }
  }

  void _handleRowTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth > 800;

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SearchAddBar(
                      hintText: "Search Lecturer...",
                      buttonText: "Add Lecturer",
                      onAddPressed: _showAddLecturerPopup,
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
                              padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 0),
                            ),
                            onPressed: _selectedIndex == null ? null : _showEditLecturerPopup,
                            child: const Text(
                              "Edit",
                              style: TextStyle(fontSize: 15, color: Colors.white),
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
                              padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 0),
                            ),
                            onPressed: _selectedIndex == null ? null : _confirmDeleteLecturer,
                            child: const Text(
                              "Delete",
                              style: TextStyle(fontSize: 15, color: Colors.white),
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
                  ? _buildDesktopTable()
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
    return Table(
      columnWidths: const {
        0: FixedColumnWidth(64),   // No
        1: FixedColumnWidth(140),  // Lecturer ID
        2: FixedColumnWidth(140),  // Lecturer Name
        3: FixedColumnWidth(120),  // Password
      },
      border: TableBorder(
        horizontalInside: BorderSide(color: Colors.grey.shade300),
      ),
      children: [
        TableRow(
          children: [
            _tableHeaderCell("No"),
            _tableHeaderCell("Lecturer ID"),
            _tableHeaderCell("Lecturer Name"),
            _tableHeaderCell("Password"),
          ],
        ),
        for (int index = 0; index < _filteredLecturers.length; index++)
          TableRow(
            decoration: BoxDecoration(
              color: _selectedIndex == index ? Colors.blue.shade50 : Colors.transparent,
            ),
            children: [
              _tableBodyCell('${index + 1}', onTap: () => _handleRowTap(index)),
              _tableBodyCell(_filteredLecturers[index].id, onTap: () => _handleRowTap(index)),
              _tableBodyCell(_filteredLecturers[index].name, onTap: () => _handleRowTap(index)),
              _tableBodyCell("••••••••", onTap: () => _handleRowTap(index)),
            ],
          ),
      ],
    );
  }

  Widget _buildMobileTable() {
    return Table(
      defaultColumnWidth: const IntrinsicColumnWidth(),
      border: TableBorder(
        horizontalInside: BorderSide(color: Colors.grey.shade300),
      ),
      children: [
        TableRow(
          children: [
            _tableHeaderCell("No"),
            _tableHeaderCell("Lecturer ID"),
            _tableHeaderCell("Lecturer Name"),
            _tableHeaderCell("Password"),
          ],
        ),
        for (int index = 0; index < _filteredLecturers.length; index++)
          TableRow(
            decoration: BoxDecoration(
              color: _selectedIndex == index ? Colors.blue.shade50 : Colors.transparent,
            ),
            children: [
              _tableBodyCell('${index + 1}', onTap: () => _handleRowTap(index)),
              _tableBodyCell(_filteredLecturers[index].id, onTap: () => _handleRowTap(index)),
              _tableBodyCell(_filteredLecturers[index].name, onTap: () => _handleRowTap(index)),
              _tableBodyCell("••••••••", onTap: () => _handleRowTap(index)),
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
        child: Text(
          text,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}