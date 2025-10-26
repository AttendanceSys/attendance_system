import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminDashboardStatsGrid extends StatelessWidget {
  const AdminDashboardStatsGrid({super.key});

  Future<int> _fetchCount(String collectionName) async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection(collectionName).get();
      return snapshot.size; // Get number of documents in the collection
    } catch (e) {
      print("Error fetching count for $collectionName: $e");
      return 0; // Return 0 in case of error
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    double aspectRatio = screenWidth < 500 ? 1.4 : 2.4;

    // Always 2 columns, so 3rd card starts second line
    return FutureBuilder(
      future: Future.wait([
        _fetchCount("faculties"),
        _fetchCount("admins"),
        _fetchCount("teachers"), // Fetch lecturers/teachers data
      ]),
      builder: (context, AsyncSnapshot<List<int>> snapshot) {
        if (!snapshot.hasData) {
          // Show loading indicator while data is being fetched
          return Center(
            child: CircularProgressIndicator(),
          );
        }

        // Extract counts from snapshot
        final facultiesCount = snapshot.data![0];
        final adminsCount = snapshot.data![1];
        final lecturersCount = snapshot.data![2];

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
              value: facultiesCount.toString(),
              color: const Color(0xFFB9EEB6),
            ),
            _StatsCard(
              icon: Icons.groups,
              label: "Admins",
              value: adminsCount.toString(),
              color: const Color(0xFFF7B345),
            ),
            _StatsCard(
              icon: Icons.school_outlined,
              label: "Lecturers",
              value: lecturersCount.toString(),
              color: const Color(0xFF31B9C1),
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
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

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