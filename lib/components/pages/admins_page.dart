import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/admin.dart';
import '../popup/add_admin_popup.dart';
import '../cards/searchBar.dart';

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
  List<String> _facultyNames = [];
  String _searchText = '';
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    _fetchAdmins();
    _fetchFaculties();
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
                if (parts.isNotEmpty)
                  facultyId = parts.last;
                else
                  facultyId = s;
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
        _facultyNames = snapshot.docs
            .map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return data['faculty_name'] ?? 'N/A';
            })
            .cast<String>()
            .toList();
      });

      print("Fetched ${_facultyNames.length} faculties");
    } catch (e) {
      print("Error fetching faculties: $e");
    }
  }

  Future<void> _addAdmin(Admin admin) async {
    final adminData = {
      'username': admin.username,
      'full_name': admin.fullName,
      'faculty_id': facultiesCollection.doc(admin.facultyId),
      'password': admin.password,
      'created_at': FieldValue.serverTimestamp(),
    };

    final userData = {
      'username': admin.username,
      'password': admin.password,
      'role': 'admin',
      'faculty_id': facultiesCollection.doc(admin.facultyId),
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    };

    // Add to admins collection
    await adminsCollection.add(adminData);

    // Add to users collection
    await usersCollection.add(userData);

    _fetchAdmins();
  }

  Future<void> _updateAdmin(Admin admin) async {
    final adminData = {
      'username': admin.username,
      'full_name': admin.fullName,
      'faculty_id': facultiesCollection.doc(admin.facultyId),
      'password': admin.password,
      'updated_at': FieldValue.serverTimestamp(),
    };

    final userData = {
      'username': admin.username, // Update username
      'password': admin.password,
      'faculty_id': facultiesCollection.doc(admin.facultyId),
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
  }

  Future<void> _deleteAdmin(Admin admin) async {
    // Delete from admins collection
    await adminsCollection.doc(admin.id).delete();

    // Delete from users collection
    await usersCollection
        .where('username', isEqualTo: admin.username)
        .get()
        .then((snapshot) {
          for (var doc in snapshot.docs) {
            doc.reference.delete();
          }
        });

    _fetchAdmins();
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
    final admin = _admins[_selectedIndex!];
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
    final admin = _admins[_selectedIndex!];
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
        1: FixedColumnWidth(120), // Admin ID
        2: FixedColumnWidth(140), // Full Name
        3: FixedColumnWidth(120), // Faculty Name
        4: FixedColumnWidth(120), // Password
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
        for (int index = 0; index < _admins.length; index++)
          TableRow(
            decoration: BoxDecoration(
              color: _selectedIndex == index
                  ? Colors.blue.shade50
                  : Colors.transparent,
            ),
            children: [
              _tableBodyCell('${index + 1}', onTap: () => _handleRowTap(index)),
              _tableBodyCell(
                _admins[index].username,
                onTap: () => _handleRowTap(index),
              ),
              _tableBodyCell(
                _admins[index].fullName,
                onTap: () => _handleRowTap(index),
              ),
              _tableBodyCell(
                _admins[index].facultyId,
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
            _tableHeaderCell("No"),
            _tableHeaderCell("Admin ID"),
            _tableHeaderCell("Full Name"),
            _tableHeaderCell("Faculty Name"),
            _tableHeaderCell("Password"),
          ],
        ),
        for (int index = 0; index < _admins.length; index++)
          TableRow(
            decoration: BoxDecoration(
              color: _selectedIndex == index
                  ? Colors.blue.shade50
                  : Colors.transparent,
            ),
            children: [
              _tableBodyCell('${index + 1}', onTap: () => _handleRowTap(index)),
              _tableBodyCell(
                _admins[index].username,
                onTap: () => _handleRowTap(index),
              ),
              _tableBodyCell(
                _admins[index].fullName,
                onTap: () => _handleRowTap(index),
              ),
              _tableBodyCell(
                _admins[index].facultyId,
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
