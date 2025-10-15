import 'package:flutter/material.dart';
import '../../components/faculty_dashboard_stats_grid.dart';

class DashboardPage extends StatelessWidget {
  const DashboardPage({Key? key}) : super(key: key);

   @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Admin Stats"),
        backgroundColor: Colors.indigo.shade100,
      ),
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: DashboardStatsGrid(),
      ),
    );
  }
}