import '../../services/theme_controller.dart';
// TeacherQRGenerationPage — save generated QR session to Firestore (qr_generation collection)
//
// Updates in this version:
// - _findTimetableMatch now finds a timetable cell for the selected class/subject/teacher
//   that matches the current day AND whose period/span contains "now". If no such match
//   exists the generation is blocked ("not your current period").
// - When saving a session we now save both period_starts_at and period_ends_at (UTC).
// - _hasActiveSession only treats a session as blocking when it is active AND it actually
//   overlaps "now" (i.e., period_starts_at <= now < period_ends_at) or (expires_at > now).
//   This prevents stale/irrelevant active documents from blocking generation.
// - Removed createdToday blocking (teachers can create multiple periods/day).
//
// Behavior: a teacher can only generate a QR if they actually have a scheduled period right now
// (based on timetable spans or parsed period strings). If another active session overlaps now
// for the same teacher+subject+class, generation is blocked.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../theme/super_admin_theme.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../services/session.dart';
import '../../theme/teacher_theme.dart';
import '../../services/location_service.dart';
import '../../config.dart';

class TeacherQRGenerationPage extends StatefulWidget {
  const TeacherQRGenerationPage({super.key});

  @override
  State<TeacherQRGenerationPage> createState() =>
      _TeacherQRGenerationPageState();
}

