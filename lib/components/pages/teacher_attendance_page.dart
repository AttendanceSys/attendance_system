import 'package:flutter/material.dart';

class TeacherAttendancePage extends StatefulWidget {
  const TeacherAttendancePage({Key? key}) : super(key: key);

  @override
  State<TeacherAttendancePage> createState() => _TeacherAttendancePageState();
}

class _TeacherAttendancePageState extends State<TeacherAttendancePage> {
  List<Map<String, dynamic>> students = [
    {"id": "5555", "name": "Anisa Mohamed", "present": true},
    {"id": "6666", "name": "Qali Abdi", "present": false},
    {"id": "7777", "name": "Adnan Mohamed", "present": true},
    {"id": "5555", "name": "Anisa Mohamed", "present": true},
    {"id": "6666", "name": "Qali Abdi", "present": true},
    {"id": "7777", "name": "Adnan Mohamed", "present": false},
    {"id": "7777", "name": "Adnan Mohamed", "present": true},
  ];

  String department = "CS";
  String className = "B3SC";
  String section = "A";

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Attendance",
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 14,
            runSpacing: 12,
            children: [
              _dropdown(department, [
                "CS",
                "IT",
                "SE",
              ], (v) => setState(() => department = v ?? department)),
              _dropdown(className, [
                "B3SC",
                "B2IT",
                "B1SE",
              ], (v) => setState(() => className = v ?? className)),
              _dropdown(section, [
                "A",
                "B",
                "C",
              ], (v) => setState(() => section = v ?? section)),
            ],
          ),
          const SizedBox(height: 28),
          Container(
            color: Colors.grey[100],
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
            child: Row(
              children: [
                _headerCell("No", flex: 1),
                _headerCell("ID", flex: 2),
                _headerCell("Student Name", flex: 4),
                _headerCell("Status", flex: 2, align: TextAlign.center),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: students.length,
              itemBuilder: (context, index) {
                final s = students[index];
                return Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.grey.shade300, width: 1),
                    ),
                  ),
                  child: Row(
                    children: [
                      _tableCell('${index + 1}', flex: 1),
                      _tableCell(s['id'], flex: 2),
                      _tableCell(s['name'], flex: 4),
                      Expanded(
                        flex: 2,
                        child: Center(
                          child: Switch(
                            value: s['present'],
                            onChanged: (v) {
                              setState(() {
                                students[index]['present'] = v;
                              });
                            },
                            activeColor: Colors.green,
                            inactiveThumbColor: Colors.redAccent,
                            inactiveTrackColor: Colors.red[200],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Align(
            alignment: Alignment.bottomRight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                padding: const EdgeInsets.symmetric(
                  horizontal: 34,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              onPressed: () {
                // TODO: Submit attendance logic
              },
              child: const Text(
                "Submit",
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropdown(
    String value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    return DropdownButton<String>(
      value: value,
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: onChanged,
      style: const TextStyle(fontSize: 18, color: Colors.black87),
      underline: const SizedBox(),
      borderRadius: BorderRadius.circular(10),
      dropdownColor: Colors.white,
    );
  }

  Widget _headerCell(
    String text, {
    int flex = 1,
    TextAlign align = TextAlign.left,
  }) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        textAlign: align,
      ),
    );
  }

  Widget _tableCell(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
        child: Text(text, style: const TextStyle(fontSize: 16)),
      ),
    );
  }
}