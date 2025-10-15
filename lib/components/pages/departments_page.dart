import 'package:flutter/material.dart';
import '../../models/department.dart';
import '../popup/add_department_popup.dart';
import '../cards/searchBar.dart';

class DepartmentsPage extends StatefulWidget {
  const DepartmentsPage({Key? key}) : super(key: key);

  @override
  State<DepartmentsPage> createState() => _DepartmentsPageState();
}

class _DepartmentsPageState extends State<DepartmentsPage> {
  final List<Department> _departments = [
    Department(code: 'CS101', name: 'CS', head: 'fuaad', status: 'Active'),
    Department(code: 'Geo101', name: 'Geology', head: 'fuaad', status: 'Active'),
    Department(code: 'Marine101', name: 'Marine', head: 'fuaad', status: 'in active'),
  ];

  final List<String> _statusOptions = ['Active', 'in active'];
  String _searchText = '';
  int? _selectedIndex;

  List<Department> get _filteredDepartments => _departments
      .where(
        (dept) =>
            dept.code.toLowerCase().contains(_searchText.toLowerCase()) ||
            dept.name.toLowerCase().contains(_searchText.toLowerCase()) ||
            dept.head.toLowerCase().contains(_searchText.toLowerCase()) ||
            dept.status.toLowerCase().contains(_searchText.toLowerCase()),
      )
      .toList();

  void _handleRowTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _showAddDepartmentPopup() async {
    final result = await showDialog<Department>(
      context: context,
      builder: (context) => AddDepartmentPopup(statusOptions: _statusOptions),
    );
    if (result != null) {
      setState(() {
        _departments.add(result);
        _selectedIndex = null;
      });
    }
  }

  Future<void> _showEditDepartmentPopup() async {
    if (_selectedIndex == null) return;
    final dept = _filteredDepartments[_selectedIndex!];
    final result = await showDialog<Department>(
      context: context,
      builder: (context) =>
          AddDepartmentPopup(department: dept, statusOptions: _statusOptions),
    );
    if (result != null) {
      int mainIndex = _departments.indexOf(dept);
      setState(() {
        _departments[mainIndex] = result;
      });
    }
  }

  Future<void> _confirmDeleteDepartment() async {
    if (_selectedIndex == null) return;
    final dept = _filteredDepartments[_selectedIndex!];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Department"),
        content: Text("Are you sure you want to delete '${dept.name}'?"),
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
        _departments.remove(dept);
        _selectedIndex = null;
      });
    }
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
            "Departments",
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
                      hintText: "Search departments...",
                      buttonText: "Add Departments",
                      onAddPressed: _showAddDepartmentPopup,
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
                                : _showEditDepartmentPopup,
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
                                : _confirmDeleteDepartment,
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
        1: FixedColumnWidth(120),  // Depart Code
        2: FixedColumnWidth(160),  // Depart Name
        3: FixedColumnWidth(160),  // Head of Depart
        4: FixedColumnWidth(120),  // Status
      },
      border: TableBorder(
        horizontalInside: BorderSide(color: Colors.grey.shade300),
      ),
      children: [
        TableRow(
          children: [
            _tableHeaderCell("No"),
            _tableHeaderCell("Depart Code"),
            _tableHeaderCell("Depart Name"),
            _tableHeaderCell("Head of Depart"),
            _tableHeaderCell("Status"),
          ],
        ),
        for (int index = 0; index < _filteredDepartments.length; index++)
          TableRow(
            decoration: BoxDecoration(
              color: _selectedIndex == index ? Colors.blue.shade50 : Colors.transparent,
            ),
            children: [
              _tableBodyCell('${index + 1}', onTap: () => _handleRowTap(index)),
              _tableBodyCell(_filteredDepartments[index].code, onTap: () => _handleRowTap(index)),
              _tableBodyCell(_filteredDepartments[index].name, onTap: () => _handleRowTap(index)),
              _tableBodyCell(_filteredDepartments[index].head, onTap: () => _handleRowTap(index)),
              _tableBodyCell(_filteredDepartments[index].status, onTap: () => _handleRowTap(index)),
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
            _tableHeaderCell("Depart Code"),
            _tableHeaderCell("Depart Name"),
            _tableHeaderCell("Head of Depart"),
            _tableHeaderCell("Status"),
          ],
        ),
        for (int index = 0; index < _filteredDepartments.length; index++)
          TableRow(
            decoration: BoxDecoration(
              color: _selectedIndex == index ? Colors.blue.shade50 : Colors.transparent,
            ),
            children: [
              _tableBodyCell('${index + 1}', onTap: () => _handleRowTap(index)),
              _tableBodyCell(_filteredDepartments[index].code, onTap: () => _handleRowTap(index)),
              _tableBodyCell(_filteredDepartments[index].name, onTap: () => _handleRowTap(index)),
              _tableBodyCell(_filteredDepartments[index].head, onTap: () => _handleRowTap(index)),
              _tableBodyCell(_filteredDepartments[index].status, onTap: () => _handleRowTap(index)),
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