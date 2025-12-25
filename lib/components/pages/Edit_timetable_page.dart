import 'package:flutter/material.dart';

class TimetableCellEditResult {
  final String? cellText; // null means no change, '' means clear
  TimetableCellEditResult({required this.cellText});
}

/// Dialog to edit a single timetable cell.
/// If both course & lecturer are empty on save -> treated as "clear" (with confirmation).
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

  // Track initial values to detect unsaved changes
  late final String _initialCourse;
  late final String _initialLecturer;
  late final bool _initialUseCustomLecturer;

  @override
  void initState() {
    super.initState();

    // Course initial
    _course = (widget.initialCourse != null && widget.initialCourse!.trim().isNotEmpty)
        ? widget.initialCourse!.trim()
        : null;

    // Lecturer initial: try to match existing lecturer values case-insensitively.
    if (widget.initialLecturer != null && widget.initialLecturer!.trim().isNotEmpty) {
      final initLect = widget.initialLecturer!.trim();
      final matched = widget.lecturers.firstWhere(
        (e) => e.toLowerCase() == initLect.toLowerCase(),
        orElse: () => '',
      );
      if (matched.isNotEmpty) {
        _lecturer = matched; // use canonical value from list
        _useCustomLecturer = false;
      } else {
        _useCustomLecturer = true;
        _customLecturerCtrl.text = initLect;
        // keep _lecturer null for clarity (it's a named lecturer when not custom)
      }
    } else {
      _lecturer = null;
      _useCustomLecturer = false;
    }

    _initialCourse = (widget.initialCourse ?? '').trim();
    _initialLecturer = (widget.initialLecturer ?? '').trim();
    _initialUseCustomLecturer = _useCustomLecturer;
  }

  @override
  void dispose() {
    _customLecturerCtrl.dispose();
    super.dispose();
  }

  String get _currentCourse => (_course ?? '').trim();
  String get _currentLecturer =>
      _useCustomLecturer ? _customLecturerCtrl.text.trim() : (_lecturer ?? '').trim();

  bool get _hasChanges =>
      _currentCourse != _initialCourse ||
      _currentLecturer != _initialLecturer ||
      _useCustomLecturer != _initialUseCustomLecturer;

  Future<bool> _confirm({
    required String title,
    required String content,
    String confirmText = 'Yes',
    String cancelText = 'No',
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(cancelText)),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: destructive ? Colors.red : Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
            child: Text(confirmText),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _onCloseOrCancel() async {
    if (_hasChanges) {
      final ok = await _confirm(
        title: 'Discard changes?',
        content: 'You have unsaved changes. Do you want to discard them?',
        confirmText: 'Discard',
        destructive: true,
      );
      if (!ok) return;
    }
    if (!mounted) return;
    Navigator.pop(context); // no result -> no change
  }

  Future<void> _clear() async {
    // If already empty, just close without extra confirmation
    final courseEmpty = _currentCourse.isEmpty;
    final lecturerEmpty = _currentLecturer.isEmpty;
    if (courseEmpty && lecturerEmpty) {
      // nothing to clear
      Navigator.pop(context, TimetableCellEditResult(cellText: ''));
      return;
    }

    final ok = await _confirm(
      title: 'Clear this cell?',
      content: 'This will remove the course and lecturer from this time slot.',
      confirmText: 'Clear',
      destructive: true,
    );
    if (!ok || !mounted) return;
    Navigator.pop(context, TimetableCellEditResult(cellText: ''));
  }

  Future<void> _save() async {
    final course = _currentCourse;
    final lecturer = _currentLecturer;

    if (course.isEmpty && lecturer.isEmpty) {
      // Treat as clear, but confirm first
      final ok = await _confirm(
        title: 'Save as empty?',
        content: 'Both Course and Lecturer are empty. This will clear the cell.',
        confirmText: 'Clear cell',
        destructive: true,
      );
      if (!ok || !mounted) return;
      Navigator.pop(context, TimetableCellEditResult(cellText: ''));
      return;
    }

    // If you want to force a course to be required, you can validate here and show a snack
    final cellText = lecturer.isEmpty ? course : '$course\n$lecturer';

    // Confirm applying non-empty edits (show before -> after summary) only if changed
    if (_hasChanges) {
      display(String s) => s.isEmpty ? '(empty)' : s;
      final beforeParts = <String>[];
      if (_initialCourse.isNotEmpty) beforeParts.add(_initialCourse);
      if (_initialLecturer.isNotEmpty) beforeParts.add(_initialLecturer);
      final before = beforeParts.isEmpty ? '(empty)' : beforeParts.join('\n');

      final afterParts = <String>[];
      if (course.isNotEmpty) afterParts.add(course);
      if (lecturer.isNotEmpty) afterParts.add(lecturer);
      final after = afterParts.isEmpty ? '(empty)' : afterParts.join('\n');

      final ok = await _confirm(
        title: 'Apply changes?',
        content: 'You are about to update this cell.\n\nBefore:\n$before\n\nAfter:\n$after',
        confirmText: 'Save',
        destructive: false,
      );
      if (!ok || !mounted) return;
    }

    if (!mounted) return;
    Navigator.pop(context, TimetableCellEditResult(cellText: cellText));
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
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.close), tooltip: 'Close', onPressed: _onCloseOrCancel),
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
                          // preserve custom text in controller so user can toggle without data loss
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
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                      onPressed: _onCloseOrCancel,
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
          items: items.map((e) => DropdownMenuItem<T>(value: e, child: Text(e.toString()))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}