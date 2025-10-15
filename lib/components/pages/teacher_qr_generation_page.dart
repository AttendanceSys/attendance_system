import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class TeacherQRGenerationPage extends StatefulWidget {
  const TeacherQRGenerationPage({super.key});

  @override
  State<TeacherQRGenerationPage> createState() =>
      _TeacherQRGenerationPageState();
}

class _TeacherQRGenerationPageState extends State<TeacherQRGenerationPage> {
  String? department;
  String? className;
  String? section;
  String? subject;

  String? qrCodeData;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Generate QR Code",
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 14,
            runSpacing: 12,
            alignment: WrapAlignment.start,
            children: [
              _dropdown(
                department,
                ["CS", "IT", "SE"],
                (v) => setState(() => department = v),
                "Select Department",
              ),
              _dropdown(
                className,
                ["B3SC", "B2IT", "B1SE"],
                (v) => setState(() => className = v),
                "Select Class",
              ),
              _dropdown(
                section,
                ["A", "B", "C"],
                (v) => setState(() => section = v),
                "Select Section",
              ),
              _dropdown(
                subject,
                ["Cloud Computing", "Software Engineering", "Databases"],
                (v) => setState(() => subject = v),
                "Select Subject",
              ),
              const SizedBox(width: 18),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2196F3),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                onPressed: () {
                  final now = DateTime.now().toIso8601String();
                  setState(() {
                    qrCodeData =
                        "$subject|$department|$className|$section|$now";
                  });
                },
                child: const Text(
                  "Generate QR Code",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Center(
            child: qrCodeData == null
                ? Container(
                    height: 260,
                    width: 260,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: Colors.grey[100],
                      border: Border.all(color: Colors.grey[300]!, width: 2),
                    ),
                    child: const Text(
                      "No QR Code generated yet.",
                      style: TextStyle(color: Colors.grey, fontSize: 18),
                    ),
                  )
                : Column(
                    children: [
                      QrImageView(
                        data: qrCodeData!,
                        size: 260.0,
                        backgroundColor: Colors.white,
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: 320,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          "For:\nSubject: $subject\nDepartment: $department\nClass: $className\nSection: $section",
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _dropdown(
    String? value,
    List<String> items,
    ValueChanged<String?> onChanged,
    String hint,
  ) {
    return DropdownButton<String>(
      value: value,
      items: [
        DropdownMenuItem(
          value: null,
          child: Text(hint, style: const TextStyle(color: Colors.grey)),
        ),
        ...items
            .map((e) => DropdownMenuItem(value: e, child: Text(e)))
            .toList(),
      ],
      onChanged: onChanged,
      style: const TextStyle(fontSize: 18, color: Colors.black87),
      underline: const SizedBox(),
      borderRadius: BorderRadius.circular(10),
      dropdownColor: Colors.white,
    );
  }
}
