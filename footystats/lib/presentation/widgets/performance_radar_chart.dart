import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/utils/match_stats_aggregation.dart';

/// Radar chart for ATT / SHT / DEF / GKP / DIS (0–10 per axis).
///
/// Loads [match_player_stats] from Supabase per player. Year mode averages
/// per-match axis scores so players with different records produce different shapes.
class PerformanceRadarChart extends StatefulWidget {
  const PerformanceRadarChart({
    super.key,
    required this.playerId,
    required this.year,
    this.comparePlayerId,
    this.playerMatchId,
    this.compareMatchId,
    this.primaryLabel = 'You',
    this.compareLabel = 'Compare',
  });

  final String playerId;
  final int year;
  final String? comparePlayerId;
  final String? playerMatchId;
  final String? compareMatchId;
  final String primaryLabel;
  final String compareLabel;

  @override
  State<PerformanceRadarChart> createState() => _PerformanceRadarChartState();
}

class _PerformanceRadarChartState extends State<PerformanceRadarChart> {
  static const _labels = <String>['ATT', 'SHT', 'DEF', 'GKP', 'DIS'];
  static const _axisMax = 10.0;
  static const _axisTickCount = 5;

  late Future<List<List<double>>> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _loadDatasets();
  }

  @override
  void didUpdateWidget(PerformanceRadarChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playerId != widget.playerId ||
        oldWidget.year != widget.year ||
        oldWidget.comparePlayerId != widget.comparePlayerId ||
        oldWidget.playerMatchId != widget.playerMatchId ||
        oldWidget.compareMatchId != widget.compareMatchId) {
      _dataFuture = _loadDatasets();
    }
  }

  bool get _hasComparison {
    final compareId = widget.comparePlayerId;
    return compareId != null &&
        compareId.isNotEmpty &&
        compareId != widget.playerId;
  }

  Future<List<List<double>>> _loadDatasets() async {
    final primary = await _loadNormalizedAxes(
      widget.playerId,
      matchId: widget.playerMatchId,
    );
    if (!_hasComparison) return [primary];
    final secondary = await _loadNormalizedAxes(
      widget.comparePlayerId!,
      matchId: widget.compareMatchId,
    );
    return [primary, secondary];
  }

  double _clamp01(num v) => v < 0 ? 0 : (v > 1 ? 1 : v.toDouble());

  double _toAxisValue(num normalized) => _clamp01(normalized) * _axisMax;

  double _asDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  double _field(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      if (row.containsKey(key)) return _asDouble(row[key]);
    }
    return 0;
  }

  /// Stat-driven axes for one match row (0–1). Uses lineup-derived [minutes_played].
  List<double> _axesForMatchRow(Map<String, dynamic> row) {
    final minutes = MatchStatsAggregation.minutesFromRow(row);
    final goals = _field(row, ['goals']);
    final assists = _field(row, ['assists']);
    final shots = _field(row, ['shots']);
    final sot = _field(row, ['shots_on_target']);
    final tackles = _field(row, ['tackles']);
    final saves = _field(row, ['saves']);
    final yellow = _field(row, ['yellow_cards']);
    final red = _field(row, ['red_cards']);
    final rating = _field(row, ['rating']);

    final activity = goals + assists + shots + sot + tackles + saves + yellow + red;

    // Bench / unused squad: no minutes → flat chart (matches DB p_share = 0).
    if (minutes <= 0) {
      if (activity <= 0 && rating <= 0) {
        return List<double>.filled(_labels.length, 0);
      }
      // Legacy rows with events but no frozen lineup minutes.
      final impact = math.min(0.9, 0.55 + 0.08 * activity);
      final cAttack = impact * (1.10 * goals + 0.90 * assists);
      final cTackles = impact * 0.14 * math.min(10.0, tackles.toDouble());
      final cSaves = impact * 0.22 * math.min(10.0, saves.toDouble());
      final pDisc = 0.6 * yellow + 2.0 * red;
      return [
        _clamp01(cAttack / 2.2),
        _clamp01(shots > 0 ? sot / shots : 0.0),
        _clamp01(cTackles / 1.4),
        saves > 0 ? _clamp01(cSaves / 1.6) : 0.0,
        _clamp01(1.0 - pDisc / 3.0),
      ];
    }

    final m = math.max(minutes, 1.0);
    final impact = math.sqrt((minutes / 90.0).clamp(0.0, 1.0));

    final shots90 = 90.0 * shots / m;
    final sot90 = 90.0 * sot / m;
    final tk90 = 90.0 * tackles / m;
    final sv90 = 90.0 * saves / m;

    final cPressure = 0.14 * math.min(5.0, sot90) +
        0.05 * math.min(6.0, math.max(0.0, shots90 - sot90));

    final cAttack = impact *
        (1.10 * goals + 0.90 * assists + 0.8 * cPressure);
    final cTackles = impact * 0.14 * math.min(10.0, tk90);
    final cSaves = impact * 0.22 * math.min(10.0, sv90);
    final pDisc = 0.6 * yellow + 2.0 * red;

    final att = _clamp01(cAttack / 2.2);
    final sht = _clamp01(
      0.55 * (shots90 / 5.0) + 0.45 * (shots > 0 ? (sot / shots) : 0.0),
    );
    final def = _clamp01(cTackles / 1.4);
    final gkp = saves > 0 || sv90 >= 0.5
        ? _clamp01(cSaves / 1.6)
        : _clamp01(0.35 + cTackles * 0.15);
    final dis = _clamp01(1.0 - pDisc / 3.0);

    final fromStats = [att, sht, def, gkp, dis];
    final statSignal = goals + assists + shots + tackles + saves;
    if (statSignal > 0) return fromStats;

    if (rating > 0) {
      final n = _clamp01(rating / 10.0);
      return [n * 0.92, n * 0.88, n * 0.90, n * 0.85, dis > 0 ? dis : n * 0.95];
    }

    return fromStats;
  }

  List<double> _averageAxes(List<List<double>> perMatchAxes) {
    if (perMatchAxes.isEmpty) {
      return List<double>.filled(_labels.length, 0);
    }
    final sums = List<double>.filled(_labels.length, 0);
    for (final axes in perMatchAxes) {
      for (var i = 0; i < _labels.length; i++) {
        sums[i] += axes[i];
      }
    }
    return [for (var i = 0; i < _labels.length; i++) sums[i] / perMatchAxes.length];
  }

  Future<List<Map<String, dynamic>>> _fetchMatchStatRows({
    required String targetPlayerId,
    required int year,
    String? matchId,
  }) async {
    final client = Supabase.instance.client;
    const select =
        'match_id, minutes_played, goals, assists, shots, shots_on_target, '
        'tackles, saves, yellow_cards, red_cards, rating, '
        'match:matches!inner(status, match_date)';

    if (matchId != null && matchId.isNotEmpty) {
      final res = await client
          .from('match_player_stats')
          .select(select)
          .eq('player_id', targetPlayerId)
          .eq('match_id', matchId);
      return List<Map<String, dynamic>>.from(res as List);
    }

    final start = DateTime(year, 1, 1).toIso8601String().split('T').first;
    final end = DateTime(year + 1, 1, 1).toIso8601String().split('T').first;
    final res = await client
        .from('match_player_stats')
        .select(select)
        .eq('player_id', targetPlayerId)
        .eq('match.status', 'fullTime')
        .gte('match.match_date', start)
        .lt('match.match_date', end);
    return List<Map<String, dynamic>>.from(res as List);
  }

  Future<List<double>> _loadNormalizedAxes(
    String targetPlayerId, {
    String? matchId,
  }) async {
    if (targetPlayerId.isEmpty) {
      return List<double>.filled(_labels.length, 0);
    }

    final rows = await _fetchMatchStatRows(
      targetPlayerId: targetPlayerId,
      year: widget.year,
      matchId: matchId,
    );
    if (rows.isEmpty) {
      return List<double>.filled(_labels.length, 0);
    }

    final isSingleMatch = matchId != null && matchId.isNotEmpty;
    final source = isSingleMatch
        ? rows
        : rows
              .where(MatchStatsAggregation.rowCountsAsAppearance)
              .toList();

    if (source.isEmpty) {
      return List<double>.filled(_labels.length, 0);
    }

    final perMatch = source.map(_axesForMatchRow).toList();
    return _averageAxes(perMatch);
  }

  List<RadarEntry> _axisEntries(List<double> normalizedValues) => normalizedValues
      .map((v) => RadarEntry(value: _toAxisValue(v)))
      .toList();

  RadarDataSet _axisAnchorDataSet() => RadarDataSet(
        fillColor: Colors.transparent,
        borderColor: Colors.transparent,
        borderWidth: 0,
        entryRadius: 0,
        dataEntries: List.generate(
          _labels.length,
          (_) => const RadarEntry(value: _axisMax),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const primaryBorder = Color(0xFF2E7DFF);
    const compareBorder = Color(0xFFFF7A00);
    const primaryFill = Color(0x332E7DFF);
    const compareFill = Color(0x33FF7A00);

    return FutureBuilder<List<List<double>>>(
      future: _dataFuture,
      builder: (context, snapshot) {
        final datasets =
            snapshot.data ?? [List<double>.filled(_labels.length, 0)];
        final values = datasets.first;
        final compareValues = datasets.length > 1
            ? datasets[1]
            : List<double>.filled(_labels.length, 0);
        final loading = snapshot.connectionState == ConnectionState.waiting;

        return Column(
          children: [
            if (_hasComparison)
              _SpatialComparisonLegend(
                leftLabel: widget.primaryLabel,
                rightLabel: widget.compareLabel,
                leftColor: primaryBorder,
                rightColor: compareBorder,
              ),
            if (_hasComparison) const SizedBox(height: 8),
            Expanded(
              child: Stack(
                children: [
                  RadarChart(
                    RadarChartData(
                      radarShape: RadarShape.polygon,
                      tickCount: _axisTickCount,
                      ticksTextStyle: TextStyle(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.8),
                        fontSize: 10,
                      ),
                      radarBackgroundColor: Colors.transparent,
                      radarBorderData: BorderSide(
                        color: cs.outline.withValues(alpha: 0.3),
                        width: 1,
                      ),
                      gridBorderData: BorderSide(
                        color: cs.outline.withValues(alpha: 0.25),
                        width: 1,
                      ),
                      tickBorderData: BorderSide(
                        color: cs.outline.withValues(alpha: 0.25),
                        width: 1,
                      ),
                      getTitle: (index, angle) => RadarChartTitle(
                        text: _labels[index % _labels.length],
                        angle: angle,
                        positionPercentageOffset: 0.16,
                      ),
                      dataSets: [
                        _axisAnchorDataSet(),
                        RadarDataSet(
                          fillColor: primaryFill,
                          borderColor: primaryBorder,
                          borderWidth: 2,
                          entryRadius: 2.5,
                          dataEntries: _axisEntries(values),
                        ),
                        if (_hasComparison)
                          RadarDataSet(
                            fillColor: compareFill,
                            borderColor: compareBorder,
                            borderWidth: 2,
                            entryRadius: 2.5,
                            dataEntries: _axisEntries(compareValues),
                          ),
                      ],
                    ),
                  ),
                  if (loading)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: cs.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Mirrors the left/right layout of head-to-head player rows: blue on the left,
/// orange on the right, each swatch adjacent to its label.
class _SpatialComparisonLegend extends StatelessWidget {
  const _SpatialComparisonLegend({
    required this.leftLabel,
    required this.rightLabel,
    required this.leftColor,
    required this.rightColor,
  });

  final String leftLabel;
  final String rightLabel;
  final Color leftColor;
  final Color rightColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final labelStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: cs.onSurface,
    );

    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
              _SeriesSwatch(color: leftColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  leftLabel,
                  style: labelStyle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  rightLabel,
                  style: labelStyle,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
              const SizedBox(width: 6),
              _SeriesSwatch(color: rightColor),
            ],
          ),
        ),
      ],
    );
  }
}

class _SeriesSwatch extends StatelessWidget {
  const _SeriesSwatch({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 3,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(1.5),
      ),
    );
  }
}
