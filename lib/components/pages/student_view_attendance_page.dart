// StudentViewAttendanceMobile — show only student's class subjects & attendance
// - Typed Firestore queries, fallback matching, and fixed bottom navigation layout
// - Fix: replaced empty InkWell that caused infinite width error with fixed-size placeholder

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../services/session.dart';
import 'student_profile_page.dart';
import 'student_scan_attendance_page.dart';
import '../../components/student_bottom_nav_bar.dart';
import '../../components/student_theme_controller.dart';

class StudentViewAttendanceMobile extends StatefulWidget {
  const StudentViewAttendanceMobile({super.key});

  @override
  State<StudentViewAttendanceMobile> createState() =>
      _StudentViewAttendanceMobileState();
}

class _StudentViewAttendanceMobileState
    extends State<StudentViewAttendanceMobile> {
  List<Map<String, dynamic>> attendance = [];
  bool isLoading = true;
  String? errorMessage;

  Map<String, dynamic>? _studentData;
  String? _studentDocId;

  @override
  void initState() {
    super.initState();
    _fetchAttendanceData();
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: StudentThemeController.instance,
      builder: (context, _) {
        final theme = StudentThemeController.instance.theme;
        final studentName =
            _studentData?['fullname']?.toString() ??
            _studentData?['fullName']?.toString() ??
            'Student';
        final avatarLetter = (studentName.isNotEmpty)
            ? studentName[0].toUpperCase()
            : 'S';
        final studentClassDisplay =
            (_studentData?['className'] ?? _studentData?['class_name'] ?? '')
                .toString();
        final semester = _studentData?['semester']?.toString() ?? '';
        final gender = _studentData?['gender']?.toString() ?? '';
        final id =
            _studentData?['id']?.toString() ??
            _studentData?['student_id']?.toString() ??
            '';
        return Scaffold(
          backgroundColor: theme.background,
          body: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Center(
                          child: Text(
                            "Attendance Overview",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color:
                                  StudentThemeController.instance.brightness ==
                                      Brightness.dark
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          ),
                        ),
                      ),
                      Material(
                        elevation: 6,
                        shape: const CircleBorder(),
                        color: theme.card,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StudentProfilePage(
                                  name: studentName,
                                  className: studentClassDisplay,
                                  semester: semester,
                                  gender: gender,
                                  id: id,
                                  avatarLetter: avatarLetter,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            width: 44,
                            height: 44,
                            alignment: Alignment.center,
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

                const SizedBox(height: 6),

                Expanded(
                  child: isLoading
                      ? const Center(child: CircularProgressIndicator())
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
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          itemCount: attendance.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = attendance[index];
                            final String course = item['course'];
                            final int present = item['present'];
                            final int absent = item['absent'];
                            final int total =
                                item['total'] ?? (present + absent);
                            final int presentFlex = (present > 0) ? present : 0;
                            final int absentFlex = (absent > 0) ? absent : 0;

                            return Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                              margin: EdgeInsets.zero,
                              color: theme.card,
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
                                          child: Text(
                                            course,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: theme.foreground,
                                            ),
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
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              "Absent: $absent",
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: theme.hint,
                                                fontWeight: FontWeight.w500,
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
                                                  decoration: BoxDecoration(
                                                    color:
                                                        theme.progressPresent,
                                                    borderRadius:
                                                        const BorderRadius.only(
                                                          topLeft:
                                                              Radius.circular(
                                                                16,
                                                              ),
                                                          bottomLeft:
                                                              Radius.circular(
                                                                16,
                                                              ),
                                                        ),
                                                  ),
                                                ),
                                              ),
                                            if (absentFlex > 0)
                                              Expanded(
                                                flex: absentFlex,
                                                child: Container(
                                                  decoration: BoxDecoration(
                                                    color: theme.progressAbsent,
                                                    borderRadius:
                                                        const BorderRadius.only(
                                                          topRight:
                                                              Radius.circular(
                                                                16,
                                                              ),
                                                          bottomRight:
                                                              Radius.circular(
                                                                16,
                                                              ),
                                                        ),
                                                  ),
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
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),

                StudentBottomNavBar(
                  currentIndex: 0,
                  onTap: (index) {
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
                          builder: (_) => StudentProfilePage(
                            name: studentName,
                            className: studentClassDisplay,
                            semester: semester,
                            gender: gender,
                            id: id,
                            avatarLetter: avatarLetter,
                          ),
                        ),
                      );
                    }
                    // index == 0 is current page
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
