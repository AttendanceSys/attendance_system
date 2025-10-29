import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/department.dart';
import '../../services/session.dart';
import '../popup/add_department_popup.dart';
import '../cards/searchBar.dart';

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

  List<Department> _departments = [];
  Map<String, String> _teacherNames = {}; // id -> display name

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
      if (Session.facultyRef != null)
        q = q.where('faculty_ref', isEqualTo: Session.facultyRef);
      final snapshot = await q.get();
      setState(() {
        _departments = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          // support multiple possible field names
          final code = data['department_code'] ?? data['code'] ?? '';
          final name = data['department_name'] ?? data['name'] ?? '';
          final head = data['head_of_department'] ?? data['head'] ?? '';
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
      });
    } catch (e) {
      print('Error fetching departments: $e');
    }
  }

  void _handleRowTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
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
      // Prevent same teacher being head of multiple departments
      if (dept.head.isNotEmpty) {
        final conflict = await departmentsCollection
            .where('head_of_department', isEqualTo: dept.head)
            .get();
        if (conflict.docs.isNotEmpty) {
          // show popup message
          showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Duplicate Head'),
              content: const Text(
                'This lecturer is already head of another department.',
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
      // Prevent assigning a head that's already used by another department
      if (newDept.head.isNotEmpty && newDept.head != oldDept.head) {
        final conflict = await departmentsCollection
            .where('head_of_department', isEqualTo: newDept.head)
            .get();
        final hasOther = conflict.docs.any((d) => d.id != oldDept.id);
        if (hasOther) {
          showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Duplicate Head'),
              content: const Text(
                'This lecturer is already head of another department.',
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
          const Text(
            "Departments",
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
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
                                : _showEditDepartmentPopup,
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
                                : _confirmDeleteDepartment,
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
    return Table(
      columnWidths: const {
        0: FixedColumnWidth(64), // No
        1: FixedColumnWidth(120), // Depart Code
        2: FixedColumnWidth(160), // Depart Name
        3: FixedColumnWidth(160), // Head of Depart
        4: FixedColumnWidth(120), // Status
      },
      border: TableBorder(
        horizontalInside: BorderSide(color: Colors.grey.shade300),
      ),
      children: [
        TableRow(
          children: [
            _tableHeaderCell("No"),
            _tableHeaderCell("Depart Code"),
            _tableHeaderCell("Depart Name"),
            _tableHeaderCell("Head of Depart"),
            _tableHeaderCell("Status"),
          ],
        ),
        for (int index = 0; index < _filteredDepartments.length; index++)
          TableRow(
            decoration: BoxDecoration(
              color: _selectedIndex == index
                  ? Colors.blue.shade50
                  : Colors.transparent,
            ),
            children: [
              _tableBodyCell('${index + 1}', onTap: () => _handleRowTap(index)),
              _tableBodyCell(
                _filteredDepartments[index].code,
                onTap: () => _handleRowTap(index),
              ),
              _tableBodyCell(
                _filteredDepartments[index].name,
                onTap: () => _handleRowTap(index),
              ),
              _tableBodyCell(
                _teacherNames[_filteredDepartments[index].head] ??
                    _filteredDepartments[index].head,
                onTap: () => _handleRowTap(index),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                child: Switch.adaptive(
                  value:
                      _filteredDepartments[index].status.toLowerCase() ==
                      'active',
                  onChanged: (val) =>
                      _toggleStatus(_filteredDepartments[index], val),
                  activeColor: Colors.green,
                  inactiveThumbColor: Colors.red,
                  inactiveTrackColor: Colors.redAccent.withOpacity(0.4),
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildMobileTable() {
    return Table(
      defaultColumnWidth: const IntrinsicColumnWidth(),
      border: TableBorder(
        horizontalInside: BorderSide(color: Colors.grey.shade300),
      ),
      children: [
        TableRow(
          children: [
            _tableHeaderCell("No"),
            _tableHeaderCell("Depart Code"),
            _tableHeaderCell("Depart Name"),
            _tableHeaderCell("Head of Depart"),
            _tableHeaderCell("Status"),
          ],
        ),
        for (int index = 0; index < _filteredDepartments.length; index++)
          TableRow(
            decoration: BoxDecoration(
              color: _selectedIndex == index
                  ? Colors.blue.shade50
                  : Colors.transparent,
            ),
            children: [
              _tableBodyCell('${index + 1}', onTap: () => _handleRowTap(index)),
              _tableBodyCell(
                _filteredDepartments[index].code,
                onTap: () => _handleRowTap(index),
              ),
              _tableBodyCell(
                _filteredDepartments[index].name,
                onTap: () => _handleRowTap(index),
              ),
              _tableBodyCell(
                _teacherNames[_filteredDepartments[index].head] ??
                    _filteredDepartments[index].head,
                onTap: () => _handleRowTap(index),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                child: Switch.adaptive(
                  value:
                      _filteredDepartments[index].status.toLowerCase() ==
                      'active',
                  onChanged: (val) =>
                      _toggleStatus(_filteredDepartments[index], val),
                  activeColor: Colors.green,
                  inactiveThumbColor: Colors.red,
                  inactiveTrackColor: Colors.redAccent.withOpacity(0.4),
                ),
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
