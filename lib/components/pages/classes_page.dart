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

  // Departments are loaded from the backend into `_departments`.
  // Don't fall back to a hard-coded list when the DB returns no rows —
  // passing an empty list will make the UI show an empty dropdown instead
  // of phantom default departments.
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
    debugPrint(
      '[showAddClassPopup] current _departments length=${_departments.length}',
    );
    if (_departments.isEmpty) {
      // Attempt an on-demand reload in case auth or backend wasn't ready
      // when the page first loaded. This avoids a poor UX where the Add
      // dialog is blocked even though data will soon be available.
      await _loadDepartments();
      if (_departments.isEmpty) {
        // Friendly UX: prevent opening Add Class when no departments exist for this faculty
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No departments available for your faculty. Please add a department first.',
              ),
            ),
          );
        }
        return;
      }
    }
    try {
      debugPrint(
        '[showAddClassPopup] sample departments: ${_departments.take(5).map((d) => d.name).toList()}',
      );
    } catch (_) {}

    final result = await showDialog<SchoolClass>(
      context: context,
      builder: (context) =>
          AddClassPopup(departments: _departments, sections: sections),
    );
    if (result != null) {
      try {
        // Prefer resolving faculty id from the departments service (which
        // already resolved/cached it during department fetch) and pass it to
        // addClass to avoid timing issues where UseClasses' resolver may
        // return null if auth state changed between calls.
        String? facultyId;
        try {
          facultyId = await _departmentsService.resolveAdminFacultyId();
        } catch (_) {}
        await _classesService.addClass(result, facultyId: facultyId);
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
      // First try a direct match by id, name or code
      final found = _departments.firstWhere(
        (d) => d.id == dept || d.name == dept || d.code == dept,
      );
      return found.name;
    } catch (_) {
      // If the stored value is a Map-like string (e.g. "{id: ...}") or
      // a JSON-like blob, attempt to extract a UUID or department_name
      // and resolve from the cached departments list.
      try {
        // Try to extract a UUID (Postgres UUID format)
        final uuidRegex = RegExp(
          r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
        );
        final uuidMatch = uuidRegex.firstMatch(dept);
        if (uuidMatch != null) {
          final id = uuidMatch.group(0) ?? '';
          try {
            final byId = _departments.firstWhere((d) => d.id == id);
            return byId.name;
          } catch (_) {}
        }

        // Try to extract a department_name like pattern: department_name: Foo
        if (dept.toLowerCase().contains('department_name')) {
          try {
            final key = 'department_name';
            final lower = dept.toLowerCase();
            final idx = lower.indexOf(key);
            if (idx != -1) {
              var after = dept.substring(idx + key.length);
              // find separator ':' or '='
              final sepIdx = after.indexOf(':');
              final altIdx = after.indexOf('=');
              int sep = sepIdx >= 0 ? sepIdx : (altIdx >= 0 ? altIdx : -1);
              if (sep >= 0 && sep + 1 < after.length) {
                var rest = after.substring(sep + 1).trim();
                if (rest.startsWith('"') || rest.startsWith('\'')) {
                  rest = rest.substring(1);
                }
                var endIdx = rest.indexOf(',');
                if (endIdx == -1) endIdx = rest.indexOf('}');
                if (endIdx == -1) endIdx = rest.length;
                final name = rest.substring(0, endIdx).trim();
                if (name.isNotEmpty) {
                  try {
                    final byName = _departments.firstWhere(
                      (d) => d.name == name,
                    );
                    return byName.name;
                  } catch (_) {}
                }
              }
            }
          } catch (_) {}
        }
      } catch (_) {}
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
        departments: _departments,
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
          (_classes[mainIndex] as dynamic).status = value
              ? 'Active'
              : 'in active';
        } catch (_) {}
      }
    });

    try {
      // Build an updated instance to send to backend if possible
      SchoolClass updated;
      try {
        updated =
            (_classes[mainIndex] as dynamic).copyWith(isActive: value)
                as SchoolClass;
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
              (_classes[mainIndex] as dynamic).status = previous
                  ? 'Active'
                  : 'in active';
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
    try {
      // First attempt: try to fetch normally (prefers resolving faculty via auth)
      List<Department> list = await _departmentsService.fetchDepartments();
      debugPrint(
        '[ClassesPage._loadDepartments] fetched ${list.length} departments',
      );
      try {
        debugPrint(
          '[ClassesPage._loadDepartments] sample: ${list.take(5).map((d) => d.name).toList()}',
        );
      } catch (_) {}

      // If empty, retry a few times with short delays in case auth/backend
      // become available shortly after page init (common on web hot-reload).
      if (list.isEmpty) {
        const int retryAttempts = 4;
        const Duration retryDelay = Duration(milliseconds: 350);
        for (int attempt = 1; attempt <= retryAttempts; attempt++) {
          if (!mounted) break;
          await Future.delayed(retryDelay);
          try {
            final tryList = await _departmentsService.fetchDepartments();
            debugPrint(
              '[ClassesPage._loadDepartments] retry $attempt fetched ${tryList.length} depts',
            );
            list = tryList;
            try {
              debugPrint(
                '[ClassesPage._loadDepartments] retry $attempt sample: ${tryList.take(5).map((d) => d.name).toList()}',
              );
            } catch (_) {}
            if (list.isNotEmpty) break;
          } catch (e) {
            debugPrint(
              '[ClassesPage._loadDepartments] retry $attempt failed: $e',
            );
          }
        }
      }

      // If still empty, attempt the explicit resolve+fetch path as a last resort.
      List<Department> finalList = list;
      if (finalList.isEmpty) {
        try {
          final resolved = await _departmentsService.resolveAdminFacultyId();
          debugPrint(
            '[ClassesPage._loadDepartments] resolved facultyId=$resolved',
          );
          if (resolved != null && resolved.isNotEmpty) {
            final retry = await _departmentsService.fetchDepartments(
              facultyId: resolved,
            );
            debugPrint(
              '[ClassesPage._loadDepartments] retry fetched ${retry.length} depts',
            );
            finalList = retry;
            try {
              debugPrint(
                '[ClassesPage._loadDepartments] retry sample: ${retry.take(5).map((d) => d.name).toList()}',
              );
            } catch (_) {}
          }
        } catch (e) {
          debugPrint('[ClassesPage._loadDepartments] resolve/retry failed: $e');
        }
      }

      if (mounted) {
        setState(() => _departments = finalList);
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
                      // Disable Add while loading or when no departments are available
                      onAddPressed: (!_isLoading && _departments.isNotEmpty)
                          ? () => _showAddClassPopup()
                          : null,
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
      // Try a normal fetch first (UseClasses will try to resolve faculty id).
      List<SchoolClass> list = await _classesService.fetchClasses();

      // If no classes returned, it's likely a race where auth wasn't ready
      // when UseClasses tried to resolve the admin's faculty id. Try a
      // fallback: resolve faculty id from the departments service (which
      // we've already used successfully) and retry the classes fetch with
      // an explicit facultyId.
      if (list.isEmpty) {
        try {
          final resolved = await _departmentsService.resolveAdminFacultyId();
          debugPrint('[ClassesPage._loadClasses] resolved facultyId=$resolved');
          if (resolved != null && resolved.isNotEmpty) {
            final retry = await _classesService.fetchClasses(
              facultyId: resolved,
            );
            debugPrint(
              '[ClassesPage._loadClasses] retry fetched ${retry.length} classes',
            );
            list = retry;
          }
        } catch (e) {
          debugPrint('[ClassesPage._loadClasses] resolve/retry failed: $e');
        }
      }

      if (mounted) {
        setState(() {
          _classes
            ..clear()
            ..addAll(list);
        });
      }
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
                onTap: () => _toggleActive(
                  index,
                  !_getIsActive(_filteredClasses[index]),
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
                onTap: () => _toggleActive(
                  index,
                  !_getIsActive(_filteredClasses[index]),
                ),
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
