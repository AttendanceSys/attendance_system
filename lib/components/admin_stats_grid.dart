//admin stast_grid

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminDashboardStatsGrid extends StatelessWidget {
  const AdminDashboardStatsGrid({super.key});

  Future<int> _fetchCount(String collectionName) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(collectionName)
          .get();
      return snapshot.size; // Get number of documents in the collection
    } catch (e) {
      print("Error fetching count for $collectionName: $e");
      return 0; // Return 0 in case of error
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: Future.wait([
        _fetchCount("faculties"),
        _fetchCount("admins"),
        _fetchCount("teachers"), // Fetch lecturers/teachers data
      ]),
      builder: (context, AsyncSnapshot<List<int>> snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final facultiesCount = snapshot.data![0];
        final adminsCount = snapshot.data![1];
        final lecturersCount = snapshot.data![2];

        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;

            int crossAxis;
            if (width < 550) {
              crossAxis = 1; // Mobile
            } else if (width < 900) {
              crossAxis = 2; // Tablet Portrait
            } else if (width < 1300) {
              crossAxis = 3; // Tablet Landscape
            } else {
              crossAxis = 4; // Desktop
            }

            final labels = ["Faculties", "Admins", "Lecturers"];
            final icons = [
              Icons.account_tree_outlined,
              Icons.groups,
              Icons.school_outlined,
            ];
            final colors = [
              const Color(0xFFB9EEB6),
              const Color(0xFFF7B345),
              const Color(0xFF31B9C1),
            ];
            final values = [
              facultiesCount.toString(),
              adminsCount.toString(),
              lecturersCount.toString(),
            ];

            return GridView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: labels.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxis,
                crossAxisSpacing: 22,
                mainAxisSpacing: 22,
                childAspectRatio: 1.4,
              ),
              itemBuilder: (context, index) {
                return _StatsCard(
                  label: labels[index],
                  value: values[index],
                  icon: icons[index],
                  color: colors[index],
                );
              },
            );
          },
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
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, size) {
        final scale = (size.maxHeight / 180).clamp(0.75, 1.0);
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final bgColor = isDark
            ? (Theme.of(context).cardTheme.color ??
                  Theme.of(context).colorScheme.surface)
            : Colors.white;
        final textColor =
            Theme.of(context).textTheme.bodyMedium?.color ??
            (isDark ? Colors.white : Colors.black87);

        return ClipRect(
          child: Container(
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(20 * scale),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.all(16 * scale),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ICON BADGE
                  Container(
                    padding: EdgeInsets.all(12 * scale),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 30 * scale, color: color),
                  ),

                  SizedBox(height: 14 * scale),

                  // LABEL
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16 * scale,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),

                  SizedBox(height: 10 * scale),

                  // VALUE — FittedBox prevents overflow
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          value,
                          style: TextStyle(
                            fontSize: 38 * scale,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
