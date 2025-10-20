import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import 'create_timetable_dialog.dart';

class TimetableSlot {
  final String day;
  final String periodLabel;
  final String course;
  final String className;
  final String department;
  final String lecturer;
  final String section;

  TimetableSlot({
    required this.day,
    required this.periodLabel,
    required this.course,
    required this.className,
    required this.department,
    required this.lecturer,
    required this.section,
  });
}

/// Result returned by TimetableCellEditDialog (nullable cellText when clearing)
class TimetableCellEditResult {
  final String? cellText;
  TimetableCellEditResult({this.cellText});
}

class TimetablePage extends StatefulWidget {
  const TimetablePage({super.key});

  @override
  State<TimetablePage> createState() => _TimetablePageState();
}

class _TimetablePageState extends State<TimetablePage> {
  String searchText = '';

  String? selectedDepartment;
  String? selectedClass;
  String? selectedLecturer;
  String? selectedSection;

  bool editingEnabled = false;

  _UndoState? _lastUndo;

  final List<String> departments = ["CS", "GEO", "Math"];
  final Map<String, List<String>> departmentClasses = {
    "CS": ["B2CS", "B3SC", "B4CS"],
    "GEO": ["B2GEO", "B3GEO"],
    "Math": ["B1MATH", "B2MATH"],
  };
  final List<String> lecturers = [
    "Dr. Mohamed Isaaq",
    "Prof. Abdullahi Sharif",
    "Prof. Fuad Mire",
    "Dr. Adam",
    "Eng M. A. Khalifa",
    "NONE",
  ];
  final List<String> coursesMock = const [
    'Math',
    'E-Commerce',
    'Data Science and Analytics',
    'Network Security',
    'Computer Ethics',
    'Selected Topics in Comp Scien.',
  ];
  final List<String> sections = ["A", "B", "C", "None"];

  final List<String> seedPeriods = const [
    "7:30 - 9:20",
    "9:20 - 11:10",
    "11:10 - 11:40 (Break)",
    "11:40 - 1:30",
  ];

  final Map<String, Map<String, Map<String, List<List<String>>>>>
  timetableData = {
    "CS": {
      "B3SC": {
        "A": [
          ["", "", "Break", ""],
          [
            "E-Commerce\nDr. Mohamed Isaaq",
            "Selected Topics in Comp Scien.\nProf. Abdullahi Sharif",
            "Break",
            "Data Science and Analytics\nProf. Fuad Mire",
          ],
          [
            "Network Security\nDr. Adam",
            "Computer Ethics\nEng M. A. Khalifa",
            "Break",
            "E-Commerce\nDr. Mohamed Isaaq",
          ],
          [
            "Network Security\nDr. Adam",
            "Computer Ethics\nEng M. A. Khalifa",
            "Break",
            "Data Science and Analytics\nProf. Fuad Mire",
          ],
          [
            "Data Science and Analytics\nProf. Fuad Mire",
            "Selected Topics in Comp Scien.\nProf. Abdullahi Sharif",
            "Break",
            "",
          ],
          ["", "Network Security\nDr. Adam", "Break", ""],
        ],
      },
      "B3CS": {
        "A": [
          ["", "", "Break", ""],
          [
            "E-Commerce\nDr. Mohamed Isaaq",
            "Selected Topics in Comp Scien.\nProf. Abdullahi Sharif",
            "Break",
            "Data Science and Analytics\nProf. Fuad Mire",
          ],
          [
            "Network Security\nDr. Adam",
            "Computer Ethics\nEng M. A. Khalifa",
            "Break",
            "E-Commerce\nDr. Mohamed Isaaq",
          ],
          [
            "Network Security\nDr. Adam",
            "Computer Ethics\nEng M. A. Khalifa",
            "Break",
            "Data Science and Analytics\nProf. Fuad Mire",
          ],
          [
            "Data Science and Analytics\nProf. Fuad Mire",
            "Selected Topics in Comp Scien.\nProf. Abdullahi Sharif",
            "Break",
            "",
          ],
          ["", "Network Security\nDr. Adam", "Break", ""],
        ],
      },
    },
  };

  final Map<String, Map<String, List<String>>> classPeriods = {};

  List<String> get days => ["Sat", "Sun", "Mon", "Tue", "Wed", "Thu"];

  @override
  void initState() {
    super.initState();
    _seedClassPeriodsFromExistingData();
  }

  void _seedClassPeriodsFromExistingData() {
    for (final dep in timetableData.keys) {
      classPeriods.putIfAbsent(dep, () => {});
      final classesMap = timetableData[dep]!;
      for (final cls in classesMap.keys) {
        classPeriods[dep]!.putIfAbsent(
          cls,
          () => List<String>.from(seedPeriods, growable: true),
        );
        for (final sect in classesMap[cls]!.keys) {
          final grid = classesMap[cls]![sect]!;
          for (int r = 0; r < grid.length; r++) {
            grid[r] = List<String>.from(grid[r], growable: true);
          }
          final labelsLen = classPeriods[dep]![cls]!.length;
          for (int r = 0; r < grid.length; r++) {
            if (grid[r].length < labelsLen) {
              grid[r].addAll(
                List<String>.filled(
                  labelsLen - grid[r].length,
                  "",
                  growable: true,
                ),
              );
            }
          }
        }
      }
    }
  }

