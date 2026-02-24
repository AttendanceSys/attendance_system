// StudentViewAttendanceMobile — show only student's class subjects & attendance
// - Typed Firestore queries, fallback matching, and fixed bottom navigation layout
// - Fix: replaced empty InkWell that caused infinite width error with fixed-size placeholder

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/session.dart';
import 'student_profile_page.dart';
import 'student_scan_attendance_page.dart';
import '../../components/animated_bottom_bar.dart';
import '../../components/student_theme_controller.dart';
import 'package:shimmer/shimmer.dart';
import 'package:fl_chart/fl_chart.dart';

class StudentViewAttendanceMobile extends StatefulWidget {
  const StudentViewAttendanceMobile({super.key});

  @override
  State<StudentViewAttendanceMobile> createState() =>
      _StudentViewAttendanceMobileState();
}

class _StudentViewAttendanceMobileState
    extends State<StudentViewAttendanceMobile> {
  List<Map<String, dynamic>> attendance = [];
  String _searchQuery = '';
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();
  bool isLoading = true;
  String? errorMessage;

  Map<String, dynamic>? _studentData;
  String? _studentDocId;

  @override
  void initState() {
    super.initState();
    _fetchAttendanceData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _loadStudentProfile(
    String username,
  ) async {
    try {
      final QuerySnapshot<Map<String, dynamic>> q = await FirebaseFirestore
          .instance
          .collection('students')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();
      if (q.docs.isEmpty) return null;
      return q.docs.first;
    } catch (e) {
      debugPrint('Error loading student profile for $username: $e');
      return null;
    }
  }

  Future<String?> _resolveClassNameFromClassRef(String classRefId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('classes')
          .doc(classRefId)
          .get();
      if (!doc.exists) return null;
      final data = doc.data() ?? {};
      final name =
          (data['className'] ?? data['name'] ?? data['class_name'] ?? '')
              .toString()
              .trim();
      return name.isNotEmpty ? name : null;
    } catch (e) {
      debugPrint('Error resolving class doc $classRefId: $e');
      return null;
    }
  }

  String _normalize(String s) => s.trim().toLowerCase();
  String _alnum(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  bool _looseMatch(String a, String b) {
    final na = _normalize(a);
    final nb = _normalize(b);
    if (na.isEmpty || nb.isEmpty) return false;
    if (na == nb) return true;
    if (na.contains(nb) || nb.contains(na)) return true;
    final ra = _alnum(na);
    final rb = _alnum(nb);
    return ra == rb || ra.contains(rb) || rb.contains(ra);
  }

  Future<void> _fetchAttendanceData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final username = Session.username;
    if (username == null) {
      setState(() {
        isLoading = false;
        errorMessage = 'User not logged in.';
      });
      return;
    }

    try {
      final firestore = FirebaseFirestore.instance;

      // Load student profile
      final studentDoc = await _loadStudentProfile(username);
      if (studentDoc == null || !studentDoc.exists) {
        setState(() {
          isLoading = false;
          errorMessage = 'Student profile not found.';
        });
        return;
      }

      final studentData = studentDoc.data() ?? {};
      _studentData = studentData;
      _studentDocId = studentDoc.id;
      debugPrint('Loaded student profile ($_studentDocId): $studentData');

      // Determine className/class_ref
      String? studentClassName =
          (studentData['className'] ?? studentData['class_name'] ?? '')
              .toString()
              .trim();

      String? studentClassRefId;
      final classRefRaw =
          studentData['class_ref'] ??
          studentData['classRef'] ??
          studentData['class'];
      if (classRefRaw is String && classRefRaw.isNotEmpty) {
        studentClassRefId = classRefRaw;
      } else if (classRefRaw is DocumentReference) {
        studentClassRefId = classRefRaw.id;
      }

      // Resolve className if missing
      if ((studentClassName.isEmpty) && (studentClassRefId != null)) {
        final resolved = await _resolveClassNameFromClassRef(studentClassRefId);
        if (resolved != null) {
          studentClassName = resolved;
          debugPrint(
            'Resolved className from classes/$studentClassRefId -> "$studentClassName"',
          );
        } else {
          debugPrint(
            'Could not resolve className for class_ref=$studentClassRefId',
          );
        }
      }

      debugPrint(
        'Using studentClassName="$studentClassName" classRef=$studentClassRefId',
      );

      final normalizedStudentClassName = (studentClassName.isNotEmpty)
          ? studentClassName.toLowerCase()
          : null;

      // Primary queries
      final List<QueryDocumentSnapshot<Map<String, dynamic>>> sessionDocs = [];

      if (normalizedStudentClassName != null) {
        final q1 = await firestore
            .collection('qr_generation')
            .where('className', isEqualTo: studentClassName)
            .get();
        debugPrint(
          'qr_generation by className returned ${q1.docs.length} docs',
        );
        sessionDocs.addAll(q1.docs);
      }

      if (studentClassRefId != null) {
        try {
          final q2 = await firestore
              .collection('qr_generation')
              .where('class_ref', isEqualTo: studentClassRefId)
              .get();
          debugPrint(
            'qr_generation by class_ref (string) returned ${q2.docs.length} docs',
          );
          final existingIds = sessionDocs.map((d) => d.id).toSet();
          for (final d in q2.docs) {
            if (!existingIds.contains(d.id)) sessionDocs.add(d);
          }

          final classRefDoc = firestore.doc('classes/$studentClassRefId');
          final q3 = await firestore
              .collection('qr_generation')
              .where('class_ref', isEqualTo: classRefDoc)
              .get();
          debugPrint(
            'qr_generation by class_ref (ref) returned ${q3.docs.length} docs',
          );
          final existingIds2 = sessionDocs.map((d) => d.id).toSet();
          for (final d in q3.docs) {
            if (!existingIds2.contains(d.id)) sessionDocs.add(d);
          }
        } catch (e) {
          debugPrint('Error querying by class_ref: $e');
        }
      }

      // Deduplicate and extract
      final Map<String, QueryDocumentSnapshot<Map<String, dynamic>>> unique =
          {};
      for (final d in sessionDocs) {
        unique[d.id] = d;
      }
      var sessionsData = unique.values.map((d) => d.data()).toList();
      debugPrint('Sessions found from primary queries: ${sessionsData.length}');

      // Fallback: scan recent and filter locally if nothing found
      if (sessionsData.isEmpty && normalizedStudentClassName != null) {
        debugPrint(
          'Primary queries returned 0; performing fallback scan of recent qr_generation docs',
        );
        final recent = await firestore
            .collection('qr_generation')
            .orderBy('created_at', descending: true)
            .limit(500)
            .get();
        final filtered = recent.docs.map((d) => d.data()).where((s) {
          final sClass = (s['className'] ?? s['class_name'] ?? s['class'] ?? '')
              .toString();
          return _looseMatch(sClass, studentClassName!);
        }).toList();
        debugPrint(
          'Fallback filter matched ${filtered.length} sessions (from ${recent.docs.length} recent docs)',
        );
        sessionsData = filtered.cast<Map<String, dynamic>>();
      }

      // Build subject|class map
      final Map<String, Map<String, dynamic>> subjectClassMap = {};
      for (final session in sessionsData) {
        final subject = (session['subject'] ?? '').toString().trim();
        final className = (session['className'] ?? '').toString().trim();
        if (subject.isEmpty || className.isEmpty) continue;
        final key = '$subject|$className';
        final existing = subjectClassMap[key];
        if (existing == null) {
          subjectClassMap[key] = {
            'subject': subject,
            'className': className,
            'totalSessions': 1,
          };
        } else {
          existing['totalSessions'] = (existing['totalSessions'] ?? 0) + 1;
        }
      }

      debugPrint('subjectClassMap keys: ${subjectClassMap.keys.toList()}');

      // Fetch attendance_records
      final QuerySnapshot<Map<String, dynamic>> attendanceQuery =
          await firestore
              .collection('attendance_records')
              .where('username', isEqualTo: username)
              .get();
      final attendanceRecords = attendanceQuery.docs
          .map((d) => d.data())
          .toList();
      debugPrint(
        'Found ${attendanceRecords.length} attendance_records for $username',
      );

      // Count presents
      for (final record in attendanceRecords) {
        final subject = (record['subject'] ?? '').toString().trim();
        final className = (record['className'] ?? '').toString().trim();
        if (subject.isEmpty || className.isEmpty) continue;
        final key = '$subject|$className';
        if (subjectClassMap.containsKey(key)) {
          subjectClassMap[key]!['present'] =
              (subjectClassMap[key]!['present'] ?? 0) + 1;
        }
      }

      final fetchedAttendance = subjectClassMap.values.map((entry) {
        final totalSessions = (entry['totalSessions'] ?? 0) as int;
        final present = (entry['present'] ?? 0) as int;
        final absent = (totalSessions - present);
        return {
          'course': entry['subject'],
          'className': entry['className'],
          'present': present,
          'absent': absent,
          'total': totalSessions,
        };
      }).toList();

      setState(() {
        attendance = fetchedAttendance;
        isLoading = false;
      });
    } catch (e, st) {
      debugPrint('Error in _fetchAttendanceData: $e\n$st');
      setState(() {
        isLoading = false;
        errorMessage = 'Failed to fetch attendance data: $e';
      });
    }
  }

  List<Map<String, dynamic>> get _filteredAttendance {
    final q = _searchQuery.trim().toLowerCase();
    if (q.isEmpty) return attendance;
    return attendance.where((item) {
      final course = (item['course'] ?? '').toString().toLowerCase();
      final className = (item['className'] ?? '').toString().toLowerCase();
      return course.contains(q) || className.contains(q);
    }).toList();
  }

  void _showCourseDetailsSheet(Map<String, dynamic> item) {
    final theme = StudentThemeController.instance.theme;
    final String course = (item['course'] ?? '').toString();
    final String className = (item['className'] ?? '').toString();
    final int present = (item['present'] ?? 0) as int;
    final int absent = (item['absent'] ?? 0) as int;
    final int total = (item['total'] ?? (present + absent)) as int;
    final double percent = total > 0 ? (present / total) * 100 : 0;

    Widget statTile(String label, String value) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: theme.inputBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: theme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: theme.hint,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: theme.foreground,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      );
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  course,
                  style: TextStyle(
                    color: theme.foreground,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Class: ${className.isEmpty ? '-' : className}',
                  style: TextStyle(
                    color: theme.hint,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    statTile('Present', '$present'),
                    const SizedBox(width: 10),
                    statTile('Absent', '$absent'),
                    const SizedBox(width: 10),
                    statTile('Total', '$total'),
                    const SizedBox(width: 10),
                    statTile('Attendance', '${percent.toStringAsFixed(1)}%'),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 190,
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 34,
                            sections: [
                              PieChartSectionData(
                                value: present.toDouble(),
                                color: theme.progressPresent,
                                radius: 48,
                                title: total > 0
                                    ? '${((present / total) * 100).toStringAsFixed(0)}%'
                                    : '0%',
                                titleStyle: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              PieChartSectionData(
                                value: absent.toDouble(),
                                color: theme.progressAbsent,
                                radius: 48,
                                title: total > 0
                                    ? '${((absent / total) * 100).toStringAsFixed(0)}%'
                                    : '0%',
                                titleStyle: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _legendItem(
                              color: theme.progressPresent,
                              label: 'Present',
                              value: '$present',
                              fg: theme.foreground,
                            ),
                            const SizedBox(height: 8),
                            _legendItem(
                              color: theme.progressAbsent,
                              label: 'Absent',
                              value: '$absent',
                              fg: theme.foreground,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _legendItem({
    required Color color,
    required String label,
    required String value,
    required Color fg,
  }) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: fg,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _overallSummaryCard({
    required StudentThemeProxy theme,
    required int present,
    required int absent,
    required int total,
    required bool basedOnSearch,
  }) {
    final percent = total > 0 ? (present / total) * 100 : 0.0;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.border.withValues(alpha: 0.6)),
      ),
      elevation: 1.5,
      margin: EdgeInsets.zero,
      color: theme.card,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              basedOnSearch
                  ? 'Overall Summary (Filtered)'
                  : 'Overall Summary',
              style: TextStyle(
                color: theme.foreground,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              basedOnSearch
                  ? 'Totals for current search results'
                  : 'Totals across all your courses',
              style: TextStyle(
                color: theme.hint,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 156,
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 26,
                        sections: [
                          PieChartSectionData(
                            value: present.toDouble(),
                            color: theme.progressPresent,
                            radius: 44,
                            title: total > 0
                                ? '${((present / total) * 100).toStringAsFixed(0)}%'
                                : '0%',
                            titleStyle: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          PieChartSectionData(
                            value: absent.toDouble(),
                            color: theme.progressAbsent,
                            radius: 44,
                            title: total > 0
                                ? '${((absent / total) * 100).toStringAsFixed(0)}%'
                                : '0%',
                            titleStyle: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _legendItem(
                          color: theme.progressPresent,
                          label: 'Present',
                          value: '$present',
                          fg: theme.foreground,
                        ),
                        const SizedBox(height: 8),
                        _legendItem(
                          color: theme.progressAbsent,
                          label: 'Absent',
                          value: '$absent',
                          fg: theme.foreground,
                        ),
                        const SizedBox(height: 8),
                        _legendItem(
                          color: theme.button,
                          label: 'Total',
                          value: '$total',
                          fg: theme.foreground,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Attendance Rate: ${percent.toStringAsFixed(1)}%',
              style: TextStyle(
                color: theme.foreground,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: StudentThemeController.instance,
      builder: (context, _) {
        final theme = StudentThemeController.instance.theme;
        final isDark =
            StudentThemeController.instance.brightness == Brightness.dark;
        final overlayStyle = SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        );
        final filteredAttendance = _filteredAttendance;
        final overallPresent = filteredAttendance.fold<int>(
          0,
          (acc, item) => acc + ((item['present'] ?? 0) as int),
        );
        final overallAbsent = filteredAttendance.fold<int>(
          0,
          (acc, item) => acc + ((item['absent'] ?? 0) as int),
        );
        final overallTotal = overallPresent + overallAbsent;
        final studentName =
            (_studentData?['fullname'] ??
                    _studentData?['fullName'] ??
                    _studentData?['name'] ??
                    _studentData?['studentName'] ??
                    '')
                .toString();
        final avatarLetter = studentName.trim().isNotEmpty
            ? studentName.trim()[0].toUpperCase()
            : '';
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlayStyle,
          child: Scaffold(
            backgroundColor: theme.background,
            resizeToAvoidBottomInset: false,
            body: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: () => FocusScope.of(context).unfocus(),
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Attendance Overview",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: theme.foreground,
                                  letterSpacing: 0.1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "Track present and absent classes",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: theme.hint,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Material(
                          elevation: 3,
                          shape: const CircleBorder(),
                          color: theme.card,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const StudentProfilePage(),
                                ),
                              );
                            },
                            child: Container(
                              width: 44,
                              height: 44,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: theme.border.withValues(alpha: 0.75),
                                ),
                              ),
                              child: Text(
                                avatarLetter,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: theme.foreground,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      onChanged: (value) => setState(() => _searchQuery = value),
                      style: TextStyle(color: theme.foreground),
                      decoration: InputDecoration(
                        hintText: 'Search by subject or class...',
                        hintStyle: TextStyle(color: theme.hint),
                        prefixIcon: Icon(Icons.search_rounded, color: theme.hint),
                        suffixIcon: _searchQuery.trim().isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                  FocusScope.of(context).unfocus();
                                  setState(() => _searchQuery = '');
                                },
                                icon: Icon(Icons.close_rounded, color: theme.hint),
                              ),
                        filled: true,
                        fillColor: theme.inputBackground,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: theme.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: theme.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: theme.button, width: 1.3),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: isLoading
                        ? _SkeletonList(theme: theme)
                        : errorMessage != null
                        ? Center(
                            child: Text(
                              errorMessage!,
                              style: TextStyle(color: theme.error),
                            ),
                          )
                        : attendance.isEmpty
                        ? Center(
                            child: Text(
                              'No attendance sessions found for your class.',
                              style: TextStyle(color: theme.hint),
                            ),
                          )
                        : filteredAttendance.isEmpty
                        ? Center(
                            child: Text(
                              'No results for "$_searchQuery".',
                              style: TextStyle(color: theme.hint),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
                            itemCount: filteredAttendance.length + 1,
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 14),
                                  child: _overallSummaryCard(
                                    theme: theme,
                                    present: overallPresent,
                                    absent: overallAbsent,
                                    total: overallTotal,
                                    basedOnSearch: _searchQuery.trim().isNotEmpty,
                                  ),
                                );
                              }

                              final item = filteredAttendance[index - 1];
                              final String course = item['course'];
                              final String className =
                                  (item['className'] ?? '').toString();
                              final int present = item['present'];
                              final int absent = item['absent'];
                              final int total =
                                  item['total'] ?? (present + absent);
                              final int presentFlex = (present > 0) ? present : 0;
                              final int absentFlex = (absent > 0) ? absent : 0;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 14),
                                child: Card(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide(
                                      color: theme.border.withValues(alpha: 0.6),
                                    ),
                                  ),
                                  elevation: 1.5,
                                  margin: EdgeInsets.zero,
                                  color: theme.card,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: () => _showCourseDetailsSheet(item),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      course,
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.w700,
                                                        color: theme.foreground,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      className.isEmpty
                                                          ? 'Class: -'
                                                          : 'Class: $className',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: theme.hint,
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    "Present: $present",
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: theme.foreground,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    "Absent: $absent",
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: theme.hint,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(16),
                                            child: Container(
                                              height: 10,
                                              color: theme.inputBackground,
                                              child: Row(
                                                children: [
                                                  if (presentFlex > 0)
                                                    Expanded(
                                                      flex: presentFlex,
                                                      child: Container(
                                                        color: theme.progressPresent,
                                                      ),
                                                    ),
                                                  if (absentFlex > 0)
                                                    Expanded(
                                                      flex: absentFlex,
                                                      child: Container(
                                                        color: theme.progressAbsent,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            "Total Classes: $total",
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: theme.hint,
                                              fontWeight: FontWeight.w500,
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
                  ),
                  AnimatedBottomBar(
                    currentIndex: 0,
                    onTap: (index) {
                      if (index == 0) return;
                      if (index == 1) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => StudentScanAttendancePage(),
                          ),
                        );
                      } else if (index == 2) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const StudentProfilePage(),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            ),
          ),
        );
      },
    );
  }
}

class _SkeletonList extends StatelessWidget {
  final StudentThemeProxy theme;
  const _SkeletonList({required this.theme});

  @override
  Widget build(BuildContext context) {
    final base = theme.inputBackground.withValues(alpha: 0.65);
    final highlight = theme.inputBackground.withValues(alpha: 0.25);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
      itemCount: 7,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 2,
              margin: EdgeInsets.zero,
              color: theme.card,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Shimmer.fromColors(
                  baseColor: base,
                  highlightColor: highlight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SkeletonBox(color: base, height: 16, width: 150),
                      const SizedBox(height: 8),
                      _SkeletonBox(color: base, height: 12, width: 180),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _SkeletonBox(
                              color: base,
                              height: 120,
                              radius: 12,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              children: [
                                _SkeletonBox(height: 12, width: 90, color: base),
                                const SizedBox(height: 10),
                                _SkeletonBox(height: 12, width: 90, color: base),
                                const SizedBox(height: 10),
                                _SkeletonBox(height: 12, width: 90, color: base),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _SkeletonBox(color: base, height: 12, width: 140),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            elevation: 2,
            margin: EdgeInsets.zero,
            color: theme.card,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Shimmer.fromColors(
                baseColor: base,
                highlightColor: highlight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SkeletonBox(
                                color: base,
                                height: 16,
                                width: 170,
                                radius: 10,
                              ),
                              const SizedBox(height: 6),
                              _SkeletonBox(
                                color: base,
                                height: 12,
                                width: 100,
                                radius: 8,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _SkeletonBox(
                              color: base,
                              height: 12,
                              width: 76,
                              radius: 8,
                            ),
                            const SizedBox(height: 6),
                            _SkeletonBox(
                              color: base,
                              height: 12,
                              width: 64,
                              radius: 8,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: _SkeletonBox(
                        color: base,
                        height: 10,
                        radius: 999,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _SkeletonBox(
                      color: base,
                      height: 12,
                      width: 120,
                      radius: 8,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  final double height;
  final double? width;
  final Color color;
  final double radius;

  const _SkeletonBox({
    required this.height,
    required this.color,
    this.width,
    this.radius = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width ?? double.infinity,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
