import 'package:flutter/material.dart';
import '../../models/department.dart';
import '../../hooks/use_departments.dart';
import '../../hooks/use_lectureres.dart';
import '../popup/add_department_popup.dart';
import '../cards/searchBar.dart';

class DepartmentsPage extends StatefulWidget {
  const DepartmentsPage({super.key});

  @override
  State<DepartmentsPage> createState() => _DepartmentsPageState();
}

class _DepartmentsPageState extends State<DepartmentsPage> {
  final List<Department> _departments = [];
  final UseDepartments _departmentsService = UseDepartments();
  final UseTeachers _teachersService = UseTeachers();

  final List<String> _statusOptions = ['Active', 'in active'];
  String _searchText = '';
  int? _selectedIndex;

  // loading & error similar to CoursesPage
  bool _isLoading = false;
  String? _loadError;

  List<Department> get _filteredDepartments => _departments
      .where(
        (dept) =>
            dept.code.toLowerCase().contains(_searchText.toLowerCase()) ||
            dept.name.toLowerCase().contains(_searchText.toLowerCase()) ||
            _resolveHeadName(
              dept,
            ).toLowerCase().contains(_searchText.toLowerCase()) ||
            dept.status.toLowerCase().contains(_searchText.toLowerCase()),
      )
      .toList();

  // Map of teacher id -> teacher display name for showing head names instead of ids
  final Map<String, String> _teacherNamesById = {};

  String _resolveHeadName(Department dept) {
    final headIdOrName = dept.head;
    if (headIdOrName.isEmpty) return '';
    return _teacherNamesById[headIdOrName] ?? headIdOrName;
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
      try {
        // UI-side validation: ensure selected teacher isn't already head elsewhere
        if (result.head.isNotEmpty) {
          final existing =
              await _departmentsService.findDepartmentByHead(result.head);
          if (existing != null) {
            // inform the user and abort the add
            if (mounted) {
              await showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Teacher already assigned'),
                  content: Text(
                      'Selected teacher is already head of department "${existing.name}" (code: ${existing.code}). Please choose another teacher.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            }
            return;
          }
        }

        await _departmentsService.addDepartment(result);
        await _loadDepartments();
        setState(() => _selectedIndex = null);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to add department: $e')),
          );
        }
      }
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
      try {
        // UI-side validation: if head changed, ensure not assigned to another department
        if (result.head.isNotEmpty) {
          final existing =
              await _departmentsService.findDepartmentByHead(result.head);
          if (existing != null && existing.code != dept.code) {
            if (mounted) {
              await showDialog<void>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Teacher already assigned'),
                  content: Text(
                      'Selected teacher is already head of department "${existing.name}" (code: ${existing.code}). Please choose another teacher.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );
            }
            return;
          }
        }

        await _departmentsService.updateDepartment(dept.code, result);
        await _loadDepartments();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update department: $e')),
          );
        }
      }
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
      try {
        await _departmentsService.deleteDepartment(dept.code);
        await _loadDepartments();
        setState(() => _selectedIndex = null);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete department: $e')),
          );
        }
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadTeachers();
    _loadDepartments();
  }

  Future<void> _loadTeachers() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }
    try {
      final list = await _teachersService.fetchTeachers();
      if (mounted) {
        setState(() {
          _teacherNamesById.clear();
          for (final t in list) {
            _teacherNamesById[t.id] = t.teacherName ?? t.username ?? t.id;
          }
        });
      }
    } catch (e, st) {
      debugPrint('Failed to load teachers: $e\n$st');
      if (mounted) {
        setState(() {
          _loadError = e.toString();
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load teachers: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleDepartmentStatus(Department dept) async {
    final originalStatus = dept.status;
    final newStatus = originalStatus.toLowerCase() == 'active'
        ? 'in active'
        : 'Active';

    // optimistic update in local list
    setState(() {
      final idx = _departments.indexWhere((d) => d.code == dept.code);
      if (idx != -1) {
        _departments[idx] = _departments[idx].copyWith(status: newStatus);
      }
    });

    try {
      await _departmentsService.updateDepartment(
        dept.code,
        dept.copyWith(status: newStatus),
      );
    } catch (e) {
      // revert on error
      if (mounted) {
        setState(() {
          final idx = _departments.indexWhere((d) => d.code == dept.code);
          if (idx != -1) {
            _departments[idx] = _departments[idx].copyWith(
              status: originalStatus,
            );
          }
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update status: $e')));
      }
    }
  }

  Future<void> _loadDepartments() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }
    try {
      final list = await _departmentsService.fetchDepartments();
      if (mounted) {
        setState(() {
          _departments
            ..clear()
            ..addAll(list);
        });
      }
    } catch (e, st) {
      debugPrint('Failed to load departments: $e\n$st');
      if (mounted) {
        setState(() {
          _loadError = e.toString();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load departments: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: LinearProgressIndicator(),
            ),
          if (_loadError != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'Failed to load departments: $_loadError',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                "Departments",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Reload from DB',
                icon: const Icon(Icons.refresh),
                onPressed: _isLoading
                    ? null
                    : () async {
                        debugPrint('Manual reload requested');
                        await _loadTeachers();
                        await _loadDepartments();
                      },
              ),
            ],
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
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () {
                setState(() {
                  _selectedIndex = null;
                });
              },
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
                _resolveHeadName(_filteredDepartments[index]),
                onTap: () => _handleRowTap(index),
              ),
              _tableBodyWidget(
                _statusIndicator(_filteredDepartments[index]),
                onTap: () =>
                    _toggleDepartmentStatus(_filteredDepartments[index]),
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
                _resolveHeadName(_filteredDepartments[index]),
                onTap: () => _handleRowTap(index),
              ),
              _tableBodyWidget(
                _statusIndicator(_filteredDepartments[index]),
                onTap: () =>
                    _toggleDepartmentStatus(_filteredDepartments[index]),
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

  // Renders a generic widget inside the same padded cell used by _tableBodyCell
  Widget _tableBodyWidget(Widget child, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: child,
      ),
    );
  }

  // Non-interactive status indicator: green pill for Active, red for in active
  Widget _statusIndicator(Department dept) {
    final isActive = dept.status.toLowerCase() == 'active';

    return Align(
      alignment: Alignment.centerLeft,
      child: Transform.scale(
        scale: 0.85,
        child: Switch(
          value: isActive,
          onChanged: (value) => _toggleDepartmentStatus(dept),
          activeColor: Colors.white,
          activeTrackColor: Colors.green,
          inactiveThumbColor: Colors.white,
          inactiveTrackColor: Colors.red,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}