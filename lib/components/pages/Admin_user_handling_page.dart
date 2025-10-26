import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user.dart';
import '../popup/edit_user_popup.dart';
import '../cards/searchBar.dart';

class UserHandlingPage extends StatefulWidget {
  const UserHandlingPage({super.key});

  @override
  State<UserHandlingPage> createState() => _UserHandlingPageState();
}

class _UserHandlingPageState extends State<UserHandlingPage> {
  final CollectionReference usersCollection = FirebaseFirestore.instance.collection('users');
  final CollectionReference adminsCollection = FirebaseFirestore.instance.collection('admins');
  final CollectionReference facultiesCollection = FirebaseFirestore.instance.collection('faculties');
  final CollectionReference teachersCollection = FirebaseFirestore.instance.collection('teachers');

  List<AppUser> _users = [];
  String _searchText = '';
  int? _selectedIndex;

  // Track password visibility for individual users
  Map<int, bool> _passwordVisibility = {};

  List<AppUser> get _filteredUsers => _users
      .where(
        (user) =>
            user.role != 'Super admin' &&
            (user.username.toLowerCase().contains(_searchText.toLowerCase()) ||
                user.role.toLowerCase().contains(_searchText.toLowerCase()) ||
                user.status.toLowerCase().contains(_searchText.toLowerCase())),
      )
      .toList();

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    try {
      final snapshot = await usersCollection.get();
      setState(() {
        _users = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;

          return AppUser(
            id: doc.id,
            username: data['username'] ?? '',
            role: data['role'] ?? '',
            password: data['password'] ?? '',
            facultyId: (data['faculty_id'] is DocumentReference)
                ? (data['faculty_id'] as DocumentReference).id
                : data['faculty_id'] ?? '',
            status: data['status'] ?? 'enabled',
            createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
            updatedAt: (data['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
          );
        }).toList();

        // Initialize password visibility for each user
        _passwordVisibility = {for (int i = 0; i < _users.length; i++) i: false};
      });
      print("Fetched ${_users.length} users");
    } catch (e) {
      print("Error fetching users: $e");
    }
  }

  Future<void> _toggleUserStatus(AppUser user) async {
    final newStatus = user.status == 'enabled' ? 'disabled' : 'enabled';
    await usersCollection.doc(user.id).update({
      'status': newStatus, // Toggle between enabled and disabled
      'updated_at': FieldValue.serverTimestamp(), // Update timestamp
    });
    _fetchUsers();
  }

  Future<void> _showEditUserPopup() async {
    if (_selectedIndex == null) return;
    final user = _filteredUsers[_selectedIndex!];
    final result = await showDialog<AppUser>(
      context: context,
      builder: (context) => EditUserPopup(user: user),
    );
    if (result != null) {
      // Update the users collection
      await usersCollection.doc(user.id).update(result.toFirestore());

      // If the user is an admin, update the admins collection
      if (user.role == 'admin') {
        await adminsCollection
            .where('username', isEqualTo: user.username)
            .get()
            .then((snapshot) {
              for (var doc in snapshot.docs) {
                doc.reference.update({
                  'username': result.username, // Update username
                  'password': result.password, // Update password
                  'updated_at': FieldValue.serverTimestamp(), // Update timestamp
                });
              }
            });
      }

      // If the user is a teacher, update the teachers collection
      if (user.role == 'teacher') {
        await teachersCollection
            .where('username', isEqualTo: user.username)
            .get()
            .then((snapshot) {
              for (var doc in snapshot.docs) {
                doc.reference.update({
                  'username': result.username, // Update username
                  'password': result.password, // Update password
                  'updated_at': FieldValue.serverTimestamp(), // Update timestamp
                });
              }
            });
      }

      _fetchUsers();
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
            "User Handling",
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
                      onAddPressed: () {},
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
                            onPressed: _selectedIndex == null ? null : _showEditUserPopup,
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
                          width: 100,
                          height: 36,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
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
                                : () => _toggleUserStatus(_filteredUsers[_selectedIndex!]),
                            child: Text(
                              _selectedIndex != null &&
                                      _filteredUsers[_selectedIndex!].status == 'enabled'
                                  ? "Disable"
                                  : "Enable",
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
        1: FixedColumnWidth(160), // Username
        2: FixedColumnWidth(160), // Role
        3: FixedColumnWidth(120), // Status
        4: FixedColumnWidth(160), // Password
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
            _tableHeaderCell("Status"),
            _tableHeaderCell("Password"),
          ],
        ),
        for (int index = 0; index < _filteredUsers.length; index++)
          TableRow(
            decoration: BoxDecoration(
              color: _selectedIndex == index ? Colors.blue.shade50 : Colors.transparent,
            ),
            children: [
              _tableBodyCell('${index + 1}', onTap: () => _handleRowTap(index)),
              _tableBodyCell(_filteredUsers[index].username, onTap: () => _handleRowTap(index)),
              _tableBodyCell(_filteredUsers[index].role, onTap: () => _handleRowTap(index)),
              _tableBodyCell(_filteredUsers[index].status, onTap: () => _handleRowTap(index)),
              _passwordCell(index),
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
            _tableHeaderCell("Status"),
            _tableHeaderCell("Password"),
          ],
        ),
        for (int index = 0; index < _filteredUsers.length; index++)
          TableRow(
            decoration: BoxDecoration(
              color: _selectedIndex == index ? Colors.blue.shade50 : Colors.transparent,
            ),
            children: [
              _tableBodyCell('${index + 1}', onTap: () => _handleRowTap(index)),
              _tableBodyCell(_filteredUsers[index].username, onTap: () => _handleRowTap(index)),
              _tableBodyCell(_filteredUsers[index].role, onTap: () => _handleRowTap(index)),
              _tableBodyCell(_filteredUsers[index].status, onTap: () => _handleRowTap(index)),
              _passwordCell(index),
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

  Widget _passwordCell(int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _passwordVisibility[index]! ? _filteredUsers[index].password : '******',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(
              _passwordVisibility[index]! ? Icons.visibility : Icons.visibility_off,
            ),
            onPressed: () {
              setState(() {
                _passwordVisibility[index] = !_passwordVisibility[index]!;
              });
            },
          ),
        ],
      ),
    );
  }
}