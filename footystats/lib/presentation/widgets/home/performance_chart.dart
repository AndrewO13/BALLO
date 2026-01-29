import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class PerformanceChart extends StatelessWidget {
  const PerformanceChart({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // Sample data for GW3-GW10 (ratings)
    final gameweekData = [
      {'week': 'GW3', 'rating': 4.5},
      {'week': 'GW4', 'rating': 6.0},
      {'week': 'GW5', 'rating': 7.5},
      {'week': 'GW6', 'rating': 3.0},
      {'week': 'GW7', 'rating': 10.0}, // Exceptional performance
      {'week': 'GW8', 'rating': 7.0},
      {'week': 'GW9', 'rating': 7.5},
      {'week': 'GW10', 'rating': 5.0},
    ];

    final maxRating = 10.0;

    return SizedBox(
      height: 200,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chart area
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxRating,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < gameweekData.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              gameweekData[index]['week'] as String,
                              style: textTheme.labelSmall,
                            ),
                          );
                        }
                        return const Text('');
                      },
                      reservedSize: 40,
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: gameweekData.asMap().entries.map((entry) {
                  final index = entry.key;
                  final data = entry.value;
                  final rating = data['rating'] as double;
                  final isExceptional = rating >= 8.0;
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: rating,
                        color: isExceptional
                            ? const Color(0xff14ff8e)
                            : const Color(0xfff2fff1),
                        width: 38,
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                    ],
                    barsSpace: 8,
                  );
                }).toList(),
              ),
            ),
          ),
          // Y-axis labels on the right
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: SizedBox(
              height: 163,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [10, 5, 0].map((value) {
                  return Text(value.toString(), style: textTheme.labelSmall);
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
