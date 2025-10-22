import 'package:flutter/material.dart';
// Use UI model only for popup typing; alias to avoid name clash
import '../../models/admin.dart' as ui;
import '../popup/add_admin_popup.dart';
import '../cards/searchBar.dart';
import '../../hooks/use_admins.dart' as api;

class AdminsPage extends StatefulWidget {
  const AdminsPage({super.key});

  @override
  State<AdminsPage> createState() => _AdminsPageState();
}

class _AdminsPageState extends State<AdminsPage> {
  final api.UseAdmins _useAdmins = api.UseAdmins();

  List<api.Admin> _admins = [];
  List<String> _facultyNames = [];

  bool _isLoading = false;
  String? _loadError;

  String _searchText = '';
  int? _selectedIndex;

  List<api.Admin> get _filteredAdmins => _admins
      .where(
        (admin) =>
            (admin.username ?? '').toLowerCase().contains(
              _searchText.toLowerCase(),
            ) ||
            (admin.fullName ?? '').toLowerCase().contains(
              _searchText.toLowerCase(),
            ) ||
            (admin.facultyName ?? '').toLowerCase().contains(
              _searchText.toLowerCase(),
            ),
      )
      .toList();

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    List<api.Admin> admins = [];
    List<String> faculties = [];
    String? err;

    try {
      admins = await _useAdmins.fetchAdmins();
      debugPrint('AdminsPage._loadAll: fetched ${admins.length} admins');
    } catch (e, st) {
      debugPrint('AdminsPage._loadAll: fetchAdmins failed: $e\n$st');
      err = 'Failed to load admins';
    }

    try {
      faculties = await _useAdmins.fetchFacultyNames();
      debugPrint('AdminsPage._loadAll: fetched ${faculties.length} faculties');
    } catch (e, st) {
      debugPrint('AdminsPage._loadAll: fetchFacultyNames failed: $e\n$st');
      err = (err == null)
          ? 'Failed to load faculties'
          : '$err; failed to load faculties';
    }

