import 'package:flutter/material.dart';
import '../student_theme_controller.dart';

class ErrorPopup extends StatelessWidget {
  final String subject;
  final String date;
  final String time;

  const ErrorPopup({
    super.key,
    required this.subject,
    required this.date,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    final theme = StudentThemeController.instance.theme;
    final double screenWidth = MediaQuery.of(context).size.width;
    final double dialogWidth = screenWidth < 400 ? screenWidth * 0.95 : 340;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
      backgroundColor: theme.card,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: dialogWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Session Ended',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: theme.foreground,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                decoration: const BoxDecoration(
                  color: Color(0xFFF90E41),
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(16),
                child: const Icon(Icons.close, color: Colors.white, size: 48),
              ),
              const SizedBox(height: 18),
              infoRow('Subject:', subject, theme.foreground, theme.hint),
              infoRow('Date:', date, theme.foreground, theme.hint),
              infoRow('Time:', time, theme.foreground, theme.hint),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    backgroundColor: theme.button,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22,
                      vertical: 8,
                    ),
                  ),
                  child: const Text(
                    'OK',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget infoRow(
    String label,
    String value,
    Color labelColor,
    Color valueColor,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: labelColor,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.normal,
                fontSize: 16,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
