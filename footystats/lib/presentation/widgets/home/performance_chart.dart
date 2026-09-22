import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class PerformanceChart extends StatefulWidget {
  const PerformanceChart({
    super.key,
    required this.gameweekRatings,
  });

  final List<PerformanceGameweekRating> gameweekRatings;

  @override
  State<PerformanceChart> createState() => _PerformanceChartState();
}

class _PerformanceChartState extends State<PerformanceChart> {
  static final _yTickValues = <double>{0, 5, 8, 10};

  int? _revealedBarIndex;
  int _revealRequestCounter = 0;

  void _revealRatingBriefly(int index) {
    final requestId = ++_revealRequestCounter;
    setState(() => _revealedBarIndex = index);
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 1400), () {
        if (!mounted || requestId != _revealRequestCounter) return;
        setState(() => _revealedBarIndex = null);
      }),
    );
  }

  bool _showsYTick(double value) =>
      _yTickValues.any((tick) => (tick - value).abs() < 0.01);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final bool isLight = colorScheme.brightness == Brightness.light;
    const chartHeight = 200.0;

    final gameweekData = widget.gameweekRatings;

    const maxRating = 10.0;

    return SizedBox(
      height: chartHeight,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          minY: 0,
          maxY: maxRating,
          barTouchData: BarTouchData(
            enabled: true,
            handleBuiltInTouches: false,
            touchTooltipData: BarTouchTooltipData(
              tooltipBorderRadius: BorderRadius.circular(10),
              tooltipPadding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 8,
              ),
              getTooltipColor: (_) => colorScheme.inverseSurface,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  rod.toY.toStringAsFixed(1),
                  textTheme.labelSmall?.copyWith(
                        color: colorScheme.onInverseSurface,
                        fontWeight: FontWeight.w700,
                      ) ??
                      TextStyle(
                        color: colorScheme.onInverseSurface,
                        fontWeight: FontWeight.w700,
                      ),
                );
              },
            ),
            touchCallback: (event, response) {
              if (!event.isInterestedForInteractions) return;
              final spot = response?.spot;
              if (spot == null) return;
              _revealRatingBriefly(spot.touchedBarGroupIndex);
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index >= 0 && index < gameweekData.length) {
                    return SideTitleWidget(
                      meta: meta,
                      space: 4,
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'GW${gameweekData[index].gameweek}',
                          style: textTheme.labelSmall,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
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
            rightTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  if (!_showsYTick(value)) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: meta,
                    space: 4,
                    child: Text(
                      value.round().toString(),
                      style: textTheme.labelSmall,
                    ),
                  );
                },
              ),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1,
            checkToShowHorizontalLine: (value) => (value - 8).abs() < 0.01,
            getDrawingHorizontalLine: (_) => FlLine(
              color: colorScheme.onSurface.withValues(alpha: 0.22),
              strokeWidth: 1,
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: gameweekData.asMap().entries.map((entry) {
            final index = entry.key;
            final data = entry.value;
            final rating = data.rating;
            final isExceptional = rating >= 8.0;
            return BarChartGroupData(
              x: index,
              showingTooltipIndicators: _revealedBarIndex == index
                  ? const [0]
                  : const [],
              barRods: [
                BarChartRodData(
                  toY: rating,
                  color: isExceptional
                      ? colorScheme.primaryContainer
                      : (isLight
                            ? colorScheme.primary
                            : const Color(0xfff2fff1)),
                  width: 39,
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ],
              barsSpace: 4,
            );
          }).toList(),
        ),
      ),
    );
  }
}

class PerformanceGameweekRating {
  const PerformanceGameweekRating({
    required this.gameweek,
    required this.rating,
  });

  final int gameweek;
  final double rating;
}
