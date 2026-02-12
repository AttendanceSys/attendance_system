import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/session.dart';
import 'dart:math' as math;

String? _extractRefId(dynamic raw, {String? expectedCollection}) {
  if (raw == null) return null;
  if (raw is DocumentReference) return raw.id;
  if (raw is! String) return null;

  var s = raw.trim();
  if (s.isEmpty) return null;
  if (s.startsWith('/')) s = s.substring(1);
  final parts = s.split('/').where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return null;

  if (expectedCollection != null) {
    for (var i = 0; i < parts.length - 1; i++) {
      if (parts[i] == expectedCollection) return parts[i + 1];
    }
  }

  return parts.length > 1 ? parts.last : s;
}

bool _belongsToSessionFaculty(Map<String, dynamic>? data) {
  final facultyRef = Session.facultyRef;
  if (facultyRef == null) return true;
  if (data == null) return false;

  final sessionId = facultyRef.id;
  final sessionPath = facultyRef.path;
  final sessionSlashPath = '/$sessionPath';

  final candidates = [
    data['faculty_ref'],
    data['facultyRef'],
    data['faculty_id'],
    data['facultyId'],
    data['faculty'],
  ];

  for (final raw in candidates) {
    if (raw == null) continue;
    if (raw is DocumentReference) {
      if (raw.id == sessionId || raw.path == sessionPath) return true;
      continue;
    }

    if (raw is String) {
      final text = raw.trim();
      if (text.isEmpty) continue;
      if (text == sessionId || text == sessionPath || text == sessionSlashPath) {
        return true;
      }
    }

    final extracted = _extractRefId(raw, expectedCollection: 'faculties');
    if (extracted == sessionId) return true;
  }

  return false;
}

/// Dashboard grid with four focused charts:
/// - Attendance (this week)
/// - Top attended classes
/// - Departments by students
/// - Students by gender
class DashboardStatsGrid extends StatelessWidget {
  const DashboardStatsGrid({super.key});

  Future<int> _fetchCount(String collectionName) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection(collectionName)
          .get();
      if (Session.facultyRef == null) {
        return snap.size;
      }

