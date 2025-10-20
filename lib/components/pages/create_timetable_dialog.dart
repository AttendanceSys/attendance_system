import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A single session result (one timetable cell)
class CreateTimetableTimeResult {
  final String department;
  final String classKey;
  final String section;
  final int dayIndex; // 0 = Sat, 1 = Sun, ...
  final int startMinutes; // minutes since midnight
  final int endMinutes; // minutes since midnight
  final String cellText; // "Course" or "Course\nLecturer"

  CreateTimetableTimeResult({
    required this.department,
    required this.classKey,
    required this.section,
    required this.dayIndex,
    required this.startMinutes,
    required this.endMinutes,
    required this.cellText,
  });
}

/// Dialog payload returned to parent
class CreateTimetableTimePayload {
  final List<CreateTimetableTimeResult> results;
  final List<String>? periodsOverride; // full (periods + breaks) list if changed

  CreateTimetableTimePayload({required this.results, this.periodsOverride});
}

class CreateTimetableDialog extends StatefulWidget {
  final List<String> departments;
  final Map<String, List<String>> departmentClasses;
  final List<String> lecturers;
  final List<String> sections;
  final List<String> days;
  final List<String>? courses;

  final String? initialDepartment;
  final String? initialClass;
  final String? initialSection;

  /// If provided, the existing schedule (periods + breaks) so user can
  /// add sessions or append new periods without re-configuring from scratch.
  final List<String>? preconfiguredLabels;

  const CreateTimetableDialog({
    super.key,
    required this.departments,
    required this.departmentClasses,
    required this.lecturers,
    required this.sections,
    required this.days,
    this.courses,
    this.initialDepartment,
    this.initialClass,
    this.initialSection,
    this.preconfiguredLabels,
  });

  @override
  State<CreateTimetableDialog> createState() => _CreateTimetableDialogState();
}

class _CreateTimetableDialogState extends State<CreateTimetableDialog> {
  // Selections
  String? _department;
  String? _classKey;
  String? _section;
  String? _lecturer;
  bool _useCustomLecturer = false;
  final TextEditingController _lecturerCustomCtrl = TextEditingController();
  String? _course;

  // Sessions
  final List<_SessionRow> _sessions = [_SessionRow()];

  // Generated schedule (labels + spans + indices)
  List<String> _labels = [];
  List<(int, int)> _spans = [];
  List<int> _teachingIndices = [];
  int? _inferredPeriodMinutes; // teaching period length (if consistent)

  // Mock courses
  static const List<String> _mockCourses = [
    'Math',
    'E-Commerce',
    'Data Science and Analytics',
    'Network Security',
    'Computer Ethics',
    'Selected Topics in Comp Scien.',
  ];
  List<String> get _courseList =>
      (widget.courses != null && widget.courses!.isNotEmpty)
          ? widget.courses!
          : _mockCourses;

  bool get _configured =>
      _labels.isNotEmpty &&
      _spans.length == _labels.length &&
      _teachingIndices.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _department = widget.initialDepartment;
    _classKey = widget.initialClass;
    _section = widget.initialSection;

