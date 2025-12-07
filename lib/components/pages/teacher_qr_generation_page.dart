import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../hooks/use_qr_generation.dart';

class TeacherQRGenerationPage extends StatefulWidget {
  final String displayName;
  const TeacherQRGenerationPage({super.key, this.displayName = ''});

  @override
  State<TeacherQRGenerationPage> createState() =>
      _TeacherQRGenerationPageState();
}

class _TeacherQRGenerationPageState extends State<TeacherQRGenerationPage> {
  String? department;
  String? className;
  String? subject;

  String? qrCodeData;

  bool _loadingSchedules = true;
  List<LecturerSchedule> _schedules = [];

  List<String> _departmentItems = [];
  List<String> _classItems = [];
  List<String> _subjectItems = [];

  @override
  void initState() {
    super.initState();
    _loadTeacherSchedules();
  }

  Future<void> _loadTeacherSchedules() async {
    setState(() => _loadingSchedules = true);

    try {
      final svc = UseQRGeneration();
      final schedules = await svc.fetchScheduleByTeacher(
        displayName: widget.displayName,
      );

      _schedules = schedules;

      final deps = <String>{};
      final classes = <String>{};
      final subs = <String>{};

      for (final s in schedules) {
        final depLabel = s.departmentName.isNotEmpty
            ? s.departmentName
            : (s.departmentId.isNotEmpty ? s.departmentId : '');
        final classLabel = s.className.isNotEmpty
            ? s.className
            : (s.classId.isNotEmpty ? s.classId : '');
        final courseLabel = s.courseName.isNotEmpty
            ? s.courseName
            : (s.courseId.isNotEmpty ? s.courseId : '');
        if (depLabel.isNotEmpty) deps.add(depLabel);
        if (classLabel.isNotEmpty) classes.add(classLabel);
        if (courseLabel.isNotEmpty) subs.add(courseLabel);
      }

      setState(() {
        _departmentItems = deps.toList()..sort();
        _classItems = classes.toList()..sort();
        _subjectItems = subs.toList()..sort();
        _loadingSchedules = false;
      });
    } catch (_) {
      setState(() => _loadingSchedules = false);
    }
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
        ...items.map((e) => DropdownMenuItem(value: e, child: Text(e))),
      ],
      onChanged: (v) {
        onChanged(v);
        setState(() {});
      },
      underline: const SizedBox(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Generate QR Code",
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          if (_loadingSchedules) const LinearProgressIndicator(),

          const SizedBox(height: 20),

          Wrap(
            spacing: 20,
            runSpacing: 12,
            children: [
              _dropdown(department, _departmentItems, (v) {
                department = v;

                _classItems = _schedules
                    .where(
                      (s) => (s.departmentName == v) || (s.departmentId == v),
                    )
                    .map(
                      (s) => s.className.isNotEmpty ? s.className : s.classId,
                    )
                    .toSet()
                    .toList();

                className = null;
                subject = null;
                _subjectItems = [];
              }, "Select Department"),

              _dropdown(className, _classItems, (v) {
                className = v;

                _subjectItems = _schedules
                    .where((s) => (s.className == v) || (s.classId == v))
                    .map(
                      (s) =>
                          s.courseName.isNotEmpty ? s.courseName : s.courseId,
                    )
                    .toSet()
                    .toList();

                subject = null;
              }, "Select Class"),

              _dropdown(
                subject,
                _subjectItems,
                (v) => subject = v,
                "Select Subject",
              ),

              ElevatedButton(
                onPressed: () async {
                  if (department == null ||
                      className == null ||
                      subject == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Complete all fields")),
                    );
                    return;
                  }

                  final now = DateTime.now().toIso8601String();
                  final payload = "$subject|$department|$className|$now";

                  setState(() => qrCodeData = payload);

                  String? teacherId;
                  if (_schedules.isNotEmpty) {
                    teacherId = _schedules.first.teacher;
                  }
                  // fallback: try resolving by displayName
                  if (teacherId == null || teacherId.isEmpty) {
                    try {
                      teacherId = await UseQRGeneration().getTeacherDatabaseId(
                        displayName: widget.displayName,
                      );
                    } catch (_) {}
                  }

                  await UseQRGeneration().createQr(
                    payload: payload,
                    teacherId: teacherId,
                  );

                  if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(const SnackBar(content: Text("QR saved")));
                  }
                },
                child: const Text("Generate QR"),
              ),
            ],
          ),

          const SizedBox(height: 40),

          Center(
            child: qrCodeData == null
                ? Container(
                    width: 220,
                    height: 220,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: Colors.grey[200],
                    ),
                    child: const Text("No QR generated"),
                  )
                : QrImageView(
                    data: qrCodeData!,
                    size: 260,
                    backgroundColor: Colors.white,
                  ),
          ),
        ],
      ),
    );
  }
}
