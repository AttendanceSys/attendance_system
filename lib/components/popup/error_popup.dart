import 'package:flutter/material.dart';
import '../../theme/super_admin_theme.dart';

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
    final palette = Theme.of(context).extension<SuperAdminColors>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface =
        palette?.surface ?? (isDark ? const Color(0xFF262C3A) : Colors.white);
    final textPrimary =
        palette?.textPrimary ?? (isDark ? Colors.white : Colors.black87);
    final textSecondary =
        palette?.textSecondary ??
        (isDark ? const Color(0xFFB5BDCB) : Colors.black54);
    final accent = palette?.accent ?? const Color(0xFF2196F3);

    final double screenWidth = MediaQuery.of(context).size.width;
    final double dialogWidth = screenWidth < 400 ? screenWidth * 0.95 : 340;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
      backgroundColor: surface,
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
                  color: textPrimary,
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
              infoRow('Subject:', subject, textPrimary, textSecondary),
              infoRow('Date:', date, textPrimary, textSecondary),
              infoRow('Time:', time, textPrimary, textSecondary),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    backgroundColor: accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
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
