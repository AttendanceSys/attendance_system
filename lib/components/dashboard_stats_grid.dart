import 'package:flutter/material.dart';

class DashboardStatsGrid extends StatelessWidget {
  final List<DashboardStat> stats;
  const DashboardStatsGrid({Key? key, required this.stats}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Use MediaQuery to adjust grid ratio for small screens
    final screenWidth = MediaQuery.of(context).size.width;
    double aspectRatio = screenWidth < 500 ? 1.2 : 1.8; // Tighter grid for mobile

    return GridView.count(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: aspectRatio,
      children: stats.map((stat) => _DashboardStatCard(stat: stat)).toList(),
    );
  }
}

class DashboardStat {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  DashboardStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
}

class _DashboardStatCard extends StatelessWidget {
  final DashboardStat stat;
  const _DashboardStatCard({Key? key, required this.stat}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Use MediaQuery to reduce font sizes on small screens
    final screenWidth = MediaQuery.of(context).size.width;
    double labelFont = screenWidth < 500 ? 16 : 19;
    double numberFont = screenWidth < 500 ? 28 : 36;

    // Padding for number so it aligns under label
    const double numberLeftPadding = 39.0;

    return Container(
      decoration: BoxDecoration(
        color: stat.color,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(stat.icon, color: Colors.white, size: 26),
              SizedBox(width: 10),
              Flexible(
                child: Text(
                  stat.label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: labelFont,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Padding(
            padding: EdgeInsets.only(left: numberLeftPadding),
            child: Text(
              stat.value,
              style: TextStyle(
                color: Colors.white,
                fontSize: numberFont,
                fontWeight: FontWeight.bold,
                height: 1,
              ),
              textAlign: TextAlign.left,
            ),
          ),
        ],
      ),
    );
  }
}

// --- Example usage in DashboardPage ---
class DashboardPage extends StatelessWidget {
  const DashboardPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Dashboard"),
        backgroundColor: Colors.indigo.shade100,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Your SearchAddBar here
            SizedBox(height: 18),
            // Expanded ensures grid uses available space and scrolls if needed
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