class _TeacherQRGenerationPageState extends State<TeacherQRGenerationPage> {
  bool get isDarkMode => Theme.of(context).brightness == Brightness.dark;
  Widget _themeToggleButton() {
    final palette = Theme.of(context).extension<TeacherThemeColors>();
    final iconColor = palette?.iconColor ?? Colors.black87;
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeMode,
      builder: (context, mode, _) {
        final isDark = mode == ThemeMode.dark;
        return IconButton(
          icon: Icon(
            isDark ? Icons.light_mode : Icons.dark_mode,
            color: iconColor,
          ),
          tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
          onPressed: () {
            ThemeController.setThemeMode(
              isDark ? ThemeMode.light : ThemeMode.dark,
            );
          },
        );
      },
    );
  }

  String? department;
  String? className;
  String? subject;

  List<String> departments = [];
  List<String> classes = [];
  List<String> subjects = [];

  String? qrCodeData;
  String? _lastSavedSessionId;
  // Location capture for allowed session area
  bool requireLocationVerification = false;
  double? _allowedLat;
  double? _allowedLng;
  double? _allowedAccuracyMeters;
  double _allowedRadiusMeters = kDefaultCampusRadiusMeters;
  late TextEditingController _radiusController;

  @override
  void initState() {
    super.initState();
    _radiusController = TextEditingController(
      text: _allowedRadiusMeters.toStringAsFixed(0),
    );
    _fetchDepartments();
  }

  @override
  void dispose() {
    _radiusController.dispose();
    super.dispose();
  }

  Future<void> _fetchDepartments() async {
    try {
      final teacher = await _fetchTeacherUsername();
      final snapshot = await FirebaseFirestore.instance
          .collection('timetables')
          .get();

      final filteredDocs = snapshot.docs.where((doc) {
        final data = doc.data();
        return _docHasTeacher(data, teacher);
      }).toList();

      final fetchedDepartments = filteredDocs
          .map((doc) {
            final data = doc.data();
            final d = data['department'];
            return d is String ? d : (d?.toString() ?? '');
          })
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();

      if (mounted) {
        setState(() {
          departments = fetchedDepartments;
          classes = [];
          subjects = [];
          department = null;
          className = null;
          subject = null;
          qrCodeData = null;
          _lastSavedSessionId = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching departments: $e')),
        );
      }
    }
  }

  Future<void> _fetchClasses(String selectedDepartment) async {
    try {
      final teacher = await _fetchTeacherUsername();
      final snapshot = await FirebaseFirestore.instance
          .collection('timetables')
          .where('department', isEqualTo: selectedDepartment)
          .get();

      // Filter docs more strictly: include a class only if at least one
      // timetable cell explicitly lists the teacher (or contains the
      // teacher string). This avoids showing classes where the teacher
      // is mentioned indirectly elsewhere in the doc.
      final teacherLower = teacher.toLowerCase().trim();
      final filteredDocs = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        bool hasTeacherInCells = false;

        final gm = data['grid_meta'];
        if (gm is List) {
          for (final gridMetaItem in gm) {
            if (gridMetaItem is Map && gridMetaItem['cells'] is List) {
              for (final cell in (gridMetaItem['cells'] as List)) {
                if (cell is Map) {
                  final lec = (cell['lecturer'] ?? '')
                      .toString()
                      .toLowerCase()
                      .trim();
                  if (lec.isNotEmpty &&
                      (lec == teacherLower || lec.contains(teacherLower))) {
                    hasTeacherInCells = true;
                    break;
                  }
                } else if (cell is String) {
                  final cellStr = cell.toLowerCase();
                  if (cellStr.contains(teacherLower)) {
                    hasTeacherInCells = true;
                    break;
                  }
                }
              }
            }
            if (hasTeacherInCells) break;
          }
        }

        if (!hasTeacherInCells) {
          final grid = data['grid'];
          if (grid is List) {
            for (final row in grid) {
              if (row is Map && row['cells'] is List) {
                for (final cell in (row['cells'] as List)) {
                  if (cell is Map) {
                    final lec = (cell['lecturer'] ?? '')
                        .toString()
                        .toLowerCase()
                        .trim();
                    if (lec.isNotEmpty &&
                        (lec == teacherLower || lec.contains(teacherLower))) {
                      hasTeacherInCells = true;
                      break;
                    }
                  } else if (cell is String) {
                    final cellStr = cell.toLowerCase();
                    if (cellStr.contains(teacherLower)) {
                      hasTeacherInCells = true;
                      break;
                    }
                  }
                }
              }
              if (hasTeacherInCells) break;
            }
          }
        }

        if (hasTeacherInCells) filteredDocs.add(doc);
      }

      final fetchedClasses = filteredDocs
          .map((doc) {
            final data = doc.data();
            final c = data['className'];
            return c is String ? c : (c?.toString() ?? '');
          })
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();

      if (mounted) {
        setState(() {
          classes = fetchedClasses;
          className = null;
          subjects = [];
          subject = null;
          qrCodeData = null;
          _lastSavedSessionId = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error fetching classes: $e')));
      }
    }
  }

  Future<void> _fetchSubjects(String selectedClass) async {
    try {
      final teacher = await _fetchTeacherUsername();
      final snapshot = await FirebaseFirestore.instance
          .collection('timetables')
          .where('className', isEqualTo: selectedClass)
          .get();

      final filteredDocs = snapshot.docs.where((doc) {
        final data = doc.data();
        return _docHasTeacher(data, teacher);
      }).toList();

      final fetchedSubjectsSet = <String>{};
      final teacherLower = teacher.toLowerCase().trim();
      for (final doc in filteredDocs) {
        final data = doc.data();
        final gm = data['grid_meta'];
        if (gm is List) {
          for (final gridMetaItem in gm) {
            if (gridMetaItem is Map && gridMetaItem['cells'] is List) {
              for (final cell in (gridMetaItem['cells'] as List)) {
                if (cell is Map) {
                  final course = (cell['course'] ?? '').toString().trim();
                  final lec = (cell['lecturer'] ?? '')
                      .toString()
                      .toLowerCase()
                      .trim();
                  if (course.isNotEmpty && lec.isNotEmpty) {
                    if (lec == teacherLower || lec.contains(teacherLower)) {
                      fetchedSubjectsSet.add(course);
                    }
                  }
                }
              }
            }
          }
        }
      }
      final fetchedSubjects = fetchedSubjectsSet.toList();

      if (mounted) {
        setState(() {
          subjects = fetchedSubjects;
          subject = null;
          qrCodeData = null;
          _lastSavedSessionId = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error fetching subjects: $e')));
      }
    }
  }

  Future<String> _fetchTeacherUsername() async {
    try {
      debugPrint('Fetching username from Session.username');
      return Session.username?.toString() ?? 'example_teacher';
    } catch (e) {
      debugPrint('Error fetching teacher username: $e');
      return 'example_teacher';
    }
  }

  bool _docHasTeacher(Map<String, dynamic> data, String teacher) {
    if (teacher.trim().isEmpty) return false;
    final t = teacher.toLowerCase();

    final gm = data['grid_meta'];
    if (gm is List) {
      for (var gridMetaItem in gm) {
        if (gridMetaItem is Map && gridMetaItem['cells'] is List) {
          for (var cell in (gridMetaItem['cells'] as List)) {
            if (cell is Map) {
              final lec = cell['lecturer'];
              if (lec != null) {
                final lecStr = lec.toString().toLowerCase();
                if (lecStr == t || lecStr.contains(t)) return true;
              }
            } else if (cell is String) {
              final cellStr = cell.toLowerCase();
              if (cellStr.contains(t)) return true;
            }
          }
        }
      }
    }

    final grid = data['grid'];
    if (grid is List) {
      for (var row in grid) {
        if (row is Map && row['cells'] is List) {
          for (var cell in (row['cells'] as List)) {
            if (cell is String) {
              final cellStr = cell.toLowerCase();
              if (cellStr.contains(t)) return true;
            } else if (cell is Map) {
              final lec = cell['lecturer'];
              if (lec != null) {
                final lecStr = lec.toString().toLowerCase();
                if (lecStr == t || lecStr.contains(t)) return true;
              }
            }
          }
        }
      }
    }

    return false;
  }

  // Helper: check whether teacher is listed as lecturer for the given class+subject.
  // This is an async method because it performs a Firestore query similar to other fetches.
  Future<bool> _isTeacherLecturerOfSubject(
    String selectedClass,
    String selectedSubject,
    String teacher,
  ) async {
    try {
      final lowerSubject = selectedSubject.toLowerCase().trim();
      final lowerTeacher = teacher.toLowerCase().trim();

      final snapshot = await FirebaseFirestore.instance
          .collection('timetables')
          .where('className', isEqualTo: selectedClass)
          .get();

      for (final doc in snapshot.docs) {
        final data = doc.data();

        final gm = data['grid_meta'];
        if (gm is List) {
          for (var gridMetaItem in gm) {
            if (gridMetaItem is Map && gridMetaItem['cells'] is List) {
              for (var cell in (gridMetaItem['cells'] as List)) {
                if (cell is Map) {
                  final course = (cell['course'] ?? '')
                      .toString()
                      .toLowerCase()
                      .trim();
                  final lec = (cell['lecturer'] ?? '')
                      .toString()
                      .toLowerCase()
                      .trim();
                  if (course == lowerSubject) {
                    if (lec.isEmpty ||
                        lec == lowerTeacher ||
                        lec.contains(lowerTeacher)) {
                      return true;
                    }
                  }
                } else if (cell is String) {
                  final cellStr = cell.toLowerCase();
                  if (cellStr.contains(lowerSubject) &&
                      cellStr.contains(lowerTeacher)) {
                    return true;
                  }
                }
              }
            }
          }
        }

        final grid = data['grid'];
        if (grid is List) {
          for (var row in grid) {
            if (row is Map && row['cells'] is List) {
              for (var cell in (row['cells'] as List)) {
                if (cell is Map) {
                  final course = (cell['course'] ?? '')
                      .toString()
                      .toLowerCase()
                      .trim();
                  final lec = (cell['lecturer'] ?? '')
                      .toString()
                      .toLowerCase()
                      .trim();
                  if (course == lowerSubject) {
                    if (lec.isEmpty ||
                        lec == lowerTeacher ||
                        lec.contains(lowerTeacher)) {
                      return true;
                    }
                  } else {
                    // fallback: sometimes course info is embedded in string fields
                    final cellStr = cell.toString().toLowerCase();
                    if (cellStr.contains(lowerSubject) &&
                        cellStr.contains(lowerTeacher)) {
                      return true;
                    }
                  }
                } else if (cell is String) {
                  final cellStr = cell.toLowerCase();
                  if (cellStr.contains(lowerSubject) &&
                      cellStr.contains(lowerTeacher)) {
                    return true;
                  }
                }
              }
            }
          }
        }
      }

      return false;
    } catch (e) {
      debugPrint('Error in _isTeacherLecturerOfSubject: $e');
      return false;
    }
  }

  // Compute current timetable day index.
  // DEFAULT ASSUMPTION: timetable 'r' index: 0=Saturday, 1=Sunday, 2=Monday, ... 6=Friday.
  int _currentTimetableDayIndex() {
    final weekday = DateTime.now().weekday; // 1=Mon ... 7=Sun
    return (weekday + 1) % 7;
  }

  // Find the timetable match that is for today AND whose period/span contains now.
  // Returns the match map including derived spanStartMinutes/spanEndMinutes (ints).
  Future<Map<String, dynamic>?> _findTimetableMatchForNow(
    String selectedClass,
    String selectedSubject,
    String teacher,
  ) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('timetables')
        .where('className', isEqualTo: selectedClass)
        .get();

    final lowerSubject = selectedSubject.toLowerCase();
    final lowerTeacher = teacher.toLowerCase();
    final todayIndex = _currentTimetableDayIndex();

    final now = DateTime.now();
    final minutesNow = now.hour * 60 + now.minute;

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final gm = data['grid_meta'];
      if (gm is List) {
        for (int gmIndex = 0; gmIndex < gm.length; gmIndex++) {
          final gridMetaItem = gm[gmIndex];
          final rField = gridMetaItem is Map && gridMetaItem['r'] is int
              ? (gridMetaItem['r'] as int)
              : gmIndex;
          // require row to be today's index
          if (rField != todayIndex) continue;

          if (gridMetaItem is Map && gridMetaItem['cells'] is List) {
            final cells = gridMetaItem['cells'] as List;
            for (int cellIndex = 0; cellIndex < cells.length; cellIndex++) {
              final cell = cells[cellIndex];
              if (cell is Map) {
                final course = (cell['course'] ?? '')
                    .toString()
                    .toLowerCase()
                    .trim();
                final lec = (cell['lecturer'] ?? '')
                    .toString()
                    .toLowerCase()
                    .trim();
                if (course != lowerSubject) continue;

                // Determine this cell's span start/end minutes from doc spans or grid_meta periods
                final spans = data['spans'];
                int? spanStart;
                int? spanEnd;
                if (spans is List &&
                    cellIndex >= 0 &&
                    cellIndex < spans.length) {
                  final span = spans[cellIndex];
                  if (span is Map &&
                      span['start'] is num &&
                      span['end'] is num) {
                    spanStart = (span['start'] as num).toInt();
                    spanEnd = (span['end'] as num).toInt();
                  }
                } else {
                  // fallback to periods array parsing
                  final periods = data['periods'];
                  if (periods is List &&
                      cellIndex >= 0 &&
                      cellIndex < periods.length) {
                    final periodStr = periods[cellIndex];
                    final parsed = (periodStr is String)
                        ? _parsePeriodString(periodStr)
                        : null;
                    if (parsed != null) {
                      spanStart = parsed[0];
                      spanEnd = parsed[1];
                    }
                  }
                }

                // If we have start/end, check if now is within; otherwise skip this cell
                if (spanStart != null && spanEnd != null) {
                  if (minutesNow >= spanStart && minutesNow < spanEnd) {
                    // ensure lecturer matches teacher (if present) or allow empty lecturer
                    if (lec.isEmpty ||
                        lec == lowerTeacher ||
                        lec.contains(lowerTeacher)) {
                      return {
                        'doc': doc,
                        'dayIndex': rField,
                        'periodIndex': cellIndex,
                        'spans': data['spans'],
                        'periods': data['periods'],
                        'spanStart': spanStart,
                        'spanEnd': spanEnd,
                        'lecturer': lec,
                      };
                    }
                  }
                }
              } else if (cell is String) {
                // best-effort: if the string contains subject and teacher, accept it
                final cellStr = cell.toLowerCase();
                if (cellStr.contains(lowerSubject) &&
                    cellStr.contains(lowerTeacher)) {
                  // try to get span from spans/periods like above
                  final spans = data['spans'];
                  int? spanStart;
                  int? spanEnd;
                  if (spans is List &&
                      cellIndex >= 0 &&
                      cellIndex < spans.length) {
                    final span = spans[cellIndex];
                    if (span is Map &&
                        span['start'] is num &&
                        span['end'] is num) {
                      spanStart = (span['start'] as num).toInt();
                      spanEnd = (span['end'] as num).toInt();
                    }
                  } else {
                    final periods = data['periods'];
                    if (periods is List &&
                        cellIndex >= 0 &&
                        cellIndex < periods.length) {
                      final periodStr = periods[cellIndex];
                      final parsed = (periodStr is String)
                          ? _parsePeriodString(periodStr)
                          : null;
                      if (parsed != null) {
                        spanStart = parsed[0];
                        spanEnd = parsed[1];
                      }
                    }
                  }

                  if (spanStart != null && spanEnd != null) {
                    if (minutesNow >= spanStart && minutesNow < spanEnd) {
                      return {
                        'doc': doc,
                        'dayIndex': rField,
                        'periodIndex': cellIndex,
                        'spans': data['spans'],
                        'periods': data['periods'],
                        'spanStart': spanStart,
                        'spanEnd': spanEnd,
                        'lecturer': '',
                      };
                    }
                  }
                }
              }
            }
          }
        }
      }
      // fallback: grid structure not used for now-only match because grid rows may not map to day indices consistently
    }
    return null;
  }

  bool _isNowWithinPeriodForMatch(Map<String, dynamic> match) {
    final spanStart = match['spanStart'] as int?;
    final spanEnd = match['spanEnd'] as int?;
    if (spanStart != null && spanEnd != null) {
      final now = DateTime.now();
      final minutesNow = now.hour * 60 + now.minute;
      return minutesNow >= spanStart && minutesNow < spanEnd;
    }
    // fallback to previous logic (less strict)
    final spans = match['spans'];
    final periods = match['periods'];
    final periodIndex = match['periodIndex'] as int;
    final now = DateTime.now();
    final minutesSinceMidnight = now.hour * 60 + now.minute;

    if (spans is List && periodIndex >= 0 && periodIndex < spans.length) {
      final span = spans[periodIndex];
      if (span is Map && span['start'] is num && span['end'] is num) {
        final start = (span['start'] as num).toInt();
        final end = (span['end'] as num).toInt();
        return minutesSinceMidnight >= start && minutesSinceMidnight < end;
      }
    }

    if (periods is List && periodIndex >= 0 && periodIndex < periods.length) {
      final periodStr = periods[periodIndex];
      if (periodStr is String) {
        final parsed = _parsePeriodString(periodStr);
        if (parsed != null) {
          return minutesSinceMidnight >= parsed[0] &&
              minutesSinceMidnight < parsed[1];
        }
      }
    }

    return false;
  }

  DateTime? _getPeriodStartDateTime(Map<String, dynamic> match) {
    try {
      final spanStart = match['spanStart'] as int?;
      final periodIndex = match['periodIndex'] as int?;
      final periods = match['periods'];
      final now = DateTime.now();

      if (spanStart != null) {
        final hour = spanStart ~/ 60;
        final minute = spanStart % 60;
        return DateTime(now.year, now.month, now.day, hour, minute);
      }

      if (periodIndex != null &&
          periods is List &&
          periodIndex >= 0 &&
          periodIndex < periods.length) {
        final parsed = _parsePeriodString(periods[periodIndex]);
        if (parsed != null) {
          final startMinutes = parsed[0];
          final hour = startMinutes ~/ 60;
          final minute = startMinutes % 60;
          return DateTime(now.year, now.month, now.day, hour, minute);
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error computing period start DateTime: $e');
      return null;
    }
  }

  DateTime? _getPeriodEndDateTime(Map<String, dynamic> match) {
    try {
      final spanEnd = match['spanEnd'] as int?;
      final periodIndex = match['periodIndex'] as int?;
      final periods = match['periods'];
      final now = DateTime.now();

      if (spanEnd != null) {
        final hour = spanEnd ~/ 60;
        final minute = spanEnd % 60;
        return DateTime(now.year, now.month, now.day, hour, minute);
      }

      if (periodIndex != null &&
          periods is List &&
          periodIndex >= 0 &&
          periodIndex < periods.length) {
        final parsed = _parsePeriodString(periods[periodIndex]);
        if (parsed != null) {
          final endMinutes = parsed[1];
          final hour = endMinutes ~/ 60;
          final minute = endMinutes % 60;
          return DateTime(now.year, now.month, now.day, hour, minute);
        }
      }
      return null;
    } catch (e) {
      debugPrint('Error computing period end DateTime: $e');
      return null;
    }
  }

  List<int>? _parsePeriodString(String s) {
    try {
      final parts = s.split('-');
      if (parts.length != 2) return null;

      int parseTime(String t) {
        final p = t.replaceAll('(', '').replaceAll(')', '').trim();
        final time = p.split(':');
        if (time.length >= 2) {
          final h = int.tryParse(time[0].trim()) ?? 0;
          final mpart = time[1].trim();
          final mDigits = RegExp(r'^\d+').stringMatch(mpart) ?? '0';
          final m = int.tryParse(mDigits) ?? 0;
          return h * 60 + m;
        } else {
          final h = int.tryParse(p) ?? 0;
          return h * 60;
        }
      }

      final start = parseTime(parts[0]);
      final end = parseTime(parts[1]);
      return [start, end];
    } catch (e) {
      debugPrint('Error parsing period string "$s": $e');
      return null;
    }
  }

  // _hasActiveSession now only treats sessions as active/blocking when they overlap "now".
  // It queries active==true docs and checks whether their period_starts_at/period_ends_at mean they are ongoing.
  Future<bool> _hasActiveSession(
    String teacher,
    String subject,
    String className,
  ) async {
    try {
      final now = DateTime.now().toUtc();
      final nowTs = Timestamp.fromDate(now);
      final collection = FirebaseFirestore.instance.collection('qr_generation');

      // Query active sessions for same teacher/subject/class
      final q = await collection
          .where('teacher', isEqualTo: teacher)
          .where('subject', isEqualTo: subject)
          .where('className', isEqualTo: className)
          .where('active', isEqualTo: true)
          .get();

      if (q.docs.isEmpty) return false;

      for (final doc in q.docs) {
        final data = doc.data();

        // prefer server-stored period window if available
        final periodStartsAtTs = data['period_starts_at'] as Timestamp?;
        final periodEndsAtTs = data['period_ends_at'] as Timestamp?;
        final expiresAtTs = data['expires_at'] as Timestamp?;

        // If we have both start and end, check if now is within [start, end)
        if (periodStartsAtTs != null && periodEndsAtTs != null) {
          final start = periodStartsAtTs.toDate();
          final end = periodEndsAtTs.toDate();
          if (now.isAfter(start) && now.isBefore(end)) {
            return true;
          }
        } else if (periodEndsAtTs != null) {
          // If only end exists, treat as ongoing if end > now and (expiresAt absent or expiresAt > now)
          final end = periodEndsAtTs.toDate();
          if (end.isAfter(now)) {
            if (expiresAtTs == null) return true;
            if (expiresAtTs.toDate().isAfter(now)) return true;
          }
        } else if (expiresAtTs != null) {
          // fallback: if expires_at in future, consider active
          if (expiresAtTs.toDate().isAfter(now)) return true;
        } else {
          // No timing info — conservative: treat as active (to avoid duplicate sessions)
          return true;
        }
      }

      return false;
    } catch (e) {
      debugPrint('Error checking active session overlap: $e');
      // fail-open to avoid blocking creation if query fails
      return false;
    }
  }

  // Save session and store BOTH:
  // - expires_at: short expiry (now + 10 minutes) to preserve current behavior
  // - period_starts_at + period_ends_at: actual class period start/end (computed from timetable) stored in UTC
  Future<void> _saveSessionToFirestore(
    String code,
    String teacherUsername,
    DateTime periodStartLocal,
    DateTime periodEndLocal,
  ) async {
    try {
      final nowUtc = DateTime.now().toUtc();
      final shortExpiryUtc = nowUtc.add(
        const Duration(minutes: 10),
      ); // keep short expiry

      final docData = {
        'code': code,
        'subject': subject,
        'department': department,
        'className': className,
        'teacher': teacherUsername,
        'created_at': FieldValue.serverTimestamp(),
        'created_at_iso': nowUtc.toIso8601String(),
        'expires_at': Timestamp.fromDate(shortExpiryUtc),
        'period_starts_at': Timestamp.fromDate(periodStartLocal.toUtc()),
        'period_ends_at': Timestamp.fromDate(periodEndLocal.toUtc()),
        'active': true,
      };

      // Attach allowed_location if teacher captured one via the UI
      if (requireLocationVerification &&
          _allowedLat != null &&
          _allowedLng != null) {
        final baseRadius = _allowedRadiusMeters.isFinite
            ? _allowedRadiusMeters
            : kDefaultCampusRadiusMeters;
        final accuracyPad =
            (_allowedAccuracyMeters != null &&
                _allowedAccuracyMeters!.isFinite &&
                _allowedAccuracyMeters! > 0)
            ? _allowedAccuracyMeters!
            : 0;
        final effectiveRadius = (baseRadius + accuracyPad)
            .clamp(0, 100000.0)
            .toDouble();
        docData['allowed_location'] = {
          'lat': _allowedLat,
          'lng': _allowedLng,
          'radius': effectiveRadius,
          'requested_radius': baseRadius,
          if (_allowedAccuracyMeters != null)
            'accuracy': _allowedAccuracyMeters,
        };
      }

      final ref = await FirebaseFirestore.instance
          .collection('qr_generation')
          .add(docData);

      if (mounted) {
        setState(() {
          _lastSavedSessionId = ref.id;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'QR session saved (id: ${ref.id}). Short expiry: ${shortExpiryUtc.toLocal()}. Period: ${periodStartLocal.toLocal()} - ${periodEndLocal.toLocal()}',
            ),
          ),
        );
      }
    } catch (e, st) {
      debugPrint('Error saving QR session: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error saving QR session: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = Theme.of(context).extension<TeacherThemeColors>();
    return Padding(
      padding: const EdgeInsets.all(32),
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Text(
                  "Generate QR Code",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(
                      context,
                    ).extension<SuperAdminColors>()?.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 14,
              runSpacing: 12,
              alignment: WrapAlignment.start,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _dropdown(
                  value: department,
                  items: departments,
                  hint: "Select Department",
                  onChanged: (value) {
                    setState(() => department = value);
                    if (value != null) _fetchClasses(value);
                  },
                ),
                _dropdown(
                  value: className,
                  items: classes,
                  hint: "Select Class",
                  onChanged: (value) {
                    setState(() => className = value);
                    if (value != null) _fetchSubjects(value);
                  },
                ),
                _dropdown(
                  value: subject,
                  items: subjects,

                  // call this color please color: isDarkMode ? Colors.white : Colors.grey[100],
                  hint: "Select Subject",
                  onChanged: (value) => setState(() => subject = value),
                ),
                // Location verification toggle + capture
                Container(
                  constraints: const BoxConstraints(
                    minWidth: 220,
                    maxWidth: 420,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: requireLocationVerification,
                        onChanged: (v) {
                          setState(() {
                            requireLocationVerification = v;
                            if (!v) {
                              _allowedLat = null;
                              _allowedLng = null;
                              _allowedAccuracyMeters = null;
                            }
                          });
                        },
                      ),
                      const SizedBox(width: 6),
                      const Flexible(
                        child: Text(
                          'Require location verification',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (requireLocationVerification) ...[
                        ElevatedButton(
                          onPressed: () async {
                            if (!requireLocationVerification) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Capturing location...'),
                              ),
                            );
                            final pos =
                                await LocationService.getCurrentPosition();
                            if (pos == null) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Failed to get GPS position'),
                                  ),
                                );
                              }
                              return;
                            }
                            setState(() {
                              _allowedLat = pos.latitude;
                              _allowedLng = pos.longitude;
                              _allowedAccuracyMeters = pos.accuracy;
                            });
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Captured location: ${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)} (±${pos.accuracy.toStringAsFixed(0)} m)',
                                  ),
                                ),
                              );
                            }
                          },
                          child: Text(
                            _allowedLat == null ? 'Capture' : 'Captured',
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 110,
                          child: TextFormField(
                            controller: _radiusController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Radius (m)',
                              isDense: true,
                            ),
                            onChanged: (v) {
                              final parsed = double.tryParse(v);
                              if (parsed != null) {
                                setState(() => _allowedRadiusMeters = parsed);
                              }
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDarkMode
                        ? Theme.of(context).colorScheme.primary
                        : const Color(0xFF2196F3),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                  ),
                  onPressed: () async {
                    // Basic non-null validation
                    if (department == null ||
                        className == null ||
                        subject == null ||
                        department!.trim().isEmpty ||
                        className!.trim().isEmpty ||
                        subject!.trim().isEmpty) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please select department, class and subject.',
                            ),
                          ),
                        );
                      }
                      return;
                    }

                    final teacherUsername = await _fetchTeacherUsername();

                    // Validation 1: teacher must be lecturer for this subject/class
                    final isLecturer = await _isTeacherLecturerOfSubject(
                      className!.trim(),
                      subject!.trim(),
                      teacherUsername.trim(),
                    );

                    if (!isLecturer) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Validation failed: You are not assigned as the lecturer for the selected subject/class.',
                            ),
                          ),
                        );
                      }
                      return;
                    }

                    // Find timetable match for NOW (today + containing now)
                    final match = await _findTimetableMatchForNow(
                      className!.trim(),
                      subject!.trim(),
                      teacherUsername.trim(),
                    );

                    if (match == null) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'You do not have a scheduled period for this subject/class at the current time.',
                            ),
                          ),
                        );
                      }
                      return;
                    }

                    // Compute period start/end DateTimes (local)
                    final periodStart = _getPeriodStartDateTime(match);
                    final periodEnd = _getPeriodEndDateTime(match);
                    if (periodStart == null || periodEnd == null) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Could not compute period start/end time; cannot set period_ends_at.',
                            ),
                          ),
                        );
                      }
                      return;
                    }

                    // Prevent duplicate active sessions that overlap now
                    final hasActive = await _hasActiveSession(
                      teacherUsername.trim(),
                      subject!.trim(),
                      className!.trim(),
                    );

                    if (hasActive) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'There is already an active QR session for this class/subject that overlaps the current period. Please end it before creating a new one.',
                            ),
                          ),
                        );
                      }
                      return;
                    }

                    // All validations passed -> generate QR
                    final nowIso = DateTime.now().toUtc().toIso8601String();
                    final code =
                        "${subject!.trim()}|${department!.trim()}|${className!.trim()}|$teacherUsername|$nowIso";

                    if (mounted) {
                      setState(() {
                        qrCodeData = code;
                      });
                    }

                    // Save to qr_generation with both short expiry and period_starts/period_ends
                    await _saveSessionToFirestore(
                      code,
                      teacherUsername,
                      periodStart,
                      periodEnd,
                    );
                  },
                  child: const Text(
                    "Generate QR Code",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Center(
              child: qrCodeData == null
                  ? Container(
                      height: 260,
                      width: 260,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        color: isDarkMode
                            ? const Color.fromARGB(255, 143, 139, 139)
                            : Colors.white,
                        border: Border.all(color: Colors.grey[300]!, width: 2),
                      ),
                      child: Text(
                        "No QR Code generated yet.",
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.grey,
                          fontSize: 18,
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        QrImageView(
                          data: qrCodeData!,
                          size: 260.0,
                          backgroundColor: Colors.white,
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: 320,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            "For:\nSubject: $subject\nDepartment: $department\nClass: $className",
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        if (_lastSavedSessionId != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Saved session id: $_lastSavedSessionId',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dropdown({
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required String hint,
    bool isLoading = false,
  }) {
    final palette = Theme.of(context).extension<SuperAdminColors>();
    final hintStyle = TextStyle(color: palette?.textSecondary);
    final itemStyle = TextStyle(color: palette?.textPrimary);
    final borderColor = palette?.border ?? const Color(0xFFC7BECF);
    return Container(
      constraints: const BoxConstraints(minWidth: 130, maxWidth: 240),
      child: InputDecorator(
        decoration: InputDecoration(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 5,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: borderColor, width: 1.1),
          ),
          isDense: true,
          filled: true,
          fillColor:
              palette?.inputFill ?? Theme.of(context).colorScheme.surface,
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String?>(
            isExpanded: true,
            value: value,
            hint: isLoading
                ? Text('Loading...', style: hintStyle)
                : Text(hint, style: hintStyle),
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text(hint, style: hintStyle),
              ),
              ...items.map(
                (e) => DropdownMenuItem<String?>(
                  value: e,
                  child: Text(e, style: itemStyle),
                ),
              ),
            ],
            onChanged: onChanged,
            dropdownColor:
                palette?.surface ?? Theme.of(context).colorScheme.surface,
            iconEnabledColor:
                palette?.iconColor ?? Theme.of(context).iconTheme.color,
          ),
        ),
      ),
    );
  }
}