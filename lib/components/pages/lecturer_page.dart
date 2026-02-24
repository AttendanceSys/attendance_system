//lecturer page

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/lecturer.dart';
import '../cards/searchBar.dart';
import '../popup/add_lecturer_popup.dart';
import '../admin_page_skeleton.dart';
import '../../theme/super_admin_theme.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import '../../utils/download_bytes.dart';

class TeachersPage extends StatefulWidget {
  const TeachersPage({super.key});

  @override
  State<TeachersPage> createState() => _TeachersPageState();
}

class _TeachersPageState extends State<TeachersPage> {
  final CollectionReference teachersCollection = FirebaseFirestore.instance
      .collection('teachers');
  final CollectionReference facultiesCollection = FirebaseFirestore.instance
      .collection('faculties');
  final CollectionReference usersCollection = FirebaseFirestore.instance
      .collection('users');

  List<Teacher> _teachers = [];
  final Map<String, String> _facultyIdToName = {};
  final Map<String, String> _facultyNameToId = {};
  String _searchText = '';
  int? _selectedIndex;
  final math.Random _random = math.Random();
  bool _loading = true;

  String _generateDefaultPassword() {
    const specials = ['#', '&', '@', '!'];
    final left = 10 + _random.nextInt(90); // 2 digits
    final middle = 100 + _random.nextInt(900); // 3 digits
    final s1 = specials[_random.nextInt(specials.length)];
    final s2 = specials[_random.nextInt(specials.length)];
    return '$left$s1$middle$s2';
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blueGrey.shade800,
      ),
    );
  }

  List<Teacher> get _filteredTeachers {
    final query = _searchText.trim().toLowerCase();
    if (query.isEmpty) return _teachers;
    return _teachers
        .where(
          (teacher) =>
              teacher.username.toLowerCase().startsWith(query) ||
              teacher.teacherName.toLowerCase().startsWith(query),
        )
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await Future.wait([_fetchTeachers(), _fetchFaculties()]);
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchTeachers() async {
    try {
      final snapshot = await teachersCollection.get();

      setState(() {
        _teachers = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          String facultyId = '';
          final facCandidate = data['faculty_id'] ?? data['faculty_ref'] ?? data['faculty'];
          if (facCandidate is DocumentReference) {
            facultyId = facCandidate.id;
          } else if (facCandidate is String) {
            final s = facCandidate.trim();
            if (s.contains('/')) {
              final parts = s.split('/').where((p) => p.isNotEmpty).toList();
              facultyId = parts.isNotEmpty ? parts.last : s;
            } else {
              facultyId = s;
            }
          } else if (facCandidate != null) {
            facultyId = facCandidate.toString();
          }

          return Teacher(
            id: doc.id, // Auto-generated Firestore document ID
            teacherName: data['teacher_name'] ?? '',
            username: data['username'] ?? '',
            password: data['password'] ?? '',
            facultyId: facultyId,
            createdAt:
                (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
          );
        }).toList();
      });

      print("Fetched ${_teachers.length} teachers");
    } catch (e) {
      print("Error fetching teachers: $e");
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
              final name = (data['faculty_name'] ?? data['name'] ?? '')
                  .toString()
                  .trim();
              return MapEntry(doc.id, name);
            }),
          );
        _facultyNameToId
          ..clear()
          ..addEntries(_facultyIdToName.entries.map(
            (e) => MapEntry(e.value.toLowerCase().trim(), e.key),
          ));
      });

      print("Fetched ${_facultyIdToName.length} faculties");
    } catch (e) {
      print("Error fetching faculties: $e");
    }
  }

  Future<void> _addTeacher(Teacher teacher) async {
    final teacherData = {
      'teacher_name': teacher.teacherName,
      'username': teacher.username,
      'password': teacher.password,
      'faculty_id': FirebaseFirestore.instance.doc(
        '/faculties/${teacher.facultyId}',
      ),
      'created_at': FieldValue.serverTimestamp(),
    };

    final userData = {
      'username': teacher.username,
      'password': teacher.password,
      'role': 'teacher',
      'faculty_id': FirebaseFirestore.instance.doc(
        '/faculties/${teacher.facultyId}',
      ),
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
    };

    // Add to teachers collection
    await teachersCollection.add(teacherData);

    // Add to users collection
    await usersCollection.add(userData);

    _fetchTeachers();
    _showSnack('Lecturer added successfully');
  }

  Future<void> _updateTeacher(Teacher teacher) async {
    final teacherData = {
      'teacher_name': teacher.teacherName,
      'username': teacher.username,
      'password': teacher.password,
      'faculty_id': FirebaseFirestore.instance.doc(
        '/faculties/${teacher.facultyId}',
      ),
      'updated_at': FieldValue.serverTimestamp(),
    };

    final userData = {
      'username': teacher.username,
      'password': teacher.password,
      'role': 'teacher',
      'faculty_id': FirebaseFirestore.instance.doc(
        '/faculties/${teacher.facultyId}',
      ),
      'updated_at': FieldValue.serverTimestamp(),
    };

    // Fetch the old teacher data to check for username changes
    final oldTeacherSnapshot = await teachersCollection.doc(teacher.id).get();
    final oldTeacherData = oldTeacherSnapshot.data() as Map<String, dynamic>;
    final oldUsername = oldTeacherData['username'];

    // Update in teachers collection
    await teachersCollection.doc(teacher.id).update(teacherData);

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

    _fetchTeachers();
    _showSnack('Lecturer updated successfully');
  }

  Future<void> _deleteTeacher(Teacher teacher) async {
    // Delete from teachers collection
    await teachersCollection.doc(teacher.id).delete();

    // Delete from users collection
    await usersCollection
        .where('username', isEqualTo: teacher.username)
        .where('role', isEqualTo: 'teacher')
        .get()
        .then((snapshot) {
          for (var doc in snapshot.docs) {
            doc.reference.delete();
          }
        });

    _fetchTeachers();
    _showSnack('Lecturer deleted successfully');
  }

  Future<void> _showAddTeacherPopup() async {
    final result = await showDialog<Teacher>(
      context: context,
      builder: (context) => AddTeacherPopup(facultyOptions: _facultyIdToName),
    );
    if (result != null) {
      _addTeacher(result);
    }
  }

  String? _resolveFacultyId(String rawValue) {
    final raw = rawValue.trim();
    if (raw.isEmpty) return null;
    if (_facultyNameToId.containsKey(raw.toLowerCase())) {
      return _facultyNameToId[raw.toLowerCase()];
    }
    if (raw.contains('/')) {
      final parts = raw.split('/').where((p) => p.isNotEmpty).toList();
      if (parts.isNotEmpty) return parts.last;
    }
    return raw;
  }

  Future<void> _handleUploadLecturers() async {
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
          content: Text('Import ${parsed.length} lecturers?'),
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
        final teacherName =
            (row['teacher_name'] ?? row['lecturer_name'] ?? row['name'] ?? '')
                .toString()
                .trim();
        final username = (row['username'] ?? '').toString().trim();
        final rawPassword = (row['password'] ?? '').toString().trim();
        final password = rawPassword.isEmpty
            ? _generateDefaultPassword()
            : rawPassword;
        final facultyRaw =
            (row['faculty_id'] ?? row['faculty'] ?? row['faculty_name'] ?? '')
                .toString()
                .trim();

        final facultyId = _resolveFacultyId(facultyRaw) ?? '';
        if (teacherName.isEmpty || username.isEmpty || facultyId.isEmpty) {
          skipped++;
          continue;
        }

        final teacher = Teacher(
          id: '',
          teacherName: teacherName,
          username: username,
          password: password,
          facultyId: facultyId,
          createdAt: DateTime.now(),
        );

        final ok = await _addTeacherFromUpload(teacher);
        if (ok) {
          added++;
        } else {
          skipped++;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported $added, skipped $skipped')),
        );
      }
      await _fetchTeachers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to import lecturers')),
        );
      }
      print('Error importing lecturers: $e');
    }
  }

  Future<void> _handleExportLecturersCsv() async {
    try {
      final rows = <List<dynamic>>[
        ['No', 'Username', 'Lecturer Name', 'Faculty'],
      ];
      for (int i = 0; i < _teachers.length; i++) {
        final t = _teachers[i];
        rows.add([
          i + 1,
          t.username,
          t.teacherName,
          _facultyIdToName[t.facultyId] ?? t.facultyId,
        ]);
      }

      final csv = const ListToCsvConverter().convert(rows);
      final bytes = Uint8List.fromList(utf8.encode(csv));
      final now = DateTime.now();
      final fileName =
          'lecturers_${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.csv';

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
      _showSnack('Failed to export lecturers CSV');
    }
  }

  Future<bool> _addTeacherFromUpload(Teacher teacher) async {
    try {
      final effectivePassword = teacher.password.trim().isEmpty
          ? _generateDefaultPassword()
          : teacher.password;
      final teacherDup = await teachersCollection
          .where('username', isEqualTo: teacher.username)
          .limit(1)
          .get();
      if (teacherDup.docs.isNotEmpty) return false;

      final userDup = await usersCollection
          .where('username', isEqualTo: teacher.username)
          .limit(1)
          .get();
      if (userDup.docs.isNotEmpty) return false;

      final teacherData = {
        'teacher_name': teacher.teacherName,
        'username': teacher.username,
        'password': effectivePassword,
        'faculty_id': FirebaseFirestore.instance.doc(
          '/faculties/${teacher.facultyId}',
        ),
        'created_at': FieldValue.serverTimestamp(),
      };

      final userData = {
        'username': teacher.username,
        'password': effectivePassword,
        'role': 'teacher',
        'faculty_id': FirebaseFirestore.instance.doc(
          '/faculties/${teacher.facultyId}',
        ),
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      };

      await teachersCollection.add(teacherData);
      await usersCollection.add(userData);
      return true;
    } catch (e) {
      print('Error adding lecturer from upload: $e');
      return false;
    }
  }

  Future<void> _showEditTeacherPopup() async {
    if (_selectedIndex == null) return;
    Teacher teacher = _filteredTeachers[_selectedIndex!];
    // Support legacy data where faculty stored as name.
    if (!_facultyIdToName.containsKey(teacher.facultyId) &&
        _facultyNameToId.containsKey(teacher.facultyId.toLowerCase().trim())) {
      teacher = teacher.copyWith(
        facultyId: _facultyNameToId[teacher.facultyId.toLowerCase().trim()],
      );
    }
    final result = await showDialog<Teacher>(
      context: context,
      builder: (context) =>
          AddTeacherPopup(teacher: teacher, facultyOptions: _facultyIdToName),
    );
    if (result != null) {
      _updateTeacher(result);
    }
  }

  Future<void> _confirmDeleteTeacher() async {
    if (_selectedIndex == null) return;
    final teacher = _filteredTeachers[_selectedIndex!];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Lecturer"),
        content: Text(
          "Are you sure you want to delete '${teacher.teacherName}'?",
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
      _deleteTeacher(teacher);
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
            "Lecturers",
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
                              hintText: "Search Lecturer...",
                              buttonText: "Add Lecturer",
                              onAddPressed: _showAddTeacherPopup,
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
                              onPressed: _handleUploadLecturers,
                              icon: const Icon(Icons.upload_file),
                              label: const Text('Upload Lecturers'),
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
                              onPressed: _handleExportLecturersCsv,
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
                        hintText: "Search Lecturer...",
                        buttonText: "Add Lecturer",
                        onAddPressed: _showAddTeacherPopup,
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
                          onPressed: _handleUploadLecturers,
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Upload Lecturers'),
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
                          onPressed: _handleExportLecturersCsv,
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
                                : _showEditTeacherPopup,
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
                                : _confirmDeleteTeacher,
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
                ? const LecturersPageSkeleton()
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
        2: FixedColumnWidth(230),
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
                    _tableHeaderCell("Lecturer Name", textPrimary),
                    _tableHeaderCell("Faculty", textPrimary),
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
                    for (int index = 0; index < _filteredTeachers.length; index++)
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
                            _filteredTeachers[index].username,
                            textPrimary,
                            onTap: () => _handleRowTap(index),
                          ),
                          _tableBodyCell(
                            _filteredTeachers[index].teacherName,
                            textPrimary,
                            onTap: () => _handleRowTap(index),
                          ),
                          _tableBodyCell(
                            _facultyIdToName[_filteredTeachers[index].facultyId] ??
                                _filteredTeachers[index].facultyId,
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