  String? _findKeyIgnoreCase(Map map, String? key) {
    if (key == null) return null;
    final lower = key.toString().toLowerCase().trim();
    for (final k in map.keys) {
      if (k.toString().toLowerCase().trim() == lower) return k.toString();
    }
    return null;
  }

  List<String> get classesForSelectedDepartment {
    if (selectedDepartment == null) return [];
    final depKey = _findKeyIgnoreCase(departmentClasses, selectedDepartment);
    if (depKey == null) return [];
    return departmentClasses[depKey] ?? [];
  }

  List<String> get currentPeriods {
    final depKey =
        _findKeyIgnoreCase(timetableData, selectedDepartment) ??
        selectedDepartment;
    final clsKey = selectedClass;
    if (depKey == null || clsKey == null) return seedPeriods;
    classPeriods.putIfAbsent(depKey, () => {});
    classPeriods[depKey]!.putIfAbsent(
      clsKey,
      () => List<String>.from(seedPeriods, growable: true),
    );
    classPeriods[depKey]![clsKey] = List<String>.from(
      classPeriods[depKey]![clsKey]!,
      growable: true,
    );
    return classPeriods[depKey]![clsKey]!;
  }

  List<List<String>>? get currentTimetable {
    final depKey = _findKeyIgnoreCase(timetableData, selectedDepartment);
    if (depKey == null) return null;
    final classesMap = timetableData[depKey]!;
    final classKey = _findKeyIgnoreCase(classesMap, selectedClass);
    if (classKey == null) return null;
    final sectionsMap = classesMap[classKey]!;
    final sectionKey = _findKeyIgnoreCase(sectionsMap, selectedSection);
    if (sectionKey == null) return null;
    return sectionsMap[sectionKey];
  }

  List<TimetableSlot> _slotsFromGrid(
    List<List<String>> grid,
    List<String> periodsForClass,
  ) {
    final List<TimetableSlot> slots = [];
    for (var d = 0; d < days.length; d++) {
      final row = d < grid.length
          ? grid[d]
          : List<String>.filled(periodsForClass.length, "", growable: true);
      for (var p = 0; p < periodsForClass.length; p++) {
        final cell = (p < row.length) ? row[p].trim() : '';
        if (cell.isEmpty) continue;
        if (cell.toLowerCase().contains('break')) continue;
        final parts = cell.split('\n');
        final course = parts.isNotEmpty ? parts[0] : '';
        final lecturer = parts.length > 1
            ? parts.sublist(1).join(' ').trim()
            : '';
        slots.add(
          TimetableSlot(
            day: days[d],
            periodLabel: periodsForClass[p],
            course: course,
            className: selectedClass ?? '',
            department: selectedDepartment ?? '',
            lecturer: lecturer,
            section: selectedSection ?? '',
          ),
        );
      }
    }
    return slots;
  }

  List<TimetableSlot> getFilteredSlotsFromGrid() {
    final grid = currentTimetable;
    if (grid == null) return [];
    final periodsForClass = currentPeriods;
    var list = _slotsFromGrid(grid, periodsForClass);

    if (selectedLecturer != null &&
        selectedLecturer!.trim().isNotEmpty &&
        selectedLecturer != 'NONE' &&
        selectedLecturer != 'All lecturers') {
      final key = selectedLecturer!.toLowerCase().trim();
      list = list.where((s) => s.lecturer.toLowerCase().contains(key)).toList();
    }
    if (searchText.trim().isNotEmpty) {
      final q = searchText.toLowerCase().trim();
      list = list.where((s) {
        return s.course.toLowerCase().contains(q) ||
            s.lecturer.toLowerCase().contains(q) ||
            s.className.toLowerCase().contains(q) ||
            s.department.toLowerCase().contains(q) ||
            s.day.toLowerCase().contains(q) ||
            s.periodLabel.toLowerCase().contains(q);
      }).toList();
    }
    final daysOrder = ['Sat', 'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
    list.sort((a, b) {
      final ai = daysOrder.indexOf(a.day);
      final bi = daysOrder.indexOf(b.day);
      if (ai != bi) return ai.compareTo(bi);
      final pi = periodsForClass.indexOf(a.periodLabel);
      final pj = periodsForClass.indexOf(b.periodLabel);
      return pi.compareTo(pj);
    });
    return list;
  }

  void copySlotsToClipboard(List<TimetableSlot> slots) {}

  String _fmtMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '$h:${m.toString().padLeft(2, '0')}';
  }

  String _makeLabel(int startMin, int endMin, {bool isBreak = false}) {
    final label = '${_fmtMinutes(startMin)} - ${_fmtMinutes(endMin)}';
    return isBreak ? '$label (Break)' : label;
  }

  int? _parseStartFromLabel(String label) {
    final m = RegExp(
      r'^\s*(\d{1,2}):([0-5]\d)\s*-\s*(\d{1,2}):([0-5]\d)(?:\s*\(.*?\))?\s*$',
    ).firstMatch(label);
    if (m == null) return null;
    final h = int.parse(m.group(1)!);
    final mm = int.parse(m.group(2)!);
    return h * 60 + mm;
  }

