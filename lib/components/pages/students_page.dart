import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/student.dart';
import '../popup/add_student_popup.dart';
import '../cards/searchBar.dart';
import '../../services/session.dart';
import '../../theme/teacher_theme.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'dart:convert';

class StudentsPage extends StatefulWidget {
  const StudentsPage({super.key});

  @override
  State<StudentsPage> createState() => _StudentsPageState();
}

class _StudentsPageState extends State<StudentsPage> {
  final CollectionReference studentsCollection = FirebaseFirestore.instance
      .collection('students');
  final CollectionReference usersCollection = FirebaseFirestore.instance
      .collection('users');
  final CollectionReference departmentsCollection = FirebaseFirestore.instance
      .collection('departments');
  final CollectionReference classesCollection = FirebaseFirestore.instance
      .collection('classes');
  final CollectionReference facultiesCollection = FirebaseFirestore.instance
      .collection('faculties');

  List<Student> _students = [];
  Map<String, String> _departmentNames = {};
  Map<String, String> _classNames = {};
  bool _loading = true;

  String _searchText = '';
  int? _selectedIndex;

  List<Student> get _filteredStudents => _students.where((s) {
    final dept = _departmentNames[s.departmentRef ?? ''] ?? '';
    final cls = _classNames[s.classRef ?? ''] ?? '';
    return s.fullname.toLowerCase().contains(_searchText.toLowerCase()) ||
        s.username.toLowerCase().contains(_searchText.toLowerCase()) ||
        dept.toLowerCase().contains(_searchText.toLowerCase()) ||
        cls.toLowerCase().contains(_searchText.toLowerCase());
  }).toList();

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    await Future.wait([_fetchLookups(), _fetchStudents()]);
    if (mounted) setState(() => _loading = false);
  }

  String _extractId(dynamic cand) {
    if (cand == null) return '';
    if (cand is DocumentReference) return cand.id;
    if (cand is String) {
      final s = cand;
      if (s.contains('/')) {
        final parts = s.split('/').where((p) => p.isNotEmpty).toList();
        return parts.isNotEmpty ? parts.last : s;
      }
      return s;
    }
    return cand.toString();
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
    if (cand is DocumentReference) {
      return cand.id == sessionId;
    }
    if (cand is String) {
      if (cand == sessionId) return true;
      if (cand == sessionPath) return true;
      // handle strings like "faculties/science" (without leading slash)
      final normalized = cand.startsWith('/') ? cand : '/$cand';
      if (normalized == sessionPath) return true;
      // fallback: last segment
      final parts = cand.split('/').where((p) => p.isNotEmpty).toList();
      if (parts.isNotEmpty && parts.last == sessionId) return true;
    }
    return false;
  }

  Future<void> _fetchLookups() async {
    try {
      Query dq = departmentsCollection;
      Query cq = classesCollection;
      if (Session.facultyRef != null) {
        // prefer server side filtering when possible
        dq = dq.where('faculty_ref', isEqualTo: Session.facultyRef);
        cq = cq.where('faculty_ref', isEqualTo: Session.facultyRef);
      }
      final deps = await dq.get();
      final classes = await cq.get();
      setState(() {
        _departmentNames = Map.fromEntries(
          deps.docs.map((d) {
            final data = d.data() as Map<String, dynamic>;
            final name = data['department_name'] ?? data['name'] ?? '';
            return MapEntry(d.id, name as String);
          }),
        );
        _classNames = Map.fromEntries(
          classes.docs.map((d) {
            final data = d.data() as Map<String, dynamic>;
            final name = data['class_name'] ?? data['name'] ?? '';
            return MapEntry(d.id, name as String);
          }),
        );
      });
    } catch (e) {
      print('Error fetching lookups: $e');
    }
  }

  Future<void> _fetchStudents() async {
    try {
      // Fetch all then client-filter to handle mixed DB shapes consistently.
      final snap = await studentsCollection.get();
      final students = <Student>[];
      for (final d in snap.docs) {
        final data = d.data() as Map<String, dynamic>;
        if (!_recordMatchesFaculty(data)) continue;
        students.add(
          Student(
            id: d.id,
            fullname: (data['fullname'] ?? data['full_name'] ?? '') as String,
            username: (data['username'] ?? '') as String,
            password: (data['password'] ?? '') as String,
            gender: (data['gender'] ?? 'Male') as String,
            departmentRef: _extractId(
              data['department_ref'] ??
                  data['department'] ??
                  data['departmentId'],
            ),
            classRef: _extractId(
              data['class_ref'] ?? data['class'] ?? data['classId'],
            ),
            facultyRef: _extractId(
              data['faculty_ref'] ??
                  data['faculty_id'] ??
                  data['faculty'] ??
                  data['facultyId'],
            ),
            createdAt: (data['created_at'] as Timestamp?)?.toDate(),
          ),
        );
      }
      setState(() => _students = students);
    } catch (e) {
      print('Error fetching students: $e');
    }
  }

  Future<void> _showAddStudentPopup() async {
    final result = await showDialog<Student>(
      context: context,
      builder: (ctx) => const AddStudentPopup(),
    );
    if (result != null) await _addStudent(result);
  }

  Future<void> _showEditStudentPopup(Student s) async {
    final result = await showDialog<Student>(
      context: context,
      builder: (ctx) => AddStudentPopup(student: s),
    );
    if (result != null) await _updateStudent(s, result);
  }

  Future<void> _addStudent(Student s) async {
    try {
      // username uniqueness
      final q = await studentsCollection
          .where('username', isEqualTo: s.username)
          .get();
      if (q.docs.isNotEmpty) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Duplicate username'),
            content: const Text('Username already exists'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      // infer faculty from department if missing
      String facultyToWrite = s.facultyRef ?? '';
      if (facultyToWrite.isEmpty && (s.departmentRef ?? '').isNotEmpty) {
        try {
          final dep = await departmentsCollection.doc(s.departmentRef).get();
          if (dep.exists) {
            final depData = dep.data() as Map<String, dynamic>?;
            final cand = depData == null
                ? null
                : (depData['faculty_ref'] ??
                      depData['facultyId'] ??
                      depData['faculty_id'] ??
                      depData['faculty']);
            if (cand != null) {
              facultyToWrite = _extractId(cand);
            }
          }
        } catch (e) {
          print('Error inferring faculty: $e');
        }
      }

      final facultyForStudentField =
          Session.facultyRef ??
          (facultyToWrite.isNotEmpty
              ? facultiesCollection.doc(facultyToWrite)
              : null);

      final Map<String, dynamic> studentDoc = {
        'fullname': s.fullname,
        'username': s.username,
        'password': s.password,
        'gender': s.gender,
        'department_ref': s.departmentRef ?? '',
        'class_ref': s.classRef ?? '',
        'className': _classNames[s.classRef ?? ''] ?? '',
        'faculty_ref': facultyForStudentField ?? '',
        'created_at': FieldValue.serverTimestamp(),
      };

      await studentsCollection.add(studentDoc);

      // prepare faculty id/path for users collection
      final String? userFacultyValue = Session.facultyRef != null
          ? '/${Session.facultyRef!.path}'
          : (facultyToWrite.isNotEmpty ? facultyToWrite : null);

      // Add to users collection
      await usersCollection.add({
        'username': s.username,
        'role': 'student',
        'password': s.password,
        'faculty_id': userFacultyValue ?? '',
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      await _fetchStudents();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Student added'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error adding student: $e');
    }
  }

  Future<void> _updateStudent(Student oldS, Student newS) async {
    if (oldS.id == null) return;
    try {
      if (oldS.username != newS.username) {
        final q = await studentsCollection
            .where('username', isEqualTo: newS.username)
            .get();
        final conflict = q.docs.any((d) => d.id != oldS.id);
        if (conflict) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Duplicate username'),
              content: const Text('Username already exists'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
          return;
        }
      }

      // infer faculty if missing like in add
      String facultyToWrite = newS.facultyRef ?? '';
      if (facultyToWrite.isEmpty && (newS.departmentRef ?? '').isNotEmpty) {
        try {
          final dep = await departmentsCollection.doc(newS.departmentRef).get();
          if (dep.exists) {
            final depData = dep.data() as Map<String, dynamic>?;
            final cand = depData == null
                ? null
                : (depData['faculty_ref'] ??
                      depData['facultyId'] ??
                      depData['faculty_id'] ??
                      depData['faculty']);
            if (cand != null) {
              facultyToWrite = _extractId(cand);
            }
          }
        } catch (e) {
          print('Error inferring faculty: $e');
        }
      }

      final facultyForStudentField =
          Session.facultyRef ??
          (facultyToWrite.isNotEmpty
              ? facultiesCollection.doc(facultyToWrite)
              : null);

      await studentsCollection.doc(oldS.id).update({
        'fullname': newS.fullname,
        'username': newS.username,
        'password': newS.password,
        'gender': newS.gender,
        'department_ref': newS.departmentRef ?? '',
        'class_ref': newS.classRef ?? '',
        'className': _classNames[newS.classRef ?? ''] ?? '',
        'faculty_ref': facultyForStudentField ?? '',
        'created_at': FieldValue.serverTimestamp(),
      });

      // Update users collection
      final userQuery = await usersCollection
          .where('username', isEqualTo: oldS.username)
          .get();
      if (userQuery.docs.isNotEmpty) {
        final userDocId = userQuery.docs.first.id;
        await usersCollection.doc(userDocId).update({
          'username': newS.username,
          'password': newS.password,
          'updated_at': FieldValue.serverTimestamp(),
        });
      }

      await _fetchStudents();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Student updated'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error updating student: $e');
    }
  }

  Future<void> _deleteStudent(Student s) async {
    if (s.id == null) return;
    try {
      await studentsCollection.doc(s.id).delete();

      // Delete from users collection
      final userQuery = await usersCollection
          .where('username', isEqualTo: s.username)
          .get();
      if (userQuery.docs.isNotEmpty) {
        final userDocId = userQuery.docs.first.id;
        await usersCollection.doc(userDocId).delete();
      }

      await _fetchStudents();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Student deleted'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error deleting student: $e');
    }
  }

  Future<void> _confirmDeleteStudent(Student s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete student'),
        content: Text('Delete ${s.fullname}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) await _deleteStudent(s);
  }

  void _handleRowTap(int index) => setState(() => _selectedIndex = index);

  // Helpers to operate on the currently selected student
  void _showEditSelected() {
    if (_selectedIndex == null) return;
    _showEditStudentPopup(_filteredStudents[_selectedIndex!]);
  }

  Future<void> _confirmDeleteSelected() async {
    if (_selectedIndex == null) return;
    await _confirmDeleteStudent(_filteredStudents[_selectedIndex!]);
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;
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
            'Students',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Theme.of(
                context,
              ).extension<TeacherThemeColors>()?.textPrimary,
            ),
          ),
          const SizedBox(height: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isDesktop)
                Row(
                  children: [
                    Expanded(
                      child: SearchAddBar(
                        hintText: 'Search student...',
                        buttonText: 'Add Student',
                        onAddPressed: _showAddStudentPopup,
                        onChanged: (v) {
                          setState(() {
                            _searchText = v;
                            _selectedIndex = null;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _handleUploadStudents,
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Upload Students'),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: const Color.fromARGB(255, 0, 150, 80),
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
                  hintText: 'Search student...',
                  buttonText: 'Add Student',
                  onAddPressed: _showAddStudentPopup,
                  onChanged: (v) {
                    setState(() {
                      _searchText = v;
                      _selectedIndex = null;
                    });
                  },
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _handleUploadStudents,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Upload Students'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: const Color.fromARGB(255, 0, 150, 80),
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
                      onPressed: _selectedIndex == null ? null : _showEditSelected,
                      child: const Text(
                        'Edit',
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
                          : _confirmDeleteSelected,
                      child: const Text(
                        'Delete',
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
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
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
          // bottom action row removed to match Classes page
        ],
      ),
    );
  }

  Widget _buildDesktopTable() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = Theme.of(context).extension<TeacherThemeColors>();
    final highlight =
        palette?.highlight ??
        (isDark ? const Color(0xFF2E3545) : Colors.blue.shade50);
    return Table(
      columnWidths: const {
        0: FixedColumnWidth(48),
        1: FixedColumnWidth(220),
        2: FixedColumnWidth(140),
        3: FixedColumnWidth(100),
        4: IntrinsicColumnWidth(),
        5: FixedColumnWidth(160),
      },
      border: TableBorder(
        horizontalInside: BorderSide(color: Colors.grey.shade300),
      ),
      children: [
        TableRow(
          children: [
            _tableHeaderCell('No'),
            _tableHeaderCell('Username'),
            _tableHeaderCell('Full name'),
            _tableHeaderCell('Gender'),
            _tableHeaderCell('Department'),
            _tableHeaderCell('Class'),
          ],
        ),
        for (int i = 0; i < _filteredStudents.length; i++)
          TableRow(
            decoration: BoxDecoration(
              color: _selectedIndex == i ? highlight : Colors.transparent,
            ),
            children: [
              _tableBodyCell('${i + 1}', onTap: () => _handleRowTap(i)),
              _tableBodyCell(
                _filteredStudents[i].username,
                onTap: () => _handleRowTap(i),
              ),
              _tableBodyCell(
                _filteredStudents[i].fullname,
                onTap: () => _handleRowTap(i),
              ),
              _tableBodyCell(
                _filteredStudents[i].gender,
                onTap: () => _handleRowTap(i),
              ),
              _tableBodyCell(
                _departmentNames[_filteredStudents[i].departmentRef ?? ''] ??
                    '',
                onTap: () => _handleRowTap(i),
              ),
              _tableBodyCell(
                _classNames[_filteredStudents[i].classRef ?? ''] ?? '',
                onTap: () => _handleRowTap(i),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildMobileTable() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = Theme.of(context).extension<TeacherThemeColors>();
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
            _tableHeaderCell('No'),
            _tableHeaderCell('Username'),
            _tableHeaderCell('Full name'),
            _tableHeaderCell('Gender'),
            _tableHeaderCell('Department'),
            _tableHeaderCell('Class'),
          ],
        ),
        for (int i = 0; i < _filteredStudents.length; i++)
          TableRow(
            decoration: BoxDecoration(
              color: _selectedIndex == i ? highlight : Colors.transparent,
            ),
            children: [
              _tableBodyCell('${i + 1}', onTap: () => _handleRowTap(i)),
              _tableBodyCell(
                _filteredStudents[i].username,
                onTap: () => _handleRowTap(i),
              ),
              _tableBodyCell(
                _filteredStudents[i].fullname,
                onTap: () => _handleRowTap(i),
              ),
              _tableBodyCell(
                _filteredStudents[i].gender,
                onTap: () => _handleRowTap(i),
              ),
              _tableBodyCell(
                _departmentNames[_filteredStudents[i].departmentRef ?? ''] ??
                    '',
                onTap: () => _handleRowTap(i),
              ),
              _tableBodyCell(
                _classNames[_filteredStudents[i].classRef ?? ''] ?? '',
                onTap: () => _handleRowTap(i),
              ),
            ],
          ),
      ],
    );
  }

  Widget _tableHeaderCell(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
  );

  String? _findIdByName(Map<String, String> map, String name) {
    final key = map.entries
        .firstWhere(
          (e) => e.value.toLowerCase().trim() == name.toLowerCase().trim(),
          orElse: () => const MapEntry('', ''),
        )
        .key;
    return key.isEmpty ? null : key;
  }

  String? _resolveRef(Map<String, String> map, String? val) {
    if (val == null || val.isEmpty) return null;
    // if it's already an id present in the lookup map
    if (map.containsKey(val)) return val;
    // try to match by name
    final byName = _findIdByName(map, val);
    if (byName != null) return byName;
    // fallback: return the value as-is (may be an id or path)
    return val;
  }

  Future<void> _handleUploadStudents() async {
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
          .map((h) => h.toString().toLowerCase())
          .toList();
      final List<Map<String, dynamic>> parsed = [];
      for (var i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.every((cell) => (cell ?? '').toString().trim().isEmpty)) {
          continue;
        }
        final map = <String, dynamic>{};
        for (var c = 0; c < headers.length && c < row.length; c++) {
          map[headers[c]] = row[c]?.toString() ?? '';
        }
        parsed.add(map);
      }

      if (parsed.isEmpty) return;

      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirm upload'),
          content: Text('Import ${parsed.length} students?'),
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

      final added = <String>[];
      final skipped = <String>[];
      for (final row in parsed) {
        final fullname =
            (row['fullname'] ?? row['full_name'] ?? row['name'] ?? '')
                .toString()
                .trim();
        final username = (row['username'] ?? '').toString().trim();
        final password = (row['password'] ?? username).toString();
        if (fullname.isEmpty || username.isEmpty) {
          skipped.add(username.isEmpty ? fullname : username);
          continue;
        }

        final rawDept =
            (row['department_ref'] ??
                    row['department'] ??
                    row['departmentid'] ??
                    row['department_name'] ??
                    '')
                .toString()
                .trim();
        final rawClass =
            (row['class_ref'] ??
                    row['class'] ??
                    row['classid'] ??
                    row['class_name'] ??
                    '')
                .toString()
                .trim();
        final rawFaculty =
            (row['faculty_ref'] ?? row['faculty'] ?? row['facultyid'] ?? '')
                .toString()
                .trim();

        final deptId = _resolveRef(_departmentNames, rawDept);
        final classId = _resolveRef(_classNames, rawClass);

        final stud = Student(
          fullname: fullname,
          username: username,
          password: password,
          gender: (row['gender'] ?? 'Male').toString(),
          departmentRef: deptId,
          classRef: classId,
          facultyRef: rawFaculty.isEmpty ? null : rawFaculty,
          createdAt: null,
        );

        final ok = await _addStudentFromUpload(stud);
        if (ok) {
          added.add(username);
        } else {
          skipped.add(username);
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Imported ${added.length}, skipped ${skipped.length}',
            ),
          ),
        );
      }
      await _fetchStudents();
    } catch (e) {
      print('Error importing students: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to import students')),
        );
      }
    }
  }

  Future<bool> _addStudentFromUpload(Student s) async {
    try {
      final q = await studentsCollection
          .where('username', isEqualTo: s.username)
          .get();
      if (q.docs.isNotEmpty) return false;

      // infer faculty from department if missing
      String facultyToWrite = s.facultyRef ?? '';
      if (facultyToWrite.isEmpty && (s.departmentRef ?? '').isNotEmpty) {
        try {
          final dep = await departmentsCollection.doc(s.departmentRef).get();
          if (dep.exists) {
            final depData = dep.data() as Map<String, dynamic>?;
            final cand = depData == null
                ? null
                : (depData['faculty_ref'] ??
                      depData['facultyId'] ??
                      depData['faculty_id'] ??
                      depData['faculty']);
            if (cand != null) facultyToWrite = _extractId(cand);
          }
        } catch (_) {}
      }

      final facultyForStudentField =
          Session.facultyRef ??
          (facultyToWrite.isNotEmpty
              ? facultiesCollection.doc(facultyToWrite)
              : null);

      final Map<String, dynamic> studentDoc = {
        'fullname': s.fullname,
        'username': s.username,
        'password': s.password,
        'gender': s.gender,
        'department_ref': s.departmentRef ?? '',
        'class_ref': s.classRef ?? '',
        'className': _classNames[s.classRef ?? ''] ?? '',
        'faculty_ref': facultyForStudentField ?? '',
        'created_at': FieldValue.serverTimestamp(),
      };

      await studentsCollection.add(studentDoc);

      final String? userFacultyValue = Session.facultyRef != null
          ? '/${Session.facultyRef!.path}'
          : (facultyToWrite.isNotEmpty ? facultyToWrite : null);

      await usersCollection.add({
        'username': s.username,
        'role': 'student',
        'password': s.password,
        'faculty_id': userFacultyValue ?? '',
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      print('Error adding student from upload: $e');
      return false;
    }
  }

  Widget _tableBodyCell(String text, {VoidCallback? onTap}) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      child: Text(text, overflow: TextOverflow.visible, softWrap: true),
    ),
  );
}