    // If preconfigured labels passed, load them
    if (widget.preconfiguredLabels != null &&
        widget.preconfiguredLabels!.isNotEmpty) {
      _loadPreconfigured(widget.preconfiguredLabels!);
    }
  }

  @override
  void dispose() {
    _lecturerCustomCtrl.dispose();
    super.dispose();
  }

  // --------------------- Parsing & Integrity ---------------------

  final RegExp _timeLabelRegex = RegExp(
    r'^\s*(\d{1,2}):([0-5]\d)\s*-\s*(\d{1,2}):([0-5]\d)(\s*\(break\))?\s*$',
    caseSensitive: false,
  );

  void _loadPreconfigured(List<String> labels) {
    final newSpans = <(int, int)>[];
    final teachingIdx = <int>[];
    int? inferredLen;

    for (int i = 0; i < labels.length; i++) {
      final l = labels[i];
      final m = _timeLabelRegex.firstMatch(l);
      if (m == null) {
        debugPrint('Skipping unparsable existing label: $l');
        return; // abort load to avoid partial mismatch
      }
      final sh = int.parse(m.group(1)!);
      final sm = int.parse(m.group(2)!);
      final eh = int.parse(m.group(3)!);
      final em = int.parse(m.group(4)!);
      final start = sh * 60 + sm;
      final end = eh * 60 + em;
      if (end <= start) {
        debugPrint('Invalid range in existing label: $l');
        return;
      }
      newSpans.add((start, end));
      final isBreak = (m.group(5) ?? '').toLowerCase().contains('break');
      if (!isBreak) {
        final len = end - start;
        inferredLen ??= len;
        // Keep inference only if consistent
        if (inferredLen != len) {
          inferredLen = null; // inconsistent pattern
        }
        teachingIdx.add(i);
      }
    }

    setState(() {
      _labels = List<String>.from(labels);
      _spans = newSpans;
      _teachingIndices = teachingIdx;
      _inferredPeriodMinutes = inferredLen;
      // Reset existing session selection
      for (final s in _sessions) {
        s.dayIndex ??= 0;
        s.periodDropdownIndex = null;
      }
    });
  }

  void _recomputeTeachingIndices() {
    _teachingIndices.clear();
    int? periodLen;
    bool consistent = true;
    for (int i = 0; i < _labels.length; i++) {
      final isBreak = _labels[i].toLowerCase().contains('break');
      if (!isBreak) {
        final span = _spans[i];
        final len = span.$2 - span.$1;
        periodLen ??= len;
        if (periodLen != len) consistent = false;
        _teachingIndices.add(i);
      }
    }
    _inferredPeriodMinutes = consistent ? periodLen : null;
  }

  void _assertIntegrity() {
    if (_labels.length != _spans.length) {
      _labels.clear();
      _spans.clear();
      _teachingIndices.clear();
      _inferredPeriodMinutes = null;
    }
  }

  // --------------------- Period Generator (Full Reconfigure) ---------------------

  Future<void> _openFullGenerator() async {
    final result = await showDialog<_GeneratedScheduleResult>(
      context: context,
      builder: (ctx) => _PeriodGeneratorDialog(
        existingLabels: _labels,
        existingSpans: _spans,
        existingTeachingIndices: _teachingIndices,
      ),
    );
    if (result == null) return;
    setState(() {
      _labels = result.labels;
      _spans = result.spans;
      _teachingIndices = result.teachingIndices;
      _recomputeTeachingIndices();
      for (final s in _sessions) {
        s.periodDropdownIndex = null;
      }
    });
  }

  // --------------------- Sessions ---------------------

  void _addSession() => setState(() => _sessions.add(_SessionRow()));
  void _removeSession(int i) {
    if (i == 0) return;
    setState(() => _sessions.removeAt(i));
  }

  List<String> get _teachingLabels =>
      _teachingIndices.map((i) => _labels[i]).toList();

  // --------------------- Clear Generated Schedule ---------------------

  void _clearGenerated() {
    setState(() {
      _labels.clear();
      _spans.clear();
      _teachingIndices.clear();
      _inferredPeriodMinutes = null;
      for (final s in _sessions) {
        s.periodDropdownIndex = null;
      }
    });
  }

  // --------------------- Save ---------------------

  void _save() {
    if (_department == null || _classKey == null || _section == null) {
      _snack('Please select Department, Class, and Section');
      return;
    }
    if ((_course ?? '').trim().isEmpty) {
      _snack('Please choose a Course');
      return;
    }
    if (!_configured) {
      _snack('Configure or load periods first');
      return;
    }
    _assertIntegrity();
    if (!_configured) {
      _snack('Schedule integrity failed; please reconfigure.');
      return;
    }

    final lecturerName = _useCustomLecturer
        ? _lecturerCustomCtrl.text.trim()
        : (_lecturer ?? '').trim();
    final cellText = lecturerName.isEmpty
        ? _course!.trim()
        : '${_course!.trim()}\n$lecturerName';

    final results = <CreateTimetableTimeResult>[];

    for (int i = 0; i < _sessions.length; i++) {
      final s = _sessions[i];
      if (s.dayIndex == null) {
        _snack('Session ${i + 1}: choose Day');
        return;
      }
      if (s.periodDropdownIndex == null) {
        _snack('Session ${i + 1}: choose Start period');
        return;
      }
      if (s.periodDropdownIndex! < 0 ||
          s.periodDropdownIndex! >= _teachingIndices.length) {
        _snack('Session ${i + 1}: invalid period selection');
        return;
      }
      final labelIdx = _teachingIndices[s.periodDropdownIndex!];
      if (labelIdx >= _spans.length) {
        _snack('Session ${i + 1}: internal span index error');
        return;
      }
      final span = _spans[labelIdx];
      results.add(
        CreateTimetableTimeResult(
          department: _department!.trim(),
          classKey: _classKey!.trim(),
          section: _section!.trim(),
          dayIndex: s.dayIndex!,
          startMinutes: span.$1,
          endMinutes: span.$2,
          cellText: cellText,
        ),
      );
    }

    if (results.isEmpty) {
      _snack('Nothing to save');
      return;
    }

    Navigator.of(context).pop(
      CreateTimetableTimePayload(
        results: results,
        periodsOverride: List<String>.from(_labels),
      ),
    );
  }

  // --------------------- UI utils ---------------------

  String _fmt(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '$h:${m.toString().padLeft(2, '0')}';
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  List<String> get _classesForDepartment {
    final d = _department;
    if (d == null) return [];
    final match = widget.departmentClasses.keys.firstWhere(
      (k) => k.toLowerCase() == d.toLowerCase(),
      orElse: () => '',
    );
    if (match.isEmpty) return [];
    return widget.departmentClasses[match] ?? [];
  }

  Widget _dropdownBox<T>({
    required String hint,
    required T? value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    Widget Function(T)? builder,
  }) {
    return InputDecorator(
      decoration: const InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        isDense: true,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true,
        fillColor: Colors.white,
      ).copyWith(hintText: hint),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          isExpanded: true,
          value: value,
          hint: Text(hint),
          items: items
              .map(
                (e) => DropdownMenuItem<T>(
                  value: e,
                  child: builder != null ? builder(e) : Text(e.toString()),
                ),
              )
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // Responsive container for fields (wraps on mobile)
  Widget _wrapFields(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Target widths that work on phones and tablets
        final double maxW = constraints.maxWidth;
        final double itemMax = maxW < 420
            ? maxW // single column
            : (maxW < 720 ? (maxW - 12) / 2 : 280); // 2 cols or fixed width
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: children
              .map((c) => ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: 180,
                      maxWidth: itemMax,
                    ),
                    child: c,
                  ))
              .toList(),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final teachingLabels = _teachingLabels;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Create Time Table Entry',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Dept / Class / Section (responsive)
                  _wrapFields([
                    _dropdownBox<String>(
                      hint: 'Department',
                      value: _department,
                      items: widget.departments,
                      onChanged: (v) => setState(() {
                        _department = v;
                        _classKey = null;
                      }),
                    ),
                    _dropdownBox<String>(
                      hint: 'Class',
                      value: _classKey,
                      items: _classesForDepartment.isNotEmpty
                          ? _classesForDepartment
                          : widget.departmentClasses.values
                              .expand((e) => e)
                              .toList(),
                      onChanged: (v) => setState(() => _classKey = v),
                    ),
                    _dropdownBox<String>(
                      hint: 'Section',
                      value: _section,
                      items: widget.sections,
                      onChanged: (v) => setState(() => _section = v),
                    ),
                  ]),

                  const SizedBox(height: 12),

                  // Lecturer / Course (responsive)
                  _wrapFields([
                    !_useCustomLecturer
                        ? _dropdownBox<String>(
                            hint: 'Lecturer',
                            value: _lecturer,
                            items: widget.lecturers,
                            onChanged: (v) => setState(() => _lecturer = v),
                          )
                        : TextFormField(
                            controller: _lecturerCustomCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Lecturer',
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                    _dropdownBox<String>(
                      hint: 'Course',
                      value: _course,
                      items: _courseList,
                      onChanged: (v) => setState(() => _course = v),
                    ),
                  ]),

                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Switch(
                        value: _useCustomLecturer,
                        onChanged: (v) => setState(() {
                          _useCustomLecturer = v;
                          if (!v) _lecturerCustomCtrl.clear();
                        }),
                      ),
                      const SizedBox(width: 6),
                      const Text('Custom lecturer'),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Schedule controls
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: _openFullGenerator,
                        icon: const Icon(Icons.settings),
                        label: Text(
                          _configured
                              ? 'Reconfigure periods'
                              : 'Configure periods',
                        ),
                      ),
                      if (_configured)
                        OutlinedButton(
                          onPressed: _clearGenerated,
                          child: const Text('Clear'),
                        ),
                    ],
                  ),

                  if (_configured) ...[
                    const SizedBox(height: 8),
                    // Labels chips (wrap nicely on mobile)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: List.generate(_labels.length, (i) {
                        final l = _labels[i];
                        final isBreak = l.toLowerCase().contains('break');
                        return Chip(
                          label: Text(
                            l,
                            style: const TextStyle(fontSize: 12),
                          ),
                          backgroundColor:
                              isBreak ? Colors.grey.shade200 : Colors.blue.shade50,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        );
                      }),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Ends at ${_fmt(_spans.last.$2)} • Teaching: '
                      '${_teachingTotalHours()} • Breaks: ${_totalBreakMinutes()}m'
                      '${_inferredPeriodMinutes != null ? ' • Period=${_inferredPeriodMinutes}m' : ''}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],

                  if (!_configured)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: const Text(
                        'Configure (or rely on an existing schedule) before adding sessions. '
                        'You can later append new periods or breaks without recreating everything.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Sessions
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Sessions',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _configured ? _addSession : null,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Session'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  if (_configured)
                    Column(
                      children: List.generate(_sessions.length, (i) {
                        final s = _sessions[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: _wrapFields([
                            _dropdownBox<int>(
                              hint: 'Day',
                              value: s.dayIndex,
                              items: List<int>.generate(
                                widget.days.length,
                                (d) => d,
                              ),
                              onChanged: (v) => setState(() => s.dayIndex = v),
                              builder: (d) => Text(widget.days[d]),
                            ),
                            _dropdownBox<int>(
                              hint: 'Start period',
                              value: s.periodDropdownIndex,
                              items: List<int>.generate(
                                teachingLabels.length,
                                (p) => p,
                              ),
                              onChanged: (v) => setState(() => s.periodDropdownIndex = v),
                              builder: (p) => Text(teachingLabels[p]),
                            ),
                            // Remove button as its own row item so it wraps
                            Row(
                              children: [
                                if (i > 0)
                                  IconButton(
                                    tooltip: 'Remove',
                                    onPressed: () => _removeSession(i),
                                    icon: const Icon(
                                      Icons.close,
                                      color: Colors.redAccent,
                                    ),
                                  )
                                else
                                  const SizedBox(width: 48),
                              ],
                            ),
                          ]),
                        );
                      }),
                    ),

                  const SizedBox(height: 16),

                  // Footer actions (stick to end)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
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
      ),
    );
  }

  String _teachingTotalHours() {
    int sum = 0;
    for (final idx in _teachingIndices) {
      final sp = _spans[idx];
      sum += sp.$2 - sp.$1;
    }
    final h = sum ~/ 60;
    final m = sum % 60;
    return '${h}h ${m}m';
  }

  int _totalBreakMinutes() {
    int total = 0;
    for (int i = 0; i < _labels.length; i++) {
      if (_labels[i].toLowerCase().contains('break')) {
        final sp = _spans[i];
        total += sp.$2 - sp.$1;
      }
    }
    return total;
  }
}

