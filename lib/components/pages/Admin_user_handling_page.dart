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
  final CollectionReference usersCollection = FirebaseFirestore.instance
      .collection('users');
  final CollectionReference adminsCollection = FirebaseFirestore.instance
      .collection('admins');
  final CollectionReference facultiesCollection = FirebaseFirestore.instance
      .collection('faculties');
  final CollectionReference teachersCollection = FirebaseFirestore.instance
      .collection('teachers');
  final CollectionReference studentsCollection = FirebaseFirestore.instance
      .collection('students');

  List<AppUser> _users = [];
  String _searchText = '';
  int? _selectedIndex;

  // Track password visibility by user id
  final Map<String, bool> _showPasswordById = {};
  // Scroll controller used for the list and scrollbar
  final ScrollController _scrollController = ScrollController();

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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchUsers() async {
    try {
      final snapshot = await usersCollection
          .where('role', whereIn: ['teacher', 'admin'])
          .get();
      final users = snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;

        final facultyId = (data['faculty_id'] is DocumentReference)
            ? (data['faculty_id'] as DocumentReference).id
            : (data['faculty_id']?.toString() ?? '');

        final user = AppUser(
          id: doc.id,
          username: data['username'] ?? '',
          role: data['role'] ?? '',
          password: data['password'] ?? '',
          facultyId: facultyId,
          status: (data['status'] ?? 'enabled').toString(),
          createdAt:
              (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
          updatedAt:
              (data['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );

        // initialize password visibility state for this user id (default false)
        _showPasswordById[user.id] = _showPasswordById[user.id] ?? false;

        return user;
      }).toList();

      setState(() {
        _users = users;
      });
      debugPrint("Fetched ${_users.length} users");
    } catch (e) {
      debugPrint("Error fetching users: $e");
    }
  }

  Future<void> _confirmToggleStatus(AppUser user) async {
    final isDisabled = user.status.toLowerCase() == 'disabled';
    final actionLabel = isDisabled ? 'Enable' : 'Disable';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$actionLabel user'),
        content: Text('$actionLabel ${user.username}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDisabled ? Colors.green : Colors.blue,
            ),
            child: Text(actionLabel),
          ),
        ],
      ),
    );

    if (ok == true) {
      try {
        final newStatus = isDisabled ? 'enabled' : 'disabled';
        await usersCollection.doc(user.id).update({
          'status': newStatus,
          'updated_at': FieldValue.serverTimestamp(),
        });

        await _fetchUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'User ${isDisabled ? 'enabled' : 'disabled'} successfully',
              ),
              backgroundColor: Colors.blueGrey.shade800,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error toggling user status: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update user status'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _showEditUserPopup() async {
    if (_selectedIndex == null) return;
    final user = _filteredUsers[_selectedIndex!];
    final result = await showDialog<AppUser>(
      context: context,
      builder: (context) => EditUserPopup(user: user),
    );
    if (result != null) {
      try {
        // Update the users collection
        await usersCollection.doc(user.id).update(result.toFirestore());

        // If the user is an admin, update the admins collection username/password
        if (user.role == 'admin') {
          final snap = await adminsCollection
              .where('username', isEqualTo: user.username)
              .get();
          for (final doc in snap.docs) {
            await doc.reference.update({
              'username': result.username,
              'password': result.password,
              'updated_at': FieldValue.serverTimestamp(),
            });
          }
        }

        // If the user is a teacher, update the teachers collection username/password
        if (user.role == 'teacher') {
          final snap = await teachersCollection
              .where('username', isEqualTo: user.username)
              .get();
          for (final doc in snap.docs) {
            await doc.reference.update({
              'username': result.username,
              'password': result.password,
              'updated_at': FieldValue.serverTimestamp(),
            });
          }
        }

        // If the user is a student, update the students collection username/password
        if (user.role == 'student') {
          final snap = await studentsCollection
              .where('username', isEqualTo: user.username)
              .get();
          for (final doc in snap.docs) {
            await doc.reference.update({
              'username': result.username,
              'password': result.password,
              'updated_at': FieldValue.serverTimestamp(),
            });
          }
        }

        await _fetchUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('User updated'),
              backgroundColor: Colors.blueGrey.shade800,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error updating user and related collections: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update user'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _handleRowTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // New: a vertically scrollable list with a header row and selectable rows.
  // This replaces the fixed Table so the user can easily reach the last user even with many rows.
  Widget _buildScrollableTable({required bool isDesktop}) {
    final rows = _filteredUsers;
    return Column(
      children: [
        // Header (sticky look)
        Container(
          color: Colors.grey[100],
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            children: const [
              Expanded(
                flex: 1,
                child: Text(
                  'No',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Username',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Role',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Status',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Password',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),

        // Flexible area with scrollbar + ListView
        Expanded(
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: isDesktop ? true : false,
            child: ListView.separated(
              controller: _scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              itemCount: rows.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: Colors.grey.shade300),
              itemBuilder: (context, index) {
                final user = rows[index];
                final selected = _selectedIndex == index;
                final visible = _showPasswordById[user.id] ?? false;

                return InkWell(
                  onTap: () => _handleRowTap(index),
                  child: Container(
                    color: selected ? Colors.blue.shade50 : Colors.transparent,
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 8,
                    ),
                    child: Row(
                      children: [
                        Expanded(flex: 1, child: Text('${index + 1}')),
                        Expanded(flex: 3, child: Text(user.username)),
                        Expanded(flex: 2, child: Text(user.role)),
                        Expanded(flex: 2, child: Text(user.status)),
                        Expanded(
                          flex: 3,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  visible ? (user.password ?? '') : '••••••••',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  visible
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  size: 20,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _showPasswordById[user.id] =
                                        !(_showPasswordById[user.id] ?? false);
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
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
                                : () => _confirmToggleStatus(
                                    _filteredUsers[_selectedIndex!],
                                  ),
                            child: Text(
                              _selectedIndex == null
                                  ? 'Disable'
                                  : (_filteredUsers[_selectedIndex!].status
                                                .toLowerCase() ==
                                            'disabled'
                                        ? 'Enable'
                                        : 'Disable'),
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
              child: _buildScrollableTable(isDesktop: isDesktop),
            ),
          ),
        ],
      ),
    );
  }
}
