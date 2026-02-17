//faculty page

import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/faculty.dart';
import '../popup/add_faculty_popup.dart';
import '../cards/searchBar.dart';
import 'package:flutter/material.dart';
import '../../theme/super_admin_theme.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../../utils/download_bytes.dart';

class FacultiesPage extends StatefulWidget {
  const FacultiesPage({super.key});

  @override
  State<FacultiesPage> createState() => _FacultiesPageState();
}

class _FacultiesPageState extends State<FacultiesPage> {
  final CollectionReference facultiesCollection = FirebaseFirestore.instance
      .collection('faculties');

  List<Faculty> _faculties = [];
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

  List<Faculty> get _filteredFaculties {
    final query = _searchText.trim().toLowerCase();
    if (query.isEmpty) return _faculties;
    return _faculties
        .where(
          (faculty) =>
              faculty.name.toLowerCase().startsWith(query) ||
              faculty.code.toLowerCase().startsWith(query),
        )
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _fetchFaculties();
  }

  Future<bool> _facultyExists({
    required String code,
    required String name,
    String? excludeId,
  }) async {
    final trimmedCode = code.trim();
    final trimmedName = name.trim();

    final codeSnap = await facultiesCollection
        .where('faculty_code', isEqualTo: trimmedCode)
        .get();
    final nameSnap = await facultiesCollection
        .where('faculty_name', isEqualTo: trimmedName)
        .get();

    final hasCode = codeSnap.docs.any((d) => d.id != excludeId);
    final hasName = nameSnap.docs.any((d) => d.id != excludeId);
    return hasCode || hasName;
  }

