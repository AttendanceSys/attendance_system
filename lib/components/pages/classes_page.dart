import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/classes.dart';
import '../popup/add_class_popup.dart';
import '../cards/searchBar.dart';
import '../../services/session.dart';
import '../../theme/super_admin_theme.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../../utils/download_bytes.dart';

class ClassesPage extends StatefulWidget {
  const ClassesPage({super.key});

  @override
  State<ClassesPage> createState() => _ClassesPageState();
}

class _ClassesPageState extends State<ClassesPage> {
  final CollectionReference classesCollection = FirebaseFirestore.instance
      .collection('classes');
  final CollectionReference departmentsCollection = FirebaseFirestore.instance
      .collection('departments');
  final CollectionReference facultiesCollection = FirebaseFirestore.instance
      .collection('faculties');

  List<SchoolClass> _classes = [];
  Map<String, String> _departmentNames = {}; // id -> name
  Map<String, String> _facultyNames = {}; // id -> name

  String _searchText = '';
  int? _selectedIndex;

  List<SchoolClass> get _filteredClasses => _classes
      .where(
        (cls) =>
            (cls.className.toLowerCase().contains(_searchText.toLowerCase()) ||
            (_departmentNames[cls.departmentRef] ?? '').toLowerCase().contains(
              _searchText.toLowerCase(),
            )),
      )
      .toList();

