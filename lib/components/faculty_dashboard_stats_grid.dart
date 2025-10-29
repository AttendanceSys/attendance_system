import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/session.dart';

class DashboardStatsGrid extends StatelessWidget {
  const DashboardStatsGrid({super.key});

  Future<int> _fetchCount(String collectionName) async {
    try {
      Query q = FirebaseFirestore.instance.collection(collectionName);
      if (Session.facultyRef != null) {
        q = q.where('faculty_ref', isEqualTo: Session.facultyRef);
      }
      final snapshot = await q.get();
      return snapshot.size;
    } catch (e) {
      print('Error fetching $collectionName count: $e');
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    double aspectRatio = screenWidth < 500 ? 1.4 : 2.4;

    return FutureBuilder<List<int>>(
      future: Future.wait([
        _fetchCount('departments'),
        _fetchCount('courses'),
        _fetchCount('classes'),
        _fetchCount('students'),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final deptCount = snapshot.data![0];
        final courseCount = snapshot.data![1];
        final classCount = snapshot.data![2];
        final studentCount = snapshot.data![3];

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
              label: 'Departments',
              value: deptCount.toString(),
              color: const Color(0xFFD23CA7),
            ),
            _StatsCard(
              icon: Icons.menu_book,
              label: 'Courses',
              value: courseCount.toString(),
              color: const Color(0xFFF7B345),
            ),
            _StatsCard(
              icon: Icons.groups,
              label: 'Classes',
              value: classCount.toString(),
              color: const Color(0xFF31B9C1),
            ),
            _StatsCard(
              icon: Icons.people,
              label: 'Students',
              value: studentCount.toString(),
              color: const Color(0xFFB9EEB6),
            ),
          ],
        );
      },
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
          Expanded(
            child: Center(
              child: Text(
                value,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: numberFont,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
