import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'student_theme.dart';

class StudentThemeController extends ChangeNotifier {
  static final StudentThemeController instance =
      StudentThemeController._internal();

  bool _isDarkMode = false;
  bool _themeLoaded = false;

  StudentThemeController._internal() {
    _loadTheme();
  }

  static const String _themeKey = 'student_theme_dark';

  bool get isDarkMode => _isDarkMode;
  bool get isLoaded => _themeLoaded;

  /// Returns the current theme brightness (Brightness.dark or Brightness.light)
  Brightness get brightness => _isDarkMode ? Brightness.dark : Brightness.light;

  /// Returns a helper object to access theme colors by brightness
  StudentThemeProxy get theme => StudentThemeProxy(brightness);

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    _isDarkMode = prefs.getBool(_themeKey) ?? false;
    _themeLoaded = true;
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    _isDarkMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themeKey, value);
    notifyListeners();
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
