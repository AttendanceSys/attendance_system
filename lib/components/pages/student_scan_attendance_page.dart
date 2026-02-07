import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/location_service.dart';
import '../../services/anomaly_service.dart';
import '../../services/session.dart';
// replaced old success popup with reusable attendance alert widget
import '../../components/popup/attendance_alert.dart';
import 'student_view_attendance_page.dart';
import 'student_profile_page.dart';
import '../../components/animated_bottom_bar.dart';
import '../../components/student_theme_controller.dart';

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
  // Loaded student profile fields (populated from Firestore)
  String? _profileName;
  String? _profileClassName;
  String? _profileSemester;
  String? _profileGender;
  String? _profileId;
  String? _profileAvatarLetter;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    // Load the student's profile for use when opening the profile page
    _loadProfileForCurrentUser();
  }

  Future<void> _loadProfileForCurrentUser() async {
    try {
      final username = Session.username;
      if (username == null) return;
      final doc = await _loadStudentProfile(username);
      if (doc == null || !doc.exists) return;
      final data = doc.data() ?? <String, dynamic>{};
      final name =
          (data['fullname'] ??
                  data['fullName'] ??
                  data['name'] ??
                  data['studentName'] ??
                  username)
              .toString();
      final className =
          (data['className'] ?? data['class_name'] ?? data['class'] ?? '')
              .toString();
      final semester = (data['semester'] ?? data['sem'] ?? '').toString();
      final gender = (data['gender'] ?? '').toString();
      final id =
          (data['studentId'] ?? data['id'] ?? data['username'] ?? username)
              .toString();
      final avatar = (name.isNotEmpty
          ? name.trim()[0].toUpperCase()
          : (id.isNotEmpty ? id[0].toUpperCase() : 'S'));
      if (mounted) {
        setState(() {
          _profileName = name;
          _profileClassName = className;
          _profileSemester = semester;
          _profileGender = gender;
          _profileId = id;
          _profileAvatarLetter = avatar;
        });
      }
    } catch (e, st) {
      debugPrint('Error loading profile for scanner page: $e\n$st');
    }
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
    dynamic position,
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
      debugPrint(
        'Duplicate attendance prevented for user=$username code=$code',
      );
      // Show "already recorded" dialog
      if (mounted) {
        await AttendanceAlert.showAlreadyRecorded(
          context,
          subject: sessionData['subject']?.toString(),
        );
      }
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
      'location': position == null
          ? null
          : {
              'lat': position.latitude,
              'lng': position.longitude,
              'accuracy': position.accuracy,
            },
    };

    await firestore.collection('attendance_records').add(attendanceData);

    debugPrint('Attendance written: user=$username session=${sessionDoc.id}');
    // Show success popup with subject, date and time using reusable AttendanceAlert
    if (mounted) {
      final now = DateTime.now();
      final date = '${now.day}/${now.month}/${now.year}';
      final time =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      await AttendanceAlert.showSuccess(
        context,
        subject: subject,
        date: date,
        time: time,
        autoCloseAfter: const Duration(seconds: 2),
      );
    }
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
        debugPrint('Duplicate found while scanning code: $code');
        if (mounted) {
          await AttendanceAlert.showAlreadyRecorded(context);
        }
        return;
      }

      final sessionQuery = await firestore
          .collection('qr_generation')
          .where('code', isEqualTo: code)
          .limit(1)
          .get();

      if (sessionQuery.docs.isEmpty) {
        debugPrint('Exact code match not found for scanned code: $code');
        if (mounted) {
          await AttendanceAlert.showQrExpired(
            context,
            details: 'No active QR session found for this code.',
          );
        }
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
        debugPrint(
          'Blocked scan: session ${sessionDoc.id} is not for student class (user=$username)',
        );
        if (mounted) {
          await AttendanceAlert.showNotYourClass(
            context,
            details: 'This QR/session does not belong to your assigned class.',
          );
        }
        return;
      }

      if (_isSessionExpired(sessionData, nowUtc)) {
        debugPrint('Session ${sessionDoc.id} is expired at scan time');
        if (mounted) {
          await AttendanceAlert.showQrExpired(
            context,
            details: 'This QR/session has expired.',
          );
        }
        return;
      }

      // Obtain current GPS position and evaluate anomalies
      final pos = await LocationService.getCurrentPosition();
      final anomaly = await AnomalyService.evaluate(
        {...sessionData, 'id': sessionDoc.id},
        username,
        pos,
      );

      if (anomaly.block) {
        debugPrint('Blocking attendance due to anomaly: ${anomaly.reason}');
        if (mounted) {
          await AttendanceAlert.showLocationBlocked(
            context,
            details: 'Attendance blocked: ${anomaly.reason}',
          );
        }
        return;
      }

      if (anomaly.flag) {
        // Allow but show flagged notice
        if (mounted) {
          await AttendanceAlert.showAnomalyFlagged(
            context,
            details: 'Suspicious scan: ${anomaly.reason}',
          );
        }
      }

      await _writeAttendanceForSession(code, sessionDoc, sessionData, pos);
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
    final studentName = _profileName ?? '';
    final avatarLetter = _profileAvatarLetter ?? '';
    final className = _profileClassName ?? '';
    final semester = _profileSemester ?? '';
    final gender = _profileGender ?? '';
    final id = _profileId ?? '';

    return AnimatedBuilder(
      animation: StudentThemeController.instance,
      builder: (context, _) {
        final theme = StudentThemeController.instance.theme;
        return Scaffold(
          backgroundColor: theme.background,
          appBar: AppBar(
            title: const Text('Scan QR Code'),
            backgroundColor: theme.appBar,
            elevation: 0,
            iconTheme: IconThemeData(color: theme.appBarForeground),
            titleTextStyle: TextStyle(
              color: theme.appBarForeground,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
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
                            color: theme.card,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: theme.shadow,
                                blurRadius: 18,
                                offset: Offset(0, 10),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(16),
                          child: Container(
                            decoration: BoxDecoration(
                              color: theme.card,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: theme.card, width: 6),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: 280,
                                height: 280,
                                color: theme.qrBackground,
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
                            style: TextStyle(color: theme.hint, fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (scanResult != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28.0,
                            ),
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: theme.inputBackground,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: theme.inputBorder),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Scanned:',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: theme.hint,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          scanResult!,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: theme.foreground,
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
                                    child: Text(
                                      'Scan again',
                                      style: TextStyle(color: theme.button),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                AnimatedBottomBar(
                  currentIndex: 1,
                  onTap: (index) async {
                    if (index == 0) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const StudentViewAttendanceMobile(),
                        ),
                      );
                    } else if (index == 1) {
                      // already on scan page
                    } else if (index == 2) {
                      await Navigator.push(
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
                      if (!mounted) return;
                      try {
                        try {
                          await _controller.stop();
                        } catch (_) {}
                        await Future.delayed(const Duration(milliseconds: 300));
                        await _controller.start();
                      } catch (e) {
                        debugPrint(
                          'Error restarting camera after returning from profile: $e',
                        );
                      }
                    }
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
