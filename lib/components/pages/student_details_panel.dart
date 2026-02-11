import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../theme/super_admin_theme.dart';

class StudentDetailsPanel extends StatefulWidget {
  final String studentId;
  final String? studentName;
  final String? studentClass;
  final String? selectedCourse;
  final bool compact;
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
    this.selectedCourse,
    this.compact = false,
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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late List<Map<String, dynamic>> editRecords;
  bool _noRecordsSnackShown = false;

  bool loading = true;
  String? _displayName;
  String? _displayClass;
  String? _loadError;

  bool _matchesSelectedCourse(String courseName) {
    final selected = (widget.selectedCourse ?? '').trim().toLowerCase();
    if (selected.isEmpty) return true;
    return courseName.trim().toLowerCase() == selected;
  }

  bool _attendanceDocBelongsToStudent(Map<String, dynamic> data) {
    final target = widget.studentId.trim().toLowerCase();
    if (target.isEmpty) return false;
    final candidates = [
      data['username'],
      data['user'],
      data['student_username'],
      data['studentId'],
      data['student_id'],
    ];
    for (final c in candidates) {
      final s = (c ?? '').toString().trim().toLowerCase();
      if (s.isNotEmpty && s == target) return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    editRecords = widget.attendanceRecords.map((e) => Map<String, dynamic>.from(e)).toList();
    _displayName = widget.studentName;
    _displayClass = widget.studentClass;
    _loadAndCompute();
  }

  @override
  void didUpdateWidget(covariant StudentDetailsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final studentChanged = oldWidget.studentId != widget.studentId;
    final classChanged = oldWidget.studentClass != widget.studentClass;
    final courseChanged = oldWidget.selectedCourse != widget.selectedCourse;
    final recordsChanged = oldWidget.attendanceRecords != widget.attendanceRecords;

    if (studentChanged || classChanged || courseChanged || recordsChanged) {
      editRecords = widget.attendanceRecords
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      _displayName = widget.studentName;
      _displayClass = widget.studentClass;
      _noRecordsSnackShown = false;
      _loadAndCompute();
    }
  }

  Future<void> _loadAndCompute() async {
    setState(() {
      loading = true;
      _loadError = null;
    });

    try {
      try {
        final q = await _firestore
            .collection('students')
            .where('username', isEqualTo: widget.studentId)
            .limit(1)
            .get();
        if (q.docs.isNotEmpty) {
          final doc = q.docs.first;
          final data = doc.data();
          _displayName = (data['fullname'] ?? data['fullName'] ?? data['name'] ?? _displayName)?.toString();
          _displayClass = (data['className'] ?? data['class_name'] ?? data['class'] ?? _displayClass)?.toString();
          if (data['courses'] is List && (data['courses'] as List).isNotEmpty) {
            final parsed = <Map<String, dynamic>>[];
            for (final c in List.from(data['courses'])) {
              if (c is Map) parsed.add(Map<String, dynamic>.from(c));
            }
            if (parsed.isNotEmpty) {
              editRecords = parsed.map((e) => Map<String, dynamic>.from(e)).toList();
            }
          }
        } else {
          final doc = await _firestore
              .collection('students')
              .doc(widget.studentId)
              .get();
          if (doc.exists) {
            final data = doc.data();
            _displayName = (data?['fullname'] ?? data?['fullName'] ?? data?['name'] ?? _displayName)?.toString();
            _displayClass = (data?['className'] ?? data?['class_name'] ?? data?['class'] ?? _displayClass)?.toString();
            if (data != null && data['courses'] is List && (data['courses'] as List).isNotEmpty) {
              final parsed = <Map<String, dynamic>>[];
              for (final c in List.from(data['courses'])) {
                if (c is Map) parsed.add(Map<String, dynamic>.from(c));
              }
              if (parsed.isNotEmpty) {
                editRecords = parsed.map((e) => Map<String, dynamic>.from(e)).toList();
              }
            }
          }
        }
      } catch (e) {}

      if (editRecords.isEmpty) {
        final synthesized = await _buildCoursesFromAttendanceRecords();
        if (synthesized.isNotEmpty) {
          editRecords = synthesized.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }

      if (editRecords.isEmpty) {
        final fromSessions = await _buildCoursesFromQrGeneration();
        if (fromSessions.isNotEmpty) {
          editRecords = fromSessions.map((e) => Map<String, dynamic>.from(e)).toList();
        }
      }

      await _computeTotalsForRecords(editRecords);
    } catch (e) {
      _loadError = 'Failed to load student data: $e';
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _buildCoursesFromAttendanceRecords() async {
    try {
      Query<Map<String, dynamic>> q = _firestore.collection('attendance_records');
      if (widget.studentClass != null && widget.studentClass!.isNotEmpty) {
        q = q.where('className', isEqualTo: widget.studentClass);
      }
      final snap = await q.get();
      if (snap.docs.isEmpty) return [];

      final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> groups = {};
      for (final d in snap.docs) {
        final data = d.data();
        if (!_attendanceDocBelongsToStudent(data)) continue;
        final subj = (data['subject'] ?? data['course'] ?? '').toString();
        if (subj.isEmpty) continue;
        if (!_matchesSelectedCourse(subj)) continue;
        groups.putIfAbsent(subj, () => []).add(d);
      }

      final List<Map<String, dynamic>> result = [];
      for (final entry in groups.entries) {
        final subj = entry.key;
        final docs = entry.value;
        final total = docs.length;
        final present = docs.where((d) {
          final v = d.data()['present'];
          if (v is bool) return v;
          if (v is num) return v != 0;
          return false;
        }).length;
        final absence = total > 0 ? ((total - present) / total) * 100 : 0.0;
        result.add({
          'course': subj,
          'total': total,
          'present': present,
          'percentage': "${absence.toStringAsFixed(1)}%",
        });
      }
      return result;
    } catch (e) {
      debugPrint('Error building courses from attendance_records: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _buildCoursesFromQrGeneration() async {
    try {
      Query<Map<String, dynamic>> q = _firestore.collection('qr_generation');
      if (widget.studentClass != null && widget.studentClass!.isNotEmpty) {
        q = q.where('className', isEqualTo: widget.studentClass);
      }
      final snap = await q.get();
      if (snap.docs.isEmpty) return [];

      final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>> groups = {};
      for (final d in snap.docs) {
        final subj = (d.data()['subject'] ?? '').toString();
        if (subj.isEmpty) continue;
        if (!_matchesSelectedCourse(subj)) continue;
        groups.putIfAbsent(subj, () => []).add(d);
      }

      final List<Map<String, dynamic>> result = [];
      for (final entry in groups.entries) {
        final subj = entry.key;
        final sessions = entry.value;
        final sessionIds = sessions.map((s) => s.id).toList();
        final sessionCodes = sessions
            .map((s) => (s.data()['code']?.toString()))
            .whereType<String>()
            .toList();

        final countedAttendanceDocIds = <String>{};

        if (sessionIds.isNotEmpty) {
          const batchSize = 10;
          for (var i = 0; i < sessionIds.length; i += batchSize) {
            final sub = sessionIds.sublist(
              i,
              (i + batchSize > sessionIds.length)
                  ? sessionIds.length
                  : i + batchSize,
            );
            final q2 = await _firestore
                .collection('attendance_records')
                .where('session_id', whereIn: sub)
                .get();
            for (final ad in q2.docs) {
              if (!_attendanceDocBelongsToStudent(ad.data())) continue;
              countedAttendanceDocIds.add(ad.id);
            }
          }
        }

        if (sessionCodes.isNotEmpty) {
          const batchSize = 10;
          for (var i = 0; i < sessionCodes.length; i += batchSize) {
            final sub = sessionCodes.sublist(
              i,
              (i + batchSize > sessionCodes.length)
                  ? sessionCodes.length
                  : i + batchSize,
            );
            final q3 = await _firestore
                .collection('attendance_records')
                .where('code', whereIn: sub)
                .get();
            for (final ad in q3.docs) {
              if (!_attendanceDocBelongsToStudent(ad.data())) continue;
              countedAttendanceDocIds.add(ad.id);
            }
          }
        }

        final presentCount = countedAttendanceDocIds.length;
        final totalSessions = sessionIds.length;

        final absence = (totalSessions > 0)
            ? ((totalSessions - presentCount) / totalSessions) * 100
            : 0.0;

        result.add({
          'course': subj,
          'total': totalSessions,
          'present': presentCount,
          'percentage': "${absence.toStringAsFixed(1)}%",
        });
      }

      return result;
    } catch (e) {
      debugPrint('Error building courses from qr_generation: $e');
      return [];
    }
  }

  Future<void> _computeTotalsForRecords(List<Map<String, dynamic>> records) async {
    for (final record in records) {
      final courseName = (record['course'] ?? '').toString();
      if (courseName.isEmpty) {
        record['total'] = 0;
        record['present'] = 0;
        record['percentage'] = "0%";
        continue;
      }

      try {
        Query<Map<String, dynamic>> sessionQuery = _firestore
            .collection('qr_generation')
            .where('subject', isEqualTo: courseName);
        if (widget.studentClass != null && widget.studentClass!.isNotEmpty) {
          sessionQuery = sessionQuery.where('className', isEqualTo: widget.studentClass);
        }
        final sessionSnap = await sessionQuery.get();
        final sessionDocs = sessionSnap.docs;
        final sessionIds = sessionDocs.map((d) => d.id).toList();
        final sessionCodes = sessionDocs
            .map((d) => (d.data()['code']?.toString()))
            .whereType<String>()
            .toList();

        final countedAttendanceDocIds = <String>{};

        if (sessionIds.isNotEmpty) {
          const batchSize = 10;
          for (var i = 0; i < sessionIds.length; i += batchSize) {
            final sub = sessionIds.sublist(
              i,
              (i + batchSize > sessionIds.length)
                  ? sessionIds.length
                  : i + batchSize,
            );
            final q = await _firestore
                .collection('attendance_records')
                .where('session_id', whereIn: sub)
                .get();
            for (final ad in q.docs) {
              if (!_attendanceDocBelongsToStudent(ad.data())) continue;
              countedAttendanceDocIds.add(ad.id);
            }
          }
        }

        if (sessionCodes.isNotEmpty) {
          const batchSize = 10;
          for (var i = 0; i < sessionCodes.length; i += batchSize) {
            final sub = sessionCodes.sublist(
              i,
              (i + batchSize > sessionCodes.length)
                  ? sessionCodes.length
                  : i + batchSize,
            );
            final q = await _firestore
                .collection('attendance_records')
                .where('code', whereIn: sub)
                .get();
            for (final ad in q.docs) {
              if (!_attendanceDocBelongsToStudent(ad.data())) continue;
              countedAttendanceDocIds.add(ad.id);
            }
          }
        }

        int presentCount = countedAttendanceDocIds.length;
        final totalSessions = sessionIds.length;
        if (totalSessions == 0) {
          final q = await _firestore
              .collection('attendance_records')
              .where('subject', isEqualTo: courseName)
              .get();
          presentCount = q.docs
              .where((d) => _attendanceDocBelongsToStudent(d.data()))
              .map((d) => d.id)
              .toSet()
              .length;
        }

        record['total'] = totalSessions;
        record['present'] = presentCount;
        final total = (record['total'] is num) ? (record['total'] as num) : 0;
        final absence = (total > 0) ? ((total - presentCount) / total) * 100 : 0.0;
        record['percentage'] = "${absence.toStringAsFixed(1)}%";
      } catch (e) {
        record['total'] = 0;
        record['present'] = 0;
        record['percentage'] = "0%";
        debugPrint('Error computing totals for course ${record['course']}: $e');
      }
    }

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<SuperAdminColors>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (loading) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 24),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_loadError!, style: const TextStyle(color: Colors.red)),
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
      );
    }

    final sourceRecords = editRecords.isNotEmpty
        ? editRecords
        : widget.attendanceRecords;
    final records = List<Map<String, dynamic>>.from(
      sourceRecords.map((e) => Map<String, dynamic>.from(e)),
    );
    final filteredRecords = records
        .where(
          (rec) => rec["course"].toString().toLowerCase().contains(
                widget.searchText.toLowerCase(),
              ),
        )
        .where((rec) => _matchesSelectedCourse(rec["course"]?.toString() ?? ''))
        .toList();

    final totalQr = filteredRecords.fold<int>(
      0,
      (sum, r) => sum + ((r['total'] as num?)?.toInt() ?? 0),
    );
    final totalPresent = filteredRecords.fold<int>(
      0,
      (sum, r) => sum + ((r['present'] as num?)?.toInt() ?? 0),
    );
    final totalAbsence = (totalQr - totalPresent) < 0 ? 0 : (totalQr - totalPresent);
    final absencePct = totalQr > 0 ? ((totalAbsence / totalQr) * 100).round() : 0;

    if (!loading &&
        filteredRecords.isEmpty &&
        !_noRecordsSnackShown &&
        !widget.compact) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No attendance records found'),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          ),
        );
      });
      _noRecordsSnackShown = true;
    }

    if (widget.compact) {
      final scheme = Theme.of(context).colorScheme;
      final displayName = _displayName ?? widget.studentName ?? widget.studentId;
      final displayClass = _displayClass ?? widget.studentClass ?? '';
      final selectedCourse = (widget.selectedCourse ?? '').trim();

      return Container(
        width: double.infinity,
        color: palette?.surface,
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 21,
                    backgroundColor:
                        palette?.highlight ??
                        scheme.primaryContainer.withValues(alpha: 0.7),
                    child: Text(
                      _initials,
                      style: TextStyle(
                        color: palette?.textPrimary ?? scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: palette?.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '@${widget.studentId}',
                          style: TextStyle(
                            fontSize: 13,
                            color: palette?.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _metaChip(label: 'Class: $displayClass'),
                            if (selectedCourse.isNotEmpty)
                              _metaChip(label: 'Course: $selectedCourse'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _kpiCard('Total QR', totalQr.toString())),
                  const SizedBox(width: 8),
                  Expanded(child: _kpiCard('Present', totalPresent.toString())),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _kpiCard(
                      'Absence %',
                      '$absencePct%',
                      emphasize: true,
                      danger: absencePct > 25,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'Attendance Summary',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: palette?.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: palette?.border ?? scheme.outline.withValues(alpha: 0.35),
                  ),
                ),
                child: filteredRecords.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'No attendance records for this selection.',
                          style: TextStyle(color: palette?.textSecondary),
                        ),
                      )
                    : Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: palette?.surfaceHigh,
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(10),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Expanded(flex: 4, child: Text('Course')),
                                Expanded(flex: 2, child: Text('Total')),
                                Expanded(flex: 2, child: Text('Present')),
                                Expanded(flex: 2, child: Text('Abs %')),
                              ],
                            ),
                          ),
                          ...filteredRecords.map((record) {
                            final percent =
                                (record['percentage'] ?? '0.0%').toString();
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(
                                    color: palette?.border ??
                                        scheme.outline.withValues(alpha: 0.35),
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 4,
                                    child: Text(
                                      (record['course'] ?? '').toString(),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      (record['total'] ?? 0).toString(),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      (record['present'] ?? 0).toString(),
                                    ),
                                  ),
                                  Expanded(flex: 2, child: _percentBadge(percent)),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      color: palette?.surface,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.onBack != null)
              Padding(
                padding: const EdgeInsets.only(left: 6, bottom: 8),
                child: IconButton(
                  onPressed: widget.onBack,
                  icon: Icon(
                    Icons.arrow_back_ios_new,
                    size: 18,
                    color: palette?.accent,
                  ),
                  tooltip: 'Back',
                  splashRadius: 22,
                ),
              ),
            // Use LayoutBuilder for responsive Card width/padding
            LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth < 600;
                return Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isMobile ? double.infinity : 1100,
                    ),
                    child: Card(
                      margin: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 0),
                      elevation: 6,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      color: palette?.surfaceHigh,
                      shadowColor: Theme.of(
                        context,
                      ).shadowColor.withValues(alpha: 0.08),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 8 : 24,
                          vertical: isMobile ? 8 : 20,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Top info block
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: palette?.highlight ??
                                      (isDark
                                          ? Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerHighest
                                          : Theme.of(context)
                                              .colorScheme
                                              .primaryContainer
                                              .withValues(alpha: 0.6)),
                                  child: Text(
                                    _initials,
                                    style: TextStyle(
                                      color: palette?.textPrimary ??
                                          Theme.of(context).colorScheme.onSurface,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _displayName ??
                                            widget.studentName ??
                                            widget.studentId,
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w800,
                                          color: palette?.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '@${widget.studentId}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: palette?.textSecondary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.school_outlined,
                                            size: 18,
                                            color: palette?.textSecondary,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Class: ${_displayClass ?? widget.studentClass ?? ''}',
                                            style: TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                              color: palette?.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.menu_book_outlined,
                                            size: 18,
                                            color: palette?.textSecondary,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            'Student Attendance Overview',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: palette?.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Divider(height: 1, color: palette?.border),
                            const SizedBox(height: 20),
                            Text(
                              'Attendance Summary',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: palette?.textPrimary,
                                shadows: [
                                  Shadow(
                                    color: Theme.of(
                                      context,
                                    ).shadowColor.withValues(alpha: 0.06),
                                    blurRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: palette?.border ??
                                      Theme.of(
                                        context,
                                      ).colorScheme.outline.withValues(alpha: 0.35),
                                ),
                              ),
                              child: filteredRecords.isEmpty
                                  ? const SizedBox(height: 48)
                                  : SizedBox(
                                      height: 420,
                                      child: SingleChildScrollView(
                                        padding: const EdgeInsets.all(8),
                                        child: SingleChildScrollView(
                                          scrollDirection: Axis.horizontal,
                                          child: DataTable(
                                            columnSpacing: 48.0,
                                            headingRowHeight: 46,
                                            dataRowHeight: 44,
                                            headingRowColor: WidgetStateProperty.all<Color?>(
                                              palette?.surfaceHigh,
                                            ),
                                            dataRowColor: WidgetStateProperty.resolveWith<Color?>(
                                              (states) => states.contains(WidgetState.hovered)
                                                  ? palette?.overlay
                                                  : palette?.surface,
                                            ),
                                            columns: const [
                                              DataColumn(
                                                label: Padding(
                                                  padding: EdgeInsets.symmetric(
                                                    vertical: 6.0,
                                                  ),
                                                  child: Text(
                                                    "Course",
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 15,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              DataColumn(
                                                label: Padding(
                                                  padding: EdgeInsets.symmetric(
                                                    vertical: 6.0,
                                                  ),
                                                  child: Text(
                                                    "Total QR",
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 15,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              DataColumn(
                                                label: Padding(
                                                  padding: EdgeInsets.symmetric(
                                                    vertical: 6.0,
                                                  ),
                                                  child: Text(
                                                    "Present",
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 15,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              DataColumn(
                                                label: Padding(
                                                  padding: EdgeInsets.symmetric(
                                                    vertical: 6.0,
                                                  ),
                                                  child: Text(
                                                    "Absence %",
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w600,
                                                      fontSize: 15,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                            rows: List.generate(
                                              filteredRecords.length,
                                              (i) {
                                                final record = filteredRecords[i];
                                                final course =
                                                    record["course"]?.toString() ?? "";
                                                final total =
                                                    (record["total"] ?? 0).toString();
                                                final present =
                                                    (record["present"] ?? 0).toString();
                                                final percent =
                                                    (record["percentage"] ?? "0.0%").toString();
                                                final headerTextColor = palette?.textPrimary;
                                                return DataRow(
                                                  cells: [
                                                    DataCell(
                                                      Text(
                                                        course,
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          color: headerTextColor,
                                                        ),
                                                      ),
                                                    ),
                                                    DataCell(
                                                      Text(
                                                        total,
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          color: headerTextColor,
                                                        ),
                                                      ),
                                                    ),
                                                    DataCell(
                                                      Text(
                                                        present,
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          color: headerTextColor,
                                                        ),
                                                      ),
                                                    ),
                                                    DataCell(
                                                      _percentBadge(percent),
                                                    ),
                                                  ],
                                                );
                                              },
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  String get _initials {
    final source = (_displayName ?? widget.studentName ?? widget.studentId).trim();
    if (source.isEmpty) return "?";
    final parts = source.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  Widget _percentBadge(String value) {
    final scheme = Theme.of(context).colorScheme;
    final pct = _parsePercent(value);
    Color bg;
    Color fg;
    if (pct <= 10) {
      bg = scheme.tertiaryContainer.withValues(alpha: 0.75);
      fg = scheme.onTertiaryContainer;
    } else if (pct <= 25) {
      bg = scheme.secondaryContainer.withValues(alpha: 0.75);
      fg = scheme.onSecondaryContainer;
    } else {
      bg = scheme.errorContainer.withValues(alpha: 0.72);
      fg = scheme.onErrorContainer;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        value,
        style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }

  double _parsePercent(String value) {
    final cleaned = value.replaceAll('%', '').trim();
    return double.tryParse(cleaned) ?? 0.0;
  }

  Widget _metaChip({required String label}) {
    final palette = Theme.of(context).extension<SuperAdminColors>();
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: palette?.border ?? scheme.outline.withValues(alpha: 0.35),
        ),
        color: palette?.surfaceHigh ?? scheme.surfaceContainerHighest,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: palette?.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _kpiCard(
    String title,
    String value, {
    bool emphasize = false,
    bool danger = false,
  }) {
    final palette = Theme.of(context).extension<SuperAdminColors>();
    final scheme = Theme.of(context).colorScheme;
    final bg = danger
        ? scheme.errorContainer.withValues(alpha: 0.72)
        : (emphasize
              ? scheme.primaryContainer.withValues(alpha: 0.6)
              : (palette?.surfaceHigh ?? scheme.surfaceContainerHighest));
    final fg = danger
        ? scheme.onErrorContainer
        : (palette?.textPrimary ?? scheme.onSurface);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: bg,
        border: Border.all(
          color: palette?.border ?? scheme.outline.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              color: palette?.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
