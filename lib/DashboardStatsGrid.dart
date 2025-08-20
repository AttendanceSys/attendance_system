import 'package:flutter/material.dart';
import 'package:attendance_system/components/dashboard_stats_grid.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Bright background, fills screen
      appBar: AppBar(
        title: const Text("Dashboard"),
        backgroundColor: Colors.indigo.shade100,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Add your search bar here if needed
            // SearchAddBar(...),
            // SizedBox(height: 18),
            Expanded(
              child: DashboardStatsGrid(
                stats: [
                  DashboardStat(
                    icon: Icons.account_tree,
                    label: "Departments",
                    value: "6",
                    color: Color(0xFFD23CA7),
                  ),
                  DashboardStat(
                    icon: Icons.menu_book,
                    label: "Courses",
                    value: "6",
                    color: Color(0xFFF7B345),
                  ),
                  DashboardStat(
                    icon: Icons.groups,
                    label: "Classes",
                    value: "16",
                    color: Color(0xFF31B9C1),
                  ),
                  DashboardStat(
                    icon: Icons.people,
                    label: "Students",
                    value: "2,000",
                    color: Color(0xFFB9EEB6),
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