import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math' as math;

class AdminDashboardStatsGrid extends StatelessWidget {
  const AdminDashboardStatsGrid({super.key});

  Future<int> _fetchCount(String collectionName) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(collectionName)
          .get();
      return snapshot.size;
    } catch (e) {
      debugPrint("Error fetching count for $collectionName: $e");
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<int>>(
      future: Future.wait([
        _fetchCount("faculties"),
        _fetchCount("admins"),
        _fetchCount("teachers"),
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

        return SingleChildScrollView(
          child: LayoutBuilder(
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

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GridView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: labels.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxis,
                      crossAxisSpacing: 22,
                      mainAxisSpacing: 16,
                      mainAxisExtent: 90, // fixed height per card
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
                  ),

                  const SizedBox(height: 20),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: LayoutBuilder(
                      builder: (context, inner) {
                        final isNarrow = inner.maxWidth < 900;

                        if (isNarrow) {
                          return Column(
                            children: const [
                              _ChartCard(
                                title: 'Departments per Faculty',
                                height: 260,
                                child: DepartmentsPerFacultyChart(),
                              ),
                              SizedBox(height: 12),
                              _ChartCard(
                                title: 'Teachers per Faculty',
                                height: 260,
                                child: TeachersPerFacultyChart(),
                              ),
                            ],
                          );
                        } else {
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Expanded(
                                flex: 3,
                                child: _ChartCard(
                                  title: 'Departments per Faculty',
                                  height: 300,
                                  child: DepartmentsPerFacultyChart(),
                                ),
                              ),
                              SizedBox(width: 16),
                              Expanded(
                                flex: 2,
                                child: _ChartCard(
                                  title: 'Teachers per Faculty',
                                  height: 300,
                                  child: TeachersPerFacultyChart(),
                                ),
                              ),
                            ],
                          );
                        }
                      },
                    ),
                  ),
                ],
              );
            },
          ),
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
        final scale = (size.maxHeight / 130).clamp(0.70, 1.0);
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
                horizontal: 16 * scale,
                vertical: 8 * scale, // Reduce vertical padding for smaller screens
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(left: 4 * scale),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontSize: 16 * scale,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          SizedBox(height: 2 * scale), // Even less spacing
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              value,
                              style: TextStyle(
                                fontSize: 30 * scale,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                          // Remove SizedBox for more vertical space
                          // Show sparkline only if enough height (avoid overflow by conditional rendering)
                          if (size.maxHeight > 70)
                            SizedBox(
                              // Make sparkline very compact
                              height: math.min((14 * scale).clamp(8.0, 16.0), size.maxHeight * 0.3),
                              child: _buildSparkline(value, theme, isDark),
                            ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 10 * scale),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4 * scale),
                    child: Container(
                      decoration: BoxDecoration(
                        color: color.withOpacity(isDark ? 0.24 : 0.10),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: color.withOpacity(isDark ? 0.35 : 0.18),
                        ),
                      ),
                      padding: EdgeInsets.all(8 * scale),
                      child: Icon(
                        icon,
                        size: 20 * scale,
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
          SizedBox(height: height ?? 180, child: child),
        ],
      ),
    );
  }
}

Widget _buildSparkline(String valueStr, ThemeData theme, bool isDark) {
  final int base = int.tryParse(valueStr.replaceAll(',', '')) ?? 0;
  final int points = 8;
  final rnd = math.Random(base == 0 ? 42 : base);
  final spots = <FlSpot>[];
  double maxY = 1;
  for (var i = 0; i < points; i++) {
    final y = (rnd.nextDouble() * (base > 0 ? base.toDouble() : 5.0)) + 1.0;
    spots.add(FlSpot(i.toDouble(), y));
    if (y > maxY) maxY = y;
  }

  return LineChart(
    LineChartData(
      lineTouchData: LineTouchData(enabled: false),
      gridData: FlGridData(show: false),
      titlesData: FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      minX: 0,
      maxX: (points - 1).toDouble(),
      minY: 0,
      maxY: maxY * 1.1,
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          color: theme.colorScheme.primary,
          barWidth: 2,
          dotData: FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            color: theme.colorScheme.primary.withOpacity(0.12),
          ),
        ),
      ],
    ),
  );
}

