import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class UsersPieChart extends StatefulWidget {
  const UsersPieChart({super.key});

  @override
  State<UsersPieChart> createState() => _UsersPieChartState();
}

class _UsersPieChartState extends State<UsersPieChart> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final isTight = width < 380; // stack legend below when space is narrow
        final chartSize = isTight
            ? height * 0.55
            : (width * 0.55).clamp(140.0, height * 0.9);

        final legend = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            _LegendIndicator(color: Color(0xFF5470C6), label: 'IT'),
            SizedBox(height: 6),
            _LegendIndicator(color: Color(0xFFFFC107), label: 'Business'),
            SizedBox(height: 6),
            _LegendIndicator(color: Color(0xFF9C27B0), label: 'Engineering'),
            SizedBox(height: 6),
            _LegendIndicator(color: Color(0xFF4CAF50), label: 'Health'),
          ],
        );

        final chart = SizedBox(
          width: chartSize,
          height: chartSize,
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (event, pieTouchResponse) {
                  setState(() {
                    if (!event.isInterestedForInteractions ||
                        pieTouchResponse == null ||
                        pieTouchResponse.touchedSection == null) {
                      touchedIndex = -1;
                      return;
                    }
                    touchedIndex =
                        pieTouchResponse.touchedSection!.touchedSectionIndex;
                  });
                },
              ),
              borderData: FlBorderData(show: false),
              sectionsSpace: 0,
              centerSpaceRadius: chartSize * 0.2,
              sections: _sections(),
            ),
          ),
        );

        if (isTight) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [chart, const SizedBox(height: 12), legend],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [chart, const SizedBox(width: 16), legend],
        );
      },
    );
  }

  List<PieChartSectionData> _sections() {
    const shadows = [Shadow(color: Colors.black54, blurRadius: 2)];
    return List.generate(4, (index) {
      final isTouched = index == touchedIndex;
      final double radius = isTouched ? 60 : 48;
      final double fontSize = isTouched ? 22 : 14;

      switch (index) {
        case 0:
          return PieChartSectionData(
            color: const Color(0xFF5470C6),
            value: 40,
            title: '40%',
            radius: radius,
            titleStyle: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              shadows: shadows,
            ),
          );
        case 1:
          return PieChartSectionData(
            color: const Color(0xFFFFC107),
            value: 30,
            title: '30%',
            radius: radius,
            titleStyle: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: Colors.black87,
              shadows: shadows,
            ),
          );
        case 2:
          return PieChartSectionData(
            color: const Color(0xFF9C27B0),
            value: 15,
            title: '15%',
            radius: radius,
            titleStyle: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              shadows: shadows,
            ),
          );
        case 3:
          return PieChartSectionData(
            color: const Color(0xFF4CAF50),
            value: 15,
            title: '15%',
            radius: radius,
            titleStyle: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              shadows: shadows,
            ),
          );
        default:
          throw StateError('Invalid pie chart index');
      }
    });
  }
}

class _LegendIndicator extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendIndicator({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
