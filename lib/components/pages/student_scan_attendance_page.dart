import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/location_service.dart';
import '../../services/device_service.dart';
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
  static bool _locationPromptShownThisSession = false;
  final MobileScannerController _controller = MobileScannerController();
  String? scanResult;
  bool _isProcessingScan = false;
  late final AnimationController _pulseController;
  double _zoomScale = 0.0;
  double _baseZoomScale = 0.0;
  Map<String, dynamic>? _cachedStudentProfileData;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _controller.zoomScaleState.addListener(_onZoomScaleChanged);
    // Load the student's profile and cache for attendance checks
    _loadProfileForCurrentUser();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showLocationSetupPromptOnEntry();
    });
  }

  void _onZoomScaleChanged() {
    if (!mounted) return;
    final next = _controller.zoomScaleState.value.clamp(0.0, 1.0).toDouble();
    if ((next - _zoomScale).abs() < 0.001) return;
    setState(() => _zoomScale = next);
  }

  Future<void> _loadProfileForCurrentUser() async {
    try {
      final username = Session.username;
      if (username == null) return;
      final doc = await _loadStudentProfile(username);
      if (doc == null || !doc.exists) return;
      final data = doc.data() ?? <String, dynamic>{};
      _cachedStudentProfileData = Map<String, dynamic>.from(data);
    } catch (e, st) {
      debugPrint('Error loading profile for scanner page: $e\n$st');
    }
  }

  Future<void> _showLocationSetupPromptOnEntry() async {
    if (!mounted || _locationPromptShownThisSession) return;
    _locationPromptShownThisSession = true;

    final turnOn = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _LocationSetupPromptDialog(),
    );

    if (!mounted) return;
    if (turnOn == true) {
      await LocationService.ensureLocationReady();
      await LocationService.getCurrentPosition();
    }
  }

  @override
  void dispose() {
    _controller.zoomScaleState.removeListener(_onZoomScaleChanged);
    _controller.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _setZoomScale(double value) async {
    final next = value.clamp(0.0, 1.0).toDouble();
    try {
      await _controller.setZoomScale(next);
      if (!mounted) return;
      setState(() => _zoomScale = next);
    } catch (e) {
      debugPrint('Failed to set zoom scale: $e');
    }
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

    // Enforce one-device-per-session: check existing records with same device id
    final deviceId = await DeviceService.getDeviceId();
    final existingForDevice = await firestore
        .collection('attendance_records')
        .where('session_id', isEqualTo: sessionDoc.id)
        .where('device_id', isEqualTo: deviceId)
        .limit(1)
        .get();

    if (existingForDevice.docs.isNotEmpty) {
      final existing = existingForDevice.docs.first.data();
      final existingUser = (existing['username'] ?? '').toString();
      if (existingUser.isNotEmpty && existingUser != username) {
        debugPrint(
          'Blocked attendance: device $deviceId already used by $existingUser for session ${sessionDoc.id}',
        );
        if (mounted) {
          await AttendanceAlert.showLocationBlocked(
            context,
            details:
                'This device has already been used to record attendance for another student ($existingUser) in this session.',
          );
        }
        return;
      }
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
      'device_id': deviceId,
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
    if (!_isProcessingScan && mounted) {
      setState(() {
        _isProcessingScan = true;
      });
    }

    final firestore = FirebaseFirestore.instance;
    final nowUtc = DateTime.now().toUtc();
    final username = Session.username;
    if (username == null) throw Exception('User not authenticated');

    try {
      Map<String, dynamic>? studentData = _cachedStudentProfileData;
      if (studentData == null) {
        final studentDocSnapshot = await _loadStudentProfile(username);
        if (studentDocSnapshot != null && studentDocSnapshot.exists) {
          studentData = studentDocSnapshot.data();
          if (studentData != null) {
            _cachedStudentProfileData = Map<String, dynamic>.from(studentData);
          }
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
                content: Text(
                  'Student profile not found. Cannot verify class.',
                ),
              ),
            );
          }
          return;
        }
      }

      final requests = await Future.wait([
        firestore
            .collection('attendance_records')
            .where('username', isEqualTo: username)
            .where('code', isEqualTo: code)
            .limit(1)
            .get(),
        firestore
            .collection('qr_generation')
            .where('code', isEqualTo: code)
            .limit(1)
            .get(),
      ]);
      final dupQuery = requests[0];
      final sessionQuery = requests[1];

      if (dupQuery.docs.isNotEmpty) {
        debugPrint('Duplicate found while scanning code: $code');
        if (mounted) {
          await AttendanceAlert.showAlreadyRecorded(context);
        }
        return;
      }

      if (sessionQuery.docs.isEmpty) {
        debugPrint('Exact code match not found for scanned code: $code');
        if (mounted) {
          await AttendanceAlert.showInvalidQr(
            context,
            details:
                'This code was not generated by your attendance system QR generator.',
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
        // Non-blocking anomalies should not interrupt successful marking with
        // a modal alert before success. Keep as debug signal only.
        debugPrint('Non-blocking anomaly flagged: ${anomaly.reason}');
      }

      await _writeAttendanceForSession(code, sessionDoc, sessionData, pos);
    } catch (e, st) {
      debugPrint('Error handling attendance: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingScan = false;
        });
      }
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (capture.barcodes.isNotEmpty) {
      final String? code = capture.barcodes.first.rawValue;
      if (scanResult == null && code != null && !_isProcessingScan) {
        setState(() {
          scanResult = code;
          _isProcessingScan = true;
        });
        _controller.stop();
        _handleMarkAttendance(code);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: StudentThemeController.instance,
      builder: (context, _) {
        final theme = StudentThemeController.instance.theme;
        final isDark =
            StudentThemeController.instance.brightness == Brightness.dark;
        final panelColor = theme.card.withValues(alpha: 0.84);
        final panelText = theme.foreground;
        final panelMuted = theme.hint;
        final scanLineColor = theme.button;
        final overlayStyle = SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        );
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlayStyle,
          child: Scaffold(
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
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final cutOutSize = constraints.maxWidth < 360
                          ? 250.0
                          : 285.0;
                      final cutOutRect = Rect.fromCenter(
                        center: Offset(
                          constraints.maxWidth / 2,
                          constraints.maxHeight / 2 - 20,
                        ),
                        width: cutOutSize,
                        height: cutOutSize,
                      );

                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onScaleStart: (_) {
                          _baseZoomScale = _zoomScale;
                        },
                        onScaleUpdate: (details) {
                          _setZoomScale(
                            _baseZoomScale + (details.scale - 1) * 0.5,
                          );
                        },
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            MobileScanner(
                              controller: _controller,
                              fit: BoxFit.cover,
                              scanWindow: cutOutRect,
                              onDetect: _onDetect,
                            ),
                            IgnorePointer(
                              child: CustomPaint(
                                painter: _ScanWindowOverlayPainter(
                                  cutOutRect: cutOutRect,
                                  borderRadius: 18,
                                  overlayColor: theme.background,
                                  cornerColor: theme.foreground,
                                ),
                                child: const SizedBox.expand(),
                              ),
                            ),
                            IgnorePointer(
                              child: AnimatedBuilder(
                                animation: _pulseController,
                                builder: (context, _) {
                                  final lineY =
                                      cutOutRect.top +
                                      (cutOutRect.height *
                                          _pulseController.value);
                                  return CustomPaint(
                                    painter: _ScanLinePainter(
                                      cutOutRect: cutOutRect,
                                      lineY: lineY,
                                      lineColor: scanLineColor,
                                    ),
                                    child: const SizedBox.expand(),
                                  );
                                },
                              ),
                            ),
                            Positioned(
                              left: 24,
                              right: 24,
                              bottom: 94,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: panelColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: theme.border.withValues(alpha: 0.65),
                                  ),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 10,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Align the QR inside the frame',
                                      style: TextStyle(
                                        color: panelText,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        IconButton(
                                          onPressed: () =>
                                              _setZoomScale(_zoomScale - 0.1),
                                          icon: Icon(
                                            Icons.remove_circle_outline,
                                            color: panelText,
                                          ),
                                        ),
                                        Expanded(
                                          child: SliderTheme(
                                            data: SliderTheme.of(context)
                                                .copyWith(
                                                  activeTrackColor: scanLineColor,
                                                  inactiveTrackColor: panelMuted
                                                      .withValues(alpha: 0.3),
                                                  thumbColor: scanLineColor,
                                                  overlayColor: scanLineColor
                                                      .withValues(alpha: 0.2),
                                                ),
                                            child: Slider(
                                              min: 0,
                                              max: 1,
                                              value: _zoomScale
                                                  .clamp(0.0, 1.0)
                                                  .toDouble(),
                                              onChanged: (value) =>
                                                  _setZoomScale(value),
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: () =>
                                              _setZoomScale(_zoomScale + 0.1),
                                          icon: Icon(
                                            Icons.add_circle_outline,
                                            color: panelText,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (scanResult != null)
                              Positioned(
                                left: 24,
                                right: 24,
                                top: 24,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: panelColor,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: theme.border.withValues(alpha: 0.65),
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          _isProcessingScan
                                          ? 'Processing attendance...'
                                              : 'Scanned: $scanResult',
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: panelText,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      if (_isProcessingScan)
                                        SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              scanLineColor,
                                            ),
                                          ),
                                        )
                                      else
                                        TextButton(
                                          onPressed: () {
                                            setState(() {
                                              scanResult = null;
                                              _isProcessingScan = false;
                                            });
                                            _controller.start();
                                          },
                                          child: Text(
                                            'Scan again',
                                            style: TextStyle(
                                              color: scanLineColor,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                AnimatedBottomBar(
                  currentIndex: 1,
                  reserveLiftSpace: false,
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
                          builder: (_) => const StudentProfilePage(),
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
          ),
        );
      },
    );
  }
}

class _LocationSetupPromptDialog extends StatelessWidget {
  const _LocationSetupPromptDialog();

  @override
  Widget build(BuildContext context) {
    final studentTheme = StudentThemeController.instance.theme;
    final isDark = StudentThemeController.instance.isDarkMode;
    final tone = studentTheme.button;
    return Dialog(
      backgroundColor: studentTheme.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'For a better experience, your device will need to use Location Accuracy',
              style: TextStyle(
                color: studentTheme.foreground,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'The following settings should be on:',
              style: TextStyle(
                color: studentTheme.hint,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 14),
            _PromptRow(
              icon: Icons.location_on_outlined,
              text: 'Device location',
              iconColor: tone,
              textColor: studentTheme.foreground,
            ),
            const SizedBox(height: 10),
            _PromptRow(
              icon: Icons.gps_fixed,
              text:
                  'Location Accuracy, which provides more accurate location for apps and services.',
              iconColor: tone,
              textColor: studentTheme.foreground,
            ),
            const SizedBox(height: 18),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: TextButton.styleFrom(
                    foregroundColor: studentTheme.foreground,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: studentTheme.border),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: const Text('No, thanks'),
                ),
                const SizedBox(width: 10),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: tone,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                  ),
                  child: const Text('Turn on'),
                ),
              ],
            ),
            if (isDark)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Divider(
                  height: 1,
                  color: studentTheme.border.withValues(alpha: 0.45),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PromptRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color iconColor;
  final Color textColor;

  const _PromptRow({
    required this.icon,
    required this.text,
    required this.iconColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: textColor,
              fontSize: 14,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _ScanWindowOverlayPainter extends CustomPainter {
  _ScanWindowOverlayPainter({
    required this.cutOutRect,
    required this.borderRadius,
    required this.overlayColor,
    required this.cornerColor,
  });

  final Rect cutOutRect;
  final double borderRadius;
  final Color overlayColor;
  final Color cornerColor;

  @override
  void paint(Canvas canvas, Size size) {
    final overlayPaint = Paint()..color = overlayColor.withValues(alpha: 0.56);
    final clearPaint = Paint()..blendMode = BlendMode.clear;

    canvas.saveLayer(Offset.zero & size, Paint());
    canvas.drawRect(Offset.zero & size, overlayPaint);
    final hole = RRect.fromRectAndRadius(
      cutOutRect,
      Radius.circular(borderRadius),
    );
    canvas.drawRRect(hole, clearPaint);
    canvas.restore();

    final cornerPaint = Paint()
      ..color = cornerColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const corner = 22.0;
    final l = cutOutRect.left;
    final t = cutOutRect.top;
    final r = cutOutRect.right;
    final b = cutOutRect.bottom;

    canvas.drawLine(Offset(l, t + corner), Offset(l, t), cornerPaint);
    canvas.drawLine(Offset(l, t), Offset(l + corner, t), cornerPaint);
    canvas.drawLine(Offset(r - corner, t), Offset(r, t), cornerPaint);
    canvas.drawLine(Offset(r, t), Offset(r, t + corner), cornerPaint);
    canvas.drawLine(Offset(l, b - corner), Offset(l, b), cornerPaint);
    canvas.drawLine(Offset(l, b), Offset(l + corner, b), cornerPaint);
    canvas.drawLine(Offset(r - corner, b), Offset(r, b), cornerPaint);
    canvas.drawLine(Offset(r, b - corner), Offset(r, b), cornerPaint);
  }

  @override
  bool shouldRepaint(covariant _ScanWindowOverlayPainter oldDelegate) {
    return oldDelegate.cutOutRect != cutOutRect ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.overlayColor != overlayColor ||
        oldDelegate.cornerColor != cornerColor;
  }
}

class _ScanLinePainter extends CustomPainter {
  _ScanLinePainter({
    required this.cutOutRect,
    required this.lineY,
    required this.lineColor,
  });

  final Rect cutOutRect;
  final double lineY;
  final Color lineColor;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..shader =
          LinearGradient(
            colors: [
              lineColor.withValues(alpha: 0.0),
              lineColor.withValues(alpha: 0.94),
              lineColor.withValues(alpha: 0.0),
            ],
          ).createShader(
            Rect.fromLTWH(cutOutRect.left, lineY - 1, cutOutRect.width, 2),
          );
    canvas.drawRect(
      Rect.fromLTWH(cutOutRect.left + 6, lineY - 1, cutOutRect.width - 12, 2),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScanLinePainter oldDelegate) {
    return oldDelegate.lineY != lineY ||
        oldDelegate.cutOutRect != cutOutRect ||
        oldDelegate.lineColor != lineColor;
  }
}
