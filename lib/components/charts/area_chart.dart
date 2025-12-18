import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class AttendanceAreaChart extends StatelessWidget {
  const AttendanceAreaChart({super.key});

  @override
  Widget build(BuildContext context) {
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
        gridData: const FlGridData(show: true),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 40),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 24),
          ),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.purple,
            barWidth: 3,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.purple.withOpacity(0.2),
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
              color: Colors.teal,
              backgroundColor: Colors.teal.withOpacity(0.15),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${(percent * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Attendance this week',
                  style: TextStyle(color: Colors.black54),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