  MapEntry<String, String> _ensureDepClass(String dep, String cls) {
    final depKey = _findKeyIgnoreCase(timetableData, dep) ?? dep;
    timetableData.putIfAbsent(depKey, () => {});
    classPeriods.putIfAbsent(depKey, () => {});
    final classesMap = timetableData[depKey]!;
    final classKey = _findKeyIgnoreCase(classesMap, cls) ?? cls;
    classesMap.putIfAbsent(classKey, () => {});
    classPeriods[depKey]!.putIfAbsent(
      classKey,
      () => List<String>.from(seedPeriods, growable: true),
    );
    classPeriods[depKey]![classKey] = List<String>.from(
      classPeriods[depKey]![classKey]!,
      growable: true,
    );
    return MapEntry(depKey, classKey);
  }

  void _ensureSectionGrid(String depKey, String classKey, String section) {
    final sectionsMap = timetableData[depKey]![classKey]!;
    final sectionKey = _findKeyIgnoreCase(sectionsMap, section) ?? section;
    final labels = classPeriods[depKey]![classKey]!;
    final labelsLen = labels.length;

    sectionsMap.putIfAbsent(
      sectionKey,
      () => List<List<String>>.generate(
        days.length,
        (_) => List<String>.filled(labelsLen, "", growable: true),
        growable: true,
      ),
    );

    final grid = sectionsMap[sectionKey]!;
    if (grid.length < days.length) {
      grid.addAll(
        List.generate(
          days.length - grid.length,
          (_) => List<String>.filled(labelsLen, "", growable: true),
        ),
      );
    }
    for (int r = 0; r < days.length; r++) {
      if (r >= grid.length) {
        grid.add(List<String>.filled(labelsLen, "", growable: true));
      }
      grid[r] = List<String>.from(grid[r], growable: true);
      if (grid[r].length < labelsLen) {
        grid[r].addAll(
          List<String>.filled(labelsLen - grid[r].length, "", growable: true),
        );
      }
    }
  }

  void _replaceClassPeriods(
    String depKey,
    String classKey,
    List<String> newLabels,
  ) {
    final oldLabels = classPeriods[depKey]![classKey]!;
    final newGrow = List<String>.from(newLabels, growable: true);
    classPeriods[depKey]![classKey] = newGrow;

    final sectionsMap = timetableData[depKey]![classKey]!;
    for (final sectKey in sectionsMap.keys) {
      final oldGrid = sectionsMap[sectKey]!;
      final newGrid = List<List<String>>.generate(
        days.length,
        (_) => List<String>.filled(newGrow.length, "", growable: true),
        growable: true,
      );
      for (int oldIdx = 0; oldIdx < oldLabels.length; oldIdx++) {
        final label = oldLabels[oldIdx];
        final newIdx = newGrow.indexWhere(
          (l) => l.trim().toLowerCase() == label.trim().toLowerCase(),
        );
        if (newIdx >= 0) {
          for (int r = 0; r < days.length; r++) {
            final row = (r < oldGrid.length)
                ? oldGrid[r]
                : List<String>.filled(oldLabels.length, "", growable: true);
            final val = (oldIdx < row.length) ? row[oldIdx] : '';
            newGrid[r][newIdx] = val;
          }
        }
      }
      sectionsMap[sectKey] = newGrid;
    }
  }

  int _findOrInsertPeriodIndexForClass({
    required String depKey,
    required String classKey,
    required String newLabel,
  }) {
    classPeriods[depKey]![classKey] = List<String>.from(
      classPeriods[depKey]![classKey]!,
      growable: true,
    );
    final labels = classPeriods[depKey]![classKey]!;
    final newStart = _parseStartFromLabel(newLabel) ?? 0;

    final existing = labels.indexWhere(
      (l) => l.trim().toLowerCase() == newLabel.trim().toLowerCase(),
    );
    if (existing >= 0) return existing;

    int insertAt = labels.length;
    for (int i = 0; i < labels.length; i++) {
      final s = _parseStartFromLabel(labels[i]) ?? 0;
      if (newStart < s) {
        insertAt = i;
        break;
      }
    }
    labels.insert(insertAt, newLabel);

    final sectionsMap = timetableData[depKey]![classKey]!;
    for (final sectKey in sectionsMap.keys) {
      final grid = sectionsMap[sectKey]!;
      if (grid.length < days.length) {
        grid.addAll(
          List.generate(
            days.length - grid.length,
            (_) => List<String>.filled(labels.length, "", growable: true),
          ),
        );
      }
      for (int r = 0; r < days.length; r++) {
        grid[r] = List<String>.from(grid[r], growable: true);
        grid[r].insert(insertAt, "");
      }
    }
    return insertAt;
  }

