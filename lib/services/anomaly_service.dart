import 'package:cloud_firestore/cloud_firestore.dart';
import '../config.dart';
import 'location_service.dart';

class AnomalyResult {
  final bool block; // should block marking attendance
  final bool flag; // suspicious but not necessarily blocking
  final String reason;

  AnomalyResult({
    required this.block,
    required this.flag,
    required this.reason,
  });
}

class AnomalyService {
  /// Evaluate common checks:
  /// - double scan (existing attendance record for same session)
  /// - fake GPS (very poor accuracy)
  /// - off-campus (distance > allowed radius)
  /// Returns AnomalyResult with block=true if action should be blocked.
  static Future<AnomalyResult> evaluate(
    Map<String, dynamic> sessionData,
    String username,
    dynamic
    position, // Position? typed as dynamic to avoid direct dependency in callers
  ) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final sessionId = sessionData['id'] ?? sessionData['session_id'] ?? null;

      // 1) double scan: attendance_records where username & session_id
      if (sessionId != null) {
        final dup = await firestore
            .collection('attendance_records')
            .where('username', isEqualTo: username)
            .where('session_id', isEqualTo: sessionId)
            .limit(1)
            .get();
        if (dup.docs.isNotEmpty) {
          return AnomalyResult(block: true, flag: false, reason: 'double_scan');
        }
      }

      // 2) fake GPS: if position null or accuracy too large
      if (position == null) {
        // Unable to obtain GPS -> block (conservative)
        return AnomalyResult(block: true, flag: false, reason: 'no_gps');
      }

      final accuracy = (position.accuracy ?? 1000.0) as double;
      if (accuracy > kGpsAccuracyThresholdMeters) {
        // Suspicious but allow if within campus bounds? flag it
        // We'll continue to check off-campus, but set flag
        final fakeFlag = AnomalyResult(
          block: false,
          flag: true,
          reason: 'low_accuracy',
        );
        // Continue to off-campus check and escalate to block if off-campus

        final off = await _checkOffCampus(sessionData, position);
        if (off) {
          return AnomalyResult(
            block: true,
            flag: true,
            reason: 'off_campus_low_accuracy',
          );
        }
        return fakeFlag;
      }

      // 3) off-campus check
      final offCampus = await _checkOffCampus(sessionData, position);
      if (offCampus) {
        return AnomalyResult(block: true, flag: false, reason: 'off_campus');
      }

      // 4) (placeholder) proxy or abnormal pattern detection
      // Advanced checks require server-side ML or more telemetry. Locally we flag
      // repeated quick scans from different devices as suspicious; skip here.

      return AnomalyResult(block: false, flag: false, reason: 'ok');
    } catch (e) {
      return AnomalyResult(block: false, flag: false, reason: 'error:$e');
    }
  }

  static Future<bool> _checkOffCampus(
    Map<String, dynamic> sessionData,
    dynamic position,
  ) async {
    try {
      double centerLat = kDefaultCampusLatitude;
      double centerLng = kDefaultCampusLongitude;
      double radius = kDefaultCampusRadiusMeters;

      // If sessionData contains an explicit allowed_location, prefer it
      if (sessionData.containsKey('allowed_location')) {
        final al = sessionData['allowed_location'];
        if (al is Map) {
          final aLat = double.tryParse(al['lat']?.toString() ?? '');
          final aLng = double.tryParse(al['lng']?.toString() ?? '');
          final aRad = double.tryParse(al['radius']?.toString() ?? '');
          if (aLat != null && aLng != null) {
            centerLat = aLat;
            centerLng = aLng;
            if (aRad != null) radius = aRad;
          }
        }
      }

      final lat = (position.latitude ?? 0.0) as double;
      final lng = (position.longitude ?? 0.0) as double;

      final within = LocationService.isWithinRadius(
        lat,
        lng,
        centerLat,
        centerLng,
        radius,
      );
      return !within;
    } catch (e) {
      return false;
    }
  }
}
