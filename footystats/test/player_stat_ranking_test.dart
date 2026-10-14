import 'package:ballo/domain/models/player_stat_ranking.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PlayerStatRanking.fromRpcRow maps ranking fields', () {
    final row = PlayerStatRanking.fromRpcRow({
      'player_id': '11111111-1111-1111-1111-111111111111',
      'player_name': 'R10',
      'image_url': 'https://example.com/r10.png',
      'player_position': 'Attacker',
      'team_name': 'Review United',
      'matches': 17,
      'stat_value': 128,
      'board_rank': 1,
    });

    expect(row.playerName, 'R10');
    expect(row.position, 'Attacker');
    expect(row.teamName, 'Review United');
    expect(row.matches, 17);
    expect(row.statValue, 128);
    expect(row.rank, 1);
  });

  test('RankingStat formats counting, percentage, and rate values', () {
    expect(RankingStat.goals.formatValue(12), '12');
    expect(RankingStat.shootingPct.formatValue(62.5), '62.5%');
    expect(RankingStat.shootingPct.formatValue(70), '70%');
    expect(RankingStat.avgRating.formatValue(7.4), '7.40');
    expect(RankingStat.goalsPerMatch.formatValue(1.25), '1.25');
  });
}