  Future<void> _fetchFaculties() async {
    try {
      final snapshot = await facultiesCollection.get();

      if (snapshot.docs.isEmpty) {
        print("No faculties found");
      } else {
        print("Fetched ${snapshot.docs.length} faculties");
      }

      setState(() {
        _faculties = snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return Faculty(
            id: doc.id,
            code: data['faculty_code'] ?? 'N/A',
            name: data['faculty_name'] ?? 'N/A',
            createdAt:
                (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
            establishmentDate: DateTime.parse(
              data['establishment_date'] ?? DateTime.now().toIso8601String(),
            ),
          );
        }).toList();
      });
    } catch (e) {
      print("Error fetching faculties: $e");
    }
  }

  Future<void> _addFaculty(Faculty faculty) async {
    final code = faculty.code.trim();
    final name = faculty.name.trim();

    final exists = await _facultyExists(code: code, name: name);
    if (exists) {
      _showSnack('Faculty code or name already exists');
      return;
    }

    await facultiesCollection.add({
      'faculty_code': code,
      'faculty_name': name,
      'created_at': FieldValue.serverTimestamp(),
      'establishment_date': faculty.establishmentDate.toIso8601String(),
    });
    _fetchFaculties();
    _showSnack('Faculty added successfully');
  }

  Future<void> _updateFaculty(Faculty faculty) async {
    final code = faculty.code.trim();
    final name = faculty.name.trim();

    final exists = await _facultyExists(
      code: code,
      name: name,
      excludeId: faculty.id,
    );
    if (exists) {
      _showSnack('Faculty code or name already exists');
      return;
    }

    await facultiesCollection.doc(faculty.id).update({
      'faculty_code': code,
      'faculty_name': name,
      'created_at': FieldValue.serverTimestamp(),
      'establishment_date': faculty.establishmentDate.toIso8601String(),
    });
    _fetchFaculties();
    _showSnack('Faculty updated successfully');
  }

  Future<void> _deleteFaculty(Faculty faculty) async {
    await facultiesCollection.doc(faculty.id).delete();
    _fetchFaculties();
    _showSnack('Faculty deleted successfully');
  }

  Future<void> _showAddFacultyPopup() async {
    final result = await showDialog<Faculty>(
      context: context,
      builder: (context) => const AddFacultyPopup(),
    );
    if (result != null) {
      _addFaculty(result);
    }
  }

  DateTime _parseEstablishmentDate(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return DateTime.now();
    final iso = DateTime.tryParse(s);
    if (iso != null) return iso;

    final parts = s.split(RegExp(r'\s+'));
    if (parts.length == 3) {
      final day = int.tryParse(parts[0]) ?? 1;
      final year = int.tryParse(parts[2]) ?? DateTime.now().year;
      const months = {
        'jan': 1,
        'feb': 2,
        'mar': 3,
        'apr': 4,
        'may': 5,
        'jun': 6,
        'jul': 7,
        'aug': 8,
        'sep': 9,
        'oct': 10,
        'nov': 11,
        'dec': 12,
      };
      final month = months[parts[1].toLowerCase().substring(0, 3)] ?? 1;
      return DateTime(year, month, day);
    }
    return DateTime.now();
  }

  Future<void> _handleExportFacultiesCsv() async {
    try {
      final rows = <List<dynamic>>[
        ['No', 'Faculty Code', 'Faculty Name', 'Establishment Date'],
      ];
      for (int i = 0; i < _faculties.length; i++) {
        final f = _faculties[i];
        rows.add([
          i + 1,
          f.code,
          f.name,
          '${f.establishmentDate.year.toString().padLeft(4, '0')}-${f.establishmentDate.month.toString().padLeft(2, '0')}-${f.establishmentDate.day.toString().padLeft(2, '0')}',
        ]);
      }

      final csv = const ListToCsvConverter().convert(rows);
      final bytes = Uint8List.fromList(utf8.encode(csv));
      final now = DateTime.now();
      final fileName =
          'faculties_${now.year.toString().padLeft(4, '0')}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}.csv';

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
      _showSnack('Failed to export faculties CSV');
    }
  }

  Future<bool> _addFacultyFromUpload(Faculty f) async {
    try {
      final code = f.code.trim();
      final name = f.name.trim();
      if (code.isEmpty || name.isEmpty) return false;
      final exists = await _facultyExists(code: code, name: name);
      if (exists) return false;
      await facultiesCollection.add({
        'faculty_code': code,
        'faculty_name': name,
        'created_at': FieldValue.serverTimestamp(),
        'establishment_date': f.establishmentDate.toIso8601String(),
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _handleUploadFaculties() async {
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
          content: Text('Import ${parsed.length} faculties?'),
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
            (row['faculty_code'] ??
                    row['faculty code'] ??
                    row['code'] ??
                    '')
                .toString()
                .trim();
        final name =
            (row['faculty_name'] ??
                    row['faculty name'] ??
                    row['name'] ??
                    '')
                .toString()
                .trim();
        final dateRaw =
            (row['establishment_date'] ??
                    row['establishment date'] ??
                    row['date'] ??
                    '')
                .toString()
                .trim();
        if (code.isEmpty || name.isEmpty) {
          skipped++;
          continue;
        }

        final faculty = Faculty(
          id: '',
          code: code,
          name: name,
          establishmentDate: _parseEstablishmentDate(dateRaw),
          createdAt: DateTime.now(),
        );
        final ok = await _addFacultyFromUpload(faculty);
        if (ok) {
          added++;
        } else {
          skipped++;
        }
      }

      await _fetchFaculties();
      _showSnack('Imported $added, skipped $skipped');
    } catch (e) {
      _showSnack('Failed to import faculties');
    }
  }

  Future<void> _showEditFacultyPopup() async {
    if (_selectedIndex == null) return;
    final faculty = _filteredFaculties[_selectedIndex!];
    final result = await showDialog<Faculty>(
      context: context,
      builder: (context) => AddFacultyPopup(faculty: faculty),
    );
    if (result != null) {
      _updateFaculty(result);
    }
  }

  Future<void> _confirmDeleteFaculty() async {
    if (_selectedIndex == null) return;
    final faculty = _filteredFaculties[_selectedIndex!];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Faculty"),
        content: Text("Are you sure you want to delete '${faculty.name}'?"),
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
      _deleteFaculty(faculty);
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
            "Faculties",
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
                        hintText: "Search Faculty...",
                        buttonText: "Add Faculty",
                        onAddPressed: _showAddFacultyPopup,
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
                        onPressed: _handleUploadFaculties,
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Upload Faculties'),
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
                        onPressed: _handleExportFacultiesCsv,
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
                  hintText: "Search Faculty...",
                  buttonText: "Add Faculty",
                  onAddPressed: _showAddFacultyPopup,
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
                    onPressed: _handleUploadFaculties,
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Upload Faculties'),
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
                    onPressed: _handleExportFacultiesCsv,
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
                          : _showEditFacultyPopup,
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
                          : _confirmDeleteFaculty,
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
        1: FlexColumnWidth(1.15),
        2: FlexColumnWidth(1.25),
        3: FlexColumnWidth(1.2),
      },
    );
  }

  Widget _buildMobileTable() {
    return _buildSaasTable(
      columnWidths: const {
        0: FixedColumnWidth(72),
        1: FixedColumnWidth(140),
        2: FixedColumnWidth(220),
        3: FixedColumnWidth(190),
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
                    _tableHeaderCell("Faculty Code", textPrimary),
                    _tableHeaderCell("Faculty Name", textPrimary),
                    _tableHeaderCell("Establishment Date", textPrimary),
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
                    for (int index = 0; index < _filteredFaculties.length; index++)
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
                            _filteredFaculties[index].code,
                            textPrimary,
                            onTap: () => _handleRowTap(index),
                          ),
                          _tableBodyCell(
                            _filteredFaculties[index].name,
                            textPrimary,
                            onTap: () => _handleRowTap(index),
                          ),
                          _tableBodyCell(
                            "${_filteredFaculties[index].establishmentDate.day.toString().padLeft(2, '0')} "
                            "${_monthString(_filteredFaculties[index].establishmentDate.month)} "
                            "${_filteredFaculties[index].establishmentDate.year}",
                            textPrimary,
                            onTap: () => _handleRowTap(index),
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
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 24),
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
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
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

  String _monthString(int month) {
    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];
    return months[month - 1];
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
}