  Future<void> _openEditCellDialog({
    required int dayIndex,
    required int periodIndex,
  }) async {
    if (!editingEnabled) return;
    final timetable = currentTimetable;
    if (timetable == null) return;
    if (periodIndex < 0 || periodIndex >= currentPeriods.length) return;

    final periodLabel = currentPeriods[periodIndex];
    if (periodLabel.toLowerCase().contains('break')) return;

    final depKey =
        _findKeyIgnoreCase(timetableData, selectedDepartment) ??
        selectedDepartment;
    final classKey = depKey == null
        ? null
        : _findKeyIgnoreCase(timetableData[depKey]!, selectedClass) ??
              selectedClass;
    final sectionKey = (depKey != null && classKey != null)
        ? _findKeyIgnoreCase(
                timetableData[depKey]![classKey]!,
                selectedSection,
              ) ??
              selectedSection
        : null;
    if (depKey == null || classKey == null || sectionKey == null) return;

    final grid = timetableData[depKey]![classKey]![sectionKey]!;
    final row = grid[dayIndex];
    final raw = periodIndex < row.length ? row[periodIndex] : '';
    String? initialCourse;
    String? initialLecturer;
    if (raw.trim().isNotEmpty && !raw.toLowerCase().contains('break')) {
      final parts = raw.split('\n');
      initialCourse = parts.isNotEmpty ? parts[0] : null;
      if (parts.length > 1) {
        initialLecturer = parts.sublist(1).join(' ').trim();
      }
    }

    final TimetableCellEditResult? result =
        await showDialog<TimetableCellEditResult>(
          context: context,
          builder: (_) => TimetableCellEditDialog(
            initialCourse: initialCourse,
            initialLecturer: initialLecturer,
            courses: coursesMock,
            lecturers: lecturers.where((l) => l != 'NONE').toList(),
          ),
        );
    if (result == null) return;

    setState(() {
      if (result.cellText == null) return;
      row[periodIndex] = result.cellText!.trim();
    });
  }