  @override
  void initState() {
    super.initState();
    _fetchDepartments();
    _fetchClasses();
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
        _departmentNames = Map.fromEntries(
          snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = data['department_name'] ?? data['name'] ?? '';
            return MapEntry(doc.id, name as String);
          }),
        );
        _facultyNames = Map.fromEntries(
          fSnap.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name =
                data['faculty_name'] ??
                data['name'] ??
                data['facultyName'] ??
                '';
            return MapEntry(doc.id, name as String);
          }),
        );
      });
    } catch (e) {
      print('Error fetching departments: $e');
    }
  }

  Future<void> _fetchClasses() async {
    try {
      Query q = classesCollection;
      if (Session.facultyRef != null) {
        q = q.where('faculty_ref', isEqualTo: Session.facultyRef);
      }
      final snapshot = await q.get();
      setState(() {
        _classes = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final className = data['class_name'] ?? data['name'] ?? '';
          final departmentRef = data['department_ref'] is DocumentReference
              ? (data['department_ref'] as DocumentReference).id
              : (data['department_ref']?.toString() ?? '');
          final facultyRef = data['faculty_ref'] is DocumentReference
              ? (data['faculty_ref'] as DocumentReference).id
              : (data['faculty_ref']?.toString() ?? '');
          final section = data['section'] ?? 'NONE';
          final status = data['status'] == null
              ? true
              : (data['status'] is bool
                    ? data['status'] as bool
                    : data['status'].toString().toLowerCase() == 'true');
          final createdAt = (data['created_at'] as Timestamp?)?.toDate();
          return SchoolClass(
            id: doc.id,
            className: className as String,
            departmentRef: departmentRef,
            facultyRef: facultyRef.isNotEmpty ? facultyRef : null,
            section: section as String,
            status: status,
            createdAt: createdAt,
          );
        }).toList();
      });
    } catch (e) {
      print('Error fetching classes: $e');
    }
  }

  Future<void> _showAddClassPopup() async {
    final result = await showDialog<SchoolClass>(
      context: context,
      builder: (context) => const AddClassPopup(),
    );
    if (result != null) {
      await _addClass(result);
    }
  }

  Future<void> _showEditClassPopup() async {
    if (_selectedIndex == null) return;
    final schoolClass = _filteredClasses[_selectedIndex!];
    final result = await showDialog<SchoolClass>(
      context: context,
      builder: (context) => AddClassPopup(schoolClass: schoolClass),
    );
    if (result != null) {
      await _updateClass(schoolClass, result);
    }
  }

  Future<void> _confirmDeleteClass() async {
    if (_selectedIndex == null) return;
    final schoolClass = _filteredClasses[_selectedIndex!];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Class"),
        content: Text(
          "Are you sure you want to delete '${schoolClass.className}'?",
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
      await _deleteClass(schoolClass);
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

  void _toggleActive(int index, bool value) {
    final sc = _filteredClasses[index];
    _toggleStatus(sc, value);
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

  String? _resolveRef(Map<String, String> map, String? val) {
    if (val == null || val.isEmpty) return null;
    if (map.containsKey(val)) return val;
    final byName = _findIdByName(map, val);
    if (byName != null) return byName;
    return val;
  }

  String _facultyDisplay(String? facultyRef) {
    final fid = (facultyRef ?? '').trim();
    if (fid.isEmpty) {
      if (Session.facultyRef == null) return '';
      return _facultyNames[Session.facultyRef!.id] ?? Session.facultyRef!.id;
    }
    if (_facultyNames.containsKey(fid)) return _facultyNames[fid]!;
    if (fid.contains('/')) {
      final parts = fid.split('/').where((p) => p.isNotEmpty).toList();
      if (parts.isNotEmpty && _facultyNames.containsKey(parts.last)) {
        return _facultyNames[parts.last]!;
      }
    }
    return fid;
  }

  Future<void> _addClass(SchoolClass sc) async {
    try {
      // uniqueness: prevent same class_name + department + section
      final keyQuery = await classesCollection
          .where('class_name', isEqualTo: sc.className)
          .where('department_ref', isEqualTo: sc.departmentRef)
          .where('section', isEqualTo: sc.section)
          .get();
      if (keyQuery.docs.isNotEmpty) {
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Duplicate Class'),
            content: const Text(
              'A class with that name/section already exists in the selected department.',
            ),
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

      // If facultyRef wasn't provided, try to infer it from the department document
      String facultyToWrite = sc.facultyRef ?? '';
      if (facultyToWrite.isEmpty && sc.departmentRef.isNotEmpty) {
        try {
          final depDoc = await departmentsCollection
              .doc(sc.departmentRef)
              .get();
          if (depDoc.exists) {
            final depData = depDoc.data() as Map<String, dynamic>?;
            final candidate = depData == null
                ? null
                : (depData['faculty_ref'] ??
                      depData['facultyId'] ??
                      depData['faculty_id'] ??
                      depData['faculty']);
            if (candidate != null) {
              if (candidate is DocumentReference) {
                facultyToWrite = candidate.id;
              } else if (candidate is String) {
                facultyToWrite = candidate;
              }
            }
          }
        } catch (e) {
          print('Error resolving faculty from department: $e');
        }
      }

      final Map<String, dynamic> toWrite = {
        'class_name': sc.className,
        'department_ref': sc.departmentRef,
        'faculty_ref': facultyToWrite,
        'section': sc.section,
        'status': sc.status,
        'created_at': FieldValue.serverTimestamp(),
      };
      if (Session.facultyRef != null) {
        toWrite['faculty_ref'] = Session.facultyRef;
      }
      await classesCollection.add(toWrite);
      await _fetchClasses();
      setState(() => _selectedIndex = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Class added successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error adding class: $e');
    }
  }

  Future<void> _updateClass(SchoolClass oldSc, SchoolClass newSc) async {
    if (oldSc.id == null) return;
    try {
      // uniqueness check if key changed
      if (oldSc.className != newSc.className ||
          oldSc.departmentRef != newSc.departmentRef ||
          oldSc.section != newSc.section) {
        final keyQuery = await classesCollection
            .where('class_name', isEqualTo: newSc.className)
            .where('department_ref', isEqualTo: newSc.departmentRef)
            .where('section', isEqualTo: newSc.section)
            .get();
        final conflict = keyQuery.docs.any((d) => d.id != oldSc.id);
        if (conflict) {
          showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Duplicate Class'),
              content: const Text(
                'A class with that name/section already exists in the selected department.',
              ),
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

      // If facultyRef wasn't provided, attempt to infer from department
      String facultyToWrite = newSc.facultyRef ?? '';
      if (facultyToWrite.isEmpty && newSc.departmentRef.isNotEmpty) {
        try {
          final depDoc = await departmentsCollection
              .doc(newSc.departmentRef)
              .get();
          if (depDoc.exists) {
            final depData = depDoc.data() as Map<String, dynamic>?;
            final candidate = depData == null
                ? null
                : (depData['faculty_ref'] ??
                      depData['facultyId'] ??
                      depData['faculty_id'] ??
                      depData['faculty']);
            if (candidate != null) {
              if (candidate is DocumentReference) {
                facultyToWrite = candidate.id;
              } else if (candidate is String) {
                facultyToWrite = candidate;
              }
            }
          }
        } catch (e) {
          print('Error resolving faculty from department: $e');
        }
      }

      final Map<String, dynamic> toUpdate = {
        'class_name': newSc.className,
        'department_ref': newSc.departmentRef,
        'faculty_ref': facultyToWrite,
        'section': newSc.section,
        'status': newSc.status,
        'created_at': FieldValue.serverTimestamp(),
      };
      if (Session.facultyRef != null) {
        toUpdate['faculty_ref'] = Session.facultyRef;
      }
      await classesCollection.doc(oldSc.id).update(toUpdate);
      await _fetchClasses();
      setState(() => _selectedIndex = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Class updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error updating class: $e');
    }
  }

  Future<void> _deleteClass(SchoolClass sc) async {
    if (sc.id == null) return;
    try {
      await classesCollection.doc(sc.id).delete();
      await _fetchClasses();
      setState(() => _selectedIndex = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Class deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error deleting class: $e');
    }
  }

  Future<void> _toggleStatus(SchoolClass sc, bool newValue) async {
    if (sc.id == null) return;
    try {
      await classesCollection.doc(sc.id).update({'status': newValue});
      await _fetchClasses();
    } catch (e) {
      print('Error toggling class status: $e');
    }
  }

  Future<void> _handleExportClassesCsv() async {
    try {
      final rows = <List<dynamic>>[
        ['No', 'Class name', 'Department', 'Faculty', 'Section', 'Status'],
      ];

      for (int i = 0; i < _classes.length; i++) {
        final c = _classes[i];
        rows.add([
          i + 1,
          c.className,
          _departmentNames[c.departmentRef] ?? c.departmentRef,
          _facultyDisplay(c.facultyRef),
          c.section,
          c.status ? 'Active' : 'Inactive',
        ]);
      }

      final csv = const ListToCsvConverter().convert(rows);
      final bytes = Uint8List.fromList(utf8.encode(csv));
      final now = DateTime.now();
      final fileName =
          'classes_${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.csv';

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
      print('Error exporting classes CSV: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to export CSV')));
    }
  }

  Future<void> _handleUploadClasses() async {
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
          content: Text('Import ${parsed.length} classes?'),
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
        final className =
            (row['class_name'] ?? row['classname'] ?? row['class'] ?? '')
                .toString()
                .trim();
        final departmentRaw =
            (row['department_ref'] ??
                    row['departmentid'] ??
                    row['department'] ??
                    row['department_name'] ??
                    '')
                .toString()
                .trim();
        final facultyRaw =
            (row['faculty_ref'] ??
                    row['faculty_id'] ??
                    row['faculty'] ??
                    row['faculty_name'] ??
                    '')
                .toString()
                .trim();
        final section =
            (row['section'] ?? '').toString().trim().isEmpty
            ? 'NONE'
            : row['section']!.toString().trim();
        final statusRaw = (row['status'] ?? 'true').toString().trim();
        final status =
            statusRaw.toLowerCase() == 'true' ||
            statusRaw == '1' ||
            statusRaw.toLowerCase() == 'active' ||
            statusRaw.toLowerCase() == 'yes';

        if (className.isEmpty || departmentRaw.isEmpty) {
          skipped++;
          continue;
        }

        final departmentRef = _resolveRef(_departmentNames, departmentRaw) ?? '';
        final facultyRef = _extractId(
          _resolveRef(_facultyNames, facultyRaw) ??
              Session.facultyRef?.id ??
              '',
        );

        final sc = SchoolClass(
          className: className,
          departmentRef: departmentRef,
          facultyRef: facultyRef.isEmpty ? null : facultyRef,
          section: section,
          status: status,
        );
        final ok = await _addClassFromUpload(sc);
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
      await _fetchClasses();
    } catch (e) {
      print('Error importing classes: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to import classes')),
      );
    }
  }

  Future<bool> _addClassFromUpload(SchoolClass sc) async {
    try {
      final keyQuery = await classesCollection
          .where('class_name', isEqualTo: sc.className)
          .where('department_ref', isEqualTo: sc.departmentRef)
          .where('section', isEqualTo: sc.section)
          .get();
      if (keyQuery.docs.isNotEmpty) return false;

      String facultyToWrite = sc.facultyRef ?? '';
      if (facultyToWrite.isEmpty && sc.departmentRef.isNotEmpty) {
        try {
          final depDoc = await departmentsCollection.doc(sc.departmentRef).get();
          if (depDoc.exists) {
            final depData = depDoc.data() as Map<String, dynamic>?;
            final candidate = depData == null
                ? null
                : (depData['faculty_ref'] ??
                      depData['facultyId'] ??
                      depData['faculty_id'] ??
                      depData['faculty']);
            if (candidate != null) {
              facultyToWrite = _extractId(candidate);
            }
          }
        } catch (_) {}
      }

      final Map<String, dynamic> toWrite = {
        'class_name': sc.className,
        'department_ref': sc.departmentRef,
        'faculty_ref': facultyToWrite,
        'section': sc.section,
        'status': sc.status,
        'created_at': FieldValue.serverTimestamp(),
      };
      if (Session.facultyRef != null) {
        toWrite['faculty_ref'] = Session.facultyRef;
      }
      await classesCollection.add(toWrite);
      return true;
    } catch (e) {
      print('Error adding class from upload: $e');
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
            "Classes",
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
                        hintText: "Search Class...",
                        buttonText: "Add Class",
                        onAddPressed: _showAddClassPopup,
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
                        onPressed: _handleUploadClasses,
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Upload Classes'),
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
                        onPressed: _handleExportClassesCsv,
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
                  hintText: "Search Class...",
                  buttonText: "Add Class",
                  onAddPressed: _showAddClassPopup,
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
                    onPressed: _handleUploadClasses,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Upload Classes'),
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
                    onPressed: _handleExportClassesCsv,
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
                      onPressed: _selectedIndex == null ? null : _showEditClassPopup,
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
                      onPressed: _selectedIndex == null ? null : _confirmDeleteClass,
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
        1: FlexColumnWidth(1.4),
        2: FlexColumnWidth(1.4),
        3: FixedColumnWidth(150),
      },
    );
  }

  Widget _buildMobileTable() {
    return _buildSaasTable(
      columnWidths: const {
        0: FixedColumnWidth(72),
        1: FixedColumnWidth(180),
        2: FixedColumnWidth(180),
        3: FixedColumnWidth(150),
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
                    _tableHeaderCell("Class name", textPrimary),
                    _tableHeaderCell("Department", textPrimary),
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
                  border: TableBorder(horizontalInside: BorderSide(color: divider)),
                  children: [
                    for (int index = 0; index < _filteredClasses.length; index++)
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
                            _filteredClasses[index].className,
                            textPrimary,
                            onTap: () => _handleRowTap(index),
                          ),
                          _tableBodyCell(
                            _departmentNames[_filteredClasses[index].departmentRef] ??
                                _filteredClasses[index].departmentRef,
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
                                  value: _filteredClasses[index].status,
                                  onChanged: (value) => _toggleActive(index, value),
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
