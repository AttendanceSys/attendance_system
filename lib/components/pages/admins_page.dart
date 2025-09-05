import 'package:flutter/material.dart';
import '../../models/admin.dart';
import '../popup/add_admin_popup.dart';
import '../cards/searchBar.dart';

class AdminsPage extends StatefulWidget {
  const AdminsPage({Key? key}) : super(key: key);

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
      });
    }
  }

  Future<void> _showEditAdminPopup(int index) async {
    final admin = _filteredAdmins[index];
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

  Future<void> _confirmDeleteAdmin(int index) async {
    final admin = _filteredAdmins[index];
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
            "Admins",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 24),
          SearchAddBar(
            hintText: "Search Admin...",
            buttonText: "Add Admin",
            onAddPressed: _showAddAdminPopup,
            onChanged: (value) => setState(() => _searchText = value),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              width: double.infinity,
              color: Colors.transparent,
              child: isMobile
                  ? SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        columnSpacing: 24,
                        headingRowHeight: 48,
                        dataRowHeight: 44,
                        columns: const [
                          DataColumn(label: Text("No", style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text("Admin ID", style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text("Full Name", style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text("Faculty Name", style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text("Password", style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text("")),
                        ],
                        rows: List.generate(_filteredAdmins.length, (index) {
                          final admin = _filteredAdmins[index];
                          return DataRow(cells: [
                            DataCell(Text('${index + 1}')),
                            DataCell(Text(admin.id)),
                            DataCell(Text(admin.fullName)),
                            DataCell(Text(admin.facultyName)),
                            DataCell(Text(admin.password)),
                            DataCell(
                              Row(
                                children: [
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      minimumSize: const Size(32, 28),
                                      padding: const EdgeInsets.symmetric(horizontal: 6),
                                    ),
                                    onPressed: () => _showEditAdminPopup(index),
                                    child: const Text("Edit", style: TextStyle(fontSize: 13, color: Colors.white)),
                                  ),
                                  const SizedBox(width: 4),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      minimumSize: const Size(32, 28),
                                      padding: const EdgeInsets.symmetric(horizontal: 6),
                                    ),
                                    onPressed: () => _confirmDeleteAdmin(index),
                                    child: const Text("Delete", style: TextStyle(fontSize: 13, color: Colors.white)),
                                  ),
                                ],
                              ),
                            ),
                          ]);
                        }),
                      ),
                    )
                  : SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: DataTable(
                        columnSpacing: 24,
                        headingRowHeight: 48,
                        dataRowHeight: 44,
                        columns: const [
                          DataColumn(label: Text("No", style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text("Admin ID", style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text("Full Name", style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text("Faculty Name", style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text("Password", style: TextStyle(fontWeight: FontWeight.bold))),
                          DataColumn(label: Text("")),
                        ],
                        rows: List.generate(_filteredAdmins.length, (index) {
                          final admin = _filteredAdmins[index];
                          return DataRow(cells: [
                            DataCell(Text('${index + 1}')),
                            DataCell(Text(admin.id)),
                            DataCell(Text(admin.fullName)),
                            DataCell(Text(admin.facultyName)),
                            DataCell(Text(admin.password)),
                            DataCell(
                              Row(
                                children: [
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      minimumSize: const Size(32, 28),
                                      padding: const EdgeInsets.symmetric(horizontal: 6),
                                    ),
                                    onPressed: () => _showEditAdminPopup(index),
                                    child: const Text("Edit", style: TextStyle(fontSize: 13, color: Colors.white)),
                                  ),
                                  const SizedBox(width: 4),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      minimumSize: const Size(32, 28),
                                      padding: const EdgeInsets.symmetric(horizontal: 6),
                                    ),
                                    onPressed: () => _confirmDeleteAdmin(index),
                                    child: const Text("Delete", style: TextStyle(fontSize: 13, color: Colors.white)),
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