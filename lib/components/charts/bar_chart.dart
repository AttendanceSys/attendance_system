import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Interactive weekly-style bar chart with tooltip and play/pause animation.
class FacultyActivityBarChart extends StatefulWidget {
  const FacultyActivityBarChart({super.key});

  @override
  State<FacultyActivityBarChart> createState() =>
      _FacultyActivityBarChartState();
}

class _FacultyActivityBarChartState extends State<FacultyActivityBarChart> {
  final Duration _animDuration = const Duration(milliseconds: 250);
  int _touchedIndex = -1;
  bool _isPlaying = false;
  // Theme-driven colors populated in build()
  late Color _barBg;
  late Color _barColor;
  late Color _touchedColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    _barBg = theme.colorScheme.onSurface.withOpacity(0.08);
    _barColor = theme.colorScheme.primary;
    _touchedColor = theme.colorScheme.secondary;
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Monthly',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Faculty activity sessions (per month)',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: BarChart(
                    _isPlaying ? _randomData() : _mainData(),
                    swapAnimationDuration: _animDuration,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Align(
            alignment: Alignment.topRight,
            child: IconButton(
              icon: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: theme.colorScheme.onSurface,
              ),
              onPressed: () {
                setState(() {
                  _isPlaying = !_isPlaying;
                  if (_isPlaying) {
                    _refreshState();
                  }
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  BarChartGroupData _group(
    int x,
    double y, {
    bool isTouched = false,
    Color? color,
    double width = 20,
    List<int> tips = const [],
  }) {
    final c = isTouched ? _touchedColor : (color ?? _barColor);
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: isTouched ? y + 1 : y,
          color: c,
          width: width,
          borderSide: isTouched
              ? BorderSide(color: _touchedColor.withOpacity(0.6))
              : const BorderSide(color: Colors.white, width: 0),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: 20,
            color: _barBg,
          ),
        ),
      ],
      showingTooltipIndicators: tips,
    );
  }

  List<BarChartGroupData> _groups() {
    // 12 months sample data (replace with real aggregates)
    final values = [
      5.0,
      6.5,
      5.2,
      7.5,
      9.0,
      11.5,
      6.5,
      8.0,
      10.0,
      9.5,
      7.2,
      12.0,
    ];
    return List.generate(
      values.length,
      (i) => _group(i, values[i], isTouched: i == _touchedIndex),
    );
  }

  BarChartData _mainData() {
    return BarChartData(
      barTouchData: BarTouchData(
        enabled: true,
        touchTooltipData: BarTouchTooltipData(
          tooltipHorizontalAlignment: FLHorizontalAlignment.right,
          tooltipMargin: -10,
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            final month = switch (group.x) {
              0 => 'Jan',
              1 => 'Feb',
              2 => 'Mar',
              3 => 'Apr',
              4 => 'May',
              5 => 'Jun',
              6 => 'Jul',
              7 => 'Aug',
              8 => 'Sep',
              9 => 'Oct',
              10 => 'Nov',
              11 => 'Dec',
              _ => '',
            };
            return BarTooltipItem(
              '$month\n',
              const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              children: [
                TextSpan(
                  text: (rod.toY - 1).toStringAsFixed(1),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            );
          },
        ),
        handleBuiltInTouches: true,
        touchCallback: (event, response) {
          setState(() {
            if (!event.isInterestedForInteractions || response?.spot == null) {
              _touchedIndex = -1;
            } else {
              _touchedIndex = response!.spot!.touchedBarGroupIndex;
            }
          });
        },
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: _bottomTitle,
            reservedSize: 28,
          ),
        ),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      borderData: FlBorderData(show: false),
      barGroups: _groups(),
      gridData: const FlGridData(show: false),
    );
  }

  Widget _bottomTitle(double value, TitleMeta meta) {
    final style = TextStyle(
      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.85),
      fontWeight: FontWeight.bold,
      fontSize: 11,
    );
    final text = switch (value.toInt()) {
      0 => 'Jan',
      1 => 'Feb',
      2 => 'Mar',
      3 => 'Apr',
      4 => 'May',
      5 => 'Jun',
      6 => 'Jul',
      7 => 'Aug',
      8 => 'Sep',
      9 => 'Oct',
      10 => 'Nov',
      11 => 'Dec',
      _ => '',
    };
    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 6,
      child: Text(text, style: style),
    );
  }

  BarChartData _randomData() {
    final colors = [
      Colors.purple,
      Colors.yellow,
      Colors.blue,
      Colors.orange,
      Colors.pink,
      Colors.red,
      Colors.teal,
    ];
    return BarChartData(
      barTouchData: BarTouchData(enabled: false),
      titlesData: FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: _bottomTitle,
            reservedSize: 28,
          ),
        ),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      ),
      borderData: FlBorderData(show: false),
      barGroups: List.generate(12, (i) {
        return _group(
          i,
          (6 + (i % 6)).toDouble(),
          color: colors[i % colors.length],
        );
      }),
      gridData: const FlGridData(show: false),
    );
  }

  Future<void> _refreshState() async {
    setState(() {});
    await Future<void>.delayed(
      _animDuration + const Duration(milliseconds: 50),
    );
    if (_isPlaying) {
      await _refreshState();
    }
  }
}

class _DepartmentData {
  final String name;
  final double value;

