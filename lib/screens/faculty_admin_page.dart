import 'package:attendance_system/components/pages/classes_page.dart';
import 'package:attendance_system/components/pages/courses_page.dart';
import 'package:attendance_system/components/pages/departments_page.dart';
import 'package:attendance_system/components/pages/students_page.dart';
import 'package:flutter/material.dart';
import '../layouts/faculty_admin_layout.dart';
import '../components/faculty_dashboard_stats_grid.dart';
import '../components/pages/faculty_user_handling_page.dart';
import '../components/pages/attendance_page.dart';
import '../components/pages/timetable_page.dart';

class FacultyAdminPage extends StatelessWidget {
  final String displayName;
  final String? facultyId;

  const FacultyAdminPage({super.key, this.displayName = '', this.facultyId});

  @override
  Widget build(BuildContext context) {
    return FacultyAdminLayout(
      customPages: [
        // 0: Dashboard (custom)
        Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const Text(
                "Dashboard",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 32),
              Expanded(child: DashboardStatsGrid(facultyId: facultyId)),
            ],
          ),
        ),
        // 1: Departments
        DepartmentsPage(facultyId: facultyId),
        // 2: Students
        StudentsPage(facultyId: facultyId),
        // 3: Subjects
        // 4: Classes
        CoursesPage(),
        ClassesPage(),
        // 5: Attendance
        AttendanceUnifiedPage(),
        // 6: TimeTable
        TimetablePage(),
        // 7: User Handling
        FacultyUserHandlingPage(),
      ],
      displayName: displayName,
    );
  }
}
