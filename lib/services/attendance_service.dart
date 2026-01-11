import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceService {
  // Your Firestore uses `attendance_records` (confirmed). Use that collection name.
  final CollectionReference _col = FirebaseFirestore.instance.collection(
    'attendance_records',
  );

  /// Returns monthly attendance counts for the last 12 months.
  /// If [facultyRef] or [classRef] are provided, the query will be filtered.
  Future<List<int>> fetchMonthlyAttendanceCounts({
    DocumentReference? facultyRef,
    DocumentReference? classRef,
  }) async {
    final now = DateTime.now().toUtc();

    // Build start = first day of month 11 months ago, end = end of current month
    final startMonth = DateTime(now.year, now.month - 11, 1);
    final endMonth = DateTime(
      now.year,
      now.month + 1,
      1,
    ).subtract(const Duration(seconds: 1));

    // Use `scannedAt` Timestamp field (your documents show `scannedAt` as timestamp)
    Query q = _col
        .where(
          'scannedAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startMonth),
        )
        .where('scannedAt', isLessThanOrEqualTo: Timestamp.fromDate(endMonth));

    if (facultyRef != null) q = q.where('faculty_ref', isEqualTo: facultyRef);
    if (classRef != null) q = q.where('class_ref', isEqualTo: classRef);

    final snapshot = await q.get();
    // Debug: log how many documents were fetched for this query and the date range
    try {
      // ignore: avoid_print
      print(
        'AttendanceService.fetchMonthlyAttendanceCounts: fetched ${snapshot.size} docs from $startMonth to $endMonth',
      );
    } catch (_) {}

    // Initialize 12 buckets (oldest -> newest)
    final List<int> buckets = List<int>.filled(12, 0);

    for (final doc in snapshot.docs) {
      try {
        // Prefer `scannedAt` timestamp, fall back to `timestamp` string if necessary
        Timestamp? ts = doc['scannedAt'] as Timestamp?;
        if (ts == null) {
          final tsString = doc['timestamp'] as String?;
          if (tsString != null) {
            try {
              final parsed = DateTime.parse(tsString).toUtc();
              ts = Timestamp.fromDate(parsed);
            } catch (_) {}
          }
        }
        if (ts == null) continue;
        final d = ts.toDate().toUtc();

        final monthsDiff =
            (d.year - startMonth.year) * 12 + (d.month - startMonth.month);
        if (monthsDiff >= 0 && monthsDiff < 12) {
          buckets[monthsDiff] += 1;
        }
      } catch (_) {
        // ignore malformed docs
      }
    }

    return buckets;
  }

  /// Returns a map of gender -> count from the `students` collection.
  /// If [facultyRef] is provided, filter students by that faculty reference.
  Future<Map<String, int>> fetchStudentsByGender({
    DocumentReference? facultyRef,
  }) async {
    final col = FirebaseFirestore.instance.collection('students');
    Query q = col;
    if (facultyRef != null) q = q.where('faculty_ref', isEqualTo: facultyRef);

    final snapshot = await q.get();
    final Map<String, int> counts = {};
    for (final doc in snapshot.docs) {
      try {
        final gender = (doc['gender'] ?? 'Unknown').toString();
        counts[gender] = (counts[gender] ?? 0) + 1;
      } catch (_) {
        // ignore malformed
      }
    }
    // Debug
    try {
      // ignore: avoid_print
      print('AttendanceService.fetchStudentsByGender: counts=$counts');
    } catch (_) {}
    return counts;
  }
}
