//theme_controller

import 'package:flutter/material.dart';

/// Central controller for app-wide theme mode.
class ThemeController {
  ThemeController._();

  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier<ThemeMode>(
    ThemeMode.light,
  );

  static void toggle() {
    final next = themeMode.value == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    themeMode.value = next;
  }
}
