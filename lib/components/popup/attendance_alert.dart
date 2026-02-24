import 'package:flutter/material.dart';
import '../student_theme_controller.dart';

enum AttendanceAlertType {
  alreadyRecorded,
  notYourClass,
  qrExpired,
  success,
  info,
}

class AttendanceAlert {
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
    title: 'Attendance Already Marked',
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

  static Future<void> showInvalidQr(
    BuildContext context, {
    String? details,
    VoidCallback? onClose,
  }) => _show(
    context,
    type: AttendanceAlertType.info,
    title: 'Invalid QR Code',
    message:
        details ??
        'This QR code is not a valid attendance session from this system.',
    onClose: onClose,
  );

  static Future<void> showSuccess(
    BuildContext context, {
    String? subject,
    String? date,
    String? time,
    Duration? autoCloseAfter,
    VoidCallback? onClose,
  }) => _show(
    context,
    type: AttendanceAlertType.success,
    subject: subject,
    date: date,
    time: time,
    title: 'Attendance Marked Successfully',
    autoCloseAfter: autoCloseAfter,
    onClose: onClose,
  );

  static Future<void> showLocationBlocked(
    BuildContext context, {
    String? details,
    VoidCallback? onClose,
  }) => _show(
    context,
    type: AttendanceAlertType.info,
    title: 'Location Verification Failed',
    message:
        details ??
        'You appear to be outside the allowed location for this session.',
    onClose: onClose,
  );

  static Future<void> showAnomalyFlagged(
    BuildContext context, {
    String? details,
    VoidCallback? onClose,
  }) => _show(
    context,
    type: AttendanceAlertType.info,
    title: 'Suspicious Activity Detected',
    message:
        details ?? 'Your scan was flagged as suspicious and will be reviewed.',
    onClose: onClose,
  );

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

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(canPop: false, child: dialog),
    );

    // Intentionally ignored. Keep explicit OK close for consistency.
    if (autoCloseAfter != null) {}
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

  Color _toneColor(StudentThemeProxy theme) {
    switch (type) {
      case AttendanceAlertType.success:
        return const Color(0xFF16B36A);
      case AttendanceAlertType.alreadyRecorded:
        return const Color(0xFF1F8FE5);
      case AttendanceAlertType.notYourClass:
      case AttendanceAlertType.qrExpired:
        return const Color(0xFFE24646);
      case AttendanceAlertType.info:
        return const Color(0xFFE68A00);
    }
  }

  IconData _icon() {
    switch (type) {
      case AttendanceAlertType.success:
        return Icons.check_rounded;
      case AttendanceAlertType.alreadyRecorded:
        return Icons.verified_rounded;
      case AttendanceAlertType.notYourClass:
        return Icons.block_rounded;
      case AttendanceAlertType.qrExpired:
        return Icons.timer_off_rounded;
      case AttendanceAlertType.info:
        return Icons.info_rounded;
    }
  }

  String _defaultTitle() {
    switch (type) {
      case AttendanceAlertType.success:
        return 'Attendance Marked Successfully';
      case AttendanceAlertType.alreadyRecorded:
        return 'Attendance Already Marked';
      case AttendanceAlertType.notYourClass:
        return 'Not Your Class';
      case AttendanceAlertType.qrExpired:
        return 'Session Ended';
      case AttendanceAlertType.info:
        return 'Notice';
    }
  }

  String _defaultMessage() {
    switch (type) {
      case AttendanceAlertType.success:
        return 'Attendance has been recorded for this session.';
      case AttendanceAlertType.alreadyRecorded:
        return 'Attendance for this session has already been recorded.';
      case AttendanceAlertType.notYourClass:
        return 'This QR/session does not belong to your assigned class.';
      case AttendanceAlertType.qrExpired:
        return 'This QR/session has expired. Please request a new active session.';
      case AttendanceAlertType.info:
        return '';
    }
  }

  Widget _metaTile({
    required String label,
    required String value,
    required Color fg,
    required Color bg,
    required Color border,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: fg.withValues(alpha: 0.72),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: fg,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final studentTheme = StudentThemeController.instance.theme;
    final isDark = StudentThemeController.instance.isDarkMode;
    final tone = _toneColor(studentTheme);
    final titleText = title?.trim().isNotEmpty == true ? title!.trim() : _defaultTitle();
    final messageText = message?.trim().isNotEmpty == true
        ? message!.trim()
        : _defaultMessage();

    final infoValues = <MapEntry<String, String>>[];
    if ((subject ?? '').trim().isNotEmpty) {
      infoValues.add(MapEntry('Subject', subject!.trim()));
    }
    if ((date ?? '').trim().isNotEmpty) {
      infoValues.add(MapEntry('Date', date!.trim()));
    }
    if ((time ?? '').trim().isNotEmpty) {
      infoValues.add(MapEntry('Time', time!.trim()));
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        decoration: BoxDecoration(
          color: studentTheme.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: studentTheme.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.30 : 0.12),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 74,
                height: 74,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(_icon(), color: tone, size: 40),
              ),
              Text(
                titleText,
                style: TextStyle(
                  color: studentTheme.foreground,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
              ),
              if (messageText.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  messageText,
                  style: TextStyle(
                    color: studentTheme.hint,
                    fontSize: 14,
                    height: 1.35,
                  ),
                ),
              ],
              if (infoValues.isNotEmpty) ...[
                const SizedBox(height: 14),
                ...infoValues.map(
                  (e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _metaTile(
                      label: e.key,
                      value: e.value,
                      fg: studentTheme.foreground,
                      bg: studentTheme.inputBackground,
                      border: studentTheme.border,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: studentTheme.button,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                  onClose?.call();
                },
                child: const Text(
                  'OK',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
