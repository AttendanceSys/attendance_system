import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user.dart';
import '../../services/session.dart';
import '../popup/edit_user_popup.dart';
import '../cards/searchBar.dart';
import '../admin_page_skeleton.dart';
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
  bool _loading = true;

  // track per-user password visibility by user id
  final Map<String, bool> _showPasswordById = {};
  final ScrollController _tableBodyScrollController = ScrollController();

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
    _init();
  }

  Future<void> _init() async {
    await _fetchStudents();
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _tableBodyScrollController.dispose();
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
      _selectedIndex = _selectedIndex == index ? null : index;
    });
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
    final rows = _filteredStudents;
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
            child: _loading
                ? const UserHandlingPageSkeleton()
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
}