// Session row model
class _SessionRow {
  int? dayIndex;
  int? periodDropdownIndex;
}

/// Result from full generator
class _GeneratedScheduleResult {
  final List<String> labels;
  final List<(int, int)> spans;
  final List<int> teachingIndices;
  _GeneratedScheduleResult({
    required this.labels,
    required this.spans,
    required this.teachingIndices,
  });
}

/// Period generator dialog (same logic as before, simplified for reconfigure).
class _PeriodGeneratorDialog extends StatefulWidget {
  final List<String> existingLabels;
  final List<(int, int)> existingSpans;
  final List<int> existingTeachingIndices;

  const _PeriodGeneratorDialog({
    required this.existingLabels,
    required this.existingSpans,
    required this.existingTeachingIndices,
  });

  @override
  State<_PeriodGeneratorDialog> createState() => _PeriodGeneratorDialogState();
}

class _PeriodGeneratorDialogState extends State<_PeriodGeneratorDialog> {
  static const List<int> _presetDurations = [30, 45, 50, 60, 75, 90, 110, 120];

  int _dayStart = 8 * 60;
  int _periodMinutes = 110;
  int _periodCount = 4;
  bool _useCustom = false;
  int _customDuration = 110;
  final List<_BreakConfig> _breaks = [];

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  void _hydrate() {
    if (widget.existingLabels.isNotEmpty &&
        widget.existingSpans.length == widget.existingLabels.length &&
        widget.existingTeachingIndices.isNotEmpty) {
      // Infer from existing
      final firstTeach = widget.existingTeachingIndices.first;
      final span = widget.existingSpans[firstTeach];
      _dayStart = span.$1;
      final len = span.$2 - span.$1;
      _periodMinutes = len;
      if (!_presetDurations.contains(len)) {
        _useCustom = true;
        _customDuration = len;
      }
      _periodCount = widget.existingTeachingIndices.length;

      // Derive breaks
      _breaks.clear();
      int teachingSeen = 0;
      for (int i = 0; i < widget.existingLabels.length; i++) {
        final isBreak = widget.existingLabels[i].toLowerCase().contains('break');
        if (isBreak) {
          final sp = widget.existingSpans[i];
          final mins = sp.$2 - sp.$1;
          _breaks.add(_BreakConfig(after: teachingSeen, minutes: mins));
        } else {
          teachingSeen++;
        }
      }
      if (_breaks.isEmpty) _breaks.add(_BreakConfig());
    } else {
      _breaks.add(_BreakConfig());
    }
  }

