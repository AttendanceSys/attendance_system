import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'student_theme.dart';

class StudentThemeController extends ChangeNotifier {
  static final StudentThemeController instance =
      StudentThemeController._internal();

  ThemeMode _mode = ThemeMode.system;
  bool _themeLoaded = false;

  StudentThemeController._internal() {
    _loadTheme();
    final dispatcher = WidgetsBinding.instance.platformDispatcher;
    final previous = dispatcher.onPlatformBrightnessChanged;
    dispatcher.onPlatformBrightnessChanged = () {
      if (previous != null) previous();
      if (_mode == ThemeMode.system) notifyListeners();
    };
  }

  static const String _themeKey = 'student_theme_dark';
  static const String _themeModeKey = 'student_theme_mode';

  ThemeMode get mode => _mode;
  bool get isLoaded => _themeLoaded;

  /// Returns the current theme brightness (Brightness.dark or Brightness.light)
  Brightness get brightness {
    if (_mode == ThemeMode.system) {
      return WidgetsBinding
          .instance.platformDispatcher.platformBrightness;
    }
    return _mode == ThemeMode.dark ? Brightness.dark : Brightness.light;
  }

  bool get isDarkMode => brightness == Brightness.dark;

  /// Returns a helper object to access theme colors by brightness
  StudentThemeProxy get theme => StudentThemeProxy(brightness);

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(_themeModeKey)) {
      final value = prefs.getString(_themeModeKey);
      _mode = _parseMode(value) ?? ThemeMode.system;
    } else if (prefs.containsKey(_themeKey)) {
      final legacyDark = prefs.getBool(_themeKey) ?? false;
      _mode = legacyDark ? ThemeMode.dark : ThemeMode.light;
    } else {
      _mode = ThemeMode.system;
    }
    _themeLoaded = true;
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    _mode = value ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _themeModeKey,
      _mode == ThemeMode.dark ? 'dark' : 'light',
    );
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _mode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, _mode.name);
    notifyListeners();
  }

  ThemeMode? _parseMode(String? value) {
    switch (value) {
      case 'system':
        return ThemeMode.system;
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
    }
    return null;
  }
}

/// Proxy to access StudentTheme colors by brightness
class StudentThemeProxy {
  final Brightness brightness;
  StudentThemeProxy(this.brightness);

  Color get background => StudentTheme.background(brightness);
  Color get card => StudentTheme.card(brightness);
  Color get border => StudentTheme.border(brightness);
  Color get foreground => StudentTheme.text(brightness);
  Color get hint => StudentTheme.subText(brightness);
  Color get button => StudentTheme.primaryPurple;
  Color get appBar => StudentTheme.card(brightness);
  Color get appBarForeground => StudentTheme.text(brightness);
  Color get shadow => Colors.black12;
  Color get inputBackground => StudentTheme.card(brightness);
  Color get inputBorder => StudentTheme.border(brightness);
  Color get qrBackground => StudentTheme.background(brightness);
  // Add error and progress colors for attendance UI
  Color get error => Colors.redAccent;
  Color get progressPresent => Colors.green;
  Color get progressAbsent => Colors.redAccent;
}
