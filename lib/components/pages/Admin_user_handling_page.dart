import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user.dart';
import '../popup/edit_user_popup.dart';
import '../cards/searchBar.dart';
import '../../theme/super_admin_theme.dart';

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

  // Scroll controller for the users list only
  final ScrollController _listScrollController = ScrollController();

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
    _listScrollController.dispose();
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

        _showPasswordById[user.id] = _showPasswordById[user.id] ?? false;

        return user;
      }).toList();

      setState(() => _users = users);
      debugPrint("Fetched ${_users.length} users");
    } catch (e) {
      debugPrint("Error fetching users: $e");
    }
  }

  void _handleRowTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _confirmToggleStatus(AppUser user) async {
    final isDisabled = user.status.toLowerCase() == 'disabled';
    final actionLabel = isDisabled ? 'Enable' : 'Disable';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          title: Text('$actionLabel user'),
          content: Text('$actionLabel ${user.username}?'),
          actions: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: isDark ? Colors.white : null,
              ),
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDisabled ? Colors.green : Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: Text(actionLabel),
            ),
          ],
        );
      },
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
        // Update users
        await usersCollection.doc(user.id).update(result.toFirestore());

        // Update related collection by role
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

  Widget _buildScrollableTable({required bool isDesktop}) {
    final rows = _filteredUsers;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = Theme.of(context).extension<SuperAdminColors>();

    final headerBg = isDark ? const Color(0xFF323746) : Colors.grey[100];
    final headerTextColor = isDark ? const Color(0xFFE6EAF1) : Colors.black87;

    return Column(
      children: [
        // Header
        Container(
          color: headerBg,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: Text(
                  'No',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: headerTextColor,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Username',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: headerTextColor,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Role',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: headerTextColor,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Status',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: headerTextColor,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Password',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: headerTextColor,
                  ),
                ),
              ),
            ],
          ),
        ),

        // ✅ List takes remaining height, no hidden bottom part
        Expanded(
          child: Scrollbar(
            controller: _listScrollController,
            thumbVisibility: isDesktop,
            child: ListView.separated(
              controller: _listScrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: rows.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: Colors.grey.shade300),
              itemBuilder: (context, index) {
                final user = rows[index];
                final selected = _selectedIndex == index;
                final visible = _showPasswordById[user.id] ?? false;

                final highlight =
                    palette?.highlight ??
                    (isDark ? const Color(0xFF2E3545) : Colors.blue.shade50);

                return InkWell(
                  onTap: () => _handleRowTap(index),
                  child: Container(
                    color: selected ? highlight : Colors.transparent,
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
                                  visible ? user.password : '••••••••',
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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final disabledActionBg = isDark
        ? const Color(0xFF4234A4)
        : const Color(0xFF8372FE);

    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 32, 32, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            "User Handling",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Theme.of(
                context,
              ).extension<SuperAdminColors>()?.textPrimary,
            ),
          ),
          const SizedBox(height: 24),

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
                    disabledBackgroundColor: disabledActionBg,
                    disabledForegroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: _selectedIndex == null ? null : _showEditUserPopup,
                  child: const Text(
                    "Edit",
                    style: TextStyle(fontSize: 15, color: Colors.white),
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
                    disabledBackgroundColor: disabledActionBg,
                    disabledForegroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
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
                    style: const TextStyle(fontSize: 15, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ✅ This makes the table use remaining space, no clipping
          Expanded(child: _buildScrollableTable(isDesktop: isDesktop)),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
