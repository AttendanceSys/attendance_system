import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/session.dart';
import 'student_view_attendance_page.dart';
import 'student_profile_page.dart';

class StudentScanAttendancePage extends StatefulWidget {
  const StudentScanAttendancePage({super.key});

  @override
  State<StudentScanAttendancePage> createState() =>
      _StudentScanAttendancePageState();
}

class _StudentScanAttendancePageState extends State<StudentScanAttendancePage>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController();
  String? scanResult;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  String _normalizeScanned(String s) {
    var out = s.trim();
    out = out.replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '');
    return out;
  }

  bool _isSessionExpired(Map<String, dynamic> sessionData, DateTime nowUtc) {
    try {
      if (sessionData.containsKey('expires_at') &&
          sessionData['expires_at'] is Timestamp) {
        final expiresAt = (sessionData['expires_at'] as Timestamp)
            .toDate()
            .toUtc();
        return expiresAt.isBefore(nowUtc);
      } else if (sessionData.containsKey('expires_at_iso')) {
        final expiresIso = sessionData['expires_at_iso']?.toString() ?? '';
        if (expiresIso.isNotEmpty) {
          final expiresDt = DateTime.parse(expiresIso).toUtc();
          return expiresDt.isBefore(nowUtc);
        }
      }
      if (sessionData.containsKey('period_ends_at') &&
          sessionData['period_ends_at'] is Timestamp) {
        final end = (sessionData['period_ends_at'] as Timestamp)
            .toDate()
            .toUtc();
        if (end.isBefore(nowUtc)) return true;
      }
    } catch (e) {
      debugPrint('Error checking expiry: $e');
    }
    return false;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _loadStudentProfile(
    String username,
  ) async {
    try {
      final q = await FirebaseFirestore.instance
          .collection('students')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (q.docs.isEmpty) {
        debugPrint(
          'No student profile found for username=$username in students collection',
        );
        return null;
      }
      return q.docs.first as DocumentSnapshot<Map<String, dynamic>>;
    } catch (e) {
      debugPrint('Error loading student profile for $username: $e');
      return null;
    }
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _fetchAttendanceRecords(
    String selectedClassName,
    String selectedSubject,
    DateTime startTime,
    DateTime endTime,
  ) async {
    try {
      final query = FirebaseFirestore.instance
          .collectionGroup('attendance_records')
          .where('className', isEqualTo: selectedClassName)
          .where('subject', isEqualTo: selectedSubject)
          .where('scannedAt', isGreaterThanOrEqualTo: startTime)
          .where('scannedAt', isLessThanOrEqualTo: endTime);

      return await query.get();
    } catch (e) {
      debugPrint('Error fetching attendance records: $e');
      rethrow;
    }
  }

  String? _extractIdFromRef(dynamic raw) {
    if (raw == null) return null;
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    if (raw is DocumentReference) return raw.id;
    if (raw is Map && raw['id'] != null) return raw['id'].toString();
    return null;
  }

  String _normalizeName(String? s) {
    return (s ?? '').toString().trim().toLowerCase();
  }

  bool _looseNameMatch(String a, String b) {
    final na = _normalizeName(a);
    final nb = _normalizeName(b);
    if (na.isEmpty || nb.isEmpty) return false;
    if (na == nb) return true;
    if (na.contains(nb) || nb.contains(na)) return true;
    final ra = na.replaceAll(RegExp(r'[^a-z0-9]'), '');
    final rb = nb.replaceAll(RegExp(r'[^a-z0-9]'), '');
    return ra == rb || ra.contains(rb) || rb.contains(ra);
  }

  bool _sessionMatchesStudentClass(
    Map<String, dynamic> sessionData,
    Map<String, dynamic>? studentData,
  ) {
    if (studentData == null) return false;

    try {
      final studentClassRefRaw =
          studentData['class_ref'] ??
          studentData['classRef'] ??
          studentData['class'];
      final studentClassRefId = _extractIdFromRef(studentClassRefRaw);

      final studentClassName =
          (studentData['className'] ??
                  studentData['class_name'] ??
                  studentData['class'] ??
                  '')
              .toString();

      final studentDeptRaw =
          studentData['department_ref'] ??
          studentData['departmentRef'] ??
          studentData['department'];
      final studentDeptId = _extractIdFromRef(studentDeptRaw);

      final sessionClassRefRaw =
          sessionData['class_ref'] ??
          sessionData['classRef'] ??
          sessionData['class'];
      final sessionClassRefId = _extractIdFromRef(sessionClassRefRaw);

      final sessionClassName =
          (sessionData['className'] ??
                  sessionData['class_name'] ??
                  sessionData['class'] ??
                  '')
              .toString();

      final sessionDeptRaw =
          sessionData['department_ref'] ??
          sessionData['departmentRef'] ??
          sessionData['department'];
      final sessionDeptId = _extractIdFromRef(sessionDeptRaw);

      debugPrint(
        'Student: classRef=$studentClassRefId className="$studentClassName" dept=$studentDeptId',
      );
      debugPrint(
        'Session: classRef=$sessionClassRefId className="$sessionClassName" dept=$sessionDeptId',
      );

      if (studentClassRefId != null && sessionClassRefId != null) {
        if (studentClassRefId == sessionClassRefId) {
          debugPrint('Matched by classRef id');
          return true;
        }
      }

      if (studentClassRefId != null && sessionClassRefId == null) {
        final sraw = sessionData['class_ref']?.toString() ?? '';
        if (sraw.contains(studentClassRefId)) {
          debugPrint('Matched session.class_ref containing studentClassRefId');
          return true;
        }
      }
      if (sessionClassRefId != null && studentClassRefId == null) {
        final sraw = studentData['class_ref']?.toString() ?? '';
        if (sraw.contains(sessionClassRefId)) {
          debugPrint('Matched student.class_ref containing sessionClassRefId');
          return true;
        }
      }

      if (_looseNameMatch(studentClassName, sessionClassName)) {
        debugPrint('Matched by loose className');
        return true;
      }

      if (studentDeptId != null &&
          sessionDeptId != null &&
          studentDeptId == sessionDeptId) {
        debugPrint('Matched by department id fallback');
        return true;
      }

      final studentDeptName =
          (studentData['department'] ?? studentData['department_name'] ?? '')
              .toString();
      final sessionDeptName =
          (sessionData['department'] ?? sessionData['department_name'] ?? '')
              .toString();
      if (_looseNameMatch(studentDeptName, sessionDeptName)) {
        debugPrint('Matched by loose department name fallback');
        return true;
      }

      debugPrint('No match found between student and session');
      return false;
    } catch (e) {
      debugPrint('Error in _sessionMatchesStudentClass: $e');
      return false;
    }
  }

  // Async helper: if student has class_ref but session lacks className/class_ref, load classes/<id>
  // and compare that class' name to session.className (loose).
  Future<bool> _matchesViaClassRef(
    Map<String, dynamic> sessionData,
    Map<String, dynamic>? studentData,
  ) async {
    if (studentData == null) return false;

    final studentClassRefRaw =
        studentData['class_ref'] ??
        studentData['classRef'] ??
        studentData['class'];
    final studentClassRefId = _extractIdFromRef(studentClassRefRaw);
    if (studentClassRefId == null) return false;

    try {
      final classDoc = await FirebaseFirestore.instance
          .collection('classes')
          .doc(studentClassRefId)
          .get();

      if (!classDoc.exists) {
        debugPrint('classes/$studentClassRefId document not found');
        return false;
      }

      final classData = classDoc.data() ?? {};
      final classNameFromDoc =
          (classData['className'] ??
                  classData['name'] ??
                  classData['class_name'] ??
                  '')
              .toString();

      final sessionClassName =
          (sessionData['className'] ??
                  sessionData['class_name'] ??
                  sessionData['class'] ??
                  '')
              .toString();

      debugPrint(
        'Resolved class doc name="$classNameFromDoc" vs sessionClassName="$sessionClassName"',
      );

      if (_looseNameMatch(classNameFromDoc, sessionClassName)) {
        debugPrint('Matched via classes/<id> lookup');
        return true;
      }
    } catch (e) {
      debugPrint('Error in _matchesViaClassRef: $e');
    }
    return false;
  }

  Future<void> _writeAttendanceForSession(
    String code,
    QueryDocumentSnapshot sessionDoc,
    Map<String, dynamic> sessionData,
  ) async {
    final firestore = FirebaseFirestore.instance;
    final username = Session.username;
    if (username == null) throw Exception('User not authenticated');

    final dupQuery = await firestore
        .collection('attendance_records')
        .where('username', isEqualTo: username)
        .where('code', isEqualTo: code)
        .limit(1)
        .get();

    if (dupQuery.docs.isNotEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Attendance already recorded')),
        );
      }
      debugPrint(
        'Duplicate attendance prevented for user=$username code=$code',
      );
      return;
    }

    String subject = sessionData['subject']?.toString() ?? '';
    String department = sessionData['department']?.toString() ?? '';
    String className = sessionData['className']?.toString() ?? '';
    String timestampFromPayload = '';

    try {
      final sessionCode = sessionData['code']?.toString() ?? '';
      if (sessionCode.isNotEmpty) {
        final p = sessionCode.split('|');
        if (p.length >= 5) timestampFromPayload = p[4].trim();
      }
    } catch (_) {}

    if (timestampFromPayload.isEmpty) {
      try {
        final p2 = code.split('|');
        if (p2.length >= 5) timestampFromPayload = p2[4].trim();
      } catch (_) {}
    }

    final attendanceData = {
      'username': username,
      'subject': subject,
      'department': department,
      'className': className,
      'timestamp': timestampFromPayload,
      'scannedAt': FieldValue.serverTimestamp(),
      'code': code,
      'session_id': sessionDoc.id,
    };

    await firestore.collection('attendance_records').add(attendanceData);

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Attendance recorded')));
    }
    debugPrint('Attendance written: user=$username session=${sessionDoc.id}');
  }

  Future<void> _handleMarkAttendance(String rawCode) async {
    final code = _normalizeScanned(rawCode);
    if (code.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Scanned empty code')));
      }
      return;
    }

    final firestore = FirebaseFirestore.instance;
    final nowUtc = DateTime.now().toUtc();
    final username = Session.username;
    if (username == null) throw Exception('User not authenticated');

    final studentDocSnapshot = await _loadStudentProfile(username);
    Map<String, dynamic>? studentData;
    if (studentDocSnapshot != null && studentDocSnapshot.exists) {
      studentData = studentDocSnapshot.data();
      debugPrint(
        'Loaded student profile for $username: ${studentDocSnapshot.id} -> $studentData',
      );
    } else {
      debugPrint(
        'Student profile not found for $username — blocking scan for safety',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Student profile not found. Cannot verify class.'),
          ),
        );
      }
      return;
    }

    try {
      final dupQuery = await firestore
          .collection('attendance_records')
          .where('username', isEqualTo: username)
          .where('code', isEqualTo: code)
          .limit(1)
          .get();

      if (dupQuery.docs.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Attendance already recorded')),
          );
        }
        return;
      }

      final sessionQuery = await firestore
          .collection('qr_generation')
          .where('code', isEqualTo: code)
          .limit(1)
          .get();

      if (sessionQuery.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No active QR session found')),
          );
        }
        debugPrint('Exact code match not found for scanned code: $code');
        return;
      }

      final sessionDoc = sessionQuery.docs.first;
      final sessionData = sessionDoc.data();
      debugPrint('Found session ${sessionDoc.id} -> $sessionData');

      bool allowed = _sessionMatchesStudentClass(sessionData, studentData);

      // If initial match failed but student has class_ref, attempt lookup via classes/<id>
      if (!allowed) {
        allowed = await _matchesViaClassRef(sessionData, studentData);
        if (allowed) debugPrint('Allowed via classes/<id> lookup');
      }

      if (!allowed) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This QR is not for your class')),
          );
        }
        debugPrint(
          'Blocked scan: session ${sessionDoc.id} is not for student class (user=$username)',
        );
        return;
      }

      if (_isSessionExpired(sessionData, nowUtc)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('QR session has expired')),
          );
        }
        return;
      }

      await _writeAttendanceForSession(code, sessionDoc, sessionData);
    } catch (e, st) {
      debugPrint('Error handling attendance: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (capture.barcodes.isNotEmpty) {
      final String? code = capture.barcodes.first.rawValue;
      if (scanResult == null && code != null) {
        setState(() {
          scanResult = code;
        });
        _controller.stop();
        _handleMarkAttendance(code);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentName = "QaalI Cabdi Cali";
    final avatarLetter = "Q";
    final className = "B3-A Computer Science";
    final semester = "Semester 7";
    final gender = "Female";
    final id = "B3SC760";

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 320,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 18,
                            offset: Offset(0, 10),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white, width: 6),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 280,
                            height: 280,
                            color: Colors.black,
                            child: MobileScanner(
                              controller: _controller,
                              fit: BoxFit.cover,
                              onDetect: _onDetect,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 28.0),
                      child: Text(
                        'Position the QR code within the frame to scan.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black45, fontSize: 13),
                      ),
                    ),

                    const SizedBox(height: 18),

                    if (scanResult != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 28.0),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Scanned:',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.black54,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      scanResult!,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    scanResult = null;
                                  });
                                  _controller.start();
                                },
                                child: const Text('Scan again'),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            BottomNavigationBar(
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.menu_book_rounded),
                  label: 'View Attendance',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.qr_code_scanner),
                  label: 'Scan',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  label: 'Profile',
                ),
              ],
              currentIndex: 1,
              onTap: (index) {
                if (index == 0) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const StudentViewAttendanceMobile(),
                    ),
                  );
                } else if (index == 2) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StudentProfilePage(
                        name: studentName,
                        className: className,
                        semester: semester,
                        gender: gender,
                        id: id,
                        avatarLetter: avatarLetter,
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
