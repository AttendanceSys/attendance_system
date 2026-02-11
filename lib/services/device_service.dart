import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// Simple device ID provider: stores a generated persistent id in
/// SharedPreferences under the key `device_id`.
class DeviceService {
  static const _key = 'device_id';

  /// Returns a stable device id for this installation. If none exists,
  /// generates one and stores it persistently.
  static Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_key);
    if (existing != null && existing.isNotEmpty) return existing;

    final r = Random();
    final gen =
        'dev_${DateTime.now().millisecondsSinceEpoch}_${r.nextInt(1 << 31)}';
    await prefs.setString(_key, gen);
    return gen;
  }
}