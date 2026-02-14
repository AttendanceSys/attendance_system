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
  final ScrollController _tableBodyScrollController = ScrollController();

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
    _tableBodyScrollController.dispose();
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
      _selectedIndex = _selectedIndex == index ? null : index;
    });
  }

  void _clearSelection() {
    if (_selectedIndex == null) return;
    setState(() => _selectedIndex = null);
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

  Widget _buildDesktopTable() {
    return _buildSaasTable(
      columnWidths: const {
        0: FixedColumnWidth(72),
        1: FlexColumnWidth(1.15),
        2: FlexColumnWidth(1.0),
        3: FlexColumnWidth(1.0),
        4: FlexColumnWidth(1.35),
      },
    );
  }

  Widget _buildMobileTable() {
    return _buildSaasTable(
      columnWidths: const {
        0: FixedColumnWidth(72),
        1: FixedColumnWidth(220),
        2: FixedColumnWidth(150),
        3: FixedColumnWidth(150),
        4: FixedColumnWidth(260),
      },
    );
  }

  Widget _buildSaasTable({required Map<int, TableColumnWidth> columnWidths}) {
    final rows = _filteredUsers;
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
                    _tableHeaderCell('No', textPrimary),
                    _tableHeaderCell('Username', textPrimary),
                    _tableHeaderCell('Role', textPrimary),
                    _tableHeaderCell('Status', textPrimary),
                    _tableHeaderCell('Password', textPrimary),
                  ],
                ),
              ],
            ),
            Container(height: 1, color: divider),
            Expanded(
              child: Scrollbar(
                controller: _tableBodyScrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _tableBodyScrollController,
                  primary: false,
                  child: Table(
                    columnWidths: columnWidths,
                    border: TableBorder(
                      horizontalInside: BorderSide(color: divider),
                    ),
                    children: [
                      for (int i = 0; i < rows.length; i++)
                        TableRow(
                          decoration: BoxDecoration(
                            color: _selectedIndex == i ? selectedBg : surface,
                          ),
                          children: [
                            _tableBodyCell(
                              '${i + 1}',
                              textPrimary,
                              onTap: () => _handleRowTap(i),
                            ),
                            _tableBodyCell(
                              rows[i].username,
                              textPrimary,
                              onTap: () => _handleRowTap(i),
                            ),
                            _tableBodyCell(
                              rows[i].role,
                              textPrimary,
                              onTap: () => _handleRowTap(i),
                            ),
                            _tableBodyCell(
                              rows[i].status,
                              textPrimary,
                              onTap: () => _handleRowTap(i),
                            ),
                            _passwordCell(
                              rows[i],
                              textPrimary,
                              onTap: () => _handleRowTap(i),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tableHeaderCell(String text, Color textColor) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 24),
    child: Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.w700,
        fontSize: 14,
        color: textColor,
        letterSpacing: 0.1,
      ),
      overflow: TextOverflow.ellipsis,
    ),
  );

  Widget _tableBodyCell(String text, Color textColor, {VoidCallback? onTap}) =>
      InkWell(
        onTap: onTap,
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: TextStyle(
              fontSize: 14.5,
              color: textColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );

  Widget _passwordCell(AppUser user, Color textColor, {VoidCallback? onTap}) {
    final visible = _showPasswordById[user.id] ?? false;
    return InkWell(
      onTap: onTap,
      hoverColor: Colors.transparent,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                visible ? user.password : '••••••••',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14.5,
                  color: textColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            IconButton(
              icon: Icon(
                visible ? Icons.visibility : Icons.visibility_off,
                size: 20,
                color: textColor.withValues(alpha: 0.8),
              ),
              onPressed: () {
                setState(() {
                  _showPasswordById[user.id] = !(_showPasswordById[user.id] ?? false);
                });
              },
            ),
          ],
        ),
      ),
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

          Expanded(
            child: Container(
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

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
