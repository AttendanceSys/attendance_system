import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TimetableCellEditResult {
  final String? cellText;    // null means no change, '' means clear
  TimetableCellEditResult({required this.cellText});
}

/// Dialog to edit a single timetable cell.
/// If both course & lecturer are empty on save -> treated as "clear".
class TimetableCellEditDialog extends StatefulWidget {
  final String? initialCourse;
  final String? initialLecturer;
  final List<String> courses;
  final List<String> lecturers;

  const TimetableCellEditDialog({
    super.key,
    required this.initialCourse,
    required this.initialLecturer,
    required this.courses,
    required this.lecturers,
  });

  @override
  State<TimetableCellEditDialog> createState() => _TimetableCellEditDialogState();
}

class _TimetableCellEditDialogState extends State<TimetableCellEditDialog> {
  String? _course;
  String? _lecturer;
  bool _useCustomLecturer = false;
  final TextEditingController _customLecturerCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _course = widget.initialCourse != null && widget.initialCourse!.isNotEmpty
        ? widget.initialCourse
        : null;

    if (widget.initialLecturer != null && widget.initialLecturer!.isNotEmpty) {
      if (widget.lecturers.map((e) => e.toLowerCase()).contains(widget.initialLecturer!.toLowerCase())) {
        _lecturer = widget.initialLecturer;
      } else {
        _useCustomLecturer = true;
        _customLecturerCtrl.text = widget.initialLecturer!;
      }
    }
  }

  @override
  void dispose() {
    _customLecturerCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final course = (_course ?? '').trim();
    String lecturer;
    if (_useCustomLecturer) {
      lecturer = _customLecturerCtrl.text.trim();
    } else {
      lecturer = (_lecturer ?? '').trim();
    }

    if (course.isEmpty && lecturer.isEmpty) {
      Navigator.pop(context, TimetableCellEditResult(cellText: ''));
      return;
    }

    final cellText =
        lecturer.isEmpty ? course : '$course\n$lecturer';

    Navigator.pop(context, TimetableCellEditResult(cellText: cellText));
  }

  void _clear() {
    Navigator.pop(context, TimetableCellEditResult(cellText: ''));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Edit Cell',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Close',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Course
                _dropdownBox<String>(
                  hint: 'Course',
                  value: _course,
                  items: widget.courses,
                  onChanged: (v) => setState(() => _course = v),
                ),
                const SizedBox(height: 14),

                // Lecturer / Custom toggle
                Row(
                  children: [
                    Switch(
                      value: _useCustomLecturer,
                      onChanged: (v) {
                        setState(() {
                          _useCustomLecturer = v;
                          if (!v) _customLecturerCtrl.clear();
                        });
                      },
                    ),
                    const SizedBox(width: 6),
                    const Text('Custom lecturer'),
                  ],
                ),
                const SizedBox(height: 4),

                _useCustomLecturer
                    ? TextFormField(
                        controller: _customLecturerCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Lecturer name',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      )
                    : _dropdownBox<String>(
                        hint: 'Lecturer',
                        value: _lecturer,
                        items: widget.lecturers,
                        onChanged: (v) => setState(() => _lecturer = v),
                      ),

                const SizedBox(height: 24),

                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _clear,
                      child: const Text(
                        'Clear',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _save,
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dropdownBox<T>({
    required String hint,
    required T? value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
  }) {
    return InputDecorator(
      decoration: InputDecoration(
        hintText: hint,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          hint: Text(hint),
          items: items
              .map(
                (e) => DropdownMenuItem<T>(
                  value: e,
                  child: Text(e.toString()),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}