  const _DepartmentData(this.name, this.value);
}

/// Simple reusable bar chart for department-level metrics.
class DepartmentMetricBarChart extends StatefulWidget {
  final List<_DepartmentData> data;
  final Color barColor;
  final String tooltipLabel;

  const DepartmentMetricBarChart({
    required this.data,
    required this.barColor,
    required this.tooltipLabel,
    super.key,
  });

  @override
  State<DepartmentMetricBarChart> createState() =>
      _DepartmentMetricBarChartState();
}

class _DepartmentMetricBarChartState extends State<DepartmentMetricBarChart> {
  int _touchedIndex = -1;

  double get _maxY {
    final maxValue = widget.data.isEmpty
        ? 0
        : widget.data.map((e) => e.value).reduce(math.max);
    return (maxValue * 1.2).clamp(10, double.infinity).toDouble();
  }

  double get _interval => _maxY <= 50
      ? 10.0
      : _maxY <= 120
      ? 20.0
      : (_maxY / 4).ceilToDouble();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final axisColor = theme.colorScheme.onSurface.withOpacity(0.20);
    final labelColor = theme.colorScheme.onSurface.withOpacity(0.75);
    return BarChart(
      BarChartData(
        maxY: _maxY,
        barGroups: _groups(),
        gridData: FlGridData(
          show: true,
          horizontalInterval: _interval,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: axisColor, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= widget.data.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    widget.data[index].name,
                    style: TextStyle(
                      color: labelColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              interval: _interval,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: TextStyle(
                  color: labelColor.withOpacity(0.8),
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(
            left: BorderSide(
              color: theme.colorScheme.outline.withOpacity(0.25),
            ),
            bottom: BorderSide(
              color: theme.colorScheme.outline.withOpacity(0.25),
            ),
          ),
        ),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipRoundedRadius: 6,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final label = widget.data[group.x.toInt()].name;
              final value = rod.toY;
              return BarTooltipItem(
                '$label\n',
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
                children: [
                  TextSpan(
                    text: '${value.toStringAsFixed(0)} ${widget.tooltipLabel}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              );
            },
          ),
          touchCallback: (event, response) {
            setState(() {
              if (!event.isInterestedForInteractions ||
                  response?.spot == null) {
                _touchedIndex = -1;
              } else {
                _touchedIndex = response!.spot!.touchedBarGroupIndex;
              }
            });
          },
        ),
      ),
      swapAnimationDuration: const Duration(milliseconds: 250),
    );
  }

  List<BarChartGroupData> _groups() {
    return List.generate(widget.data.length, (index) {
      final point = widget.data[index];
      final bool isTouched = index == _touchedIndex;
      return BarChartGroupData(
        x: index,
        showingTooltipIndicators: isTouched ? [0] : [],
        barRods: [
          BarChartRodData(
            toY: point.value,
            width: 18,
            color: isTouched
                ? widget.barColor.withOpacity(0.85)
                : widget.barColor,
            borderRadius: BorderRadius.circular(6),
            borderSide: isTouched
                ? BorderSide(
                    color: widget.barColor.withOpacity(0.4),
                    width: 1.5,
                  )
                : BorderSide.none,
            backDrawRodData: BackgroundBarChartRodData(
              show: true,
              toY: _maxY,
              color: Colors.black12.withOpacity(0.08),
            ),
          ),
        ],
      );
    });
  }
}

class StudentsPerDepartmentBarChart extends StatelessWidget {
  const StudentsPerDepartmentBarChart({super.key});

  @override
  Widget build(BuildContext context) {
    const data = [
      _DepartmentData('IT', 420),
      _DepartmentData('Business', 310),
      _DepartmentData('Engineering', 260),
      _DepartmentData('Health', 180),
      _DepartmentData('Arts', 140),
    ];

    return DepartmentMetricBarChart(
      data: data,
      barColor: Colors.indigo,
      tooltipLabel: 'arday',
    );
  }
}

class ClassesPerDepartmentBarChart extends StatelessWidget {
  const ClassesPerDepartmentBarChart({super.key});

  @override
  Widget build(BuildContext context) {
    const data = [
      _DepartmentData('IT', 36),
      _DepartmentData('Business', 28),
      _DepartmentData('Engineering', 24),
      _DepartmentData('Health', 18),
      _DepartmentData('Arts', 14),
    ];

    return DepartmentMetricBarChart(
      data: data,
      barColor: Colors.orange,
      tooltipLabel: 'fasal',
    );
  }
}

class TopFacultiesBarChart extends StatelessWidget {
  const TopFacultiesBarChart({super.key});

  @override
  Widget build(BuildContext context) {
    final data = [80.0, 72.0, 64.0, 58.0, 50.0];

    return BarChart(
      BarChartData(
        gridData: const FlGridData(show: false),
        titlesData: FlTitlesData(
          show: true,
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final labels = ['Sci', 'Eng', 'Biz', 'Arts', 'Med'];
                final idx = value.toInt();
                if (idx < 0 || idx >= labels.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    labels[idx],
                    style: const TextStyle(fontSize: 11, color: Colors.black87),
                  ),
                );
              },
              reservedSize: 28,
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(data.length, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: data[i],
                color: Colors.green,
                width: 16,
                borderRadius: BorderRadius.circular(4),
              ),
            ],
          );
        }),
      ),
    );
  }
}
