import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Line chart with avg toggle, adapted for fl_chart 0.69.x without external AppColors.
class LineGrowthChart extends StatefulWidget {
  const LineGrowthChart({super.key});

  @override
  State<LineGrowthChart> createState() => _LineGrowthChartState();
}

class _LineGrowthChartState extends State<LineGrowthChart> {
  bool showAvg = false;
  final List<Color> gradientColors = const [Colors.cyan, Colors.blue];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    return Stack(
      children: [
        AspectRatio(
          aspectRatio: 1.70,
          child: Padding(
            padding: const EdgeInsets.only(
              right: 18,
              left: 12,
              top: 24,
              bottom: 12,
            ),
            child: LineChart(showAvg ? _avgData() : _mainData()),
          ),
        ),
        SizedBox(
          width: 60,
          height: 34,
          child: TextButton(
            onPressed: () => setState(() => showAvg = !showAvg),
            child: Text(
              'avg',
              style: TextStyle(
                fontSize: 12,
                color: showAvg
                    ? onSurface.withOpacity(0.6)
                    : onSurface.withOpacity(0.9),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _bottomTitle(double value, TitleMeta meta) {
    final style = TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 12,
      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.85),
    );
    final text = switch (value.toInt()) {
      0 => 'JAN',
      2 => 'MAR',
      5 => 'JUN',
      8 => 'SEP',
      11 => 'DEC',
      _ => '',
    };
    return SideTitleWidget(
      axisSide: meta.axisSide,
      child: Text(text, style: style),
    );
  }

  Widget _leftTitle(double value, TitleMeta meta) {
    final style = TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 11,
      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.75),
    );
    final text = switch (value.toInt()) {
      1 => '10',
      3 => '30',
      5 => '50',
      _ => '',
    };
    return Text(text, style: style, textAlign: TextAlign.left);
  }

  LineChartData _mainData() {
    final theme = Theme.of(context);
    final axisColor = theme.colorScheme.onSurface.withOpacity(0.25);
    final borderColor = theme.colorScheme.outline.withOpacity(0.30);
    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        horizontalInterval: 1,
        verticalInterval: 1,
        getDrawingHorizontalLine: (value) =>
            FlLine(color: axisColor, strokeWidth: 1),
        getDrawingVerticalLine: (value) =>
            FlLine(color: axisColor, strokeWidth: 1),
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
            reservedSize: 26,
            interval: 1,
            getTitlesWidget: _bottomTitle,
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            getTitlesWidget: _leftTitle,
            reservedSize: 36,
          ),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: borderColor),
      ),
      minX: 0,
      maxX: 11,
      minY: 0,
      maxY: 6,
      lineBarsData: [
        LineChartBarData(
          spots: const [
            FlSpot(0, 3),
            FlSpot(2.6, 2),
            FlSpot(4.9, 5),
            FlSpot(6.8, 3.1),
            FlSpot(8, 4),
            FlSpot(9.5, 3),
            FlSpot(11, 4),
          ],
          isCurved: true,
          gradient: LinearGradient(colors: gradientColors),
          barWidth: 4,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: gradientColors.map((c) => c.withOpacity(0.25)).toList(),
            ),
          ),
        ),
      ],
    );
  }

  LineChartData _avgData() {
    final theme = Theme.of(context);
    final axisColor = theme.colorScheme.onSurface.withOpacity(0.30);
    final borderColor = theme.colorScheme.outline.withOpacity(0.35);
    return LineChartData(
      lineTouchData: const LineTouchData(enabled: false),
      gridData: FlGridData(
        show: true,
        drawHorizontalLine: true,
        verticalInterval: 1,
        horizontalInterval: 1,
        getDrawingVerticalLine: (value) =>
            FlLine(color: axisColor, strokeWidth: 1),
        getDrawingHorizontalLine: (value) =>
            FlLine(color: axisColor, strokeWidth: 1),
      ),
      titlesData: FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 26,
            getTitlesWidget: _bottomTitle,
            interval: 1,
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: _leftTitle,
            reservedSize: 36,
            interval: 1,
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: borderColor),
      ),
      minX: 0,
      maxX: 11,
      minY: 0,
      maxY: 6,
      lineBarsData: [
        LineChartBarData(
          spots: const [
            FlSpot(0, 3.44),
            FlSpot(2.6, 3.44),
            FlSpot(4.9, 3.44),
            FlSpot(6.8, 3.44),
            FlSpot(8, 3.44),
            FlSpot(9.5, 3.44),
            FlSpot(11, 3.44),
          ],
          isCurved: true,
          gradient: LinearGradient(
            colors: [
              ColorTween(
                begin: gradientColors[0],
                end: gradientColors[1],
              ).lerp(0.2)!,
              ColorTween(
                begin: gradientColors[0],
                end: gradientColors[1],
              ).lerp(0.2)!,
            ],
          ),
          barWidth: 4,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                ColorTween(
                  begin: gradientColors[0],
                  end: gradientColors[1],
                ).lerp(0.2)!.withOpacity(0.12),
                ColorTween(
                  begin: gradientColors[0],
                  end: gradientColors[1],
                ).lerp(0.2)!.withOpacity(0.12),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
