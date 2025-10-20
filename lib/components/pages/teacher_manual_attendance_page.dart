import 'package:flutter/material.dart';

class TeacherAttendanceManualPage extends StatefulWidget {
  const TeacherAttendanceManualPage({super.key});

  @override
  State<TeacherAttendanceManualPage> createState() => _TeacherAttendanceManualPageState();
}

class _TeacherAttendanceManualPageState extends State<TeacherAttendanceManualPage> {
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
    final bool isDesktop = MediaQuery.of(context).size.width > 700;

    Widget sidebar = Container(
      width: 210,
      color: const Color(0xFF353F86),
      child: Column(
        children: [
          const SizedBox(height: 34),
          CircleAvatar(
            radius: 38,
            backgroundColor: Colors.lightBlue[400],
            child: Text(
              "D",
              style: TextStyle(fontSize: 44, color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          SizedBox(height: 18),
          Text(
            "Dr Adam",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          SizedBox(height: 38),
          ListTile(
            leading: Icon(Icons.qr_code, color: Colors.white),
            title: Text("QR Generation", style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.of(context).pushReplacementNamed('/teacher-qr-generation');
            },
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.13),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListTile(
              leading: Icon(Icons.table_chart, color: Colors.white),
              title: Text("Attendance", style: TextStyle(color: Colors.white)),
              selected: true,
            ),
          ),
        ],
      ),
    );

    Widget mainContent = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Attendance", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
          SizedBox(height: 18),
          Wrap(
            spacing: 14,
            runSpacing: 12,
            children: [
              _dropdown(department, ["CS", "IT", "SE"], (v) => setState(() => department = v ?? department)),
              _dropdown(className, ["B3SC", "B2IT", "B1SE"], (v) => setState(() => className = v ?? className)),
              _dropdown(section, ["A", "B", "C"], (v) => setState(() => section = v ?? section)),
            ],
          ),
          SizedBox(height: 28),
          Container(
            color: Colors.grey[100],
            padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
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
                padding: EdgeInsets.symmetric(horizontal: 34, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(9),
                ),
              ),
              onPressed: () {
                // TODO: Submit attendance logic
              },
              child: Text(
                "Submit",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      body: isDesktop
          ? Row(
              children: [
                sidebar,
                Expanded(child: mainContent),
              ],
            )
          : Column(
              children: [
                SizedBox(
                  height: 74,
                  child: Row(
                    children: [
                      SizedBox(width: 16),
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.lightBlue[400],
                        child: Text(
                          "D",
                          style: TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        "Dr Adam",
                        style: TextStyle(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      Spacer(),
                      IconButton(
                        icon: Icon(Icons.qr_code),
                        onPressed: () {
                          Navigator.of(context).pushReplacementNamed('/teacher-qr-generation');
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.table_chart),
                        onPressed: () {},
                        color: Colors.blue,
                      ),
                      SizedBox(width: 16),
                    ],
                  ),
                ),
                Expanded(child: mainContent),
              ],
            ),
    );
  }

  Widget _dropdown(String value, List<String> items, ValueChanged<String?> onChanged) {
    return DropdownButton<String>(
      value: value,
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: onChanged,
      style: TextStyle(fontSize: 18, color: Colors.black87),
      underline: SizedBox(),
      borderRadius: BorderRadius.circular(10),
      dropdownColor: Colors.white,
    );
  }

  Widget _headerCell(String text, {int flex = 1, TextAlign align = TextAlign.left}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        textAlign: align,
      ),
    );
  }

  Widget _tableCell(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
        child: Text(
          text,
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}