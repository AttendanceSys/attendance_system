import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user.dart';
import '../../services/session.dart';
import '../popup/edit_user_popup.dart';
import '../cards/searchBar.dart';
import '../../theme/super_admin_theme.dart';

class FacultyUserHandlingPage extends StatefulWidget {
  const FacultyUserHandlingPage({super.key});

  @override
  State<FacultyUserHandlingPage> createState() =>
      _FacultyUserHandlingPageState();
}

class _FacultyUserHandlingPageState extends State<FacultyUserHandlingPage> {
  final CollectionReference usersCollection = FirebaseFirestore.instance
      .collection('users');
  final CollectionReference studentsCollection = FirebaseFirestore.instance
      .collection('students');

  List<AppUser> _students = [];
  String _searchText = '';
  int? _selectedIndex;

  // track per-user password visibility by user id
  final Map<String, bool> _showPasswordById = {};

  // Scroll controller for the list
  final ScrollController _scrollController = ScrollController();

  List<AppUser> get _filteredStudents => _students
      .where(
        (student) =>
            student.username.toLowerCase().contains(
              _searchText.toLowerCase(),
            ) ||
            student.status.toLowerCase().contains(_searchText.toLowerCase()),
      )
      .toList();

  @override
  void initState() {
    super.initState();
    _fetchStudents();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  bool _recordMatchesFaculty(Map<String, dynamic> data) {
    if (Session.facultyRef == null) return true;
    final sessionId = Session.facultyRef!.id;
    final sessionPath = '/${Session.facultyRef!.path}';

    final cand =
        data['faculty_ref'] ??
        data['faculty_id'] ??
        data['faculty'] ??
        data['facultyId'];
    if (cand == null) return false;
    if (cand is DocumentReference) return cand.id == sessionId;
    if (cand is String) {
      if (cand == sessionId) return true;
      if (cand == sessionPath) return true;
      final normalized = cand.startsWith('/') ? cand : '/$cand';
      if (normalized == sessionPath) return true;
      final parts = cand.split('/').where((p) => p.isNotEmpty).toList();
      if (parts.isNotEmpty && parts.last == sessionId) return true;
    }
    return false;
  }

  Future<void> _fetchStudents() async {
    try {
      // Always fetch students by role, then apply robust client-side faculty scoping.
      final Query q = usersCollection.where('role', isEqualTo: 'student');
      final snap = await q.get();
      final docs = snap.docs;

      final List<AppUser> users = [];
      for (final doc in docs) {
        final data = doc.data() as Map<String, dynamic>;
        // normalize faculty id into string for display/matching
        final facultyId = (data['faculty_id'] is DocumentReference)
            ? (data['faculty_id'] as DocumentReference).id
            : (data['faculty_id']?.toString() ?? '');

        final user = AppUser(
          id: doc.id,
          username: data['username'] ?? '',
          role: data['role'] ?? 'student',
          password: data['password'] ?? '',
          facultyId: facultyId,
          status: (data['status'] ?? 'enabled').toString(),
          createdAt:
              (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
          updatedAt:
              (data['updated_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );

        // apply faculty scoping client-side if Session.facultyRef present
        if (Session.facultyRef == null) {
          users.add(user);
        } else {
          if (_recordMatchesFaculty(data)) users.add(user);
        }

        // initialize password visibility state (default hidden)
        _showPasswordById[user.id] = _showPasswordById[user.id] ?? false;
      }

      setState(() {
        _students = users;
      });
    } catch (e) {
      debugPrint('Error fetching students for faculty user handling: $e');
    }
  }

  Future<void> _showEditStudentPopup() async {
    if (_selectedIndex == null) return;
    final student = _filteredStudents[_selectedIndex!];
    final result = await showDialog<AppUser>(
      context: context,
      builder: (context) => EditUserPopup(user: student),
    );
    if (result != null) {
      // Update user document
      await usersCollection.doc(student.id).update(result.toFirestore());

      // Propagate username/password changes to matching student document(s)
      final snap = await studentsCollection
          .where('username', isEqualTo: student.username)
          .get();
      for (final doc in snap.docs) {
        await doc.reference.update({
          'username': result.username,
          'password': result.password,
          'updated_at': FieldValue.serverTimestamp(),
        });
      }
      await _fetchStudents();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('User updated'),
            backgroundColor: Colors.blueGrey.shade800,
          ),
        );
      }
    }
  }

  // Generic toggle (enable/disable) with confirmation
  Future<void> _confirmToggleStatus(AppUser s) async {
    final isDisabled = s.status.toLowerCase() == 'disabled';
    final actionLabel = isDisabled ? 'Enable' : 'Disable';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$actionLabel student'),
        content: Text('$actionLabel ${s.username}?'),
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
        await usersCollection.doc(s.id).update({'status': newStatus});
        await _fetchStudents();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Student ${isDisabled ? 'enabled' : 'disabled'} successfully',
              ),
              backgroundColor: Colors.blueGrey.shade800,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error toggling student status: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to update student status'),
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

  Widget _buildScrollableTable({required bool isDesktop}) {
    final rows = _filteredStudents;
    final palette = Theme.of(context).extension<SuperAdminColors>();
    return Column(
      children: [
        // Header
        Container(
          color: palette?.surfaceHigh,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            children: [
              Expanded(
                flex: 1,
                child: Text(
                  'No',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: palette?.textPrimary,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Username',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: palette?.textPrimary,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Role',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: palette?.textPrimary,
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  'Status',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: palette?.textPrimary,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'Password',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: palette?.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),

        // List with Scrollbar
        Expanded(
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: isDesktop,
            child: ListView.separated(
              controller: _scrollController,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              itemCount: rows.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                color: palette?.border ?? Colors.grey.shade300,
              ),
              itemBuilder: (context, index) {
                final user = rows[index];
                final selected = _selectedIndex == index;
                final visible = _showPasswordById[user.id] ?? false;
                final isDark = Theme.of(context).brightness == Brightness.dark;
                final palette = Theme.of(context).extension<SuperAdminColors>();
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
                        Expanded(
                          flex: 1,
                          child: Text(
                            '${index + 1}',
                            style: TextStyle(color: palette?.textPrimary),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Text(
                            user.username,
                            style: TextStyle(color: palette?.textPrimary),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            user.role,
                            style: TextStyle(color: palette?.textPrimary),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            user.status,
                            style: TextStyle(color: palette?.textPrimary),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  visible ? user.password : '••••••••',
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: palette?.textPrimary),
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  visible
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  size: 20,
                                  color: palette?.iconColor,
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

  Widget _buildDesktopTable() {
    // Use the scrollable list on both desktop and mobile for consistency and accessibility.
    return _buildScrollableTable(isDesktop: true);
  }

  Widget _buildMobileTable() {
    return _buildScrollableTable(isDesktop: false);
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
          Text(
            "Faculty User Handling",
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
                                : _showEditStudentPopup,
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
                                    _filteredStudents[_selectedIndex!],
                                  ),
                            child: Text(
                              _selectedIndex == null
                                  ? 'Disable'
                                  : (_filteredStudents[_selectedIndex!].status
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
              child: isDesktop ? _buildDesktopTable() : _buildMobileTable(),
            ),
          ),
        ],
      ),
    );
  }
}
