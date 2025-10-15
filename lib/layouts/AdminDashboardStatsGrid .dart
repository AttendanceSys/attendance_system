import 'package:flutter/material.dart';
import '../../components/admin_stats_grid.dart';

class AdminStatsPage extends StatelessWidget {
  const AdminStatsPage({super.key});

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
        child: AdminDashboardStatsGrid(),
      ),
    );
  }
}