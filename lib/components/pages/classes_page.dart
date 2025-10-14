import 'package:flutter/material.dart';
import '../../models/classes.dart';
import '../popup/add_class_popup.dart';
import '../cards/searchBar.dart';

class ClassesPage extends StatefulWidget {
  const ClassesPage({super.key});

  @override
  State<ClassesPage> createState() => _ClassesPageState();
}

class _ClassesPageState extends State<ClassesPage> {
  final List<SchoolClass> _classes = [
    SchoolClass(name: 'B3SC A', department: 'CS', section: 'A', isActive: true),
    SchoolClass(name: 'B2SC', department: 'CS', section: '', isActive: false),
    SchoolClass(name: 'B4SC', department: 'MATH', section: '', isActive: true),
    SchoolClass(name: 'B5SC', department: 'GEO', section: '', isActive: true),
  ];

  final List<String> departments = ['CS', 'MATH', 'GEO', 'BIO', 'CHEM'];
  final List<String> sections = ['A', 'B', 'C', 'D', ''];

  String _searchText = '';
  int? _selectedIndex;

  List<SchoolClass> get _filteredClasses => _classes.where((cls) =>
    cls.name.toLowerCase().contains(_searchText.toLowerCase()) ||
    cls.department.toLowerCase().contains(_searchText.toLowerCase())
  ).toList();

  Future<void> _showAddClassPopup() async {
    final result = await showDialog<SchoolClass>(
      context: context,
      builder: (context) => AddClassPopup(
        departments: departments,
        sections: sections,
      ),
    );
    if (result != null) {
      setState(() {
        _classes.add(result);
        _selectedIndex = null;
      });
    }
  }

  Future<void> _showEditClassPopup() async {
    if (_selectedIndex == null) return;
    final schoolClass = _filteredClasses[_selectedIndex!];
    final result = await showDialog<SchoolClass>(
      context: context,
      builder: (context) => AddClassPopup(
        schoolClass: schoolClass,
        departments: departments,
        sections: sections,
      ),
    );
    if (result != null) {
      int mainIndex = _classes.indexOf(schoolClass);
      setState(() {
        _classes[mainIndex] = result;
      });
    }
  }

  Future<void> _confirmDeleteClass() async {
    if (_selectedIndex == null) return;
    final schoolClass = _filteredClasses[_selectedIndex!];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Class"),
        content: Text("Are you sure you want to delete '${schoolClass.name}'?"),
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
        _classes.remove(schoolClass);
        _selectedIndex = null;
      });
    }
  }

  void _handleRowTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _toggleActive(int index, bool value) {
    setState(() {
      _filteredClasses[index].isActive = value;
      // Optionally, also update the main list if needed:
      int mainIndex = _classes.indexOf(_filteredClasses[index]);
      _classes[mainIndex].isActive = value;
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
            "Classes",
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
                      hintText: "Search Class...",
                      buttonText: "Add Class",
                      onAddPressed: _showAddClassPopup,
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
                            onPressed: _selectedIndex == null ? null : _showEditClassPopup,
                            child: const Text("Edit", style: TextStyle(fontSize: 15, color: Colors.white)),
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
                            onPressed: _selectedIndex == null ? null : _confirmDeleteClass,
                            child: const Text("Delete", style: TextStyle(fontSize: 15, color: Colors.white)),
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
        1: FixedColumnWidth(140),  // Class name
        2: FixedColumnWidth(120),  // Department
        3: FixedColumnWidth(170),  // Active/Inactive
      },
      border: TableBorder(
        horizontalInside: BorderSide(color: Colors.grey.shade300),
      ),
      children: [
        TableRow(
          children: [
            _tableHeaderCell("No"),
            _tableHeaderCell("Class name"),
            _tableHeaderCell("Department"),
            _tableHeaderCell("Active/Inactive"),
          ],
        ),
        for (int index = 0; index < _filteredClasses.length; index++)
          TableRow(
            decoration: BoxDecoration(
              color: _selectedIndex == index ? Colors.blue.shade50 : Colors.transparent,
            ),
            children: [
              _tableBodyCell('${index + 1}', onTap: () => _handleRowTap(index)),
              _tableBodyCell(_filteredClasses[index].name, onTap: () => _handleRowTap(index)),
              _tableBodyCell(_filteredClasses[index].department, onTap: () => _handleRowTap(index)),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Switch(
                  value: _filteredClasses[index].isActive,
                  onChanged: (value) => _toggleActive(index, value),
                  activeColor: Colors.green,
                  inactiveThumbColor: Colors.red,
                ),
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
            _tableHeaderCell("Class name"),
            _tableHeaderCell("Department"),
            _tableHeaderCell("Active/Inactive"),
          ],
        ),
        for (int index = 0; index < _filteredClasses.length; index++)
          TableRow(
            decoration: BoxDecoration(
              color: _selectedIndex == index ? Colors.blue.shade50 : Colors.transparent,
            ),
            children: [
              _tableBodyCell('${index + 1}', onTap: () => _handleRowTap(index)),
              _tableBodyCell(_filteredClasses[index].name, onTap: () => _handleRowTap(index)),
              _tableBodyCell(_filteredClasses[index].department, onTap: () => _handleRowTap(index)),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                child: Switch(
                  value: _filteredClasses[index].isActive,
                  onChanged: (value) => _toggleActive(index, value),
                  activeColor: Colors.green,
                  inactiveThumbColor: Colors.red,
                ),
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
        child: Text(
          text,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}