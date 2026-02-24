import 'dart:async';

import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Try to prepare location services and permissions for scanning.
  /// Returns true when location service is enabled and permission is granted.
  static Future<bool> ensureLocationReady() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      try {
        await Geolocator.openLocationSettings();
      } catch (_) {}
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      try {
        await Geolocator.openAppSettings();
      } catch (_) {}
      return false;
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Request permissions (if necessary) and return the current position.
  /// Returns null if permissions are denied or location unavailable.
  static Future<Position?> getCurrentPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;

    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 4),
      );
    } on TimeoutException {
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    } catch (_) {
      try {
        return await Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  /// Returns distance in meters between two coordinates using haversine.
  static double distanceMeters(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    return Geolocator.distanceBetween(startLat, startLng, endLat, endLng);
  }

  static bool isWithinRadius(
    double lat,
    double lng,
    double centerLat,
    double centerLng,
    double radiusMeters,
  ) {
    final d = distanceMeters(lat, lng, centerLat, centerLng);
    return d <= radiusMeters;
  }
}
