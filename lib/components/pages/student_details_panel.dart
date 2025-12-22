import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../theme/super_admin_theme.dart';

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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  late List<Map<String, dynamic>> editRecords;

  // Firestore state
  bool loading = true;
  String? _displayName;
  String? _displayClass;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    // start from parent-supplied records (fallback)
    editRecords = widget.attendanceRecords
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    _displayName = widget.studentName;
    _displayClass = widget.studentClass;
    _loadAndCompute();
  }

  Future<void> _loadAndCompute() async {
    setState(() {
      loading = true;
      _loadError = null;
    });

    try {
      // 1) Load student doc (if present) and use courses[] if available
      try {
        final q = await _firestore
            .collection('students')
            .where('username', isEqualTo: widget.studentId)
            .limit(1)
            .get();
        if (q.docs.isNotEmpty) {
          final doc = q.docs.first;
          final data = doc.data();
          _displayName =
              (data['fullname'] ??
                      data['fullName'] ??
                      data['name'] ??
                      _displayName)
                  ?.toString();
          _displayClass =
              (data['className'] ??
                      data['class_name'] ??
                      data['class'] ??
                      _displayClass)
                  ?.toString();

          if (data['courses'] is List && (data['courses'] as List).isNotEmpty) {
            final parsed = <Map<String, dynamic>>[];
            for (final c in List.from(data['courses'])) {
              if (c is Map) parsed.add(Map<String, dynamic>.from(c));
            }
            if (parsed.isNotEmpty) {
              editRecords = parsed
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList();
            }
          }
        } else {
          // try as doc id
          final doc = await _firestore
              .collection('students')
              .doc(widget.studentId)
              .get();
          if (doc.exists) {
            final data = doc.data();
            _displayName =
                (data?['fullname'] ??
                        data?['fullName'] ??
                        data?['name'] ??
                        _displayName)
                    ?.toString();
            _displayClass =
                (data?['className'] ??
                        data?['class_name'] ??
                        data?['class'] ??
                        _displayClass)
                    ?.toString();
            if (data != null &&
                data['courses'] is List &&
                (data['courses'] as List).isNotEmpty) {
              final parsed = <Map<String, dynamic>>[];
              for (final c in List.from(data['courses'])) {
                if (c is Map) parsed.add(Map<String, dynamic>.from(c));
              }
              if (parsed.isNotEmpty) {
                editRecords = parsed
                    .map((e) => Map<String, dynamic>.from(e))
                    .toList();
              }
            }
          }
        }
      } catch (e) {
        // ignore lookup errors here; we'll handle below
      }

      // 2) If no courses found in student doc, synthesize from attendance_records grouping
      if (editRecords.isEmpty) {
        final synthesized = await _buildCoursesFromAttendanceRecords();
        if (synthesized.isNotEmpty) {
          editRecords = synthesized
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }

      // 3) If still empty, build course list from qr_generation sessions for the student's class
      if (editRecords.isEmpty) {
        final fromSessions = await _buildCoursesFromQrGeneration();
        if (fromSessions.isNotEmpty) {
          editRecords = fromSessions
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }

      // 4) For each course record compute totals & present counts (overrides/sets record['total'] and record['present'])
      await _computeTotalsForRecords(editRecords);
    } catch (e) {
      _loadError = 'Failed to load student data: $e';
    } finally {
      setState(() {
        loading = false;
      });
    }
  }

  // Build course summaries from attendance_records when student.courses absent
  // Groups attendance_records by subject (or 'course' field if present) and computes counts.
  Future<List<Map<String, dynamic>>>
  _buildCoursesFromAttendanceRecords() async {
    try {
      Query<Map<String, dynamic>> q = _firestore
          .collection('attendance_records')
          .where('username', isEqualTo: widget.studentId);
      if (widget.studentClass != null && widget.studentClass!.isNotEmpty) {
        q = q.where('className', isEqualTo: widget.studentClass);
      }
      final snap = await q.get();
      if (snap.docs.isEmpty) return [];

      final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      groups = {};
      for (final d in snap.docs) {
        final data = d.data();
        final subj = (data['subject'] ?? data['course'] ?? '').toString();
        if (subj.isEmpty) continue;
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
        result.add({
          'course': subj,
          'total': total,
          'present': present,
          'percentage': total > 0
              ? "${((present / total) * 100).toStringAsFixed(1)}%"
              : "0%",
        });
      }
      return result;
    } catch (e) {
      debugPrint('Error building courses from attendance_records: $e');
      return [];
    }
  }

  // Build courses list from qr_generation sessions for student's class when there are no attendance docs
  // For each subject present in qr_generation for this class, compute total sessions and student's present count (may be 0).
  Future<List<Map<String, dynamic>>> _buildCoursesFromQrGeneration() async {
    try {
      Query<Map<String, dynamic>> q = _firestore.collection('qr_generation');
      if (widget.studentClass != null && widget.studentClass!.isNotEmpty) {
        q = q.where('className', isEqualTo: widget.studentClass);
      }
      final snap = await q.get();
      if (snap.docs.isEmpty) return [];

      // Group sessions by subject
      final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      groups = {};
      for (final d in snap.docs) {
        final subj = (d.data()['subject'] ?? '').toString();
        if (subj.isEmpty) continue;
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

        // Count student's attendance docs for these sessions (may be zero)
        final countedAttendanceDocIds = <String>{};

        // Query by session_id in batches
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
                .where('username', isEqualTo: widget.studentId)
                .where('session_id', whereIn: sub)
                .get();
            for (final ad in q2.docs) {
              countedAttendanceDocIds.add(ad.id);
            }
          }
        }

        // Query by code in batches
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
                .where('username', isEqualTo: widget.studentId)
                .where('code', whereIn: sub)
                .get();
            for (final ad in q3.docs) {
              countedAttendanceDocIds.add(ad.id);
            }
          }
        }

        final presentCount = countedAttendanceDocIds.length;
        final totalSessions = sessionIds.length;

        final percent = (totalSessions > 0)
            ? ((presentCount / totalSessions) * 100)
            : 0.0;

        result.add({
          'course': subj,
          'total': totalSessions,
          'present': presentCount,
          'percentage': "${percent.toStringAsFixed(1)}%",
        });
      }

      return result;
    } catch (e) {
      debugPrint('Error building courses from qr_generation: $e');
      return [];
    }
  }

  // For each record (by course name) compute totals & present counts by matching qr_generation sessions
  Future<void> _computeTotalsForRecords(
    List<Map<String, dynamic>> records,
  ) async {
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
          sessionQuery = sessionQuery.where(
            'className',
            isEqualTo: widget.studentClass,
          );
        }
        final sessionSnap = await sessionQuery.get();
        final sessionDocs = sessionSnap.docs;
        final sessionIds = sessionDocs.map((d) => d.id).toList();
        final sessionCodes = sessionDocs
            .map((d) => (d.data()['code']?.toString()))
            .whereType<String>()
            .toList();

        final countedAttendanceDocIds = <String>{};

        // count attendance docs by session_id (batched)
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
                .where('username', isEqualTo: widget.studentId)
                .where('session_id', whereIn: sub)
                .get();
            for (final ad in q.docs) {
              countedAttendanceDocIds.add(ad.id);
            }
          }
        }

        // count attendance docs by code (batched)
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
                .where('username', isEqualTo: widget.studentId)
                .where('code', whereIn: sub)
                .get();
            for (final ad in q.docs) {
              countedAttendanceDocIds.add(ad.id);
            }
          }
        }

        // If no sessions found for this course, fallback to counting attendance_records by subject
        int presentCount = countedAttendanceDocIds.length;
        final totalSessions = sessionIds.length;
        if (totalSessions == 0) {
          final q = await _firestore
              .collection('attendance_records')
              .where('username', isEqualTo: widget.studentId)
              .where('subject', isEqualTo: courseName)
              .get();
          presentCount = q.docs.map((d) => d.id).toSet().length;
        }

        record['total'] = totalSessions;
        record['present'] = presentCount;
        final percent = (record['total'] is num && (record['total'] as num) > 0)
            ? ((presentCount / (record['total'] as num)) * 100)
            : 0.0;
        record['percentage'] = "${percent.toStringAsFixed(1)}%";
      } catch (e) {
        record['total'] = 0;
        record['present'] = 0;
        record['percentage'] = "0%";
        debugPrint('Error computing totals for course ${record['course']}: $e');
      }
    }

    setState(() {});
  }

  // Edit actions removed (view-only panel)

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

    // Use DB-backed records when available, otherwise fall back to widget.attendanceRecords
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
        .toList();

    return Container(
      width: double.infinity,
      color: palette?.surface,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
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
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Card(
                elevation: 6,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: palette?.surfaceHigh,
                shadowColor: Colors.black.withOpacity(0.05),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
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
                            backgroundColor:
                                palette?.highlight ??
                                (isDark
                                    ? const Color(0xFF2A2F3A)
                                    : const Color(0xFFE5EDFF)),
                            child: Text(
                              _initials,
                              style: TextStyle(
                                color:
                                    palette?.textPrimary ??
                                    (isDark ? Colors.white : Colors.black),
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
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (filteredRecords.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24.0),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 56,
                                  color: Colors.grey[500],
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'No attendance records available for this student.',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Color(0xFF6D6D6D),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                if (widget.onBack != null)
                                  OutlinedButton.icon(
                                    onPressed: widget.onBack,
                                    icon: const Icon(
                                      Icons.arrow_back_ios_new,
                                      size: 16,
                                    ),
                                    label: const Text('Back'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: const Color(0xFF2563EB),
                                      side: const BorderSide(
                                        color: Color(0xFF2563EB),
                                        width: 1.1,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 10,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(24),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        )
                      else
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: palette?.border ?? const Color(0xFFE5E7EB),
                            ),
                          ),
                          child: DataTable(
                            columnSpacing: 48,
                            headingRowHeight: 46,
                            dataRowHeight: 44,
                            headingRowColor: WidgetStateProperty.all(
                              palette?.surfaceHigh,
                            ),
                            dataRowColor: WidgetStateProperty.resolveWith(
                              (states) => states.contains(WidgetState.hovered)
                                  ? palette?.overlay
                                  : palette?.surface,
                            ),
                            columns: const [
                              DataColumn(
                                label: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 6.0),
                                  child: Text(
                                    "Course",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      // color will be set below dynamically
                                    ),
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 6.0),
                                  child: Text(
                                    "Total QR",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      // color will be set below dynamically
                                    ),
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 6.0),
                                  child: Text(
                                    "Present",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      // color will be set below dynamically
                                    ),
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 6.0),
                                  child: Text(
                                    "Percentage",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                      // color will be set below dynamically
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            rows: List.generate(filteredRecords.length, (i) {
                              final record = filteredRecords[i];
                              final course = record["course"]?.toString() ?? "";
                              final total = (record["total"] ?? 0).toString();
                              final present = (record["present"] ?? 0)
                                  .toString();
                              final percent = (record["percentage"] ?? "0%")
                                  .toString();
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
                                  DataCell(_percentBadge(percent)),
                                ],
                              );
                            }),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _initials {
    final source = (_displayName ?? widget.studentName ?? widget.studentId)
        .trim();
    if (source.isEmpty) return "?";
    final parts = source.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }

  Widget _percentBadge(String value) {
    final pct = _parsePercent(value);
    Color bg;
    Color fg;
    if (pct >= 90) {
      bg = const Color(0xFFEFFAF3);
      fg = const Color(0xFF16A34A);
    } else if (pct >= 75) {
      bg = const Color(0xFFFEF7E8);
      fg = const Color(0xFFF59E0B);
    } else {
      bg = const Color(0xFFFEECEC);
      fg = const Color(0xFFDC2626);
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
}