  Future<void> _showDeleteMenu() async {
    if (selectedDepartment == null || selectedClass == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select Department and Class first')),
      );
      return;
    }
    final depKey =
        _findKeyIgnoreCase(timetableData, selectedDepartment) ??
        selectedDepartment;
    final classKey = depKey == null
        ? null
        : _findKeyIgnoreCase(timetableData[depKey]!, selectedClass) ??
              selectedClass;
    if (depKey == null || classKey == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Timetable not found for class')),
      );
      return;
    }

    final sectionsMap = timetableData[depKey]![classKey]!;
    final sectionCount = sectionsMap.length;
    final periodsCount = classPeriods[depKey]![classKey]!.length;

    final action = await showDialog<_DeleteAction>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Timetable Data'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Class: $classKey  (Sections: $sectionCount, Period columns: $periodsCount)',
              ),
              const SizedBox(height: 12),
              if (selectedSection != null)
                Text('Current Section: $selectedSection'),
              const SizedBox(height: 12),
              const Text('Choose what you want to delete:'),
              const SizedBox(height: 8),
              _DeleteOptionTile(
                title: 'Delete This Section Timetable',
                subtitle:
                    'Clears all cells for section only. Period labels stay.',
                action: _DeleteAction.section,
              ),
              _DeleteOptionTile(
                title: 'Delete Entire Class Timetable',
                subtitle:
                    'Clears all sections for this class. Period labels stay.',
                action: _DeleteAction.classAll,
              ),
              _DeleteOptionTile(
                title: 'Delete Class Period Structure',
                subtitle:
                    'Removes all period labels & cells (all sections). Class resets to seed periods later.',
                action: _DeleteAction.classStructure,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (action == null) return;

    if (action == _DeleteAction.section &&
        (selectedSection == null || selectedSection!.trim().isEmpty)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select a Section first')));
      return;
    }

    // Build confirmation message based on chosen action
    String title = 'Confirm Deletion';
    String body;
    switch (action) {
      case _DeleteAction.section:
        body =
            'This will clear all cells for section "${selectedSection!}" of class "$classKey" in department "$depKey".\n\nPeriod labels will stay.\n\nDo you want to proceed?';
        break;
      case _DeleteAction.classAll:
        body =
            'This will clear all cells for ALL sections of class "$classKey" in department "$depKey".\n\nPeriod labels will stay.\n\nDo you want to proceed?';
        break;
      case _DeleteAction.classStructure:
        body =
            'This will remove ALL period labels and ALL cells for all sections of class "$classKey" in department "$depKey".\n\nDo you want to proceed?';
        break;
    }

    final confirmed = await _confirmDelete(
      title: title,
      content: body,
      confirmText: 'Delete',
    );
    if (!confirmed) return;

    // Backup for UNDO
    final backup = _UndoState(
      depKey: depKey,
      classKey: classKey!,
      sectionKey: selectedSection,
      classPeriodsCopy: Map<String, List<String>>.from(classPeriods[depKey]!),
      timetableCopy: _deepCopyTimetableClass(timetableData[depKey]![classKey]!),
      action: action,
    );

    setState(() {
      switch (action) {
        case _DeleteAction.section:
          final sectKey =
              _findKeyIgnoreCase(sectionsMap, selectedSection) ??
              selectedSection!;
          final grid = sectionsMap[sectKey]!;
          for (int r = 0; r < grid.length; r++) {
            for (int c = 0; c < grid[r].length; c++) {
              grid[r][c] = '';
            }
          }
          break;
        case _DeleteAction.classAll:
          for (final sectKey in sectionsMap.keys) {
            final grid = sectionsMap[sectKey]!;
            for (int r = 0; r < grid.length; r++) {
              for (int c = 0; c < grid[r].length; c++) {
                grid[r][c] = '';
              }
            }
          }
          break;
        case _DeleteAction.classStructure:
          classPeriods[depKey]![classKey] = [];
          for (final sectKey in sectionsMap.keys) {
            sectionsMap[sectKey] = List.generate(
              days.length,
              (_) => <String>[],
              growable: true,
            );
          }
          break;
      }
      _lastUndo = backup;
    });

    _showUndoBar();
  }

  Map<String, List<List<String>>> _deepCopyTimetableClass(
    Map<String, List<List<String>>> src,
  ) {
    final out = <String, List<List<String>>>{};
    src.forEach((k, v) {
      out[k] = v
          .map((row) => List<String>.from(row, growable: true))
          .toList(growable: true);
    });
    return out;
  }

  void _showUndoBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Timetable deleted'),
        action: SnackBarAction(
          label: 'UNDO',
          onPressed: () {
            if (_lastUndo == null) return;
            setState(() {
              final b = _lastUndo!;
              classPeriods[b.depKey]!.clear();
              b.classPeriodsCopy.forEach((k, v) {
                classPeriods[b.depKey]![k] = List<String>.from(
                  v,
                  growable: true,
                );
              });
              timetableData[b.depKey]![b.classKey]!.clear();
              b.timetableCopy.forEach((sect, grid) {
                timetableData[b.depKey]![b.classKey]![sect] = grid
                    .map((r) => List<String>.from(r, growable: true))
                    .toList();
              });
              _lastUndo = null;
            });
          },
        ),
        duration: const Duration(seconds: 7),
      ),
    );
  }

  Future<void> _exportPdfFlow() async {
    if (selectedDepartment == null || selectedClass == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select Department and Class first')),
      );
      return;
    }

    final choice = await showDialog<_ExportChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export PDF'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ExportOptionTile(
              title: 'Current Section',
              subtitle:
                  'Export only the timetable for the selected section (${selectedSection ?? 'None selected'})',
              choice: _ExportChoice.currentSection,
            ),
            _ExportOptionTile(
              title: 'Entire Class (All Sections)',
              subtitle: 'Include all sections for this class in one PDF',
              choice: _ExportChoice.entireClass,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (choice == null) return;

    if (choice == _ExportChoice.currentSection && selectedSection == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select a Section first to export current section'),
        ),
      );
      return;
    }

    await _generatePdf(choice);
  }

  Future<void> _generatePdf(_ExportChoice choice) async {
    final depKey =
        _findKeyIgnoreCase(timetableData, selectedDepartment) ??
        selectedDepartment;
    final classKey = depKey == null
        ? null
        : _findKeyIgnoreCase(timetableData[depKey]!, selectedClass) ??
              selectedClass;
    if (depKey == null || classKey == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Class not found')));
      return;
    }

    final pdf = pw.Document();
    final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    final periods = (classPeriods[depKey]?[classKey] ?? <String>[]);
    final sectionsMap = timetableData[depKey]![classKey]!;

    if (choice == _ExportChoice.currentSection) {
      final sectKey =
          _findKeyIgnoreCase(sectionsMap, selectedSection) ?? selectedSection!;
      final grid = sectionsMap[sectKey];

      pdf.addPage(
        pw.MultiPage(
          pageTheme: pw.PageTheme(
            margin: const pw.EdgeInsets.all(24),
            theme: pw.ThemeData.withFont(
              base: pw.Font.helvetica(),
              bold: pw.Font.helveticaBold(),
            ),
          ),
          build: (ctx) => [
            _pdfHeader(depKey!, classKey!, dateStr, section: sectKey),
            pw.SizedBox(height: 8),
            if (periods.isEmpty)
              pw.Text(
                'No period structure configured.',
                style: pw.TextStyle(color: PdfColors.grey600),
              ),
            if (grid == null || periods.isEmpty)
              pw.Padding(
                padding: const pw.EdgeInsets.only(top: 16),
                child: pw.Text(
                  'No timetable data',
                  style: pw.TextStyle(fontSize: 14),
                ),
              )
            else
              _pdfGridTable(periods: periods, grid: grid),
          ],
        ),
      );
    } else {
      if (sectionsMap.isEmpty) {
        pdf.addPage(
          pw.MultiPage(
            pageTheme: pw.PageTheme(
              margin: const pw.EdgeInsets.all(24),
              theme: pw.ThemeData.withFont(
                base: pw.Font.helvetica(),
                bold: pw.Font.helveticaBold(),
              ),
            ),
            build: (ctx) => [
              _pdfHeader(depKey!, classKey!, dateStr),
              pw.SizedBox(height: 8),
              pw.Text('No sections found for this class.'),
            ],
          ),
        );
      } else {
        for (final sectKey in sectionsMap.keys) {
          final grid = sectionsMap[sectKey]!;
          pdf.addPage(
            pw.MultiPage(
              pageTheme: pw.PageTheme(
                margin: const pw.EdgeInsets.all(24),
                theme: pw.ThemeData.withFont(
                  base: pw.Font.helvetica(),
                  bold: pw.Font.helveticaBold(),
                ),
              ),
              build: (ctx) => [
                _pdfHeader(depKey!, classKey!, dateStr, section: sectKey),
                pw.SizedBox(height: 8),
                if (periods.isEmpty)
                  pw.Text(
                    'No period structure configured.',
                    style: pw.TextStyle(color: PdfColors.grey600),
                  )
                else
                  _pdfGridTable(periods: periods, grid: grid),
              ],
            ),
          );
        }
      }
    }

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name:
          'timetable_${depKey}_${classKey}${choice == _ExportChoice.currentSection ? '_${selectedSection ?? 'Section'}' : '_ALL'}_${dateStr.replaceAll(':', '-')}.pdf',
    );
  }

  pw.Widget _pdfHeader(
    String dep,
    String cls,
    String dateStr, {
    String? section,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Class Timetable',
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'Department: $dep   Class: $cls${section != null ? "   Section: $section" : ""}',
        ),
        pw.Text('Exported: $dateStr'),
      ],
    );
  }

  pw.Widget _pdfGridTable({
    required List<String> periods,
    required List<List<String>> grid,
  }) {
    final headerColor = PdfColors.grey200;
    final breakFill = PdfColors.grey300;

    final tableHeaders = ['Day', ...periods];
    final dataRows = <List<pw.Widget>>[];

    for (int d = 0; d < days.length; d++) {
      final row = grid.length > d
          ? grid[d]
          : List<String>.filled(periods.length, '');
      final cells = <pw.Widget>[
        pw.Container(
          width: 40,
          padding: const pw.EdgeInsets.all(4),
          child: pw.Text(
            days[d],
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ),
      ];
      for (int p = 0; p < periods.length; p++) {
        final label = periods[p];
        final isBreak = label.toLowerCase().contains('break');
        final raw = p < row.length ? row[p] : '';
        final display = raw.trim().isEmpty || raw.toLowerCase() == 'break'
            ? (isBreak ? 'Break' : '')
            : raw;
        cells.add(
          pw.Container(
            padding: const pw.EdgeInsets.all(4),
            decoration: pw.BoxDecoration(
              color: isBreak ? breakFill : null,
              border: pw.Border.all(color: PdfColors.grey400, width: 0.3),
            ),
            child: pw.Text(display, style: pw.TextStyle(fontSize: 9)),
          ),
        );
      }
      dataRows.add(cells);
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.5),
      defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
      columnWidths: {
        0: pw.FixedColumnWidth(42),
        for (int i = 1; i < tableHeaders.length; i++) i: pw.FlexColumnWidth(2),
      },
      children: [
        pw.TableRow(
          decoration: pw.BoxDecoration(color: headerColor),
          children: tableHeaders
              .map(
                (h) => pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(
                    h,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 9,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        ...dataRows.map((cells) => pw.TableRow(children: cells)),
      ],
    );
  }

  Future<bool> _confirmDelete({
    required String title,
    required String content,
    String confirmText = 'Delete',
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    final grid = currentTimetable;
    final periodsForClass = currentPeriods;
    final canEdit = grid != null;
    final canDelete = selectedDepartment != null && selectedClass != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Time Table'),
        foregroundColor: Colors.black,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12.0), // mobile-friendly padding
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Search
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search Time Table...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                onChanged: (v) => setState(() => searchText = v),
              ),
              const SizedBox(height: 10),

              // Create button (left) and Edit/Delete/Export (right) — like your other pages
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Left: Create Time Table
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Create Time Table'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B4B9B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      minimumSize: const Size(0, 40),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () async {
                      final existingLabels =
                          (selectedDepartment != null &&
                              selectedClass != null &&
                              classPeriods[selectedDepartment!] != null &&
                              classPeriods[selectedDepartment!]![selectedClass!] !=
                                  null)
                          ? classPeriods[selectedDepartment!]![selectedClass!]
                          : null;

                      final payload =
                          await showDialog<CreateTimetableTimePayload>(
                            context: context,
                            builder: (_) => CreateTimetableDialog(
                              departments: departments,
                              departmentClasses: departmentClasses,
                              lecturers: lecturers,
                              sections: sections,
                              days: days,
                              courses: const [],
                              initialDepartment: selectedDepartment,
                              initialClass: selectedClass,
                              initialSection: selectedSection,
                              preconfiguredLabels: existingLabels,
                            ),
                          );

                      if (payload == null) return;

                      if (payload.periodsOverride != null &&
                          payload.periodsOverride!.isNotEmpty) {
                        final depClass = _ensureDepClass(
                          payload.results.first.department,
                          payload.results.first.classKey,
                        );
                        final depKey = depClass.key;
                        final classKey = depClass.value;
                        _replaceClassPeriods(
                          depKey,
                          classKey,
                          payload.periodsOverride!,
                        );
                        _ensureSectionGrid(
                          depKey,
                          classKey,
                          payload.results.first.section,
                        );
                      }

                      setState(() {
                        for (final r in payload.results) {
                          final depClass = _ensureDepClass(
                            r.department,
                            r.classKey,
                          );
                          final depKey = depClass.key;
                          final classKey = depClass.value;
                          _ensureSectionGrid(depKey, classKey, r.section);

                          final label = _makeLabel(
                            r.startMinutes,
                            r.endMinutes,
                          );
                          final colIndex = _findOrInsertPeriodIndexForClass(
                            depKey: depKey,
                            classKey: classKey,
                            newLabel: label,
                          );

                          _ensureSectionGrid(depKey, classKey, r.section);
                          final sectionsMap = timetableData[depKey]![classKey]!;
                          final sectionKey =
                              _findKeyIgnoreCase(sectionsMap, r.section) ??
                              r.section;
                          final tgtGrid = sectionsMap[sectionKey]!;
                          if (r.dayIndex >= 0 &&
                              r.dayIndex < tgtGrid.length &&
                              colIndex >= 0 &&
                              colIndex < tgtGrid[r.dayIndex].length) {
                            tgtGrid[r.dayIndex][colIndex] = r.cellText;
                          }
                        }
                      });

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Time table entries saved'),
                        ),
                      );
                    },
                  ),

                  // Right: Edit / Delete (disabled until needed) + Export icon
                  Row(
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
                          onPressed: !canEdit
                              ? null
                              : () {
                                  setState(
                                    () => editingEnabled = !editingEnabled,
                                  );
                                },
                          child: Text(
                            editingEnabled ? "Done" : "Edit",
                            style: const TextStyle(
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
                          onPressed: !canDelete ? null : _showDeleteMenu,
                          child: const Text(
                            "Delete",
                            style: TextStyle(fontSize: 15, color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: 'Export PDF',
                        onPressed: canDelete ? _exportPdfFlow : null,
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Filters – horizontal scroll on mobile
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterBox(
                      hint: 'Department',
                      value: selectedDepartment,
                      items: departments,
                      onChanged: (v) => setState(() {
                        selectedDepartment = v?.trim();
                        selectedClass = null;
                        selectedSection = null;
                      }),
                    ),
                    const SizedBox(width: 8),
                    _FilterBox(
                      hint: 'Class',
                      value: selectedClass,
                      items: selectedDepartment == null
                          ? departmentClasses.values.expand((e) => e).toList()
                          : (departmentClasses[selectedDepartment] ?? []),
                      onChanged: (v) =>
                          setState(() => selectedClass = v?.trim()),
                    ),
                    const SizedBox(width: 8),
                    _FilterBox(
                      hint: 'Lecturer',
                      value: selectedLecturer,
                      items: lecturers,
                      onChanged: (v) =>
                          setState(() => selectedLecturer = v?.trim()),
                    ),
                    const SizedBox(width: 8),
                    _FilterBox(
                      hint: 'Section',
                      value: selectedSection,
                      items: sections,
                      onChanged: (v) =>
                          setState(() => selectedSection = v?.trim()),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Content
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: (grid == null)
                      ? Center(
                          child: Text(
                            'Please select Department, Class, and Section to view the timetable.',
                            style: TextStyle(color: Colors.grey.shade600),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : _TimetableGrid(
                          days: days,
                          periods: periodsForClass,
                          timetable: grid,
                          editing: editingEnabled,
                          onCellTap: (d, p) =>
                              _openEditCellDialog(dayIndex: d, periodIndex: p),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------- Supporting Widgets & Models -------------------

class _FilterBox extends StatelessWidget {
  final String hint;
  final String? value;
  final List<String> items;
  final ValueChanged<String?> onChanged;

  const _FilterBox({
    super.key,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 130, maxWidth: 240),
      child: InputDecorator(
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          isDense: true,
          filled: true,
          fillColor: Colors.white,
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            hint: Text(hint),
            isExpanded: true,
            value: value,
            items: items
                .map((i) => DropdownMenuItem(value: i, child: Text(i)))
                .toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

class _TimetableGrid extends StatelessWidget {
  final List<String> days;
  final List<String> periods;
  final List<List<String>> timetable;
  final bool editing;
  final void Function(int dayIndex, int periodIndex)? onCellTap;

  const _TimetableGrid({
    super.key,
    required this.days,
    required this.periods,
    required this.timetable,
    required this.editing,
    this.onCellTap,
  });

  double _periodWidthFor(BoxConstraints c) {
    if (c.maxWidth <= 420) return 140; // very small phones
    if (c.maxWidth <= 600) return 160; // phones
    if (c.maxWidth <= 900) return 200; // tablets portrait
    return 260; // desktop / wide
  }

  @override
  Widget build(BuildContext context) {
    const double headerHeight = 50.0;
    const double dividerHeight = 1.0;

    final highlightShape = RoundedRectangleBorder(
      side: BorderSide(
        color: editing ? const Color(0xFF3B4B9B) : Colors.transparent,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final periodColWidth = _periodWidthFor(constraints);
        final dayColWidth =
            periodColWidth * 0.5; // smaller day column on phones

        final totalWidth = dayColWidth + periodColWidth * periods.length;
        final childWidth = totalWidth > constraints.maxWidth
            ? totalWidth
            : constraints.maxWidth;

        double rowsAreaHeight =
            constraints.maxHeight - headerHeight - dividerHeight;
        if (rowsAreaHeight < 120) rowsAreaHeight = 220;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: childWidth,
            child: Column(
              children: [
                // Header row
                Row(
                  children: [
                    Container(
                      width: dayColWidth,
                      height: headerHeight,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      alignment: Alignment.centerLeft,
                      child: const Text(
                        'Day',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    ...periods.map((p) {
                      final isBreak = p.toLowerCase().contains('break');
                      return Container(
                        width: periodColWidth,
                        height: headerHeight,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border(
                            left: BorderSide(color: Colors.grey.shade300),
                          ),
                          color: isBreak ? Colors.grey.shade100 : null,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          p,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }),
                  ],
                ),
                const Divider(height: dividerHeight),
                // Rows
                SizedBox(
                  height: rowsAreaHeight,
                  child: ListView.builder(
                    itemCount: days.length,
                    itemBuilder: (context, rowIdx) {
                      final row = rowIdx < timetable.length
                          ? timetable[rowIdx]
                          : List<String>.filled(
                              periods.length,
                              '',
                              growable: true,
                            );
                      return Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: dayColWidth,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 12,
                                ),
                                child: Text(
                                  days[rowIdx],
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              ...List.generate(periods.length, (colIdx) {
                                final cell = (colIdx < row.length)
                                    ? row[colIdx]
                                    : '';
                                final isBreak = periods[colIdx]
                                    .toLowerCase()
                                    .contains('break');
                                final tappable =
                                    editing && !isBreak && onCellTap != null;

                                Widget content = cell.trim().isEmpty
                                    ? (editing && !isBreak
                                          ? Opacity(
                                              opacity: 0.5,
                                              child: Text(
                                                'Tap to add',
                                                style: TextStyle(
                                                  fontStyle: FontStyle.italic,
                                                  color: Colors.grey.shade600,
                                                  fontSize: 12,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            )
                                          : const SizedBox.shrink())
                                    : Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            cell.split('\n').first,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 4),
                                          if (cell.split('\n').length > 1)
                                            Text(
                                              cell
                                                  .split('\n')
                                                  .skip(1)
                                                  .join(' — '),
                                              style: const TextStyle(
                                                color: Colors.black87,
                                                fontSize: 12,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                        ],
                                      );

                                return InkWell(
                                  onTap: tappable
                                      ? () => onCellTap!(rowIdx, colIdx)
                                      : null,
                                  child: Container(
                                    width: periodColWidth,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        left: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      color: isBreak
                                          ? Colors.grey.shade100
                                          : null,
                                      boxShadow: (editing && !isBreak)
                                          ? [
                                              BoxShadow(
                                                color: Colors.blue.withOpacity(
                                                  0.05,
                                                ),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    foregroundDecoration: (editing && !isBreak)
                                        ? ShapeDecoration(shape: highlightShape)
                                        : null,
                                    child: content,
                                  ),
                                );
                              }),
                            ],
                          ),
                          const Divider(height: 1),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

enum _DeleteAction { section, classAll, classStructure }

class _DeleteOptionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final _DeleteAction action;

  const _DeleteOptionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.action,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      onTap: () => Navigator.pop(context, action),
      leading: const Icon(Icons.delete_outline),
    );
  }
}

class _UndoState {
  final String depKey;
  final String classKey;
  final String? sectionKey;
  final Map<String, List<String>> classPeriodsCopy;
  final Map<String, List<List<String>>> timetableCopy;
  final _DeleteAction action;
  _UndoState({
    required this.depKey,
    required this.classKey,
    required this.sectionKey,
    required this.classPeriodsCopy,
    required this.timetableCopy,
    required this.action,
  });
}

enum _ExportChoice { currentSection, entireClass }

class _ExportOptionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final _ExportChoice choice;

  const _ExportOptionTile({
    required this.title,
    required this.subtitle,
    required this.choice,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      leading: const Icon(Icons.picture_as_pdf_outlined),
      onTap: () => Navigator.pop(context, choice),
    );
  }
}

/// Simple dialog to edit a timetable cell (course + lecturer).
/// Returns TimetableCellEditResult with cellText containing "Course\nLecturer"
/// or with cellText == null when the user chooses the "Clear" action.
class TimetableCellEditDialog extends StatefulWidget {
  final String? initialCourse;
  final String? initialLecturer;
  final List<String> courses;
  final List<String> lecturers;

  const TimetableCellEditDialog({
    super.key,
    this.initialCourse,
    this.initialLecturer,
    required this.courses,
    required this.lecturers,
  });

  @override
  State<TimetableCellEditDialog> createState() =>
      _TimetableCellEditDialogState();
}

class _TimetableCellEditDialogState extends State<TimetableCellEditDialog> {
  late TextEditingController _courseController;
  late TextEditingController _lecturerController;

  @override
  void initState() {
    super.initState();
    _courseController =
        TextEditingController(text: widget.initialCourse ?? '');
    _lecturerController =
        TextEditingController(text: widget.initialLecturer ?? '');
  }

  @override
  void dispose() {
    _courseController.dispose();
    _lecturerController.dispose();
    super.dispose();
  }

  void _submit() {
    final course = _courseController.text.trim();
    final lecturer = _lecturerController.text.trim();
    final combined = course.isEmpty && lecturer.isEmpty
        ? ''
        : (course.isEmpty ? lecturer : (lecturer.isEmpty ? course : '$course\n$lecturer'));
    Navigator.of(context).pop(TimetableCellEditResult(cellText: combined));
  }

  void _clearCell() {
    // As documented, returning cellText == null indicates a clear action.
    Navigator.of(context).pop(TimetableCellEditResult(cellText: null));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Cell'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _courseController,
              decoration: const InputDecoration(
                labelText: 'Course',
                hintText: 'Course name',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _lecturerController,
              decoration: const InputDecoration(
                labelText: 'Lecturer',
                hintText: 'Lecturer name',
              ),
            ),
            const SizedBox(height: 12),
            // Quick pick buttons (optional, non-intrusive)
            if (widget.courses.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: widget.courses.take(6).map((c) {
                  return ActionChip(
                    label: Text(
                      c,
                      style: const TextStyle(fontSize: 12),
                    ),
                    onPressed: () {
                      _courseController.text = c;
                    },
                  );
                }).toList(),
              ),
            const SizedBox(height: 8),
            if (widget.lecturers.isNotEmpty)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: widget.lecturers.take(6).map((l) {
                  return ActionChip(
                    label: Text(
                      l,
                      style: const TextStyle(fontSize: 12),
                    ),
                    onPressed: () {
                      _lecturerController.text = l;
                    },
                  );
                }).toList(),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(), // cancel
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _clearCell,
          child: const Text(
            'Clear',
            style: TextStyle(color: Colors.red),
          ),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
