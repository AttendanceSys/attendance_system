import 'package:flutter/material.dart';

class StudentDetailsPanel extends StatefulWidget {
  final String studentId;
  final String? studentName;
  final String? studentClass;
  final DateTime? selectedDate;
  final List<Map<String, dynamic>> attendanceRecords;
  final String searchText;
  final VoidCallback? onBack;
  final Function(List<Map<String, dynamic>>) onEdit;

  const StudentDetailsPanel({
    super.key,
    required this.studentId,
    this.studentName,
    this.studentClass,
    this.selectedDate,
    required this.attendanceRecords,
    required this.searchText,
    this.onBack,
    required this.onEdit,
  });

  @override
  State<StudentDetailsPanel> createState() => _StudentDetailsPanelState();
}

class _StudentDetailsPanelState extends State<StudentDetailsPanel> {
  bool isEditing = false;
  late List<Map<String, dynamic>> editRecords;
  late List<Map<String, dynamic>>
  baseRecords; // <- The snapshot for confirmation!
  String? editError;

  @override
  void initState() {
    super.initState();
    editRecords = widget.attendanceRecords
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    baseRecords = widget.attendanceRecords
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  void _startEdit() {
    setState(() {
      isEditing = true;
      editError = null;
      // Take a fresh snapshot of current attendance for confirmation
      baseRecords = editRecords
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    });
  }

  void _cancelEdit() {
    setState(() {
      isEditing = false;
      editRecords = baseRecords
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      editError = null;
    });
  }

  void _saveEdit() async {
    // Validate present days
    for (final record in editRecords) {
      if ((record["present"] ?? 0) < 0 ||
          (record["present"] ?? 0) > (record["total"] ?? 0)) {
        setState(() {
          editError =
              "Present days must be between 0 and total days for each course.";
        });
        return;
      }
    }

    // Find changed subjects (compare with baseRecords!)
    final changes = <Map<String, dynamic>>[];
    for (final record in editRecords) {
      final orig = baseRecords.firstWhere(
        (r) => r["course"] == record["course"],
      );
      final diff = (record["present"] ?? 0) - (orig["present"] ?? 0);
      if (diff != 0) {
        changes.add({
          "course": record["course"],
          "added": diff > 0 ? diff : 0,
          "removed": diff < 0 ? -diff : 0,
          "newValue": record["present"],
          "oldValue": orig["present"],
        });
      }
    }

    if (changes.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Confirm Edit"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Are you sure you want to edit these subjects?"),
              const SizedBox(height: 10),
              ...changes.map(
                (change) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    "${change["course"]}: "
                    "${change["added"] > 0 ? "+${change["added"]}" : ""}"
                    "${change["removed"] > 0 ? "-${change["removed"]}" : ""} "
                    "(was: ${change["oldValue"]}, now: ${change["newValue"]})",
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.of(ctx).pop(false),
            ),
            ElevatedButton(
              child: const Text("Confirm"),
              onPressed: () => Navigator.of(ctx).pop(true),
            ),
          ],
        ),
      );
      if (confirmed != true) {
        return;
      }
    }

    setState(() {
      isEditing = false;
      editError = null;
      // After saving, baseRecords and editRecords become the same
      baseRecords = editRecords
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    });
    widget.onEdit(editRecords);
  }

  @override
  Widget build(BuildContext context) {
    final records = isEditing ? editRecords : widget.attendanceRecords;
    final filteredRecords = records
        .where(
          (rec) => rec["course"].toString().toLowerCase().contains(
            widget.searchText.toLowerCase(),
          ),
        )
        .toList();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 24),
      child: Material(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(18),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 38, vertical: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top bar (Back, Title, Edit/Save/Cancel)
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (widget.onBack != null)
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: widget.onBack,
                      tooltip: "Back",
                      splashRadius: 24,
                    ),
                  // Header: ID, Name, Class (simple, labelled and larger)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ID: ${widget.studentId}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Name: ${widget.studentName ?? ''}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Class: ${widget.studentClass ?? ''}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),

                  if (isEditing)
                    Row(
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.save, size: 20),
                          label: const Text(
                            "Save",
                            style: TextStyle(fontSize: 17),
                          ),
                          onPressed: _saveEdit,
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          icon: const Icon(Icons.cancel, size: 20),
                          label: const Text(
                            "Cancel",
                            style: TextStyle(fontSize: 17),
                          ),
                          onPressed: _cancelEdit,
                        ),
                      ],
                    ),
                ],
              ),
              if (editError != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 8,
                  ),
                  child: Text(
                    editError!,
                    style: const TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              if (widget.selectedDate != null)
                Padding(
                  padding: const EdgeInsets.only(left: 48.0, top: 5),
                  child: Text(
                    "Date: ${widget.selectedDate!.day}/${widget.selectedDate!.month}/${widget.selectedDate!.year}",
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              const SizedBox(height: 28),
              // If there are no attendance records for this student, show a friendly empty state
              if (filteredRecords.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 48,
                          color: Colors.grey[500],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No attendance records available for this student.',
                          style: TextStyle(fontSize: 16, color: Colors.black54),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        if (widget.onBack != null)
                          ElevatedButton.icon(
                            onPressed: widget.onBack,
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Back'),
                          ),
                      ],
                    ),
                  ),
                )
              else
                // Table full width and beautiful, no extra search
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: DataTable(
                    columnSpacing: 60,
                    headingRowHeight: 48,
                    dataRowHeight: 44,
                    columns: const [
                      DataColumn(
                        label: Text(
                          "Courses",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          "Total",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          "Present",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          "Percentage (%)",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                    ],
                    rows: List.generate(filteredRecords.length, (i) {
                      final record = filteredRecords[i];
                      return DataRow(
                        cells: [
                          DataCell(
                            Text(
                              record["course"]?.toString() ?? "",
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          DataCell(
                            Text(
                              record["total"].toString(),
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                          DataCell(
                            isEditing
                                ? Row(
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.remove,
                                          size: 18,
                                        ),
                                        tooltip: "Remove present day",
                                        onPressed: () {
                                          setState(() {
                                            if ((record["present"] ?? 0) > 0) {
                                              record["present"] =
                                                  (record["present"] ?? 0) - 1;
                                            }
                                          });
                                        },
                                      ),
                                      Text(
                                        "${record["present"]}",
                                        style: const TextStyle(fontSize: 16),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.add, size: 18),
                                        tooltip: "Add present day",
                                        onPressed: () {
                                          setState(() {
                                            if ((record["present"] ?? 0) <
                                                (record["total"] ?? 0)) {
                                              record["present"] =
                                                  (record["present"] ?? 0) + 1;
                                            }
                                          });
                                        },
                                      ),
                                    ],
                                  )
                                : Text(
                                    record["present"].toString(),
                                    style: const TextStyle(fontSize: 16),
                                  ),
                          ),
                          DataCell(
                            Text(
                              (() {
                                final total = record["total"] ?? 0;
                                final present = record["present"] ?? 0;
                                if (total == 0) return "0%";
                                final percent = (present / total) * 100;
                                return "${percent.toStringAsFixed(1)}%";
                              })(),
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}