      var count = 0;
      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (_belongsToSessionFaculty(data)) count++;
      }
      return count;
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
        final counts = snapshot.data ?? const [0, 0, 0, 0];

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

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GridView.builder(
                  padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
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
                    // Keep dashboard icons aligned with the Faculty Admin sidebar.
                    // Sidebar uses: Departments=account_tree_rounded, Classes=class_rounded, Students=groups_rounded, Courses=menu_book_rounded.
                    final icons = [
                      Icons.account_tree_rounded,
                      Icons.menu_book_rounded,
                      Icons.class_rounded,
                      Icons.groups_rounded,
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
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: LayoutBuilder(
                    builder: (context, inner) {
                      final isNarrow = inner.maxWidth < 900;

                      // Requested layout:
                      // - First line: Attendance (this week) and Top Attended Classes
                      // - Second line: Departments by Students and Students by Gender
                      if (isNarrow) {
                        // On narrow screens stack vertically in the requested order
                        return Column(
                          children: [
                            _ChartCard(
                              title: 'Attendance (this week)',
                              height: 240,
                              child: const WeeklyAttendanceChart(),
                            ),
                            const SizedBox(height: 12),
                            _ChartCard(
                              title: 'Top Attended Classes (this week)',
                              height: 200,
                              child: TopAttendedClassesChart(days: 7, topN: 6),
                            ),
                            const SizedBox(height: 12),
                            _ChartCard(
                              title: 'Departments by Students',
                              height: 200,
                              child: const DepartmentsByStudentsChart(),
                            ),
                            const SizedBox(height: 12),
                            _ChartCard(
                              title: 'Students by Gender',
                              height: 180,
                              child: const StudentsByGenderChart(),
                            ),
                          ],
                        );
                      } else {
                        // Wide layout: two rows
                        return Column(
                          children: [
                            // First row: Attendance (left) | Top Attended Classes (right)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 3,
                                  child: _ChartCard(
                                    title: 'Attendance (this week)',
                                    height: 260,
                                    child: const WeeklyAttendanceChart(),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 2,
                                  child: _ChartCard(
                                    title: 'Top Attended Classes (this week)',
                                    height: 260,
                                    child: TopAttendedClassesChart(
                                      days: 7,
                                      topN: 6,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Second row: Departments | Students by Gender
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  flex: 1,
                                  child: _ChartCard(
                                    title: 'Departments by Students',
                                    height: 180,
                                    child: const DepartmentsByStudentsChart(),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  flex: 1,
                                  child: _ChartCard(
                                    title: 'Students by Gender',
                                    height: 180,
                                    child: const StudentsByGenderChart(),
                                  ),
                                ),
                              ],
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
            color: theme.shadowColor.withValues(alpha: isDark ? 0.30 : 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: theme.dividerColor.withValues(alpha: isDark ? 0.30 : 0.15),
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
                  color: theme.shadowColor.withValues(alpha: isDark ? 0.30 : 0.08),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: theme.colorScheme.outline.withValues(
                  alpha: isDark ? 0.28 : 0.16,
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
                  SizedBox(width: 14 * scale),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6 * scale),
                    child: Container(
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: isDark ? 0.25 : 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: color.withValues(alpha: isDark ? 0.35 : 0.18),
                        ),
                      ),
                      padding: EdgeInsets.all(8 * scale),
                      child: Icon(
                        icon,
                        size: 22 * scale,
                        color: isDark
                            ? theme.colorScheme.onSurface.withValues(alpha: 0.95)
                            : color,
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

// ---------------------- Weekly attendance chart ----------------------

class WeeklyAttendanceChart extends StatefulWidget {
  const WeeklyAttendanceChart({super.key});

  @override
  State<WeeklyAttendanceChart> createState() => _WeeklyAttendanceChartState();
}

class _WeeklyAttendanceChartState extends State<WeeklyAttendanceChart> {
  late Future<List<int>> _futureCounts;
  _ChartType _type = _ChartType.line;

  @override
  void initState() {
    super.initState();
    _futureCounts = _fetchWeeklyAttendanceCounts();
  }

  /// Debug helper: prints a few documents for troubleshooting.
  Future<void> debugAttendanceQuery() async {
    try {
      final colName = 'attendance_records';
      final col = FirebaseFirestore.instance.collection(colName);
      final snap = await col.limit(10).get();
      debugPrint('Debug sample size: ${snap.size}');
      for (final d in snap.docs) {
        debugPrint('doc id=${d.id} data=${d.data()}');
      }
    } catch (e, st) {
      debugPrint('debugAttendanceQuery error: $e\n$st');
    }
  }

  Future<List<int>> _fetchWeeklyAttendanceCounts() async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final start = today.subtract(const Duration(days: 6)); // inclusive
      final startTs = Timestamp.fromDate(start);

      final colName = 'attendance_records';
      final col = FirebaseFirestore.instance.collection(colName);

      Query q = col.where('scannedAt', isGreaterThanOrEqualTo: startTs);

      QuerySnapshot? snap;
      try {
        snap = await q.get();
      } catch (e) {
        snap = null;
      }

      if (snap == null || snap.docs.isEmpty) {
        try {
          snap = await col
              .orderBy('scannedAt', descending: true)
              .limit(1000)
              .get();
        } catch (_) {
          snap = await col.limit(1000).get();
        }
      }

      final counts = List<int>.filled(7, 0);
      final seen = <String>{};

      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        if (!_belongsToSessionFaculty(data)) continue;

        DateTime? dt;
        final scanned = data['scannedAt'];
        if (scanned is Timestamp) {
          dt = scanned.toDate();
        } else {
          final tsString =
              (data['scannedAt'] ?? data['timestamp'] ?? data['created_at'])
                  ?.toString();
          if (tsString != null && tsString.isNotEmpty) {
            dt = DateTime.tryParse(tsString);
          }
        }

        if (dt == null) continue;

        final dateOnly = DateTime(dt.year, dt.month, dt.day);
        final diffDays = dateOnly.difference(start).inDays;
        if (diffDays < 0 || diffDays > 6) continue;

        final username = (data['username'] ?? data['user'] ?? '')
            .toString()
            .trim();
        final sessionId =
            (data['session_id'] ?? data['sessionId'] ?? data['code'] ?? '')
                .toString()
                .trim();

        if (username.isEmpty) continue;

        final key = sessionId.isNotEmpty
            ? '$sessionId|$username'
            : '${dateOnly.toIso8601String()}|$username';
        if (seen.contains(key)) continue;
        seen.add(key);

        counts[diffDays] = counts[diffDays] + 1;
      }

      return counts;
    } catch (e, st) {
      debugPrint('Failed to fetch weekly attendance counts: $e\n$st');
      return List<int>.filled(7, 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<List<int>>(
      future: _futureCounts,
      builder: (c, s) {
        if (!s.hasData) return const _ChartLoading();
        final counts = s.data!;
        return Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ToggleButtons(
                  isSelected: [
                    _type == _ChartType.line,
                    _type == _ChartType.bar,
                  ],
                  onPressed: (i) => setState(
                    () => _type = i == 0 ? _ChartType.line : _ChartType.bar,
                  ),
                  color: theme.textTheme.bodySmall?.color,
                  selectedColor: theme.brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black,
                  borderRadius: BorderRadius.circular(8),
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('Line'),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('Bar'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _type == _ChartType.line
                  ? _buildLine(theme, counts)
                  : _buildBar(theme, counts),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLine(ThemeData theme, List<int> counts) {
    final isLight = theme.brightness == Brightness.light;
    final tooltipBg = isLight ? theme.colorScheme.primary : Colors.white;
    final tooltipText = isLight ? Colors.white : Colors.black;
    final spots = counts
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.toDouble()))
        .toList();
    final maxY =
        (counts.isEmpty ? 10 : counts.reduce(math.max)).toDouble() * 1.4;
    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY <= 0 ? 10 : maxY,
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => tooltipBg,
            getTooltipItems: (touchedSpots) {
              return touchedSpots
                  .map(
                    (spot) => LineTooltipItem(
                      spot.y.toInt().toString(),
                      TextStyle(
                        color: tooltipText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                  .toList();
            },
          ),
        ),
        gridData: FlGridData(show: true),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final startDate = DateTime.now();
                final labels = List.generate(7, (i) {
                  final d = DateTime(
                    startDate.year,
                    startDate.month,
                    startDate.day,
                  ).subtract(Duration(days: 6 - i));
                  final weekDays = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];
                  return weekDays[d.weekday % 7];
                });
                final idx = value.toInt();
                if (idx < 0 || idx >= labels.length) {
                  return const SizedBox.shrink();
                }
                return Text(labels[idx], style: theme.textTheme.bodySmall);
              },
            ),
          ),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: theme.colorScheme.primary,
            barWidth: 3,
            dotData: FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBar(ThemeData theme, List<int> counts) {
    final bars = counts
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

    return BarChart(
      BarChartData(
        barGroups: bars,
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final startDate = DateTime.now();
                final labels = List.generate(7, (i) {
                  final d = DateTime(
                    startDate.year,
                    startDate.month,
                    startDate.day,
                  ).subtract(Duration(days: 6 - i));
                  final weekDays = ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'];
                  return weekDays[d.weekday % 7];
                });
                final idx = value.toInt();
                if (idx < 0 || idx >= labels.length) {
                  return const SizedBox.shrink();
                }
                return Text(labels[idx], style: theme.textTheme.bodySmall);
              },
            ),
          ),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true)),
        ),
        gridData: FlGridData(show: true),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}

// ---------------------- Departments by students ----------------------

class DepartmentsByStudentsChart extends StatefulWidget {
  const DepartmentsByStudentsChart({super.key});

  @override
  State<DepartmentsByStudentsChart> createState() =>
      _DepartmentsByStudentsChartState();
}

class _DepartmentsByStudentsChartState
    extends State<DepartmentsByStudentsChart> {
  late Future<Map<String, int>> _futureCounts;

  @override
  void initState() {
    super.initState();
    _futureCounts = _fetchDepartmentsStudentCounts();
  }

  Future<Map<String, int>> _fetchDepartmentsStudentCounts() async {
    try {
      final studentsRef = FirebaseFirestore.instance.collection('students');
      Query q = studentsRef;
      final snap = await q.get();

      // Build raw counts from students
      final Map<String, int> rawCounts = {};
      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        if (!_belongsToSessionFaculty(data)) continue;
        final raw =
            data['department_ref'] ??
            data['departmentRef'] ??
            data['department'];
        String? key;
        if (raw is DocumentReference) {
          key = raw.id;
        } else if (raw is String) {
          final s = raw;
          if (s.contains('/')) {
            final parts = s.split('/').where((p) => p.isNotEmpty).toList();
            key = parts.isNotEmpty ? parts.last : s;
          } else {
            key = s;
          }
        }
        if (key == null || key.trim().isEmpty) continue;
        rawCounts[key] = (rawCounts[key] ?? 0) + 1;
      }

      // Fetch all departments so we can include zero-count ones
      final deptRef = FirebaseFirestore.instance.collection('departments');
      final deptSnap = await deptRef.get();
      final Map<String, String> names = {};
      for (final d in deptSnap.docs) {
        final m = d.data() as Map<String, dynamic>?;
        if (!_belongsToSessionFaculty(m)) continue;
        final disp =
            (m?['department_name'] ??
                    m?['departmentName'] ??
                    m?['name'] ??
                    m?['department_code'] ??
                    m?['departmentCode'] ??
                    m?['title'])
                ?.toString() ??
            d.id;
        names[d.id] = disp;
      }

      // Resolve rawCounts keys to department ids where possible
      final Map<String, int> countsById = {for (final id in names.keys) id: 0};
      final Map<String, int> unknowns = {};

      for (final entry in rawCounts.entries) {
        final key = entry.key;
        final value = entry.value;
        String? resolvedId;
        if (names.containsKey(key)) {
          resolvedId = key; // key is department id
        } else {
          // try match by name (case-insensitive)
          for (final dd in deptSnap.docs) {
            final m = dd.data() as Map<String, dynamic>?;
            final candidate =
                (m?['department_name'] ??
                        m?['departmentName'] ??
                        m?['name'] ??
                        '')
                    .toString();
            if (candidate.isNotEmpty &&
                candidate.toLowerCase() == key.toLowerCase()) {
              resolvedId = dd.id;
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

      // Convert to name -> count and include zeroes
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
      debugPrint('Failed to fetch department student counts: $e');
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final tooltipBg = isLight ? theme.colorScheme.primary : Colors.white;
    final tooltipText = isLight ? Colors.white : Colors.black;
    return FutureBuilder<Map<String, int>>(
      future: _futureCounts,
      builder: (c, s) {
        if (!s.hasData) return const _ChartLoading();
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
                      getTooltipColor: (group) => tooltipBg,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final idx = group.x.toInt();
                        final label = (idx >= 0 && idx < labels.length)
                            ? labels[idx]
                            : '';
                        final value = rod.toY.toInt();
                        return BarTooltipItem(
                          '$label\n$value',
                          TextStyle(
                            color: tooltipText,
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
                            space: 6,
                            child: Text(
                              txt,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
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
              height: math.min(labels.length, 4) * 28.0,
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

// ---------------------- Students by gender ----------------------

class StudentsByGenderChart extends StatefulWidget {
  const StudentsByGenderChart({super.key});

  @override
  State<StudentsByGenderChart> createState() => _StudentsByGenderChartState();
}

class _StudentsByGenderChartState extends State<StudentsByGenderChart> {
  late Future<Map<String, int>> _futureGenderCounts;

  @override
  void initState() {
    super.initState();
    _futureGenderCounts = _fetchGenderCounts();
  }

  Future<Map<String, int>> _fetchGenderCounts() async {
    try {
      Query q = FirebaseFirestore.instance.collection('students');
      final snap = await q.get();
      final Map<String, int> map = {};
      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        if (!_belongsToSessionFaculty(data)) continue;
        final raw = (data['gender'] ?? '').toString().trim();
        final key = raw.isEmpty ? 'Unknown' : raw;
        map[key] = (map[key] ?? 0) + 1;
      }
      return map;
    } catch (e) {
      debugPrint('Failed to fetch gender counts: $e');
      return {};
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<Map<String, int>>(
      future: _futureGenderCounts,
      builder: (c, s) {
        if (s.hasError) return Center(child: Text('Error loading gender data'));
        if (!s.hasData) return const _ChartLoading();
        final map = s.data!;
        if (map.isEmpty) return const Center(child: Text('No student data'));
        final total = map.values.fold<int>(0, (a, b) => a + b);

        final colors = [
          Colors.green,
          Colors.blueGrey,
          Colors.orange,
          Colors.purple,
          Colors.teal,
          Colors.brown,
        ];

        final sections = map.entries.toList().asMap().entries.map((entry) {
          final idx = entry.key;
          final e = entry.value;
          final value = e.value.toDouble();
          final color = colors[idx % colors.length];
          return PieChartSectionData(
            value: value,
            color: color,
            radius: 40,
            title:
                '${((value / (total == 0 ? 1 : total)) * 100).toStringAsFixed(0)}%',
            titleStyle: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          );
        }).toList();

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Center(
                child: PieChart(
                  PieChartData(
                    sections: sections,
                    centerSpaceRadius: 18,
                    sectionsSpace: 2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: math.min(map.length, 4) * 28.0,
              child: ListView.builder(
                itemCount: map.length,
                padding: EdgeInsets.zero,
                itemBuilder: (ctx, i) {
                  final entry = map.entries.toList()[i];
                  return Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        color: colors[i % colors.length],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entry.key,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        entry.value.toString(),
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

// ---------------------- Top Attended Classes ----------------------

class TopAttendedClassesChart extends StatefulWidget {
  final int days; // lookback days (default 7)
  final int topN; // how many classes to show
  const TopAttendedClassesChart({super.key, this.days = 7, this.topN = 6});

  @override
  State<TopAttendedClassesChart> createState() =>
      _TopAttendedClassesChartState();
}

class _TopAttendedClassesChartState extends State<TopAttendedClassesChart> {
  late Future<List<_ClassCount>> _futureTop;

  @override
  void initState() {
    super.initState();
    _futureTop = _fetchTopAttendedClasses(days: widget.days, topN: widget.topN);
  }

  Future<List<_ClassCount>> _fetchTopAttendedClasses({
    required int days,
    required int topN,
  }) async {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final start = today.subtract(Duration(days: days - 1));
      final startTs = Timestamp.fromDate(start);

      final colName = 'attendance_records';
      final col = FirebaseFirestore.instance.collection(colName);

      Query q = col.where('scannedAt', isGreaterThanOrEqualTo: startTs);

      QuerySnapshot snap;
      try {
        snap = await q.get();
      } catch (_) {
        // fallback
        try {
          snap = await col
              .orderBy('scannedAt', descending: true)
              .limit(2000)
              .get();
        } catch (_) {
          snap = await col.limit(2000).get();
        }
      }

      final Map<String, Set<String>> map = {}; // className -> set of usernames

      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;
        if (!_belongsToSessionFaculty(data)) continue;

        DateTime? dt;
        final scanned = data['scannedAt'];
        if (scanned is Timestamp) {
          dt = scanned.toDate();
        } else {
          final tsString =
              (data['scannedAt'] ?? data['timestamp'] ?? data['created_at'])
                  ?.toString();
          if (tsString != null && tsString.isNotEmpty) {
            dt = DateTime.tryParse(tsString);
          }
        }
        if (dt == null) continue;
        final dateOnly = DateTime(dt.year, dt.month, dt.day);
        if (dateOnly.isBefore(start)) continue;

        final className = (data['className'] ?? data['class'] ?? '')
            .toString()
            .trim();
        if (className.isEmpty) continue;

        final username = (data['username'] ?? data['user'] ?? '')
            .toString()
            .trim();
        if (username.isEmpty) continue;

        map.putIfAbsent(className, () => <String>{}).add(username);
      }

      final list =
          map.entries
              .map((e) => _ClassCount(name: e.key, count: e.value.length))
              .toList()
            ..sort((a, b) => b.count.compareTo(a.count));

      return list.take(topN).toList();
    } catch (e, st) {
      debugPrint('Error fetching top attended classes: $e\n$st');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<List<_ClassCount>>(
      future: _futureTop,
      builder: (c, s) {
        if (s.hasError) return Center(child: Text('Error loading data'));
        if (!s.hasData) return const _ChartLoading();
        final data = s.data!;
        if (data.isEmpty) {
          return const Center(child: Text('No attendance data'));
        }
        final maxCount = data
            .map((e) => e.count)
            .fold<int>(0, (a, b) => math.max(a, b));
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6.0),
          child: Column(
            children: [
              ...data.map((d) {
                final pct = maxCount == 0 ? 0.0 : (d.count / maxCount);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 4,
                        child: Text(
                          d.name,
                          style: theme.textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 6,
                        child: Stack(
                          children: [
                            Container(
                              height: 18,
                              decoration: BoxDecoration(
                                color: theme.dividerColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: pct.clamp(0.0, 1.0),
                              child: Container(
                                height: 18,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 42,
                        child: Text(
                          d.count.toString(),
                          textAlign: TextAlign.right,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Top ${data.length} classes — last ${widget.days} days',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ClassCount {
  final String name;
  final int count;
  _ClassCount({required this.name, required this.count});
}

// reused small enum
enum _ChartType { line, bar }