// -------------------- Departments per Faculty (Bar Chart)
class DepartmentsPerFacultyChart extends StatefulWidget {
  const DepartmentsPerFacultyChart({super.key});

  @override
  State<DepartmentsPerFacultyChart> createState() =>
      _DepartmentsPerFacultyChartState();
}

class _DepartmentsPerFacultyChartState
    extends State<DepartmentsPerFacultyChart> {
  late Future<Map<String, int>> _futureCounts;

  @override
  void initState() {
    super.initState();
    _futureCounts = _fetchDepartmentsPerFaculty();
  }

  Future<Map<String, int>> _fetchDepartmentsPerFaculty() async {
    try {
      final depSnap = await FirebaseFirestore.instance
          .collection('departments')
          .get();

      final Map<String, int> facultyCounts = {};
      final Set<String> facultyIds = {};

      for (final d in depSnap.docs) {
        final data = d.data() as Map<String, dynamic>?;
        if (data == null) continue;

        final raw =
            data['faculty_ref'] ?? data['facultyRef'] ?? data['faculty'];
        String? facultyId;
        if (raw is DocumentReference) {
          facultyId = raw.id;
        } else if (raw is String) {
          final s = raw;
          if (s.contains('/')) {
            final parts = s.split('/').where((p) => p.isNotEmpty).toList();
            facultyId = parts.isNotEmpty ? parts.last : s;
          } else {
            facultyId = s;
          }
        }
        if (facultyId == null || facultyId.trim().isEmpty) continue;

        facultyIds.add(facultyId);
        facultyCounts[facultyId] = (facultyCounts[facultyId] ?? 0) + 1;
      }

      if (facultyCounts.isEmpty) {
        return {};
      }

      final facultySnap = await FirebaseFirestore.instance
          .collection('faculties')
          .get();
      final Map<String, String> names = {
        for (final f in facultySnap.docs)
          f.id:
              ((f.data() as Map<String, dynamic>?)?['name'] ??
                      (f.data() as Map<String, dynamic>?)?['faculty_name'] ??
                      (f.data() as Map<String, dynamic>?)?['title'] ??
                      (f.data() as Map<String, dynamic>?)?['facultyName'] ??
                      f.id)
                  .toString(),
      };

      final Map<String, int> countsById = {for (final id in names.keys) id: 0};
      final Map<String, int> unknowns = {};

      for (final entry in facultyCounts.entries) {
        final key = entry.key;
        final value = entry.value;
        String? resolvedId;
        if (names.containsKey(key)) {
          resolvedId = key;
        } else {
          for (final f in facultySnap.docs) {
            final m = f.data() as Map<String, dynamic>?;
            final candidate =
                (m?['name'] ?? m?['faculty_name'] ?? m?['title'] ?? '')
                    .toString();
            if (candidate.isNotEmpty &&
                candidate.toLowerCase() == key.toLowerCase()) {
              resolvedId = f.id;
              break;
            }
          }
        }

        if (resolvedId != null) {
          countsById[resolvedId] = (countsById[resolvedId] ?? 0) + value;
        } else {
          unknowns[key] = (unknowns[key] ?? 0) + value;
        }
      }

      final Map<String, int> resultUnsorted = {};
      for (final id in countsById.keys) {
        final label = names[id] ?? id;
        resultUnsorted[label] = countsById[id] ?? 0;
      }
      for (final u in unknowns.entries) {
        resultUnsorted[u.key] = u.value;
      }

      final entries = resultUnsorted.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final Map<String, int> result = {for (final e in entries) e.key: e.value};
      return result;
    } catch (e) {
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<Map<String, int>>(
      future: _futureCounts,
      builder: (c, s) {
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final map = s.data!;
        if (map.isEmpty) return const Center(child: Text('No department data'));

        final labels = map.keys.toList();
        final values = map.values.toList();

        final bars = values
            .asMap()
            .entries
            .map(
              (e) => BarChartGroupData(
                x: e.key,
                barRods: [
                  BarChartRodData(
                    toY: e.value.toDouble(),
                    color: theme.colorScheme.primary,
                    width: 18,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            )
            .toList();

        final int maxVal = values.isEmpty ? 0 : values.reduce(math.max);
        int step = ((maxVal / 4).ceil());
        if (step < 1) step = 1;
        final double maxY = (step * 4).toDouble();

        return Column(
          children: [
            Expanded(
              child: BarChart(
                BarChartData(
                  maxY: maxY <= 0 ? 4 : maxY,
                  barGroups: bars,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final idx = group.x.toInt();
                        final label = (idx >= 0 && idx < labels.length)
                            ? labels[idx]
                            : '';
                        final value = rod.toY.toInt();
                        return BarTooltipItem(
                          '$label\n$value',
                          TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= values.length) {
                            return const SizedBox.shrink();
                          }
                          final txt = values[idx].toString();
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(
                              txt,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            space: 6,
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= labels.length) {
                            return const SizedBox.shrink();
                          }
                          final txt = labels[idx];
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            space: 6,
                            child: Text(
                              txt,
                              style: theme.textTheme.bodySmall,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final v = value.toInt();
                          if (v % step != 0) return const SizedBox.shrink();
                          return Text(
                            v.toString(),
                            style: theme.textTheme.bodySmall,
                          );
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: math.min(labels.length, 6) * 28.0,
              child: ListView.builder(
                itemCount: labels.length,
                padding: EdgeInsets.zero,
                itemBuilder: (ctx, i) {
                  return Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          labels[i],
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        values[i].toString(),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// -------------------- Teachers per Faculty (Bar Chart)
class TeachersPerFacultyChart extends StatefulWidget {
  const TeachersPerFacultyChart({super.key});

  @override
  State<TeachersPerFacultyChart> createState() =>
      _TeachersPerFacultyChartState();
}

class _TeachersPerFacultyChartState extends State<TeachersPerFacultyChart> {
  late Future<Map<String, int>> _futureCounts;

  @override
  void initState() {
    super.initState();
    _futureCounts = _fetchTeachersPerFaculty();
  }

  Future<Map<String, int>> _fetchTeachersPerFaculty() async {
    try {
      final teacherSnap = await FirebaseFirestore.instance
          .collection('teachers')
          .get();

      final Map<String, int> facultyCounts = {};
      final Set<String> facultyIds = {};

      for (final d in teacherSnap.docs) {
        final data = d.data() as Map<String, dynamic>?;
        if (data == null) continue;

        final raw =
            data['faculty_ref'] ??
            data['facultyRef'] ??
            data['faculty'] ??
            data['faculty_id'];
        String? facultyId;
        if (raw is DocumentReference) {
          facultyId = raw.id;
        } else if (raw is String) {
          final s = raw;
          if (s.contains('/')) {
            final parts = s.split('/').where((p) => p.isNotEmpty).toList();
            facultyId = parts.isNotEmpty ? parts.last : s;
          } else {
            facultyId = s;
          }
        }
        if (facultyId == null || facultyId.trim().isEmpty) continue;

        facultyIds.add(facultyId);
        facultyCounts[facultyId] = (facultyCounts[facultyId] ?? 0) + 1;
      }

      if (facultyCounts.isEmpty) {
        return {};
      }

      final facultySnap = await FirebaseFirestore.instance
          .collection('faculties')
          .get();
      final Map<String, String> names = {
        for (final f in facultySnap.docs)
          f.id:
              ((f.data() as Map<String, dynamic>?)?['name'] ??
                      (f.data() as Map<String, dynamic>?)?['faculty_name'] ??
                      (f.data() as Map<String, dynamic>?)?['title'] ??
                      (f.data() as Map<String, dynamic>?)?['facultyName'] ??
                      f.id)
                  .toString(),
      };

      final Map<String, int> countsById = {for (final id in names.keys) id: 0};
      final Map<String, int> unknowns = {};

      for (final entry in facultyCounts.entries) {
        final key = entry.key;
        final value = entry.value;
        String? resolvedId;
        if (names.containsKey(key)) {
          resolvedId = key;
        } else {
          for (final f in facultySnap.docs) {
            final m = f.data() as Map<String, dynamic>?;
            final candidate =
                (m?['name'] ?? m?['faculty_name'] ?? m?['title'] ?? '')
                    .toString();
            if (candidate.isNotEmpty &&
                candidate.toLowerCase() == key.toLowerCase()) {
              resolvedId = f.id;
              break;
            }
          }
        }

        if (resolvedId != null) {
          countsById[resolvedId] = (countsById[resolvedId] ?? 0) + value;
        } else {
          unknowns[key] = (unknowns[key] ?? 0) + value;
        }
      }

      final Map<String, int> resultUnsorted = {};
      for (final id in countsById.keys) {
        final label = names[id] ?? id;
        resultUnsorted[label] = countsById[id] ?? 0;
      }
      for (final u in unknowns.entries) {
        resultUnsorted[u.key] = u.value;
      }

      final entries = resultUnsorted.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final Map<String, int> result = {for (final e in entries) e.key: e.value};
      return result;
    } catch (e) {
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<Map<String, int>>(
      future: _futureCounts,
      builder: (c, s) {
        if (!s.hasData) return const Center(child: CircularProgressIndicator());
        final map = s.data!;
        if (map.isEmpty) return const Center(child: Text('No teachers data'));

        final labels = map.keys.toList();
        final values = map.values.toList();

        final bars = values
            .asMap()
            .entries
            .map(
              (e) => BarChartGroupData(
                x: e.key,
                barRods: [
                  BarChartRodData(
                    toY: e.value.toDouble(),
                    color: theme.colorScheme.secondary,
                    width: 18,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            )
            .toList();

        final int maxVal = values.isEmpty ? 0 : values.reduce(math.max);
        int step = ((maxVal / 4).ceil());
        if (step < 1) step = 1;
        final double maxY = (step * 4).toDouble();

        return Column(
          children: [
            Expanded(
              child: BarChart(
                BarChartData(
                  maxY: maxY <= 0 ? 4 : maxY,
                  barGroups: bars,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final idx = group.x.toInt();
                        final label = (idx >= 0 && idx < labels.length)
                            ? labels[idx]
                            : '';
                        final value = rod.toY.toInt();
                        return BarTooltipItem(
                          '$label\n$value',
                          TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= values.length) {
                            return const SizedBox.shrink();
                          }
                          final txt = values[idx].toString();
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(
                              txt,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            space: 6,
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= labels.length) {
                            return const SizedBox.shrink();
                          }
                          final txt = labels[idx];
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            space: 6,
                            child: Text(
                              txt,
                              style: theme.textTheme.bodySmall,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final v = value.toInt();
                          if (v % step != 0) return const SizedBox.shrink();
                          return Text(
                            v.toString(),
                            style: theme.textTheme.bodySmall,
                          );
                        },
                      ),
                    ),
                  ),
                  gridData: FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: math.min(labels.length, 6) * 28.0,
              child: ListView.builder(
                itemCount: labels.length,
                padding: EdgeInsets.zero,
                itemBuilder: (ctx, i) {
                  return Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        color: theme.colorScheme.secondary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          labels[i],
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        values[i].toString(),
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}