  List<int> get _afterPeriodOptions =>
      (_periodCount <= 1) ? const [] : List<int>.generate(_periodCount - 1, (i) => i + 1);

  TimeOfDay _toTimeOfDay(int minutes) {
    final h = (minutes ~/ 60) % 24;
    final m = minutes % 60;
    return TimeOfDay(hour: h, minute: m);
  }

  String _fmt(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '$h:${m.toString().padLeft(2, '0')}';
  }

  void _generate() {
    if (_periodMinutes <= 0) {
      _toast('Period duration must be > 0');
      return;
    }
    if (_periodCount < 1) {
      _toast('Number of periods must be >=1');
      return;
    }
    final used = <int>{};
    for (final b in _breaks) {
      if (b.after == null) continue;
      final a = b.after!;
      if (a < 1 || a >= _periodCount) {
        _toast('Break after period must be in 1..${_periodCount - 1}');
        return;
      }
      if (used.contains(a)) {
        _toast('Duplicate break after period #$a');
        return;
      }
      if (b.minutes != null && b.minutes! <= 0) {
        _toast('Break minutes must be > 0');
        return;
      }
      used.add(a);
    }

    int t = _dayStart;
    final labels = <String>[];
    final spans = <(int, int)>[];
    final teachingIdx = <int>[];

    for (int i = 1; i <= _periodCount; i++) {
      final ps = t;
      final pe = t + _periodMinutes;
      labels.add('${_fmt(ps)} - ${_fmt(pe)}');
      spans.add((ps, pe));
      teachingIdx.add(labels.length - 1);
      t = pe;

      final b = _breaks.firstWhere(
        (x) => x.after == i,
        orElse: () => _BreakConfig(),
      );
      if (b.after == i && b.minutes != null && b.minutes! > 0) {
        final bs = t;
        final be = t + b.minutes!;
        labels.add('${_fmt(bs)} - ${_fmt(be)} (Break)');
        spans.add((bs, be));
        t = be;
      }
    }

    Navigator.pop(
      context,
      _GeneratedScheduleResult(
        labels: labels,
        spans: spans,
        teachingIndices: teachingIdx,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Configure Periods'),
      content: SizedBox(
        width: 600,
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Day start
              InkWell(
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _toTimeOfDay(_dayStart),
                  );
                  if (picked != null) {
                    setState(() => _dayStart = picked.hour * 60 + picked.minute);
                  }
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Day start',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      // Value text set below via LayoutBuilder (can't use const here)
                    ],
                  ),
                ),
              ),
              // The above Row placeholder gets replaced; show actual value below:
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(top: 6, left: 2),
                  child: Text(_fmt(_dayStart), style: const TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Period duration',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          isExpanded: true,
                          value: _useCustom
                              ? null
                              : (_presetDurations.contains(_periodMinutes)
                                  ? _periodMinutes
                                  : null),
                          hint: Text(_useCustom ? 'Custom (${_periodMinutes}m)' : '${_periodMinutes}m'),
                          items: _presetDurations
                              .map((m) => DropdownMenuItem<int>(value: m, child: Text('$m min')))
                              .toList()
                            ..add(const DropdownMenuItem<int>(value: -1, child: Text('Custom…'))),
                          onChanged: (v) {
                            if (v == null) return;
                            if (v == -1) {
                              setState(() => _useCustom = true);
                            } else {
                              setState(() {
                                _useCustom = false;
                                _periodMinutes = v;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (_useCustom)
                    Expanded(
                      child: TextFormField(
                        initialValue: _customDuration.toString(),
                        decoration: const InputDecoration(
                          labelText: 'Custom minutes',
                          border: OutlineInputBorder(),
                          isDense: true,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        onChanged: (v) {
                          final n = int.tryParse(v.trim());
                          if (n != null && n > 0) {
                            setState(() {
                              _customDuration = n;
                              _periodMinutes = n;
                            });
                          }
                        },
                      ),
                    ),
                  if (_useCustom) const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      initialValue: _periodCount.toString(),
                      decoration: const InputDecoration(
                        labelText: 'Number of periods',
                        border: OutlineInputBorder(),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (v) {
                        final n = int.tryParse(v.trim());
                        if (n != null && n >= 1 && n <= 40) setState(() => _periodCount = n);
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Breaks (optional)', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 6),
              Column(
                children: List.generate(_breaks.length, (i) {
                  final b = _breaks[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'After period #',
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                isExpanded: true,
                                value: b.after,
                                hint: const Text('Choose'),
                                items: _afterPeriodOptions
                                    .map((n) => DropdownMenuItem<int>(value: n, child: Text('$n')))
                                    .toList(),
                                onChanged: (v) => setState(() => b.after = v),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            initialValue: b.minutes?.toString() ?? '',
                            decoration: const InputDecoration(
                              labelText: 'Break minutes',
                              border: OutlineInputBorder(),
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            onChanged: (v) {
                              final n = int.tryParse(v.trim());
                              setState(() => b.minutes = (n != null && n > 0) ? n : null);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (i > 0)
                          IconButton(
                            onPressed: () {
                              if (_breaks.length > 1) setState(() => _breaks.removeAt(i));
                            },
                            icon: const Icon(Icons.close, color: Colors.redAccent),
                          )
                        else
                          const SizedBox(width: 40),
                      ],
                    ),
                  );
                }),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() => _breaks.add(_BreakConfig())),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Break'),
                ),
              ),
              const SizedBox(height: 12),
              _rulesBox(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: _generate, child: const Text('Generate')),
      ],
    );
  }

  Widget _rulesBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: const Text(
        'Rules:\n'
        '• Each teaching period = fixed duration.\n'
        '• Breaks can be any positive length after a period.\n'
        '• No duplicate breaks after the same period.\n'
        '• Final end time = start + (#periods × duration) + breaks.',
        style: TextStyle(fontSize: 12),
      ),
    );
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _BreakConfig {
  int? after;
  int? minutes;
  _BreakConfig({this.after, this.minutes});
}

/// Add new period or break dialog (incremental change)
class _AddPeriodDialog extends StatefulWidget {
  final List<(int, int)> existingSpans;
  final List<String> existingLabels;
  final int? periodMinutes;

  const _AddPeriodDialog({
    super.key,
    required this.existingSpans,
    required this.existingLabels,
    required this.periodMinutes,
  });

  @override
  State<_AddPeriodDialog> createState() => _AddPeriodDialogState();
}

class _AddPeriodDialogState extends State<_AddPeriodDialog> {
  bool isBreak = false;
  int? customBreakMinutes; // for breaks
  TimeOfDay? startPicker; // user-chosen start (must not overlap)
  String? error;

  String fmt(int m) => '${m ~/ 60}:${(m % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final periodLen = widget.periodMinutes;
    return AlertDialog(
      title: const Text('Add Period / Break'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Switch(
                  value: isBreak,
                  onChanged: (v) => setState(() {
                    isBreak = v;
                    error = null;
                  }),
                ),
                Text(isBreak ? 'Adding Break' : 'Adding Teaching Period'),
              ],
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final initial = startPicker ?? inferNextStart();
                final picked = await showTimePicker(
                  context: context,
                  initialTime: initial,
                );
                if (picked != null) {
                  setState(() {
                    startPicker = picked;
                    error = null;
                  });
                }
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Start time',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      startPicker == null
                          ? 'Tap to select'
                          : '${startPicker!.hour}:${startPicker!.minute.toString().padLeft(2, '0')}',
                    ),
                    const Icon(Icons.access_time, size: 18),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            if (isBreak)
              TextFormField(
                initialValue: customBreakMinutes?.toString() ?? '',
                decoration: const InputDecoration(
                  labelText: 'Break minutes',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (v) {
                  final n = int.tryParse(v.trim());
                  setState(() {
                    customBreakMinutes = (n != null && n > 0) ? n : null;
                    error = null;
                  });
                },
              )
            else
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Length (minutes)',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                child: Text(
                  periodLen != null
                      ? '$periodLen (fixed)'
                      : 'Inconsistent existing periods; please reconfigure',
                ),
              ),
            if (error != null) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            ],
            const SizedBox(height: 8),
            hintBox(periodLen),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: submit, child: const Text('Add')),
      ],
    );
  }

  _AddPeriodResult? buildResult() {
    if (startPicker == null) {
      error = 'Select a start time';
      return null;
    }
    final start = startPicker!.hour * 60 + startPicker!.minute;
    // Determine length
    int? length;
    if (isBreak) {
      if (customBreakMinutes == null || customBreakMinutes! <= 0) {
        error = 'Enter break minutes';
        return null;
      }
      length = customBreakMinutes;
    } else {
      if (widget.periodMinutes == null) {
        error = 'Period length inconsistent. Reconfigure.';
        return null;
      }
      length = widget.periodMinutes;
    }
    final end = start + length!;
    // Overlap check with existing spans
    for (final sp in widget.existingSpans) {
      final s = sp.$1;
      final e = sp.$2;
      final overlap = !(end <= s || start >= e);
      if (overlap) {
        error = 'Overlaps existing ${fmt(s)}-${fmt(e)}';
        return null;
      }
    }
    return _AddPeriodResult(start: start, end: end, isBreak: isBreak);
  }

  void submit() {
    setState(() => error = null);
    final res = buildResult();
    if (res == null) {
      setState(() {}); // refresh error
      return;
    }
    Navigator.pop(context, res);
  }

  TimeOfDay inferNextStart() {
    if (widget.existingSpans.isEmpty) {
      final now = TimeOfDay.now();
      return TimeOfDay(hour: now.hour, minute: 0);
    }
    // Suggest end of last span
    final lastEnd =
        widget.existingSpans.map((e) => e.$2).reduce((a, b) => a > b ? a : b);
    return TimeOfDay(hour: lastEnd ~/ 60, minute: lastEnd % 60);
  }

  Widget hintBox(int? periodLen) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: Text(
        isBreak
            ? 'Break can be any positive minutes. It must not overlap existing spans.'
            : (periodLen != null
                ? 'New teaching period will be exactly $periodLen minutes; choose a start time that does not overlap.'
                : 'Period length unknown (inconsistent). Please reconfigure.'),
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}

class _AddPeriodResult {
  final int start;
  final int end;
  final bool isBreak;
  _AddPeriodResult({
    required this.start,
    required this.end,
    required this.isBreak,
  });
}

class TimeSpan {
  final int start;
  final int end;

  TimeSpan({required this.start, required this.end});
}