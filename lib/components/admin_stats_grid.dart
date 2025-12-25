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

        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            int crossAxis;
            if (width < 550) {
              crossAxis = 1;
            } else if (width < 900) {
              crossAxis = 2;
            } else if (width < 1300) {
              crossAxis = 3;
            } else {
              crossAxis = 4;
            }
            return GridView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: labels.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxis,
                crossAxisSpacing: 22,
                mainAxisSpacing: 16,
                mainAxisExtent: 90,
              ),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              primary: false,
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
        final scale = (size.maxHeight / 130).clamp(0.75, 1.0);
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;

        return ClipRect(
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20 * scale),
              boxShadow: [
                BoxShadow(
                  color: theme.shadowColor.withOpacity(isDark ? 0.30 : 0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: theme.colorScheme.outline.withOpacity(
                  isDark ? 0.28 : 0.16,
                ),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 22 * scale,
                vertical: 12 * scale,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // LEFT: LABEL + VALUE
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: 6 * scale),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontSize: 18 * scale,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          SizedBox(height: 4 * scale),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              value,
                              style: TextStyle(
                                fontSize: 34 * scale,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // RIGHT: ICON
                  SizedBox(width: 14 * scale),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6 * scale),
                    child: Container(
                      decoration: BoxDecoration(
                        color: color.withOpacity(isDark ? 0.25 : 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: color.withOpacity(isDark ? 0.35 : 0.18),
                        ),
                      ),
                      padding: EdgeInsets.all(8 * scale),
                      child: Icon(
                        icon,
                        size: 22 * scale,
                        color: isDark ? color.withOpacity(0.95) : color,
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
