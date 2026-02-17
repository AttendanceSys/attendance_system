import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/department.dart';
import '../../services/session.dart';
import '../popup/add_department_popup.dart';
import '../cards/searchBar.dart';
import '../../theme/super_admin_theme.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../../utils/download_bytes.dart';

class DepartmentsPage extends StatefulWidget {
  const DepartmentsPage({super.key});

  @override
  State<DepartmentsPage> createState() => _DepartmentsPageState();
}

class _DepartmentsPageState extends State<DepartmentsPage> {
  final CollectionReference departmentsCollection = FirebaseFirestore.instance
      .collection('departments');

  final CollectionReference teachersCollection = FirebaseFirestore.instance
      .collection('teachers');
  final CollectionReference facultiesCollection = FirebaseFirestore.instance
      .collection('faculties');

  List<Department> _departments = [];
  Map<String, String> _teacherNames = {}; // id -> display name
  Map<String, String> _facultyNames = {}; // id -> display name
  Map<String, String> _departmentFacultyIds = {}; // department id -> faculty id

  final List<String> _statusOptions = ['Active', 'in active'];
  String _searchText = '';
  int? _selectedIndex;

  List<Department> get _filteredDepartments => _departments
      .where(
        (dept) =>
            dept.code.toLowerCase().contains(_searchText.toLowerCase()) ||
            dept.name.toLowerCase().contains(_searchText.toLowerCase()) ||
            dept.head.toLowerCase().contains(_searchText.toLowerCase()) ||
            dept.status.toLowerCase().contains(_searchText.toLowerCase()),
      )
      .toList();

  @override
  void initState() {
    super.initState();
    _fetchTeachers();
    _fetchDepartments();
  }

  Future<void> _fetchTeachers() async {
    try {
      final snapshot = await teachersCollection.get();
      setState(() {
        _teacherNames = Map.fromEntries(
          snapshot.docs.map((doc) {
            final d = doc.data() as Map<String, dynamic>;
            final name = (d['teacher_name'] ?? d['name'] ?? '') as String;
            return MapEntry(doc.id, name);
          }),
        );
      });
    } catch (e) {
      print('Error fetching teacher names: $e');
    }
  }

