import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../hooks/use_user_handling.dart';
import '../popup/edit_user_popup.dart';
import '../cards/searchBar.dart';

class FacultyUserHandlingPage extends StatefulWidget {
  const FacultyUserHandlingPage({super.key});

  @override
  State<FacultyUserHandlingPage> createState() =>
      _FacultyUserHandlingPageState();
}

class _FacultyUserHandlingPageState extends State<FacultyUserHandlingPage> {
  final UseUserHandling _userService = UseUserHandling();

  // If we want to show students on this page, use the student handler
  final UseStudentHandling _studentService = UseStudentHandling();

  // Hold user_handling rows fetched from Supabase
  List<UserHandling> _users = [];

  String _searchText = '';
  int? _selectedIndex;

  bool _isLoading = false;
  String? _loadError;

  List<UserHandling> get _filteredUsers => _users
      .where(
        (user) =>
            (user.usernames ?? '').toLowerCase().contains(
              _searchText.toLowerCase(),
            ) ||
            user.role.toLowerCase().contains(_searchText.toLowerCase()),
      )
      .toList();

  Future<void> _showEditUserPopup() async {
    if (_selectedIndex == null) return;
    final userRow = _filteredUsers[_selectedIndex!];

    final appUser = AppUser(
      username: userRow.usernames ?? '',
      role: userRow.role,
      password: userRow.passwords ?? '',
    );

    final result = await showDialog<AppUser>(
      context: context,
      builder: (context) => EditUserPopup(user: appUser),
    );

    if (result != null) {
      final updated = UserHandling(
        id: userRow.id,
        authUid: userRow.authUid,
        usernames: result.username,
        role: result.role.toLowerCase(),
        passwords: result.password,
        createdAt: userRow.createdAt,
      );

      try {
        await _userService.updateUser(userRow.id, updated);
        final mainIndex = _users.indexWhere((u) => u.id == userRow.id);
        if (mainIndex != -1) {
          setState(() {
            _users[mainIndex] = updated;
            _selectedIndex = null;
          });
        }
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('User updated')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to update user: $e')));
        }
      }
    }
  }

  Future<void> _confirmDeleteUser() async {
    if (_selectedIndex == null) return;
    final user = _filteredUsers[_selectedIndex!];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete User"),
        content: Text(
          "Are you sure you want to delete '${user.usernames ?? ''}'?",
        ),
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
        _users.removeWhere((u) => u.id == user.id);
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
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      // Fetch students (role = 'student') and map to UserHandling so UI stays the same
      final studentList = await _studentService.fetchStudentsWithSync();
      final mapped = studentList
          .map(
            (s) => UserHandling(
              id: s.id,
              authUid: s.authUid,
              usernames: s.usernames,
              role: s.role,
              passwords: s.passwords,
              createdAt: s.createdAt,
            ),
          )
          .toList();
      if (!mounted) return;
      setState(() {
        _users = mapped;
        _isLoading = false;
      });
    } catch (e, st) {
      debugPrint('FacultyUserHandlingPage._loadUsers error: $e\n$st');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = e.toString();
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
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: LinearProgressIndicator(),
            ),
          if (_loadError != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'Failed to load users: $_loadError',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                "Faculty User Handling",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Reload from DB',
                icon: const Icon(Icons.refresh),
                onPressed: _isLoading
                    ? null
                    : () async {
                        debugPrint('Manual reload requested');
                        await _loadUsers();
                      },
              ),
            ],
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
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                // clicking blank area unselects
                setState(() {
                  _selectedIndex = null;
                });
              },
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
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable() {
    return Table(
      columnWidths: const {
        0: FixedColumnWidth(64), // No
        1: FixedColumnWidth(160), // Username
        2: FixedColumnWidth(160), // Role
        3: FixedColumnWidth(120), // Password
      },
      border: TableBorder(
        horizontalInside: BorderSide(color: Colors.grey.shade300),
      ),
      children: [
        TableRow(
          children: [
            _tableHeaderCell("NO"),
            _tableHeaderCell("Username"),
            _table_header_cell_for_role(),
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
                _filteredUsers[index].usernames ?? '',
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

  // Small helper to keep header consistent in both desktop/mobile builds
  Widget _table_header_cell_for_role() {
    return _tableHeaderCell("Role");
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
                _filteredUsers[index].usernames ?? '',
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
        child: Text(text, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}