import 'package:attendance_system/components/pages/classes_page.dart';
import 'package:attendance_system/components/pages/courses_page.dart';
import 'package:attendance_system/components/pages/departments_page.dart';
import 'package:attendance_system/components/pages/admin_anomalies_page.dart';
import 'package:attendance_system/components/pages/students_page.dart';
import 'package:flutter/material.dart';
import '../layouts/faculty_admin_layout.dart';
import '../components/faculty_dashboard_stats_grid.dart';
import '../components/pages/faculty_user_handling_page.dart';
import '../components/pages/attendance_page.dart';
import '../components/pages/admin_profile_page.dart';
import 'package:attendance_system/components/pages/timetable_page.dart';

class FacultyAdminPage extends StatelessWidget {
  const FacultyAdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FacultyAdminLayout(
      customPages: [
        // 0: Dashboard (custom)
        Padding(
          // Dashboard needs extra top space to align with floating header controls.
          padding: const EdgeInsets.fromLTRB(32.0, 44.0, 32.0, 32.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Builder(
                  builder: (context) {
                    final theme = Theme.of(context);
                    return Text(
                      "Dashboard",
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    );
                  },
                ),
                const DashboardStatsGrid(),
              ],
            ),
          ),
        ),
        // 1: Departments
        DepartmentsPage(),
        // 2: Classes
        ClassesPage(),
        // 3: Students
        StudentsPage(),
        // 4: Courses
        CoursesPage(),
        // 5: Attendance
        AttendanceUnifiedPage(),
        // 6: TimeTable
        TimetablePage(),
        // 7: User Handling
        FacultyUserHandlingPage(),
        // 8: Anomalies
        const AdminAnomaliesPage(),
        // 9: Profile
        const AdminProfilePage(
          roleFilter: 'admin',
          roleLabel: 'Faculty Admin',
        ),
      ],
    );
  }
}