  Future<void> _fetchDepartments() async {
    try {
      Query q = departmentsCollection;
      Query fq = facultiesCollection;
      if (Session.facultyRef != null) {
        q = q.where('faculty_ref', isEqualTo: Session.facultyRef);
        fq = fq.where(FieldPath.documentId, isEqualTo: Session.facultyRef!.id);
      }
      final snapshot = await q.get();
      final fSnap = await fq.get();
      setState(() {
        _departmentFacultyIds = {};
        _departments = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          // support multiple possible field names
          final code = data['department_code'] ?? data['code'] ?? '';
          final name = data['department_name'] ?? data['name'] ?? '';
          final head = data['head_of_department'] ?? data['head'] ?? '';
          final fac = data['faculty_ref'] ?? data['faculty_id'] ?? data['faculty'];
          _departmentFacultyIds[doc.id] = _extractId(fac);
          final statusVal = data['status'] is bool
              ? ((data['status'] as bool) ? 'Active' : 'in active')
              : (data['status']?.toString() ?? '');
          final createdAt = (data['created_at'] as Timestamp?)?.toDate();
          return Department(
            id: doc.id,
            code: code,
            name: name,
            head: head,
            status: statusVal,
            createdAt: createdAt,
          );
        }).toList();
        _facultyNames = Map.fromEntries(
          fSnap.docs.map((doc) {
            final d = doc.data() as Map<String, dynamic>;
            final name =
                (d['faculty_name'] ?? d['name'] ?? d['facultyName'] ?? '')
                    .toString();
            return MapEntry(doc.id, name);
          }),
        );
      });
    } catch (e) {
      print('Error fetching departments: $e');
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

  String _extractId(dynamic cand) {
    if (cand == null) return '';
    if (cand is DocumentReference) return cand.id;
    if (cand is String) {
      final s = cand.trim();
      if (s.contains('/')) {
        final parts = s.split('/').where((p) => p.isNotEmpty).toList();
        return parts.isNotEmpty ? parts.last : s;
      }
      return s;
    }
    return cand.toString();
  }

  String? _findIdByName(Map<String, String> map, String name) {
    final key = map.entries
        .firstWhere(
          (e) => e.value.toLowerCase().trim() == name.toLowerCase().trim(),
          orElse: () => const MapEntry('', ''),
        )
        .key;
    return key.isEmpty ? null : key;
  }

  String? _resolveRef(Map<String, String> map, String? value) {
    if (value == null || value.trim().isEmpty) return null;
    if (map.containsKey(value)) return value;
    final byName = _findIdByName(map, value);
    if (byName != null) return byName;
    return value;
  }

  String _teacherDisplay(String? head) {
    final raw = (head ?? '').trim();
    if (raw.isEmpty) return '';
    return _teacherNames[raw] ?? raw;
  }

  String _facultyDisplayByDepartmentId(String? departmentId) {
    final did = (departmentId ?? '').trim();
    if (did.isEmpty) return Session.facultyRef?.id ?? '';
    final fid = _departmentFacultyIds[did] ?? '';
    if (fid.isEmpty) {
      if (Session.facultyRef == null) return '';
      return _facultyNames[Session.facultyRef!.id] ?? Session.facultyRef!.id;
    }
    return _facultyNames[fid] ?? fid;
  }

  Future<void> _showAddDepartmentPopup() async {
    final result = await showDialog<Department>(
      context: context,
      builder: (context) => AddDepartmentPopup(statusOptions: _statusOptions),
    );
    if (result != null) {
      await _addDepartment(result);
    }
  }

  Future<void> _showEditDepartmentPopup() async {
    if (_selectedIndex == null) return;
    final dept = _filteredDepartments[_selectedIndex!];
    final result = await showDialog<Department>(
      context: context,
      builder: (context) =>
          AddDepartmentPopup(department: dept, statusOptions: _statusOptions),
    );
    if (result != null) {
      await _updateDepartment(dept, result);
    }
  }

  Future<void> _confirmDeleteDepartment() async {
    if (_selectedIndex == null) return;
    final dept = _filteredDepartments[_selectedIndex!];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Department"),
        content: Text("Are you sure you want to delete '${dept.name}'?"),
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
      await _deleteDepartment(dept);
    }
  }

  Future<void> _addDepartment(Department dept) async {
    try {
      final Map<String, dynamic> toWrite = {
        'department_code': dept.code,
        'department_name': dept.name,
        'head_of_department': dept.head,
        'status': dept.status == 'Active' ? true : false,
        'created_at': FieldValue.serverTimestamp(),
      };
      if (Session.facultyRef != null) {
        toWrite['faculty_ref'] = Session.facultyRef;
      }
      await departmentsCollection.add(toWrite);
      await _fetchDepartments();
      setState(() => _selectedIndex = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Department added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error adding department: $e');
    }
  }

  Future<void> _updateDepartment(Department oldDept, Department newDept) async {
    if (oldDept.id == null) return;
    try {
      await departmentsCollection.doc(oldDept.id).update({
        'department_code': newDept.code,
        'department_name': newDept.name,
        'head_of_department': newDept.head,
        'status': newDept.status == 'Active' ? true : false,
        'created_at': FieldValue.serverTimestamp(),
      });
      await _fetchDepartments();
      setState(() => _selectedIndex = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Department updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error updating department: $e');
    }
  }

  Future<void> _deleteDepartment(Department dept) async {
    if (dept.id == null) return;
    try {
      await departmentsCollection.doc(dept.id).delete();
      await _fetchDepartments();
      setState(() => _selectedIndex = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Department deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error deleting department: $e');
    }
  }

  Future<void> _toggleStatus(Department dept, bool newValue) async {
    if (dept.id == null) return;
    try {
      await departmentsCollection.doc(dept.id).update({'status': newValue});
      await _fetchDepartments();
    } catch (e) {
      print('Error toggling status: $e');
    }
  }

  Future<void> _handleExportDepartmentsCsv() async {
    try {
      final rows = <List<dynamic>>[
        ['No', 'Department code', 'Department name', 'Head of department', 'Faculty', 'Status'],
      ];
      for (int i = 0; i < _departments.length; i++) {
        final d = _departments[i];
        rows.add([
          i + 1,
          d.code,
          d.name,
          _teacherDisplay(d.head),
          _facultyDisplayByDepartmentId(d.id),
          d.status,
        ]);
      }

      final csv = const ListToCsvConverter().convert(rows);
      final bytes = Uint8List.fromList(utf8.encode(csv));
      final now = DateTime.now();
      final fileName =
          'departments_${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.csv';

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
      print('Error exporting departments CSV: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to export CSV')),
      );
    }
  }

  Future<void> _handleUploadDepartments() async {
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
          content: Text('Import ${parsed.length} departments?'),
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
        final code =
            (row['department_code'] ??
                    row['department code'] ??
                    row['code'] ??
                    '')
                .toString()
                .trim();
        final name =
            (row['department_name'] ??
                    row['department name'] ??
                    row['name'] ??
                    '')
                .toString()
                .trim();
        final headRaw =
            (row['head_of_department'] ??
                    row['head of department'] ??
                    row['head'] ??
                    row['head_name'] ??
                    '')
                .toString()
                .trim();
        final statusRaw = (row['status'] ?? 'Active').toString().trim();

        if (code.isEmpty || name.isEmpty) {
          skipped++;
          continue;
        }

        final exists = await departmentsCollection
            .where('department_code', isEqualTo: code)
            .get();
        if (exists.docs.isNotEmpty) {
          skipped++;
          continue;
        }

        final headResolved = _resolveRef(_teacherNames, headRaw) ?? headRaw;
        final dept = Department(
          code: code,
          name: name,
          head: headResolved,
          status: statusRaw.toLowerCase() == 'active' ||
                  statusRaw.toLowerCase() == 'true' ||
                  statusRaw == '1' ||
                  statusRaw.toLowerCase() == 'yes'
              ? 'Active'
              : 'in active',
        );
        final ok = await _addDepartmentFromUpload(dept, row);
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
      await _fetchDepartments();
    } catch (e) {
      print('Error importing departments: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to import departments')),
      );
    }
  }

  Future<bool> _addDepartmentFromUpload(
    Department dept,
    Map<String, String> row,
  ) async {
    try {
      final facultyRaw =
          (row['faculty_ref'] ??
                  row['faculty_id'] ??
                  row['faculty'] ??
                  row['faculty name'] ??
                  row['faculty_name'] ??
                  '')
              .toString()
              .trim();
      final facultyId = _extractId(
        _resolveRef(_facultyNames, facultyRaw) ?? Session.facultyRef?.id ?? '',
      );
      final Map<String, dynamic> toWrite = {
        'department_code': dept.code,
        'department_name': dept.name,
        'head_of_department': dept.head,
        'status': dept.status == 'Active',
        'created_at': FieldValue.serverTimestamp(),
      };
      if (Session.facultyRef != null) {
        toWrite['faculty_ref'] = Session.facultyRef;
      } else if (facultyId.isNotEmpty) {
        toWrite['faculty_ref'] = facultiesCollection.doc(facultyId);
      }
      await departmentsCollection.add(toWrite);
      return true;
    } catch (e) {
      print('Error adding department from upload: $e');
      return false;
    }
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
            "Departments",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Theme.of(
                context,
              ).extension<SuperAdminColors>()?.textPrimary,
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
                        hintText: "Search departments...",
                        buttonText: "Add Departments",
                        onAddPressed: _showAddDepartmentPopup,
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
                        onPressed: _handleUploadDepartments,
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Upload Departments'),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: const Color.fromARGB(255, 0, 150, 80),
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
                        onPressed: _handleExportDepartmentsCsv,
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
                  hintText: "Search departments...",
                  buttonText: "Add Departments",
                  onAddPressed: _showAddDepartmentPopup,
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
                    onPressed: _handleUploadDepartments,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Upload Departments'),
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: const Color.fromARGB(255, 0, 150, 80),
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
                    onPressed: _handleExportDepartmentsCsv,
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
                          : _showEditDepartmentPopup,
                      child: const Text(
                        "Edit",
                        style: TextStyle(fontSize: 15, color: Colors.white),
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
                          : _confirmDeleteDepartment,
                      child: const Text(
                        "Delete",
                        style: TextStyle(fontSize: 15, color: Colors.white),
                      ),
                    ),
                  ),
                ],
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
        1: FlexColumnWidth(1.2),
        2: FlexColumnWidth(1.6),
        3: FlexColumnWidth(1.8),
        4: FixedColumnWidth(150),
      },
    );
  }

  Widget _buildMobileTable() {
    return _buildSaasTable(
      columnWidths: const {
        0: FixedColumnWidth(72),
        1: FixedColumnWidth(150),
        2: FixedColumnWidth(180),
        3: FixedColumnWidth(220),
        4: FixedColumnWidth(150),
      },
    );
  }

  Widget _buildSaasTable({
    required Map<int, TableColumnWidth> columnWidths,
  }) {
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
                    _tableHeaderCell("Depart Code", textPrimary),
                    _tableHeaderCell("Depart Name", textPrimary),
                    _tableHeaderCell("Head of Depart", textPrimary),
                    _tableHeaderCell("Status", textPrimary),
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
                  border: TableBorder(
                    horizontalInside: BorderSide(color: divider),
                  ),
                  children: [
                    for (int index = 0; index < _filteredDepartments.length; index++)
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
                            _filteredDepartments[index].code,
                            textPrimary,
                            onTap: () => _handleRowTap(index),
                          ),
                          _tableBodyCell(
                            _filteredDepartments[index].name,
                            textPrimary,
                            onTap: () => _handleRowTap(index),
                          ),
                          _tableBodyCell(
                            _teacherNames[_filteredDepartments[index].head] ??
                                _filteredDepartments[index].head,
                            textPrimary,
                            onTap: () => _handleRowTap(index),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 10,
                              horizontal: 16,
                            ),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Transform.scale(
                                scale: 0.94,
                                child: Switch.adaptive(
                                  value:
                                      _filteredDepartments[index]
                                          .status
                                          .toLowerCase() ==
                                      'active',
                                  onChanged: (val) => _toggleStatus(
                                    _filteredDepartments[index],
                                    val,
                                  ),
                                  activeColor: const Color(0xFF1DBA73),
                                  inactiveThumbColor: const Color(0xFFD33D57),
                                  inactiveTrackColor: const Color(
                                    0xFFD33D57,
                                  ).withValues(alpha: 0.35),
                                ),
                              ),
                            ),
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
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
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
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
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
