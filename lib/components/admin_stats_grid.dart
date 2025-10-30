// ...existing code...
import 'package:flutter/material.dart';
import '../hooks/use_admins.dart';
import '../hooks/use_lectureres.dart';
import '../hooks/use_faculties.dart';

class AdminDashboardStatsGrid extends StatefulWidget {
  const AdminDashboardStatsGrid({super.key});

  @override
  State<AdminDashboardStatsGrid> createState() => _AdminDashboardStatsGridState();
}

class _AdminDashboardStatsGridState extends State<AdminDashboardStatsGrid> {
  int facultyCount = 0;
  int adminCount = 0;
  int lecturerCount = 0;
  bool loading = true;

  final _facilities = UseFaculties();
  final _admins = UseAdmins();
  final _teachers = UseTeachers();

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    setState(() => loading = true);
    try {
      final faculties = await _facilities.fetchFaculties();
      final admins = await _admins.fetchAdmins();
      final teachers = await _teachers.fetchTeachers();

      setState(() {
        facultyCount = faculties.length;
        adminCount = admins.length;
        lecturerCount = teachers.length;
        loading = false;
      });
    } catch (e) {
      // On error keep counts at 0 and stop loading.
      setState(() {
        facultyCount = 0;
        adminCount = 0;
        lecturerCount = 0;
        loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    double aspectRatio = screenWidth < 500 ? 1.4 : 2.4;

    String facultiesValue = loading ? '...' : facultyCount.toString();
    String adminsValue = loading ? '...' : adminCount.toString();
    String lecturersValue = loading ? '...' : lecturerCount.toString();

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: aspectRatio,
      children: [
        _StatsCard(
          icon: Icons.account_tree_outlined,
          label: "Faculties",
          value: facultiesValue,
          color: const Color(0xFFB9EEB6),
        ),
        _StatsCard(
          icon: Icons.groups,
          label: "Admins",
          value: adminsValue,
          color: const Color(0xFFF7B345),
        ),
        _StatsCard(
          icon: Icons.school_outlined,
          label: "Lecturers",
          value: lecturersValue,
          color: const Color(0xFF31B9C1),
        ),
      ],
    );
  }
}

class _StatsCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _StatsCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
// ...existing code...
  @override
  Widget build(BuildContext context) {
    const double numberLeftPadding = 39.0;
    final screenWidth = MediaQuery.of(context).size.width;
    double labelFont = screenWidth < 500 ? 20 : 29;
    double numberFont = screenWidth < 500 ? 36 : 50;

    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 50),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: labelFont,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // centered value (both vertically and horizontally)
          Expanded(
            child: Center(
              child: Text(
                value,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: numberFont,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
// ...existing code...
