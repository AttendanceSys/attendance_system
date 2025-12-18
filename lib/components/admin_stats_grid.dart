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
    return FutureBuilder<List<int>>(
      future: Future.wait([
        _fetchCount('faculties'),
        _fetchCount('teachers'),
        _fetchCount('admins'),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

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

            final labels = ['Faculties', 'Teachers', 'Admins'];
            final icons = [
              Icons.apartment_outlined,
              Icons.school_outlined,
              Icons.admin_panel_settings_outlined,
            ];

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
                  value: snapshot.data![index].toString(),
                  icon: icons[index],
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

  const _StatsCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, size) {
        final scale = (size.maxHeight / 130).clamp(0.75, 1.0);

        return ClipRect(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20 * scale),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: 22 * scale,
                vertical: 12 * scale,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
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
                            style: TextStyle(
                              fontSize: 16 * scale,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          SizedBox(height: 6 * scale),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              value,
                              style: TextStyle(
                                fontSize: 34 * scale,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 14 * scale),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6 * scale),
                    child: Icon(icon, size: 32 * scale, color: Colors.black87),
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
