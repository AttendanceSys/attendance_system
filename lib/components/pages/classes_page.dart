import 'package:flutter/material.dart';
import '../../models/classes.dart';
import '../../models/department.dart';
import '../../hooks/use_classes.dart';
import '../../hooks/use_departments.dart';
import '../popup/add_class_popup.dart';
import '../cards/searchBar.dart';

class ClassesPage extends StatefulWidget {
  const ClassesPage({super.key});

  @override
  State<ClassesPage> createState() => _ClassesPageState();
}

class _ClassesPageState extends State<ClassesPage> {
  final List<SchoolClass> _classes = [];
  final UseClasses _classesService = UseClasses();
  final UseDepartments _departmentsService = UseDepartments();
  List<Department> _departments = [];

  final List<String> departments = ['CS', 'MATH', 'GEO', 'BIO', 'CHEM'];
  final List<String> sections = ['A', 'B', 'C', 'D', ''];

  String _searchText = '';
  int? _selectedIndex;

  // Loading & error to match CoursesPage/DepartmentsPage
  bool _isLoading = false;
  String? _loadError;

  List<SchoolClass> get _filteredClasses => _classes.where((cls) {
        final deptName = _getDepartmentName(cls.department).toLowerCase();
        return cls.name.toLowerCase().contains(_searchText.toLowerCase()) ||
            deptName.contains(_searchText.toLowerCase());
      }).toList();

