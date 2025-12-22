import 'package:flutter/material.dart';

/// Theme extension providing Super Admin exact palette tokens for consistent UI.
class SuperAdminColors extends ThemeExtension<SuperAdminColors> {
  // Layout colors
  final Color scaffold;
  final Color surface;
  final Color surfaceHigh;
  final Color sidebarColor;
  final Color highlight; // e.g. used in list item backgrounds

  // Controls and content
  final Color inputFill;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color iconColor;
  final Color accent;

  // Interaction overlays
  final Color overlay;
  final Color selectedBg;
  final Color hoverOverlay;
  final Color pressedOverlay;

  const SuperAdminColors({
    required this.scaffold,
    required this.surface,
    required this.surfaceHigh,
    required this.sidebarColor,
    required this.highlight,
    required this.inputFill,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.iconColor,
    required this.accent,
    required this.overlay,
    required this.selectedBg,
    required this.hoverOverlay,
    required this.pressedOverlay,
  });

  /// Dark mode palette aligned exactly with Super Admin custom theme.
  factory SuperAdminColors.dark() => SuperAdminColors(
    scaffold: const Color(0xFF1F2431),
    surface: const Color(0xFF262C3A),
    surfaceHigh: const Color(0xFF323746),
    sidebarColor: const Color(0xFF0E1A60),
    highlight: const Color(0xFF2E3545),
    inputFill: const Color(0xFF2B303D),
    border: const Color(0xFF3A404E),
    textPrimary: const Color(0xFFE6EAF1),
    textSecondary: const Color(0xFF9EA5B5),
    iconColor: const Color(0xFFE6EAF1),
    accent: const Color(0xFF0A1E90),
    overlay: const Color(0x1AFFFFFF),
    selectedBg: Colors.white.withOpacity(0.13),
    hoverOverlay: Colors.white.withOpacity(0.10),
    pressedOverlay: Colors.white.withOpacity(0.16),
  );

  /// Light mode palette aligned to current app’s light defaults.
  factory SuperAdminColors.light() => SuperAdminColors(
    scaffold: Colors.white,
    surface: Colors.white,
    surfaceHigh: Colors.blue.shade50,
    sidebarColor: const Color(0xFF3B4B9B),
    highlight: Colors.blue.shade50,
    inputFill: Colors.white,
    border: Colors.blue[100]!,
    textPrimary: Colors.black87,
    textSecondary: Colors.black54,
    iconColor: Colors.black87,
    accent: Colors.blue[900]!,
    overlay: Colors.black12,
    selectedBg: Colors.white.withOpacity(0.25),
    hoverOverlay: Colors.white.withOpacity(0.20),
    pressedOverlay: Colors.white.withOpacity(0.28),
  );

  @override
  SuperAdminColors copyWith({
    Color? scaffold,
    Color? surface,
    Color? surfaceHigh,
    Color? sidebarColor,
    Color? highlight,
    Color? inputFill,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? iconColor,
    Color? accent,
    Color? overlay,
    Color? selectedBg,
    Color? hoverOverlay,
    Color? pressedOverlay,
  }) {
    return SuperAdminColors(
      scaffold: scaffold ?? this.scaffold,
      surface: surface ?? this.surface,
      surfaceHigh: surfaceHigh ?? this.surfaceHigh,
      sidebarColor: sidebarColor ?? this.sidebarColor,
      highlight: highlight ?? this.highlight,
      inputFill: inputFill ?? this.inputFill,
      border: border ?? this.border,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      iconColor: iconColor ?? this.iconColor,
      accent: accent ?? this.accent,
      overlay: overlay ?? this.overlay,
      selectedBg: selectedBg ?? this.selectedBg,
      hoverOverlay: hoverOverlay ?? this.hoverOverlay,
      pressedOverlay: pressedOverlay ?? this.pressedOverlay,
    );
  }

  @override
  ThemeExtension<SuperAdminColors> lerp(
    ThemeExtension<SuperAdminColors>? other,
    double t,
  ) {
    if (other is! SuperAdminColors) return this;
    return SuperAdminColors(
      scaffold: Color.lerp(scaffold, other.scaffold, t) ?? scaffold,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      surfaceHigh: Color.lerp(surfaceHigh, other.surfaceHigh, t) ?? surfaceHigh,
      sidebarColor:
          Color.lerp(sidebarColor, other.sidebarColor, t) ?? sidebarColor,
      highlight: Color.lerp(highlight, other.highlight, t) ?? highlight,
      inputFill: Color.lerp(inputFill, other.inputFill, t) ?? inputFill,
      border: Color.lerp(border, other.border, t) ?? border,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t) ?? textPrimary,
      textSecondary:
          Color.lerp(textSecondary, other.textSecondary, t) ?? textSecondary,
      iconColor: Color.lerp(iconColor, other.iconColor, t) ?? iconColor,
      accent: Color.lerp(accent, other.accent, t) ?? accent,
      overlay: Color.lerp(overlay, other.overlay, t) ?? overlay,
      selectedBg: Color.lerp(selectedBg, other.selectedBg, t) ?? selectedBg,
      hoverOverlay:
          Color.lerp(hoverOverlay, other.hoverOverlay, t) ?? hoverOverlay,
      pressedOverlay:
          Color.lerp(pressedOverlay, other.pressedOverlay, t) ?? pressedOverlay,
    );
  }
}
