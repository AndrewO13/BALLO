import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PerformanceRadarChart extends StatelessWidget {
  const PerformanceRadarChart({
    super.key,
    required this.playerId,
    required this.year,
    this.comparePlayerId,
  });

  final String playerId;
  final int year;
  final String? comparePlayerId;

  static const _labels = <String>['ATT', 'SHT', 'DEF', 'GKP', 'DIS'];

  double _clamp01(num v) => v < 0 ? 0 : (v > 1 ? 1 : v.toDouble());

  Future<List<double>> _loadNormalizedAxesForPlayer(String targetPlayerId) async {
    final client = Supabase.instance.client;
    try {
      final res = await client.rpc(
        'get_player_year_stats',
        params: {'p_player_id': targetPlayerId, 'p_year': year},
      );
      final row = (res as List?)?.isNotEmpty == true
          ? Map<String, dynamic>.from((res as List).first as Map)
          : null;
      if (row == null) return List<double>.filled(_labels.length, 0);

      double asDouble(dynamic v) {
        if (v == null) return 0;
        if (v is num) return v.toDouble();
        return double.tryParse(v.toString()) ?? 0;
      }

      final minutes = asDouble(row['minutes_played']);
      final goals = asDouble(row['goals']);
      final assists = asDouble(row['assists']);
      final shots = asDouble(row['shots']);
      final sot = asDouble(row['shots_on_target']);
      final tackles = asDouble(row['tackles']);
      final saves = asDouble(row['saves']);
      final xg = asDouble(row['xg']);
      final xa = asDouble(row['xa']);
      final yellow = asDouble(row['yellow_cards']);
      final red = asDouble(row['red_cards']);

      final denomMinutes = minutes <= 0 ? 1.0 : minutes;
      double per90(double v) => 90.0 * v / denomMinutes;

      final goals90 = per90(goals);
      final assists90 = per90(assists);
      final xg90 = per90(xg);
      final xa90 = per90(xa);
      final shots90 = per90(shots);
      final tackles90 = per90(tackles);
      final saves90 = per90(saves);

      final sotRate = shots <= 0 ? 0.0 : (sot / shots).clamp(0.0, 1.0);

      final att = _clamp01(
        (goals90 * 1.0 + assists90 * 0.7 + xg90 * 0.6 + xa90 * 0.4) / 2.0,
      );
      final sht = _clamp01(0.6 * (shots90 / 6.0) + 0.4 * (sotRate / 0.6));
      final def = _clamp01(tackles90 / 8.0);
      final gkp = _clamp01(saves90 / 8.0);
      final cardCost90 = per90(yellow + 3.0 * red);
      final dis = _clamp01(1.0 - (cardCost90 / 2.0));

      return [att, sht, def, gkp, dis];
    } catch (_) {
      // If RPC isn't deployed yet, fall back to a direct query for the selected year.
    }

    final start = DateTime(year, 1, 1);
    final end = DateTime(year + 1, 1, 1);
    final res = await client
        .from('match_player_stats')
        .select(
          'minutes_played, goals, assists, shots, shots_on_target, tackles, saves, xG, xA, yellow_cards, red_cards, match:matches!inner(status, match_date)',
        )
        .eq('player_id', targetPlayerId)
        .eq('match.status', 'fullTime')
        .gte('match.match_date', start.toIso8601String().split('T').first)
        .lt('match.match_date', end.toIso8601String().split('T').first);
    final rows = List<Map<String, dynamic>>.from(res as List);
    if (rows.isEmpty) return List<double>.filled(_labels.length, 0);

    double minutes = 0;
    double goals = 0;
    double assists = 0;
    double shots = 0;
    double sot = 0;
    double tackles = 0;
    double saves = 0;
    double xg = 0;
    double xa = 0;
    double yellow = 0;
    double red = 0;

    double asDouble(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    for (final r in rows) {
      minutes += asDouble(r['minutes_played']);
      goals += asDouble(r['goals']);
      assists += asDouble(r['assists']);
      shots += asDouble(r['shots']);
      sot += asDouble(r['shots_on_target']);
      tackles += asDouble(r['tackles']);
      saves += asDouble(r['saves']);
      xg += asDouble(r['xG']);
      xa += asDouble(r['xA']);
      yellow += asDouble(r['yellow_cards']);
      red += asDouble(r['red_cards']);
    }

    final denomMinutes = minutes <= 0 ? 1.0 : minutes;
    double per90(double v) => 90.0 * v / denomMinutes;

    final goals90 = per90(goals);
    final assists90 = per90(assists);
    final xg90 = per90(xg);
    final xa90 = per90(xa);
    final shots90 = per90(shots);
    final tackles90 = per90(tackles);
    final saves90 = per90(saves);

    final sotRate = shots <= 0 ? 0.0 : (sot / shots).clamp(0.0, 1.0);

    final att = _clamp01(
      (goals90 * 1.0 + assists90 * 0.7 + xg90 * 0.6 + xa90 * 0.4) / 2.0,
    );
    final sht = _clamp01(0.6 * (shots90 / 6.0) + 0.4 * (sotRate / 0.6));
    final def = _clamp01(tackles90 / 8.0);
    final gkp = _clamp01(saves90 / 8.0);
    final cardCost90 = per90(yellow + 3.0 * red);
    final dis = _clamp01(1.0 - (cardCost90 / 2.0));

    return [att, sht, def, gkp, dis];
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const primaryBorder = Color(0xFF2E7DFF); // blue
    const compareBorder = Color(0xFFFF7A00); // orange
    const primaryFill = Color(0x332E7DFF);
    const compareFill = Color(0x33FF7A00);
    final hasComparison =
        comparePlayerId != null &&
        comparePlayerId!.isNotEmpty &&
        comparePlayerId != playerId;

    return FutureBuilder<List<List<double>>>(
      future: () async {
        final primary = await _loadNormalizedAxesForPlayer(playerId);
        if (!hasComparison) return [primary];
        final secondary = await _loadNormalizedAxesForPlayer(comparePlayerId!);
        return [primary, secondary];
      }(),
      builder: (context, snapshot) {
        final datasets = snapshot.data ?? [List<double>.filled(_labels.length, 0)];
        final values = datasets.first;
        final compareValues =
            datasets.length > 1 ? datasets[1] : List<double>.filled(_labels.length, 0);
        final loading = snapshot.connectionState == ConnectionState.waiting;

        return Stack(
          children: [
            RadarChart(
              RadarChartData(
                radarShape: RadarShape.polygon,
                tickCount: 4,
                ticksTextStyle: TextStyle(
                  color: cs.onSurfaceVariant.withOpacity(0.8),
                  fontSize: 10,
                ),
                radarBackgroundColor: Colors.transparent,
                radarBorderData: BorderSide(
                  color: cs.outline.withOpacity(0.3),
                  width: 1,
                ),
                gridBorderData: BorderSide(
                  color: cs.outline.withOpacity(0.25),
                  width: 1,
                ),
                tickBorderData: BorderSide(
                  color: cs.outline.withOpacity(0.25),
                  width: 1,
                ),
                getTitle: (index, angle) => RadarChartTitle(
                  text: _labels[index % _labels.length],
                  angle: angle,
                  positionPercentageOffset: 0.16,
                ),
                dataSets: [
                  RadarDataSet(
                    fillColor: primaryFill,
                    borderColor: primaryBorder,
                    borderWidth: 2,
                    entryRadius: 2.5,
                    dataEntries: values
                        .map((v) => RadarEntry(value: (v * 1.0).toDouble()))
                        .toList(),
                  ),
                  if (hasComparison)
                    RadarDataSet(
                      fillColor: compareFill,
                      borderColor: compareBorder,
                      borderWidth: 2,
                      entryRadius: 2.5,
                      dataEntries: compareValues
                          .map((v) => RadarEntry(value: (v * 1.0).toDouble()))
                          .toList(),
                    ),
                ],
              ),
            ),
            if (hasComparison)
              Positioned(
                left: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: cs.surface.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: cs.outline.withOpacity(0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(width: 10, height: 2, color: primaryBorder),
                      const SizedBox(width: 4),
                      Text('You', style: TextStyle(fontSize: 11, color: cs.onSurface)),
                      const SizedBox(width: 10),
                      Container(width: 10, height: 2, color: compareBorder),
                      const SizedBox(width: 4),
                      Text(
                        'Compare',
                        style: TextStyle(fontSize: 11, color: cs.onSurface),
                      ),
                    ],
                  ),
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
        );
      },
    );
  }
}
