import 'package:flutter/material.dart';
import '../../models/faculty.dart';
import '../../hooks/use_faculties.dart';
import '../popup/add_faculty_popup.dart';
import '../cards/searchBar.dart';

class FacultiesPage extends StatefulWidget {
  const FacultiesPage({super.key});

  @override
  State<FacultiesPage> createState() => _FacultiesPageState();
}

class _FacultiesPageState extends State<FacultiesPage> {
  final UseFaculties _useFaculties = UseFaculties();
  List<Faculty> _faculties = [];
  bool _loading = false;

  String _searchText = '';
  int? _selectedIndex;

  List<Faculty> get _filteredFaculties => _faculties
      .where(
        (faculty) =>
            faculty.code.toLowerCase().contains(_searchText.toLowerCase()) ||
            faculty.name.toLowerCase().contains(_searchText.toLowerCase()),
      )
      .toList();

  @override
  void initState() {
    super.initState();
    _fetchFaculties();
  }

  Future<void> _fetchFaculties() async {
    setState(() => _loading = true);
    final faculties = await _useFaculties.fetchFaculties();
    setState(() {
      _faculties = faculties;
      _loading = false;
      _selectedIndex = null;
    });
  }

  Future<void> _showAddFacultyPopup() async {
    final result = await showDialog<Faculty>(
      context: context,
      builder: (context) => const AddFacultyPopup(),
    );
    if (result != null) {
      await _useFaculties.addFaculty(result);
      await _fetchFaculties();
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
      await _useFaculties.updateFaculty(faculty.code, result);
      await _fetchFaculties();
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
      await _useFaculties.deleteFaculty(faculty.code);
      await _fetchFaculties();
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
            "Faculties",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 24),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (!_loading)
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
          if (!_loading)
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
            _tableHeaderCell("Created At"),
          ],
        ),
        for (int index = 0; index < _filteredFaculties.length; index++)
          TableRow(
            decoration: BoxDecoration(
              color: _selectedIndex == index
                  ? Colors.blue.shade50
                  : Colors.transparent,
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
                "${_filteredFaculties[index].createdAt.day.toString().padLeft(2, '0')} "
                "${_monthString(_filteredFaculties[index].createdAt.month)} "
                "${_filteredFaculties[index].createdAt.year}",
                onTap: () => _handleRowTap(index),
              ),
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
            _tableHeaderCell("Faculty Code"),
            _tableHeaderCell("Faculty Name"),
            _tableHeaderCell("Created At"),
          ],
        ),
        for (int index = 0; index < _filteredFaculties.length; index++)
          TableRow(
            decoration: BoxDecoration(
              color: _selectedIndex == index
                  ? Colors.blue.shade50
                  : Colors.transparent,
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
                "${_filteredFaculties[index].createdAt.day.toString().padLeft(2, '0')} "
                "${_monthString(_filteredFaculties[index].createdAt.month)} "
                "${_filteredFaculties[index].createdAt.year}",
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
}
