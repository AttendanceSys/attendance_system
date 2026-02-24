//admin page
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../../models/admin.dart';
import '../popup/add_admin_popup.dart';
import '../cards/searchBar.dart';
import '../admin_page_skeleton.dart';
import '../../theme/super_admin_theme.dart';
import '../../utils/download_bytes.dart';

class AdminsPage extends StatefulWidget {
  const AdminsPage({super.key});

  @override
  State<AdminsPage> createState() => _AdminsPageState();
}

class _AdminsPageState extends State<AdminsPage> {
  final CollectionReference adminsCollection = FirebaseFirestore.instance
      .collection('admins');
  final CollectionReference facultiesCollection = FirebaseFirestore.instance
      .collection('faculties');
  final CollectionReference usersCollection = FirebaseFirestore.instance
      .collection('users'); // Reference to users collection

  List<Admin> _admins = [];
  final Map<String, String> _facultyIdToName = {};
  final Map<String, String> _facultyNameToId = {};
  List<String> _facultyNames = [];
  String _searchText = '';
  int? _selectedIndex;
  bool _loading = true;

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blueGrey.shade800,
      ),
    );
  }

  List<Admin> get _filteredAdmins {
    final query = _searchText.trim().toLowerCase();
    if (query.isEmpty) return _admins;
    return _admins
        .where(
          (admin) =>
              admin.username.toLowerCase().startsWith(query) ||
              admin.fullName.toLowerCase().startsWith(query),
        )
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await Future.wait([_fetchAdmins(), _fetchFaculties()]);
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchAdmins() async {
    try {
      final snapshot = await adminsCollection.get();

      setState(() {
        _admins = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;

          // faculty_id in the DB may be stored as a DocumentReference or as a string
          // (e.g. '/faculties/Engineering' or 'Engineering'). Normalize to the id.
          String facultyId = 'N/A';
          final facCandidate =
              data['faculty_ref'] ?? data['faculty_id'] ?? data['faculty'];
          if (facCandidate != null) {
            if (facCandidate is DocumentReference) {
              facultyId = facCandidate.id;
            } else if (facCandidate is String) {
              final s = facCandidate;
              // try to extract last path segment if a path was stored
              if (s.contains('/')) {
                final parts = s.split('/').where((p) => p.isNotEmpty).toList();
                if (parts.isNotEmpty) {
                  facultyId = parts.last;
                } else {
                  facultyId = s;
                }
              } else {
                facultyId = s;
              }
            } else {
              facultyId = facCandidate.toString();
            }
          }

          return Admin(
            id: doc.id,
            username: data['username'] ?? 'N/A',
            fullName: data['full_name'] ?? 'N/A',
            facultyId: facultyId,
            password: data['password'] ?? '',
            createdAt:
                (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
          );
        }).toList();
      });

      print("Fetched ${_admins.length} admins");
    } catch (e) {
      print("Error fetching admins: $e");
    }
  }

  Future<void> _fetchFaculties() async {
    try {
      final snapshot = await facultiesCollection.get();

      setState(() {
        _facultyIdToName
          ..clear()
          ..addEntries(
            snapshot.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final name = (data['faculty_name'] ?? '').toString().trim();
              return MapEntry(doc.id, name);
            }),
          );
        _facultyNameToId
          ..clear()
          ..addEntries(
            _facultyIdToName.entries.map(
              (e) => MapEntry(e.value.toLowerCase().trim(), e.key),
            ),
          );
        _facultyNames = _facultyIdToName.values.toList();
      });

      print("Fetched ${_facultyNames.length} faculties");
    } catch (e) {
      print("Error fetching faculties: $e");
    }
  }

  String? _resolveFacultyId(String rawValue) {
    final raw = rawValue.trim();
    if (raw.isEmpty) return null;
    final byName = _facultyNameToId[raw.toLowerCase()];
    if (byName != null && byName.isNotEmpty) return byName;
    if (_facultyIdToName.containsKey(raw)) return raw;
    if (raw.contains('/')) {
      final parts = raw.split('/').where((p) => p.isNotEmpty).toList();
      if (parts.isNotEmpty) return parts.last;
    }
    return raw;
  }

  String _displayFacultyName(String rawValue) {
    final resolvedId = _resolveFacultyId(rawValue);
    if (resolvedId == null) return rawValue;
    return _facultyIdToName[resolvedId] ?? rawValue;
  }

  Future<void> _addAdmin(Admin admin) async {
    final facultyId = _resolveFacultyId(admin.facultyId) ?? admin.facultyId;
    final adminData = {
      'username': admin.username,
      'full_name': admin.fullName,
      'faculty_id': facultiesCollection.doc(facultyId),
      'password': admin.password,
      'created_at': FieldValue.serverTimestamp(),
    };

    final userData = {
      'username': admin.username,
      'password': admin.password,
      'role': 'admin',
      'faculty_id': facultiesCollection.doc(facultyId),
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    };

    // Add to admins collection
    await adminsCollection.add(adminData);

    // Add to users collection
    await usersCollection.add(userData);

    _fetchAdmins();
    _showSnack('Admin added successfully');
  }

  Future<void> _updateAdmin(Admin admin) async {
    final facultyId = _resolveFacultyId(admin.facultyId) ?? admin.facultyId;
    final adminData = {
      'username': admin.username,
      'full_name': admin.fullName,
      'faculty_id': facultiesCollection.doc(facultyId),
      'password': admin.password,
      'updated_at': FieldValue.serverTimestamp(),
    };

    final userData = {
      'username': admin.username, // Update username
      'password': admin.password,
      'role': 'admin',
      'faculty_id': facultiesCollection.doc(facultyId),
      'updated_at': FieldValue.serverTimestamp(),
    };

    // Fetch the old admin data to check for username changes
    final oldAdminSnapshot = await adminsCollection.doc(admin.id).get();
    final oldAdminData = oldAdminSnapshot.data() as Map<String, dynamic>;
    final oldUsername = oldAdminData['username'];

    // Update in admins collection
    await adminsCollection.doc(admin.id).update(adminData);

    // Update in users collection
    await usersCollection
        .where(
          'username',
          isEqualTo: oldUsername,
        ) // Use old username to find the user
        .get()
        .then((snapshot) {
          for (var doc in snapshot.docs) {
            doc.reference.update(userData);
          }
        });

    _fetchAdmins();
    _showSnack('Admin updated successfully');
  }

  Future<void> _deleteAdmin(Admin admin) async {
    // Delete from admins collection
    await adminsCollection.doc(admin.id).delete();

    // Delete from users collection
    await usersCollection
        .where('username', isEqualTo: admin.username)
        .where('role', isEqualTo: 'admin')
        .get()
        .then((snapshot) {
          for (var doc in snapshot.docs) {
            doc.reference.delete();
          }
        });

    _fetchAdmins();
    _showSnack('Admin deleted successfully');
  }

  Future<bool> _addAdminFromUpload(Admin admin) async {
    try {
      final username = admin.username.trim();
      final fullName = admin.fullName.trim();
      final password = admin.password.trim();
      final facultyId = _resolveFacultyId(admin.facultyId) ?? '';

      if (username.isEmpty ||
          fullName.isEmpty ||
          password.isEmpty ||
          facultyId.isEmpty) {
        return false;
      }

      final adminDup = await adminsCollection
          .where('username', isEqualTo: username)
          .limit(1)
          .get();
      if (adminDup.docs.isNotEmpty) return false;

      final userDup = await usersCollection
          .where('username', isEqualTo: username)
          .limit(1)
          .get();
      if (userDup.docs.isNotEmpty) return false;

      final adminData = {
        'username': username,
        'full_name': fullName,
        'faculty_id': facultiesCollection.doc(facultyId),
        'password': password,
        'created_at': FieldValue.serverTimestamp(),
      };

      final userData = {
        'username': username,
        'password': password,
        'role': 'admin',
        'faculty_id': facultiesCollection.doc(facultyId),
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };

      await adminsCollection.add(adminData);
      await usersCollection.add(userData);
      return true;
    } catch (e) {
      print('Error adding admin from upload: $e');
      return false;
    }
  }

  Future<void> _handleUploadAdmins() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );
      if (result == null) return;
      final file = result.files.first;
      if (file.bytes == null) return;

      final content = utf8.decode(file.bytes!);
      final rows = const CsvToListConverter(eol: '\n').convert(content);
      if (rows.isEmpty) return;

      final headers = rows.first
          .map((h) => h.toString().toLowerCase().trim())
          .toList();
      final parsed = <Map<String, String>>[];
      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.every((c) => (c ?? '').toString().trim().isEmpty)) continue;
        final map = <String, String>{};
        for (int c = 0; c < headers.length && c < row.length; c++) {
          map[headers[c]] = row[c]?.toString().trim() ?? '';
        }
        parsed.add(map);
      }
      if (parsed.isEmpty) return;

      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirm upload'),
          content: Text('Import ${parsed.length} admins?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Import'),
            ),
          ],
        ),
      );
      if (proceed != true) return;

      int added = 0;
      int skipped = 0;
      for (final row in parsed) {
        final username = (row['username'] ?? '').toString().trim();
        final fullName =
            (row['full_name'] ??
                    row['full name'] ??
                    row['admin_name'] ??
                    row['admin name'] ??
                    row['name'] ??
                    '')
                .toString()
                .trim();
        final facultyRaw =
            (row['faculty_id'] ??
                    row['faculty_ref'] ??
                    row['faculty_name'] ??
                    row['faculty name'] ??
                    row['faculty'] ??
                    '')
                .toString()
                .trim();
        final password = (row['password'] ?? '').toString().trim();

        final admin = Admin(
          id: '',
          username: username,
          fullName: fullName,
          facultyId: facultyRaw,
          password: password,
          createdAt: DateTime.now(),
        );
        final ok = await _addAdminFromUpload(admin);
        if (ok) {
          added++;
        } else {
          skipped++;
        }
      }

      await _fetchAdmins();
      _showSnack('Imported $added, skipped $skipped');
    } catch (e) {
      _showSnack('Failed to import admins');
    }
  }

  Future<void> _handleExportAdminsCsv() async {
    try {
      final rows = <List<dynamic>>[
        ['No', 'Username', 'Admin Name', 'Faculty'],
      ];
      for (int i = 0; i < _admins.length; i++) {
        final a = _admins[i];
        rows.add([
          i + 1,
          a.username,
          a.fullName,
          _displayFacultyName(a.facultyId),
        ]);
      }

      final csv = const ListToCsvConverter().convert(rows);
      final bytes = Uint8List.fromList(utf8.encode(csv));
      final now = DateTime.now();
      final fileName =
          'admins_${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.csv';

      final downloaded = await downloadBytes(
        bytes: bytes,
        fileName: fileName,
        mimeType: 'text/csv;charset=utf-8',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            downloaded
                ? 'CSV exported: $fileName'
                : 'CSV export is currently supported on web only',
          ),
        ),
      );
    } catch (e) {
      _showSnack('Failed to export admins CSV');
    }
  }

  Future<void> _showAddAdminPopup() async {
    final result = await showDialog<Admin>(
      context: context,
      builder: (context) => AddAdminPopup(facultyNames: _facultyNames),
    );
    if (result != null) {
      _addAdmin(result);
    }
  }

  Future<void> _showEditAdminPopup() async {
    if (_selectedIndex == null) return;
    var admin = _filteredAdmins[_selectedIndex!];
    final facultyName = _facultyIdToName[admin.facultyId];
    if (facultyName != null && facultyName.isNotEmpty) {
      admin = admin.copyWith(facultyId: facultyName);
    }
    final result = await showDialog<Admin>(
      context: context,
      builder: (context) =>
          AddAdminPopup(admin: admin, facultyNames: _facultyNames),
    );
    if (result != null) {
      _updateAdmin(result);
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
      _deleteAdmin(admin);
    }
  }

  void _handleRowTap(int index) {
    setState(() {
      _selectedIndex = _selectedIndex == index ? null : index;
    });
  }

  void _clearSelection() {
    if (_selectedIndex == null) return;
    setState(() => _selectedIndex = null);
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isDesktop = screenWidth > 800;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final disabledActionBg = isDark
        ? const Color(0xFF4234A4)
        : const Color(0xFF8372FE);

    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            "Admins",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Theme.of(
                context,
              ).extension<SuperAdminColors>()?.textPrimary,
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
                    if (isDesktop)
                      Row(
                        children: [
                          Expanded(
                            child: SearchAddBar(
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
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _handleUploadAdmins,
                              icon: const Icon(Icons.upload_file),
                              label: const Text('Upload Admins'),
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: const Color.fromARGB(
                                  255,
                                  0,
                                  150,
                                  80,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _handleExportAdminsCsv,
                              icon: const Icon(Icons.download),
                              label: const Text('Export CSV'),
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: const Color(0xFF1F6FEB),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    else ...[
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
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _handleUploadAdmins,
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Upload Admins'),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: const Color.fromARGB(
                              255,
                              0,
                              150,
                              80,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _handleExportAdminsCsv,
                          icon: const Icon(Icons.download),
                          label: const Text('Export CSV'),
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: const Color(0xFF1F6FEB),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ],
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
                              disabledBackgroundColor: disabledActionBg,
                              disabledForegroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
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
                              disabledBackgroundColor: disabledActionBg,
                              disabledForegroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
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
          Expanded(
            child: _loading
                ? const AdminsPageSkeleton()
                : Container(
                    width: double.infinity,
                    color: Colors.transparent,
                    child: isDesktop
                        ? _buildDesktopTable()
                        : SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: _buildMobileTable(),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTable() {
    return _buildSaasTable(
      columnWidths: const {
        0: FixedColumnWidth(72),
        1: FlexColumnWidth(1.1),
        2: FlexColumnWidth(1.3),
        3: FlexColumnWidth(1.2),
      },
    );
  }

  Widget _buildMobileTable() {
    return _buildSaasTable(
      columnWidths: const {
        0: FixedColumnWidth(72),
        1: FixedColumnWidth(180),
        2: FixedColumnWidth(220),
        3: FixedColumnWidth(210),
      },
    );
  }

  Widget _buildSaasTable({required Map<int, TableColumnWidth> columnWidths}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = Theme.of(context).extension<SuperAdminColors>();
    final scheme = Theme.of(context).colorScheme;
    final surface = palette?.surface ?? scheme.surface;
    final border =
        palette?.border ??
        (isDark ? const Color(0xFF3A404E) : const Color(0xFFD7DCEA));
    final headerBg = palette?.surfaceHigh ?? scheme.surfaceContainerHighest;
    final textPrimary = palette?.textPrimary ?? scheme.onSurface;
    final selectedBg =
        palette?.selectedBg ??
        Color.alphaBlend(
          (palette?.accent ?? const Color(0xFF6A46FF)).withValues(alpha: 0.12),
          surface,
        );
    final divider = border.withValues(alpha: isDark ? 0.7 : 0.85);

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: divider),
        boxShadow: [
          BoxShadow(
            color: (palette?.accent ?? const Color(0xFF6A46FF)).withValues(
              alpha: isDark ? 0.06 : 0.08,
            ),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Table(
              columnWidths: columnWidths,
              children: [
                TableRow(
                  decoration: BoxDecoration(color: headerBg),
                  children: [
                    _tableHeaderCell("No", textPrimary),
                    _tableHeaderCell("Username", textPrimary),
                    _tableHeaderCell("Admin Name", textPrimary),
                    _tableHeaderCell("Faculty Name", textPrimary),
                  ],
                ),
              ],
            ),
            Container(height: 1, color: divider),
            Expanded(
              child: SingleChildScrollView(
                primary: false,
                child: Table(
                  columnWidths: columnWidths,
                  border: TableBorder(horizontalInside: BorderSide(color: divider)),
                  children: [
                    for (int index = 0; index < _filteredAdmins.length; index++)
                      TableRow(
                        decoration: BoxDecoration(
                          color: _selectedIndex == index ? selectedBg : surface,
                        ),
                        children: [
                          _tableBodyCell(
                            '${index + 1}',
                            textPrimary,
                            onTap: () => _handleRowTap(index),
                          ),
                          _tableBodyCell(
                            _filteredAdmins[index].username,
                            textPrimary,
                            onTap: () => _handleRowTap(index),
                          ),
                          _tableBodyCell(
                            _filteredAdmins[index].fullName,
                            textPrimary,
                            onTap: () => _handleRowTap(index),
                          ),
                          _tableBodyCell(
                            _displayFacultyName(_filteredAdmins[index].facultyId),
                            textPrimary,
                            onTap: () => _handleRowTap(index),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tableHeaderCell(String text, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 24),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          color: textColor,
          letterSpacing: 0.1,
        ),
        textAlign: TextAlign.left,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _tableBodyCell(String text, Color textColor, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      hoverColor: Colors.transparent,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        child: Text(
          text,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14.5,
            color: textColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
