import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../components/charts/line_chart.dart' as charts;
import '../components/charts/bar_chart.dart' as charts;
import '../components/charts/area_chart.dart' as charts;
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

            // Build KPI grid + charts below
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GridView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: 4,
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
                ),
                const SizedBox(height: 24),
                // Charts section matching super admin style
                Row(
                  children: const [
                    Expanded(
                      child: _ChartCard(
                        title: 'Growth (Monthly)',
                        height: 220,
                        child: charts.LineGrowthChart(),
                      ),
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: _ChartCard(
                        title: 'Activity Comparison',
                        height: 220,
                        child: charts.FacultyActivityBarChart(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const _ChartCard(
                  title: 'Usage Rate',
                  height: 320,
                  child: charts.AttendanceAreaChart(),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  final double? height;

  const _ChartCard({required this.title, required this.child, this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          SizedBox(height: height ?? 240, child: child),
        ],
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
        final scale = (size.maxHeight / 130).clamp(0.75, 1.0);

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
                            style: TextStyle(
                              fontSize: 18 * scale,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
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
                                color: Colors.black87,
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
                    child: Icon(icon, size: 38 * scale, color: Colors.black87),
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
