import 'package:flutter/material.dart';

class AdminDashboardStatsGrid extends StatelessWidget {
  const AdminDashboardStatsGrid({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    double aspectRatio = screenWidth < 500 ? 1.4 : 2.2;

    // Always 2 columns, so 3rd card starts second line
    return GridView.count(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: aspectRatio,
      children: [
        _StatsCard(
          icon: Icons.account_tree_outlined,
          label: "Faculties",
          value: "4",
          color: Color(0xFFB9EEB6),
        ),
        _StatsCard(
          icon: Icons.groups,
          label: "Admins",
          value: "0",
          color: Color(0xFFF7B345),
        ),
        _StatsCard(
          icon: Icons.school_outlined,
          label: "Lecturers",
          value: "4",
          color: Color(0xFF31B9C1),
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
    Key? key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const double numberLeftPadding = 39.0;
    final screenWidth = MediaQuery.of(context).size.width;
    double labelFont = screenWidth < 500 ? 16 : 19;
    double numberFont = screenWidth < 500 ? 28 : 36;

    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: EdgeInsets.symmetric(horizontal: 22, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 29),
              SizedBox(width: 10),
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
          SizedBox(height: 12),
          Padding(
            padding: EdgeInsets.only(left: numberLeftPadding),
            child: Text(
              value,
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