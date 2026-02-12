//lecturer page

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/lecturer.dart';
import '../cards/searchBar.dart';
import '../popup/add_lecturer_popup.dart';
import '../../theme/super_admin_theme.dart';

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
  List<String> _facultyNames = [];
  String _searchText = '';
  int? _selectedIndex;

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
    _fetchTeachers();
    _fetchFaculties();
  }

  Future<void> _fetchTeachers() async {
    try {
      final snapshot = await teachersCollection.get();

      setState(() {
        _teachers = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;

          return Teacher(
            id: doc.id, // Auto-generated Firestore document ID
            teacherName: data['teacher_name'] ?? '',
            username: data['username'] ?? '',
            password: data['password'] ?? '',
            facultyId: (data['faculty_id'] as DocumentReference?)?.id ?? '',
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
        _facultyNames = snapshot.docs
            .map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return data['faculty_name'] ?? '';
            })
            .cast<String>()
            .toList(); // Explicitly cast to List<String>
      });

      print("Fetched ${_facultyNames.length} faculties");
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
      builder: (context) => AddTeacherPopup(facultyNames: _facultyNames),
    );
    if (result != null) {
      _addTeacher(result);
    }
  }

  Future<void> _showEditTeacherPopup() async {
    if (_selectedIndex == null) return;
    final teacher = _filteredTeachers[_selectedIndex!];
    final result = await showDialog<Teacher>(
      context: context,
      builder: (context) =>
          AddTeacherPopup(teacher: teacher, facultyNames: _facultyNames),
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
      _selectedIndex = index;
    });
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = Theme.of(context).extension<SuperAdminColors>();
    final highlight =
        palette?.highlight ??
        (isDark ? const Color(0xFF2E3545) : Colors.blue.shade50);

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: Table(
        columnWidths: const {
          0: FixedColumnWidth(64), // No
          1: FixedColumnWidth(140), // Username
          2: FixedColumnWidth(140), // Lecturer Name
          3: FixedColumnWidth(120), // Faculty
        },
        border: TableBorder(
          horizontalInside: BorderSide(color: Colors.grey.shade300),
        ),
        children: [
          TableRow(
            children: [
              _tableHeaderCell("No"),
              _tableHeaderCell("Username"),
              _tableHeaderCell("Lecturer Name"),
              _tableHeaderCell("Faculty"),
            ],
          ),
          for (int index = 0; index < _filteredTeachers.length; index++)
            TableRow(
              decoration: BoxDecoration(
                color: _selectedIndex == index ? highlight : Colors.transparent,
              ),
              children: [
                _tableBodyCell(
                  '${index + 1}',
                  onTap: () => _handleRowTap(index),
                ),
                _tableBodyCell(
                  _filteredTeachers[index].username,
                  onTap: () => _handleRowTap(index),
                ),
                _tableBodyCell(
                  _filteredTeachers[index].teacherName,
                  onTap: () => _handleRowTap(index),
                ),
                _tableBodyCell(
                  _filteredTeachers[index].facultyId,
                  onTap: () => _handleRowTap(index),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMobileTable() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = Theme.of(context).extension<SuperAdminColors>();
    final highlight =
        palette?.highlight ??
        (isDark ? const Color(0xFF2E3545) : Colors.blue.shade50);

    return Table(
      defaultColumnWidth: const IntrinsicColumnWidth(),
      border: TableBorder(
        horizontalInside: BorderSide(color: Colors.grey.shade300),
      ),
      children: [
        TableRow(
          children: [
            _tableHeaderCell("No"),
            _tableHeaderCell("Username"),
            _tableHeaderCell("Lecturer Name"),
            _tableHeaderCell("Faculty"),
          ],
        ),
        for (int index = 0; index < _filteredTeachers.length; index++)
          TableRow(
            decoration: BoxDecoration(
              color: _selectedIndex == index ? highlight : Colors.transparent,
            ),
            children: [
              _tableBodyCell('${index + 1}', onTap: () => _handleRowTap(index)),
              _tableBodyCell(
                _filteredTeachers[index].username,
                onTap: () => _handleRowTap(index),
              ),
              _tableBodyCell(
                _filteredTeachers[index].teacherName,
                onTap: () => _handleRowTap(index),
              ),
              _tableBodyCell(
                _filteredTeachers[index].facultyId,
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