    if (!mounted) return;
    setState(() {
      _admins = admins;
      _facultyNames = faculties;
      _isLoading = false;
      _selectedIndex = null;
      _loadError = err;
    });
  }

  Future<void> _fetchAdmins() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final admins = await _useAdmins.fetchAdmins();
      if (!mounted) return;
      setState(() {
        _admins = admins;
        _selectedIndex = null;
        _isLoading = false;
      });
    } catch (e, st) {
      debugPrint('AdminsPage._fetchAdmins error: $e\n$st');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = 'Failed to refresh admins';
      });
    }
  }

  Future<void> _showAddAdminPopup() async {
    final result = await showDialog<ui.Admin>(
      context: context,
      builder: (context) => AddAdminPopup(facultyNames: _facultyNames),
    );
    if (result != null) {
      // Check if faculty already has an admin
      final existing = _admins
          .where((a) => a.facultyName == result.facultyName)
          .toList();
      bool shouldReplace = true;
      if (existing.isNotEmpty) {
        // Show confirmation dialog
        shouldReplace =
            await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text("Replace Admin"),
                content: Text(
                  "This faculty already has an admin. Are you sure you want to replace the existing admin with the new one?",
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text("Cancel"),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("Replace"),
                  ),
                ],
              ),
            ) ??
            false;
      }
      if (shouldReplace) {
        // If replacing, delete the old admin first
        if (existing.isNotEmpty) {
          await _useAdmins.deleteAdmin(existing.first.id);
        }
        final admin = api.Admin(
          id: '', // DB will generate uuid
          username: result.id,
          fullName: result.fullName,
          facultyName: result.facultyName,
          password: result.password,
          createdAt: DateTime.now(),
        );
        await _useAdmins.addAdmin(admin);
        await _fetchAdmins();
      }
    }
  }

  Future<void> _showEditAdminPopup() async {
    if (_selectedIndex == null) return;
    final admin = _filteredAdmins[_selectedIndex!];

    // Map API Admin to UI Admin for the popup
    final uiAdmin = ui.Admin(
      id: admin.username ?? '',
      fullName: admin.fullName ?? '',
      facultyName: admin.facultyName ?? '',
      password: admin.password ?? '',
    );

    final result = await showDialog<ui.Admin>(
      context: context,
      builder: (context) =>
          AddAdminPopup(admin: uiAdmin, facultyNames: _facultyNames),
    );
    if (result != null) {
      // Check if another admin exists for the selected faculty (except current)
      final existing = _admins
          .where((a) => a.facultyName == result.facultyName && a.id != admin.id)
          .toList();

      bool shouldReplace = true;
      if (existing.isNotEmpty) {
        // Show confirmation dialog
        shouldReplace =
            await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text("Replace Admin"),
                content: const Text(
                  "This faculty already has an admin. Are you sure you want to replace the existing admin with the new one?",
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text("Cancel"),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text("Replace"),
                  ),
                ],
              ),
            ) ??
            false;
      }
      if (shouldReplace) {
        // If replacing, delete the old admin first (except current)
        if (existing.isNotEmpty) {
          await _useAdmins.deleteAdmin(existing.first.id);
        }
        final updated = api.Admin(
          id: admin.id, // keep DB uuid
          username: result.id,
          fullName: result.fullName,
          facultyName: result.facultyName,
          password: result.password,
          createdAt: admin.createdAt,
        );
        await _useAdmins.updateAdmin(admin.id, updated);
        await _fetchAdmins();
      }
    }
  }

  Future<void> _confirmDeleteAdmin() async {
    if (_selectedIndex == null) return;
    final admin = _filteredAdmins[_selectedIndex!];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Admin"),
        content: Text(
          "Are you sure you want to delete '${admin.fullName ?? ''}'?",
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
      await _useAdmins.deleteAdmin(admin.id);
      await _fetchAdmins();
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
          Row(
            children: [
              const Text(
                "Admins",
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
                onPressed: () async {
                  debugPrint('Manual reload requested');
                  await _loadAll();
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
          if (_loadError != null && !_isLoading)
            Center(
              child: Text(
                _loadError!,
                style: const TextStyle(color: Colors.red),
              ),
            ),

          // Controls (search + buttons)
          if (!_isLoading && _loadError == null)
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
                                padding: const EdgeInsets.symmetric(
                                  vertical: 0,
                                  horizontal: 0,
                                ),
                              ),
                              onPressed: _selectedIndex == null
                                  ? null
                                  : _showEditAdminPopup,
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
                                  : _confirmDeleteAdmin,
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

          // TABLE AREA — wrap in GestureDetector so tapping blank area clears selection
          if (!_isLoading && _loadError == null)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  // clicking blank area unselects the current row
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
        1: FixedColumnWidth(140), // Admin Username
        2: FixedColumnWidth(180), // Full Name
        3: FixedColumnWidth(140), // Faculty Name
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
          ],
        ),
        for (int index = 0; index < _filteredAdmins.length; index++)
          TableRow(
            decoration: BoxDecoration(
              color: _selectedIndex == index
                  ? Colors.blue.shade50
                  : Colors.transparent,
            ),
            children: [
              _tableBodyCell('${index + 1}', onTap: () => _handleRowTap(index)),
              _tableBodyCell(
                _filteredAdmins[index].username ?? '',
                onTap: () => _handleRowTap(index),
              ),
              _tableBodyCell(
                _filteredAdmins[index].fullName ?? '',
                onTap: () => _handleRowTap(index),
              ),
              _tableBodyCell(
                _filteredAdmins[index].facultyName ?? '',
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
            _tableHeaderCell("Admin ID"),
            _tableHeaderCell("Full Name"),
            _tableHeaderCell("Faculty Name"),
          ],
        ),
        for (int index = 0; index < _filteredAdmins.length; index++)
          TableRow(
            decoration: BoxDecoration(
              color: _selectedIndex == index
                  ? Colors.blue.shade50
                  : Colors.transparent,
            ),
            children: [
              _tableBodyCell('${index + 1}', onTap: () => _handleRowTap(index)),
              _tableBodyCell(
                _filteredAdmins[index].username ?? '',
                onTap: () => _handleRowTap(index),
              ),
              _tableBodyCell(
                _filteredAdmins[index].fullName ?? '',
                onTap: () => _handleRowTap(index),
              ),
              _tableBodyCell(
                _filteredAdmins[index].facultyName ?? '',
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
