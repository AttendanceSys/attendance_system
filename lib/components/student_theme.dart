import 'package:flutter/material.dart';

class StudentTheme {
  // Primary accent color
  static const Color primaryPurple = Color(0xFF6C4DFF);
  static const Color unselectedGrey = Color(0xFF636E72);

  // Light mode colors
  static const Color lightBackground = Colors.white;
  static const Color lightCard = Colors.white;
  static const Color lightBorder = Color(0xFFE0E0E0);
  static const Color lightText = Colors.black;
  static const Color lightSubText = Colors.black54;

  // Dark mode colors
  static const Color darkBackground = Color(0xFF1F2937);
  static const Color darkCard = Color(0xFF23243A);
  static const Color darkBorder = Color(0xFF374151);
  static const Color darkText = Colors.white;
  static const Color darkSubText = Colors.white70;
  static const Color darkIcon = Color(0xFF6C4DFF);
  static const Color darkLabel = Color(0xFF6C4DFF);

  // Helper to get colors by brightness
  static Color background(Brightness brightness) =>
      brightness == Brightness.dark ? darkBackground : lightBackground;
  static Color card(Brightness brightness) =>
      brightness == Brightness.dark ? darkCard : lightCard;
  static Color border(Brightness brightness) =>
      brightness == Brightness.dark ? darkBorder : lightBorder;
  static Color text(Brightness brightness) =>
      brightness == Brightness.dark ? darkText : lightText;
  static Color subText(Brightness brightness) =>
      brightness == Brightness.dark ? darkSubText : lightSubText;
  static Color icon(Brightness brightness, {bool selected = false}) => selected
      ? Colors.white
      : (brightness == Brightness.dark ? darkIcon : unselectedGrey);
  static Color label(Brightness brightness) =>
      brightness == Brightness.dark ? darkLabel : unselectedGrey;
}
