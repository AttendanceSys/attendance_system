import 'package:flutter/material.dart';
import '../../models/user_model.dart';
import '../popup/edit_faculty_user_popup.dart';
import '../cards/searchBar.dart';

class FacultyUserHandlingPage extends StatefulWidget {
  const FacultyUserHandlingPage({super.key});

  @override
  State<FacultyUserHandlingPage> createState() =>
      _FacultyUserHandlingPageState();
}

class _FacultyUserHandlingPageState extends State<FacultyUserHandlingPage> {
  final List<AppUser> _users = [
    AppUser(username: 'FAC1234', role: 'Faculty Admin', password: '*******'),
    AppUser(username: 'TEACH5678', role: 'Teacher', password: '*******'),
    AppUser(username: 'ASSIST1122', role: 'Assistant', password: '*******'),
    AppUser(username: 'FAC2345', role: 'Faculty Admin', password: '*******'),
  ];

  String _searchText = '';
  int? _selectedIndex;

  List<AppUser> get _filteredUsers => _users
      .where(
        (user) =>
            user.username.toLowerCase().contains(_searchText.toLowerCase()) ||
            user.role.toLowerCase().contains(_searchText.toLowerCase()),
      )
      .toList();

  Future<void> _showEditUserPopup() async {
    if (_selectedIndex == null) return;
    final user = _filteredUsers[_selectedIndex!];
    final result = await showDialog<AppUser>(
      context: context,
      builder: (context) => EditUserPopup(user: user),
    );
    if (result != null) {
      int mainIndex = _users.indexOf(user);
      setState(() {
        _users[mainIndex] = result;
      });
    }
  }

  Future<void> _confirmDeleteUser() async {
    if (_selectedIndex == null) return;
    final user = _filteredUsers[_selectedIndex!];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete User"),
        content: Text("Are you sure you want to delete '${user.username}'?"),
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
        _users.remove(user);
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
            "Faculty User Handling",
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
                      hintText: "Search users...",
                      buttonText: "",
                      onAddPressed: () {}, // Placeholder for add functionality
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
                                : _showEditUserPopup,
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
                                : _confirmDeleteUser,
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
        1: FixedColumnWidth(160),  // Username
        2: FixedColumnWidth(160),  // Role
        3: FixedColumnWidth(120),  // Password
      },
      border: TableBorder(
        horizontalInside: BorderSide(color: Colors.grey.shade300),
      ),
      children: [
        TableRow(
          children: [
            _tableHeaderCell("NO"),
            _tableHeaderCell("Username"),
            _tableHeaderCell("Role"),
            _tableHeaderCell("Password"),
          ],
        ),
        for (int index = 0; index < _filteredUsers.length; index++)
          TableRow(
            decoration: BoxDecoration(
              color: _selectedIndex == index
                  ? Colors.blue.shade50
                  : Colors.transparent,
            ),
            children: [
              _tableBodyCell('${index + 1}', onTap: () => _handleRowTap(index)),
              _tableBodyCell(
                _filteredUsers[index].username,
                onTap: () => _handleRowTap(index),
              ),
              _tableBodyCell(
                _filteredUsers[index].role,
                onTap: () => _handleRowTap(index),
              ),
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
            _tableHeaderCell("NO"),
            _tableHeaderCell("Username"),
            _tableHeaderCell("Role"),
            _tableHeaderCell("Password"),
          ],
        ),
        for (int index = 0; index < _filteredUsers.length; index++)
          TableRow(
            decoration: BoxDecoration(
              color: _selectedIndex == index
                  ? Colors.blue.shade50
                  : Colors.transparent,
            ),
            children: [
              _tableBodyCell('${index + 1}', onTap: () => _handleRowTap(index)),
              _tableBodyCell(
                _filteredUsers[index].username,
                onTap: () => _handleRowTap(index),
              ),
              _tableBodyCell(
                _filteredUsers[index].role,
                onTap: () => _handleRowTap(index),
              ),
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