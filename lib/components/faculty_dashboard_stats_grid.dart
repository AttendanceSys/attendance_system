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
      debugPrint('Error fetching $collectionName count: $e');
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: FutureBuilder<List<int>>(
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

          return LayoutBuilder(
            builder: (context, constraints) {
              // RESPONSIVE BREAKPOINTS
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

              return GridView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: 4,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxis,
                  crossAxisSpacing: 22,
                  mainAxisSpacing: 22,
                  childAspectRatio: 1.4,
                ),
                itemBuilder: (context, index) {
                  final labels = [
                    "Departments",
                    "Courses",
                    "Classes",
                    "Students",
                  ];
                  final icons = [
                    Icons.account_tree_outlined,
                    Icons.menu_book_outlined,
                    Icons.groups_2_outlined,
                    Icons.people_alt_outlined,
                  ];
                  final colors = [
                    Colors.blue,
                    Colors.indigo,
                    Colors.teal,
                    Colors.orange,
                  ];

                  return _StatsCard(
                    label: labels[index],
                    value: snapshot.data![index].toString(),
                    icon: icons[index],
                    color: colors[index],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _StatsCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatsCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, size) {
        final scale = (size.maxHeight / 180).clamp(0.75, 1.0);

        return ClipRect(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
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
                      color: Colors.black87,
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
                            color: Colors.black87,
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
