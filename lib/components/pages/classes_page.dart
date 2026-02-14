import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/classes.dart';
import '../popup/add_class_popup.dart';
import '../cards/searchBar.dart';
import '../../services/session.dart';
import '../../theme/super_admin_theme.dart';

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

  List<SchoolClass> _classes = [];
  Map<String, String> _departmentNames = {}; // id -> name

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
      if (Session.facultyRef != null) {
        q = q.where('faculty_ref', isEqualTo: Session.facultyRef);
      }
      final snapshot = await q.get();
      setState(() {
        _departmentNames = Map.fromEntries(
          snapshot.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final name = data['department_name'] ?? data['name'] ?? '';
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                                : _showEditClassPopup,
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
                                : _confirmDeleteClass,
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
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: _clearSelection,
                behavior: HitTestBehavior.opaque,
                child: const SizedBox.expand(),
              ),
            ),
            Table(
              columnWidths: columnWidths,
              border: TableBorder(horizontalInside: BorderSide(color: divider)),
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
