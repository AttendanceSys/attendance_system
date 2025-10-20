import 'package:flutter/material.dart';

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
    final double screenWidth = MediaQuery.of(context).size.width;
    final double dialogWidth = screenWidth < 400 ? screenWidth * 0.95 : 340;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: dialogWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'Session Ended',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
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
              infoRow('Subject:', subject),
              infoRow('Date:', date),
              infoRow('Time:', time),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.blue,
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

  Widget infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.normal, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }
}