import 'package:flutter/material.dart';
import 'student_profile_page.dart';
import 'student_scan_attendance_page.dart';

class StudentViewAttendanceMobile extends StatelessWidget {
  const StudentViewAttendanceMobile({super.key});

  final List<Map<String, dynamic>> attendance = const [
    {'course': 'Cloud Computing', 'present': 28, 'absent': 2, 'total': 30},
    {'course': 'Software Engineering', 'present': 25, 'absent': 5, 'total': 30},
    {'course': 'Database Management', 'present': 29, 'absent': 1, 'total': 30},
    {
      'course': 'Artificial Intelligence',
      'present': 27,
      'absent': 3,
      'total': 30,
    },
    {'course': 'Web Development', 'present': 26, 'absent': 4, 'total': 30},
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
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: Column(
          children: [
            // Top app bar style (centered title + floating avatar button)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12,
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Center(
                      child: Text(
                        "Attendance Overview",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  Material(
                    elevation: 6,
                    shape: const CircleBorder(),
                    color: Colors.white,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => StudentProfilePage(
                              name: studentName,
                              className: className,
                              semester: semester,
                              gender: gender,
                              id: id,
                              avatarLetter: avatarLetter,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFFFFFFFF),
                          child: Text(
                            avatarLetter,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // List of cards (attendance items)
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                itemCount: attendance.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = attendance[index];
                  final String course = item['course'];
                  final int present = item['present'];
                  final int absent = item['absent'];
                  final int total = item['total'] ?? (present + absent);
                  final int presentFlex = (present > 0) ? present : 0;
                  final int absentFlex = (absent > 0) ? absent : 0;

                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                    margin: EdgeInsets.zero,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title row: course + Present/Absent on right
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  course,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF222238),
                                  ),
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    "Present: $present",
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF222238),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    "Absent: $absent",
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black45,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          // Progress bar (purple present + small red absent)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              height: 10,
                              color: const Color(0xFFF0F2F5),
                              child: Row(
                                children: [
                                  // Present portion
                                  if (presentFlex > 0)
                                    Expanded(
                                      flex: presentFlex,
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF6A46FF),
                                          borderRadius: BorderRadius.only(
                                            topLeft: Radius.circular(16),
                                            bottomLeft: Radius.circular(16),
                                          ),
                                        ),
                                      ),
                                    ),
                                  // Absent portion
                                  if (absentFlex > 0)
                                    Expanded(
                                      flex: absentFlex,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF05368),
                                          borderRadius: BorderRadius.only(
                                            topRight: Radius.circular(16),
                                            bottomRight: Radius.circular(16),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 8),

                          // small footer: total classes
                          Text(
                            "Total Classes: $total",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Bottom navigation area (raised and left-floating purple active button)
            Transform.translate(
              offset: const Offset(0, -14), // raise the whole bottom bar a bit
              child: Container(
                height: 86,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, -2),
                    ),
                  ],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        // Left: View Attendance (label only; floating button represents active icon)
                        InkWell(
                          onTap: () {
                            // already on this page
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              SizedBox(
                                height: 12,
                              ), // space for floating button above
                            ],
                          ),
                        ),

                        // Center: Scan Attendance
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    StudentScanAttendancePage(),
                              ),
                            );
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.qr_code_scanner,
                                color: Colors.black54,
                              ),
                              SizedBox(height: 6),
                              Text(
                                "Scan Attendance",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Right: Profile (open popup)
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => StudentProfilePage(
                                  name: studentName,
                                  className: className,
                                  semester: semester,
                                  gender: gender,
                                  id: id,
                                  avatarLetter: avatarLetter,
                                ),
                              ),
                            );
                          },
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.person_outline, color: Colors.black54),
                              SizedBox(height: 6),
                              Text(
                                "Profile",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // Left-floating purple active button (overlaps left nav)
                    Positioned(
                      left: 18,
                      top:
                          -36, // higher so it overlaps and appears floating (kor u kaca)
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GestureDetector(
                            onTap: () {
                              // already on view page
                            },
                            child: Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: const Color(0xFF6A46FF),
                                borderRadius: BorderRadius.circular(32),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF6A46FF,
                                    ).withOpacity(0.28),
                                    blurRadius: 14,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.menu_book_rounded,
                                size: 30,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
