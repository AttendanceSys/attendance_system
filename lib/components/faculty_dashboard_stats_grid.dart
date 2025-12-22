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
        final isLoading = !snapshot.hasData;
        final counts = snapshot.data ?? const [0, 0, 0, 0];

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
                      value: counts[index].toString(),
                      icon: icons[index],
                      color: colors[index],
                    );
                  },
                ),
                const SizedBox(height: 24),
                // Charts section matching super admin style
                Row(
                  children: [
                    Expanded(
                      child: _ChartCard(
                        title: 'Growth (Monthly)',
                        height: 220,
                        child: isLoading
                            ? const _ChartLoading()
                            : const charts.LineGrowthChart(),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _ChartCard(
                        title: 'Activity Comparison',
                        height: 220,
                        child: isLoading
                            ? const _ChartLoading()
                            : const charts.FacultyActivityBarChart(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _ChartCard(
                  title: 'Usage Rate',
                  height: 320,
                  child: isLoading
                      ? const _ChartLoading()
                      : const charts.AttendanceAreaChart(),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(isDark ? 0.30 : 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: theme.dividerColor.withOpacity(isDark ? 0.30 : 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(height: height ?? 240, child: child),
        ],
      ),
    );
  }
}

class _ChartLoading extends StatelessWidget {
  const _ChartLoading();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator.adaptive(
          strokeWidth: 2.5,
          valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
        ),
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
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 250),
                              transitionBuilder: (child, anim) =>
                                  FadeTransition(opacity: anim, child: child),
                              child: Text(
                                value,
                                key: ValueKey(value),
                                style: TextStyle(
                                  fontSize: 34 * scale,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
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
