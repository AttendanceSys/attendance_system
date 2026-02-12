import 'package:flutter/material.dart';
import '../student_theme_controller.dart';

Future<bool?> showLogoutConfirmationPopup(BuildContext context) {
  final studentTheme = StudentThemeController.instance.theme;
  final isDark = StudentThemeController.instance.isDarkMode;
  final barrierOpacity = isDark ? 0.62 : 0.40;
  final barrierAlpha = (barrierOpacity * 255).round().clamp(0, 255);

  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withAlpha(barrierAlpha),
    barrierDismissible: false,
    builder: (context) {
      final surface = studentTheme.card;
      final borderColor = studentTheme.border;
      final textPrimary = studentTheme.foreground;
      final accent = studentTheme.button;
      final shadowOpacity = isDark ? 0.30 : 0.10;
      final shadowAlpha = (shadowOpacity * 255).round().clamp(0, 255);

      return Dialog(
        elevation: 8,
        backgroundColor: Colors.transparent,
        child: Center(
          child: Container(
            width: MediaQuery.of(context).size.width > 400
                ? 340
                : double.infinity,
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borderColor, width: isDark ? 2 : 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(shadowAlpha),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Are you sure you want to logout",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 40,
                      width: 100,
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: isDark ? accent : borderColor,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          "Cancel",
                          style: TextStyle(
                            color: isDark ? Colors.white : textPrimary,
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 18),
                    SizedBox(
                      height: 40,
                      width: 100,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Center(
                          child: Text(
                            "Log out",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
