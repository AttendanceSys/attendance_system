import 'package:flutter/material.dart';
import '../popup/student_profile_popup.dart';
import 'student_scan_attendance_page.dart';

class StudentViewAttendanceMobile extends StatelessWidget {
  const StudentViewAttendanceMobile({Key? key}) : super(key: key);

  final List<Map<String, dynamic>> attendance = const [
    {'course': 'Cloud', 'present': 11, 'absent': 0},
    {'course': 'Cloud', 'present': 10, 'absent': 2},
    {'course': 'Cloud', 'present': 10, 'absent': 2},
    {'course': 'Cloud', 'present': 10, 'absent': 2},
    {'course': 'Software engineering', 'present': 10, 'absent': 2},
  ];

  @override
  Widget build(BuildContext context) {
    final studentName = "QaalI Cabdi Cali";
    final avatarLetter = "Q";
    final className = "B3-A Computer Science";
    final semester = "Semester 7";
    final gender = "Female";
    final id = "B3SC760";

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top: Welcome & Avatar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Welcome $studentName!",
                            style: TextStyle(
                                fontSize: 22, fontWeight: FontWeight.w400, color: Colors.black87)),
                        SizedBox(height: 14),
                        Text("View Attendance",
                            style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87)),
                      ],
                    ),
                  ),
                  // Avatar: tap to show profile popup
                  Column(
                    children: [
                      GestureDetector(
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (_) => StudentProfilePopup(
                              name: studentName,
                              className: className,
                              semester: semester,
                              gender: gender,
                              id: id,
                              avatarLetter: avatarLetter,
                            ),
                          );
                        },
                        child: CircleAvatar(
                          radius: 32,
                          backgroundColor: Colors.lightBlue[400],
                          child: Text(
                            avatarLetter,
                            style: TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        studentName,
                        style: TextStyle(fontWeight: FontWeight.w400, fontSize: 16),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            // Attendance cards
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: 8),
                itemCount: attendance.length,
                itemBuilder: (context, index) {
                  final item = attendance[index];
                  final int present = item['present'];
                  final int absent = item['absent'];
                  final hasAbsent = absent > 0;

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Course name above the bar
                        Padding(
                          padding: const EdgeInsets.only(left: 12, bottom: 4),
                          child: Text(
                            item['course'],
                            style: TextStyle(
                              color: Color(0xFF353F86),
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            // Present bar
                            Expanded(
                              flex: present,
                              child: Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Color(0xFF353F86),
                                  borderRadius: BorderRadius.horizontal(
                                    left: Radius.circular(32),
                                    right: hasAbsent ? Radius.circular(0) : Radius.circular(32),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    "$present present",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Absent bar
                            if (hasAbsent)
                              Expanded(
                                flex: absent,
                                child: Container(
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: Color(0xFFF41B4F),
                                    borderRadius: BorderRadius.horizontal(
                                      left: Radius.circular(0),
                                      right: Radius.circular(32),
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      "$absent absent",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // Bottom navigation bar
            Container(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const StudentViewAttendanceMobile()),
                      );
                    },
                    child: Column(
                      children: [
                        Text("View  Attendance",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w400)),
                        SizedBox(height: 2),
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: Colors.lightBlue[400],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(Icons.table_chart, size: 32, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => StudentScanAttendancePage()),
                      );
                    },
                    child: Column(
                      children: [
                        Text("Scan  Attendance",
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w400)),
                        SizedBox(height: 2),
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: Colors.lightBlue[400],
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(Icons.qr_code_scanner, size: 38, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}