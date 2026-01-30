import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class AttendanceAreaChart extends StatelessWidget {
  const AttendanceAreaChart({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lineColor = theme.colorScheme.primary;
    final axisColor = theme.colorScheme.onSurface.withOpacity(0.22);
    final borderColor = theme.colorScheme.outline.withOpacity(0.28);
    final spots = [
      const FlSpot(0, 30),
      const FlSpot(1, 45),
      const FlSpot(2, 40),
      const FlSpot(3, 55),
      const FlSpot(4, 65),
      const FlSpot(5, 60),
      const FlSpot(6, 80),
    ];

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: axisColor, strokeWidth: 1),
          getDrawingVerticalLine: (value) =>
              FlLine(color: axisColor, strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) => Text(
                value.toInt().toString(),
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.75),
                  fontSize: 11,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              getTitlesWidget: (value, meta) => Text(
                (value + 0.5).toStringAsFixed(1),
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.85),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: borderColor),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: lineColor,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: lineColor.withOpacity(0.2),
            ),
          ),
        ],
      ),
    );
  }
}

class SystemHealthGauge extends StatelessWidget {
  const SystemHealthGauge({super.key});

  @override
  Widget build(BuildContext context) {
    // Simple radial progress replacement using CustomPaint
    final percent = 0.72; // 72% teachers took attendance this week
    final theme = Theme.of(context);
    return Center(
      child: SizedBox(
        height: 220,
        width: 220,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: percent,
              strokeWidth: 12,
              color: theme.colorScheme.primary,
              backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${(percent * 100).round()}%',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Attendance this week',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
