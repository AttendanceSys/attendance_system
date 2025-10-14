import 'package:flutter/material.dart';
import '../../models/admin.dart';
import '../popup/add_admin_popup.dart';
import '../cards/searchBar.dart';

class AdminsPage extends StatefulWidget {
  const AdminsPage({super.key});

  @override
  State<AdminsPage> createState() => _AdminsPageState();
}

class _AdminsPageState extends State<AdminsPage> {
  final List<Admin> _admins = [
    Admin(id: 'SNU1234', fullName: 'Cali', facultyName: 'ENG', password: '*******'),
    Admin(id: 'SNU5678', fullName: 'Amina', facultyName: 'ENG', password: '*******'),
    Admin(id: 'SNU9101', fullName: 'Yusuf', facultyName: 'ENG', password: '*******'),
    Admin(id: 'SNU1121', fullName: 'Fatima', facultyName: 'ENG', password: '*******'),
  ];

  final List<String> _facultyNames = [
    'ENG',
    'SCI',
    'MED',
    'EDU',
  ];

  String _searchText = '';
  int? _selectedIndex;

  List<Admin> get _filteredAdmins => _admins
      .where((admin) =>
          admin.id.toLowerCase().contains(_searchText.toLowerCase()) ||
          admin.fullName.toLowerCase().contains(_searchText.toLowerCase()) ||
          admin.facultyName.toLowerCase().contains(_searchText.toLowerCase()))
      .toList();

  Future<void> _showAddAdminPopup() async {
    final result = await showDialog<Admin>(
      context: context,
      builder: (context) => AddAdminPopup(facultyNames: _facultyNames),
    );
    if (result != null) {
      setState(() {
        _admins.add(result);
        _selectedIndex = null;
      });
    }
  }

  Future<void> _showEditAdminPopup() async {
    if (_selectedIndex == null) return;
    final admin = _filteredAdmins[_selectedIndex!];
    final result = await showDialog<Admin>(
      context: context,
      builder: (context) => AddAdminPopup(admin: admin, facultyNames: _facultyNames),
    );
    if (result != null) {
      int mainIndex = _admins.indexOf(admin);
      setState(() {
        _admins[mainIndex] = result;
      });
    }
  }

  Future<void> _confirmDeleteAdmin() async {
    if (_selectedIndex == null) return;
    final admin = _filteredAdmins[_selectedIndex!];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Admin"),
        content: Text("Are you sure you want to delete '${admin.fullName}'?"),
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
        _admins.remove(admin);
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
            "Admins",
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
                      hintText: "Search Admin...",
                      buttonText: "Add Admin",
                      onAddPressed: _showAddAdminPopup,
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
                            onPressed: _selectedIndex == null ? null : _showEditAdminPopup,
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
                            onPressed: _selectedIndex == null ? null : _confirmDeleteAdmin,
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
        0: FixedColumnWidth(64),    // No
        1: FixedColumnWidth(120),   // Admin ID
        2: FixedColumnWidth(140),   // Full Name
        3: FixedColumnWidth(120),   // Faculty Name
        4: FixedColumnWidth(120),   // Password
      },
      border: TableBorder(
        horizontalInside: BorderSide(color: Colors.grey.shade300),
      ),
      children: [
        TableRow(
          children: [
            _tableHeaderCell("No"),
            _tableHeaderCell("Admin ID"),
            _tableHeaderCell("Full Name"),
            _tableHeaderCell("Faculty Name"),
            _tableHeaderCell("Password"),
          ],
        ),
        for (int index = 0; index < _filteredAdmins.length; index++)
          TableRow(
            decoration: BoxDecoration(
              color: _selectedIndex == index ? Colors.blue.shade50 : Colors.transparent,
            ),
            children: [
              _tableBodyCell('${index + 1}', onTap: () => _handleRowTap(index)),
              _tableBodyCell(_filteredAdmins[index].id, onTap: () => _handleRowTap(index)),
              _tableBodyCell(_filteredAdmins[index].fullName, onTap: () => _handleRowTap(index)),
              _tableBodyCell(_filteredAdmins[index].facultyName, onTap: () => _handleRowTap(index)),
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
            _tableHeaderCell("Admin ID"),
            _tableHeaderCell("Full Name"),
            _tableHeaderCell("Faculty Name"),
            _tableHeaderCell("Password"),
          ],
        ),
        for (int index = 0; index < _filteredAdmins.length; index++)
          TableRow(
            decoration: BoxDecoration(
              color: _selectedIndex == index ? Colors.blue.shade50 : Colors.transparent,
            ),
            children: [
              _tableBodyCell('${index + 1}', onTap: () => _handleRowTap(index)),
              _tableBodyCell(_filteredAdmins[index].id, onTap: () => _handleRowTap(index)),
              _tableBodyCell(_filteredAdmins[index].fullName, onTap: () => _handleRowTap(index)),
              _tableBodyCell(_filteredAdmins[index].facultyName, onTap: () => _handleRowTap(index)),
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