  Future<void> _showAddClassPopup() async {
    final result = await showDialog<SchoolClass>(
      context: context,
      builder: (context) => AddClassPopup(
        departments: _departments.isNotEmpty
            ? _departments.map((d) => d).toList()
            : departments
                .map(
                  (c) => Department(
                    id: '',
                    code: c,
                    name: c,
                    head: '',
                    status: '',
                  ),
                )
                .toList(),
        sections: sections,
      ),
    );
    if (result != null) {
      try {
        await _classesService.addClass(result);
        await _loadClasses();
        setState(() => _selectedIndex = null);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to add class: $e')));
        }
      }
    }
  }

  String _getDepartmentName(String dept) {
    if (_departments.isEmpty) return dept;
    try {
      final found = _departments.firstWhere(
        (d) => d.id == dept || d.name == dept || d.code == dept,
      );
      return found.name;
    } catch (_) {
      return dept;
    }
  }

  Future<void> _showEditClassPopup() async {
    if (_selectedIndex == null) return;
    final schoolClass = _filteredClasses[_selectedIndex!];
    final result = await showDialog<SchoolClass>(
      context: context,
      builder: (context) => AddClassPopup(
        schoolClass: schoolClass,
        departments: _departments.isNotEmpty
            ? _departments
            : departments
                .map(
                  (c) => Department(
                    id: '',
                    code: c,
                    name: c,
                    head: '',
                    status: '',
                  ),
                )
                .toList(),
        sections: sections,
      ),
    );
    if (result != null) {
      try {
        await _classesService.updateClass(schoolClass.name, result);
        await _loadClasses();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to update class: $e')));
        }
      }
    }
  }

  Future<void> _confirmDeleteClass() async {
    if (_selectedIndex == null) return;
    final schoolClass = _filteredClasses[_selectedIndex!];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Class"),
        content: Text("Are you sure you want to delete '${schoolClass.name}'?"),
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
        await _classesService.deleteClass(schoolClass.name);
        await _loadClasses();
        setState(() => _selectedIndex = null);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Failed to delete class: $e')));
        }
      }
    }
  }

  void _handleRowTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  // Determine active state defensively (in case model uses bool or string)
  bool _getIsActive(SchoolClass cls) {
    try {
      final dyn = cls as dynamic;
      final val = dyn.isActive;
      if (val is bool) return val;
    } catch (_) {}
    try {
      final dyn = cls as dynamic;
      final status = dyn.status;
      if (status is String) return status.toLowerCase() == 'active';
    } catch (_) {}
    return false;
  }

  Future<void> _toggleActive(int filteredIndex, bool value) async {
    // Use the filtered index (matching how DepartmentsPage toggles by passing the model)
    final SchoolClass selected = _filteredClasses[filteredIndex];
    final int mainIndex = _classes.indexOf(selected);
    if (mainIndex == -1) return;

    final bool previous = _getIsActive(_classes[mainIndex]);

    // Optimistic UI update: set the boolean field if available, else try to update status string
    setState(() {
      try {
        (_classes[mainIndex] as dynamic).isActive = value;
      } catch (_) {
        try {
          (_classes[mainIndex] as dynamic).status =
              value ? 'Active' : 'in active';
        } catch (_) {}
      }
    });

    try {
      // Build an updated instance to send to backend if possible
      SchoolClass updated;
      try {
        updated = ( _classes[mainIndex] as dynamic ).copyWith(isActive: value) as SchoolClass;
      } catch (_) {
        // fallback construct
        updated = SchoolClass(
          id: (_classes[mainIndex] as dynamic).id ?? '',
          name: (_classes[mainIndex] as dynamic).name ?? '',
          department: (_classes[mainIndex] as dynamic).department ?? '',
          section: (_classes[mainIndex] as dynamic).section ?? '',
          isActive: value,
        );
      }

      await _classesService.updateClass(_classes[mainIndex].name, updated);

      // refresh authoritative state
      await _loadClasses();
    } catch (e) {
      if (mounted) {
        // rollback
        setState(() {
          try {
            (_classes[mainIndex] as dynamic).isActive = previous;
          } catch (_) {
            try {
              (_classes[mainIndex] as dynamic).status =
                  previous ? 'Active' : 'in active';
            } catch (_) {}
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update class status: $e')),
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadClasses();
    _loadDepartments();
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
        setState(() => _departments = list);
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
                'Failed to load classes: $_loadError',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                "Classes",
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
                        await _loadClasses();
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
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 0,
                                horizontal: 0,
                              ),
                            ),
                            onPressed:
                                _selectedIndex == null ? null : _showEditClassPopup,
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
                            onPressed:
                                _selectedIndex == null ? null : _confirmDeleteClass,
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

  Future<void> _loadClasses() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _loadError = null;
      });
    }
    try {
      final list = await _classesService.fetchClasses();
      if (mounted)
        setState(() {
          _classes
            ..clear()
            ..addAll(list);
        });
    } catch (e, st) {
      debugPrint('Failed to load classes: $e\n$st');
      if (mounted) {
        setState(() {
          _loadError = e.toString();
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load classes: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildDesktopTable() {
    return Table(
      columnWidths: const {
        0: FixedColumnWidth(64), // No
        1: FixedColumnWidth(140), // Class name
        2: FixedColumnWidth(120), // Department
        3: FixedColumnWidth(120), // Status
      },
      border: TableBorder(
        horizontalInside: BorderSide(color: Colors.grey.shade300),
      ),
      children: [
        TableRow(
          children: [
            _tableHeaderCell("No"),
            _tableHeaderCell("Class name"),
            _tableHeaderCell("Department"),
            _tableHeaderCell("Status"),
          ],
        ),
        for (int index = 0; index < _filteredClasses.length; index++)
          TableRow(
            decoration: BoxDecoration(
              color: _selectedIndex == index
                  ? Colors.blue.shade50
                  : Colors.transparent,
            ),
            children: [
              _tableBodyCell('${index + 1}', onTap: () => _handleRowTap(index)),
              _tableBodyCell(
                _filteredClasses[index].name,
                onTap: () => _handleRowTap(index),
              ),
              _tableBodyCell(
                _getDepartmentName(_filteredClasses[index].department),
                onTap: () => _handleRowTap(index),
              ),
              _tableBodyWidget(
                _statusIndicator(index),
                onTap: () => _toggleActive(index, !_getIsActive(_filteredClasses[index])),
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
            _tableHeaderCell("Class name"),
            _tableHeaderCell("Department"),
            _tableHeaderCell("Status"),
          ],
        ),
        for (int index = 0; index < _filteredClasses.length; index++)
          TableRow(
            decoration: BoxDecoration(
              color: _selectedIndex == index
                  ? Colors.blue.shade50
                  : Colors.transparent,
            ),
            children: [
              _tableBodyCell('${index + 1}', onTap: () => _handleRowTap(index)),
              _tableBodyCell(
                _filteredClasses[index].name,
                onTap: () => _handleRowTap(index),
              ),
              _tableBodyCell(
                _getDepartmentName(_filteredClasses[index].department),
                onTap: () => _handleRowTap(index),
              ),
              _tableBodyWidget(
                _statusIndicator(index),
                onTap: () => _toggleActive(index, !_getIsActive(_filteredClasses[index])),
              ),
            ],
          ),
      ],
    );
  }

  Widget _statusIndicator(int filteredIndex) {
    final cls = _filteredClasses[filteredIndex];
    final isActive = _getIsActive(cls);

    return Align(
      alignment: Alignment.centerLeft,
      child: Transform.scale(
        scale: 0.85,
        child: Switch(
          value: isActive,
          onChanged: (value) => _toggleActive(filteredIndex, value),
          activeColor: Colors.white,
          activeTrackColor: Colors.green,
          inactiveThumbColor: Colors.white,
          inactiveTrackColor: Colors.red,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
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
}