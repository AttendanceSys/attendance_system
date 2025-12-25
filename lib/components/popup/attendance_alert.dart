import 'package:flutter/material.dart';
import '../../theme/super_admin_theme.dart';

enum AttendanceAlertType {
  alreadyRecorded,
  notYourClass,
  qrExpired,
  success,
  info,
}

class AttendanceAlert {
  // Convenience show methods (all accept optional subject/date/time details)
  static Future<void> showAlreadyRecorded(
    BuildContext context, {
    String? subject,
    String? date,
    String? time,
    VoidCallback? onClose,
  }) => _show(
    context,
    type: AttendanceAlertType.alreadyRecorded,
    subject: subject,
    date: date,
    time: time,
    title: 'Already Attendance\nMarked',
    onClose: onClose,
  );

  static Future<void> showNotYourClass(
    BuildContext context, {
    String? subject,
    String? date,
    String? time,
    String? details,
    VoidCallback? onClose,
  }) => _show(
    context,
    type: AttendanceAlertType.notYourClass,
    subject: subject,
    date: date,
    time: time,
    title: 'Not Your Class',
    message: details,
    onClose: onClose,
  );

  static Future<void> showQrExpired(
    BuildContext context, {
    String? subject,
    String? date,
    String? time,
    String? details,
    VoidCallback? onClose,
  }) => _show(
    context,
    type: AttendanceAlertType.qrExpired,
    subject: subject,
    date: date,
    time: time,
    title: 'Session Ended',
    message: details,
    onClose: onClose,
  );

  static Future<void> showSuccess(
    BuildContext context, {
    String? subject,
    String? date,
    String? time,
    Duration autoCloseAfter = const Duration(seconds: 2),
    VoidCallback? onClose,
  }) => _show(
    context,
    type: AttendanceAlertType.success,
    subject: subject,
    date: date,
    time: time,
    title: 'Attendance Marked\nSuccessfully',
    autoCloseAfter: autoCloseAfter,
    onClose: onClose,
  );

  // Generic show function
  static Future<void> _show(
    BuildContext context, {
    required AttendanceAlertType type,
    String? title,
    String? message,
    String? subject,
    String? date,
    String? time,
    Duration? autoCloseAfter,
    VoidCallback? onClose,
  }) async {
    final dialog = _AttendanceAlertDialog(
      type: type,
      title: title,
      message: message,
      subject: subject,
      date: date,
      time: time,
      onClose: onClose,
    );

    // Show dialog. Keep qrExpired non-dismissible if you prefer (so user must acknowledge).
    showDialog(
      context: context,
      barrierDismissible: type != AttendanceAlertType.qrExpired,
      builder: (_) => dialog,
    );

    if (autoCloseAfter != null) {
      await Future.delayed(autoCloseAfter);
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
        if (onClose != null) onClose();
      }
    }
  }
}

class _AttendanceAlertDialog extends StatelessWidget {
  final AttendanceAlertType type;
  final String? title;
  final String? message;
  final String? subject;
  final String? date;
  final String? time;
  final VoidCallback? onClose;

  const _AttendanceAlertDialog({
    required this.type,
    this.title,
    this.message,
    this.subject,
    this.date,
    this.time,
    this.onClose,
  });

  Color get _primaryColor {
    switch (type) {
      case AttendanceAlertType.success:
        return const Color(0xFF19C37D);
      case AttendanceAlertType.alreadyRecorded:
      case AttendanceAlertType.info:
        return Colors.orange.shade700;
      case AttendanceAlertType.notYourClass:
      case AttendanceAlertType.qrExpired:
      default:
        return Colors.red.shade600;
    }
  }

  IconData get _icon {
    switch (type) {
      case AttendanceAlertType.success:
        return Icons.check;
      case AttendanceAlertType.alreadyRecorded:
        return Icons
            .check_circle; // show success-looking icon for already-recorded
      case AttendanceAlertType.notYourClass:
        return Icons.block;
      case AttendanceAlertType.qrExpired:
        return Icons.timer_off;
      case AttendanceAlertType.info:
      default:
        return Icons.info_outline;
    }
  }

  String get _effectiveTitle => title ?? _defaultTitle;

  String get _defaultTitle {
    switch (type) {
      case AttendanceAlertType.success:
        return 'Attendance Marked\nSuccessfully';
      case AttendanceAlertType.alreadyRecorded:
        return 'Already Attendance\nMarked';
      case AttendanceAlertType.notYourClass:
        return 'Not Your Class';
      case AttendanceAlertType.qrExpired:
        return 'Session Ended';
      case AttendanceAlertType.info:
      default:
        return 'Notice';
    }
  }

  String get _effectiveMessage {
    if (message != null && message!.isNotEmpty) return message!;
    switch (type) {
      case AttendanceAlertType.success:
        return 'Attendance successfully recorded.';
      case AttendanceAlertType.alreadyRecorded:
        return 'Attendance for this session has already been recorded.';
      case AttendanceAlertType.notYourClass:
        return 'This QR/session does not belong to your assigned class or subject.';
      case AttendanceAlertType.qrExpired:
        return 'This QR/session has expired. Please request a new active session.';
      case AttendanceAlertType.info:
      default:
        return '';
    }
  }

  Widget _infoRow(
    BuildContext c,
    String label,
    String? value,
    Color labelColor,
    Color valueColor,
  ) {
    if (value == null || value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: labelColor,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w400,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

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

    final double screenW = MediaQuery.of(context).size.width;
    final double dialogW = screenW < 420 ? screenW * 0.96 : 380;
    final double dialogH = MediaQuery.of(context).size.height < 700
        ? MediaQuery.of(context).size.height * 0.82
        : 520;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      backgroundColor: surface,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: dialogW, maxHeight: dialogH),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title (large)
              Text(
                _effectiveTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 18),

              // Large circular icon (center)
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  color: _primaryColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(_icon, color: Colors.white, size: 96),
                ),
              ),

              const SizedBox(height: 22),

              // Message (optional short message)
              if (_effectiveMessage.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6.0),
                  child: Text(
                    _effectiveMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: textSecondary),
                  ),
                ),

              const SizedBox(height: 18),

              // Info rows (subject / date / time) — large readable text
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6.0),
                child: Column(
                  children: [
                    _infoRow(
                      context,
                      'Subject',
                      subject,
                      textSecondary,
                      textPrimary,
                    ),
                    _infoRow(context, 'Date', date, textSecondary, textPrimary),
                    _infoRow(context, 'Time', time, textSecondary, textPrimary),
                  ],
                ),
              ),

              const Spacer(),

              // OK button bottom-right
              Row(
                children: [
                  const Spacer(),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette?.accent ?? Colors.blue,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 4,
                    ),
                    onPressed: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                      if (onClose != null) onClose!();
                    },
                    child: const Text(
                      'OK',
                      style: TextStyle(fontSize: 20, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
