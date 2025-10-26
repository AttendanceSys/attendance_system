import 'package:flutter/material.dart';

import '../../models/user.dart';
import '../popup/edit_user_popup.dart';
import '../cards/searchBar.dart';
import '../../hooks/use_user_handling.dart';

class UserHandlingPage extends StatefulWidget {
  const UserHandlingPage({super.key});

  @override
  State<UserHandlingPage> createState() => _UserHandlingPageState();
}

class _UserHandlingPageState extends State<UserHandlingPage> {
  final UseUserHandling _dataSource = UseUserHandling();

  // store the actual DB rows (UserHandling) so we keep the DB id for updates
  List<UserHandling> _rows = [];
  bool _isLoading = true;
  String? _loadError;

  String _searchText = '';
  int? _selectedIndex;

  // filtered view of DB rows for the table (teachers + faculty admins only)
  List<UserHandling> get _filteredRows {
    final q = _searchText.toLowerCase();
    return _rows.where((r) {
      final username = (r.username ?? '').toLowerCase();
      final role = (r.role).toLowerCase();
      // filter by search (username or role)
      final matchesSearch = username.contains(q) || role.contains(q);
      return matchesSearch;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadUsersFromDb();
  }

  Future<void> _loadUsersFromDb() async {
    try {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });

      // fetch & sync (will update existing rows if needed)
      // Use dynamic to try multiple possible method names on UseUserHandling,
      // so we don't rely on a single method name that may differ between versions.
      final dynamic ds = _dataSource;
      List<UserHandling> allRows = [];
      try {
        allRows = await ds.fetchUsersWithSync();
      } catch (_) {
        try {
          allRows = await ds.fetchUsers();
        } catch (_) {
          try {
            allRows = await ds.fetchAllUsers();
          } catch (e) {
            // If none of the common methods exist, rethrow a descriptive error.
            throw Exception(
              'No suitable fetch method found on UseUserHandling. Tried fetchUsersWithSync, fetchUsers, fetchAllUsers. Error: $e',
            );
          }
        }
      }

      // keep only teachers and faculty admins (exclude students)
      final filtered = allRows.where((r) {
        final role = (r.role ?? '').toString().toLowerCase().trim();
        return role == 'teacher' ||
            role == 'admin' || // DB 'admin' maps to faculty admin display
            role == 'faculty admin' ||
            role == 'faculty_admin';
      }).toList();

      if (!mounted) return;
      setState(() {
        _rows = filtered;
        _isLoading = false;
        _selectedIndex = null;
      });
    } catch (e, st) {
      debugPrint('UserHandlingPage._loadUsersFromDb error: $e\n$st');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = e.toString();
      });
    }
  }

  Future<void> _showEditUserPopup() async {
    if (_selectedIndex == null) return;

    // pick the selected DB row
    final row = _filteredRows[_selectedIndex!];

    // Build AppUser for the popup (UI model)
    final appUser = AppUser(
      username: row.username ?? '',
      role: // show 'faculty admin' instead of raw 'admin' for display
      (row.role.toLowerCase().trim() == 'admin')
          ? 'faculty admin'
          : (row.role),
      password: row.password ?? '',
    );

    final result = await showDialog<AppUser>(
      context: context,
      builder: (context) => EditUserPopup(user: appUser),
    );

    if (result == null) return;

    // Construct updated UserHandling to send to backend
    final updatedRow = UserHandling(
      id: row.id,
      authUid: row.authUid,
      username: result.username,
      // Normalize role back to DB form: map 'faculty admin' -> 'admin'
      role: (result.role.toLowerCase().trim() == 'faculty admin')
          ? 'admin'
          : result.role,
      password: result.password,
      createdAt: row.createdAt,
      isDisabled: row.isDisabled,
    );

    // Persist update to Supabase
    try {
      await _dataSource.updateUser(row.id, updatedRow);

      // update local list (replace by id)
      final mainIndex = _rows.indexWhere((r) => r.id == row.id);
      if (mainIndex != -1) {
        setState(() {
          _rows[mainIndex] = updatedRow;
          _selectedIndex = null;
        });
      }

      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(const SnackBar(content: Text('User updated')));
      }
    } catch (e) {
      debugPrint('Edit user failed: $e');
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to update user: $e')),
        );
      }
    }
  }

  Future<void> _confirmDisableUser() async {
    if (_selectedIndex == null) return;
    final row = _filteredRows[_selectedIndex!];

    final willDisable = !(row.isDisabled);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(willDisable ? "Disable User" : "Enable User"),
        content: Text(
          willDisable
              ? "Are you sure you want to disable '${row.username ?? ''}'?"
              : "Are you sure you want to enable '${row.username ?? ''}'?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: willDisable ? Colors.orange : Colors.green,
            ),
            child: Text(willDisable ? "Disable" : "Enable"),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // call backend to set is_disabled flag
      final dynamic ds = _dataSource;
      await ds.setUserDisabled(row.id, willDisable);

      // update local list only (preserve other fields)
      final mainIndex = _rows.indexWhere((r) => r.id == row.id);
      if (mainIndex != -1) {
        final existing = _rows[mainIndex];
        final updated = UserHandling(
          id: existing.id,
          authUid: existing.authUid,
          username: existing.username,
          role: existing.role,
          password: existing.password,
          createdAt: existing.createdAt,
          isDisabled: willDisable,
        );
        setState(() {
          _rows[mainIndex] = updated;
          _selectedIndex = null;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(willDisable ? 'User disabled' : 'User enabled'),
          ),
        );
      }
    } catch (e) {
      debugPrint('Disable/Enable user failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to change user status: $e')),
        );
      }
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
          // single loading / error area
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
                "User Handling",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Reload users from DB',
                icon: const Icon(Icons.refresh),
                onPressed: _isLoading
                    ? null
                    : () async {
                        debugPrint('Manual reload requested');
                        await _loadUsersFromDb();
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
                                : _confirmDisableUser,
                            child: Text(
                              (_selectedIndex != null &&
                                      _filteredRows.length > _selectedIndex! &&
                                      _filteredRows[_selectedIndex!].isDisabled)
                                  ? "Enable"
                                  : "Disable",
                              style: const TextStyle(
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
                // clicking blank area unselects the current selection
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
            _tableHeaderCell("Role"),
            _tableHeaderCell("Password"),
          ],
        ),
        for (int index = 0; index < _filteredRows.length; index++)
          TableRow(
            decoration: BoxDecoration(
              color: _selectedIndex == index
                  ? Colors.blue.shade50
                  : Colors.transparent,
            ),
            children: [
              _tableBodyCell('${index + 1}', onTap: () => _handleRowTap(index)),
              _tableBodyCell(
                _filteredRows[index].username ?? '',
                onTap: () => _handleRowTap(index),
              ),
              _tableBodyCell(
                // display "faculty admin" instead of raw 'admin'
                (_filteredRows[index].role.toLowerCase().trim() == 'admin')
                    ? 'faculty admin'
                    : (_filteredRows[index].role),
                onTap: () => _handleRowTap(index),
              ),
              _tableBodyCell(
                _filteredRows[index].isDisabled ? 'Disabled' : '••••••••',
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
            _tableHeaderCell("NO"),
            _tableHeaderCell("Username"),
            _tableHeaderCell("Role"),
            _tableHeaderCell("Password"),
          ],
        ),
        for (int index = 0; index < _filteredRows.length; index++)
          TableRow(
            decoration: BoxDecoration(
              color: _selectedIndex == index
                  ? Colors.blue.shade50
                  : Colors.transparent,
            ),
            children: [
              _tableBodyCell('${index + 1}', onTap: () => _handleRowTap(index)),
              _tableBodyCell(
                _filteredRows[index].username ?? '',
                onTap: () => _handleRowTap(index),
              ),
              _tableBodyCell(
                (_filteredRows[index].role.toLowerCase().trim() == 'admin')
                    ? 'faculty admin'
                    : (_filteredRows[index].role),
                onTap: () => _handleRowTap(index),
              ),
              _tableBodyCell(
                _filteredRows[index].isDisabled ? 'Disabled' : '••••••••',
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
