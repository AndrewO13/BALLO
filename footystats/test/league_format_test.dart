import 'package:flutter_test/flutter_test.dart';

import 'package:ballo/domain/models/league_format.dart';

void main() {
  group('LeagueFormat', () {
    test('4-4-2 is 11-a-side with one GK excluded from the string', () {
      const format = LeagueFormat(playersPerSide: 11, formation: '4-4-2');
      expect(format.isValid, isTrue);
      expect(format.defenderCount, 4);
      expect(format.midfielderCount, 4);
      expect(format.attackerCount, 2);
      expect(format.outfieldCount + 1, 11);
    });

    test('4-2-3-1 splits midfield into two pitch rows', () {
      const format = LeagueFormat(playersPerSide: 11, formation: '4-2-3-1');
      expect(format.isValid, isTrue);
      expect(format.midfielderCount, 5);
      final roles = format.pitchLinesFromAttack.map((l) => (l.role, l.count));
      expect(roles, [
        (LeagueFormationRole.attacker, 1),
        (LeagueFormationRole.midfielder, 3),
        (LeagueFormationRole.midfielder, 2),
        (LeagueFormationRole.defender, 4),
        (LeagueFormationRole.goalkeeper, 1),
      ]);
    });

    test('9-a-side 3-3-2 excludes the goalkeeper', () {
      const format = LeagueFormat(playersPerSide: 9, formation: '3-3-2');
      expect(format.isValid, isTrue);
      expect(format.defenderCount, 3);
      expect(format.midfielderCount, 3);
      expect(format.attackerCount, 2);
    });

    test('5-a-side 2-2 has no midfield line', () {
      const format = LeagueFormat(playersPerSide: 5, formation: '2-2');
      expect(format.isValid, isTrue);
      expect(format.midfielderCount, 0);
      expect(format.pitchLinesFromAttack.map((l) => l.role), [
        LeagueFormationRole.attacker,
        LeagueFormationRole.defender,
        LeagueFormationRole.goalkeeper,
      ]);
    });

    test('invalid stored values fall back to 11-a-side 4-4-2', () {
      final format = LeagueFormat.fromStored(
        playersPerSide: 10,
        formation: '9-9-9',
      );
      expect(format.playersPerSide, 11);
      expect(format.formation, '4-4-2');
    });

    test('assignToPitch fills attacking midfield first', () {
      const format = LeagueFormat(playersPerSide: 11, formation: '4-2-3-1');
      final lines = format.assignToPitch<String>(
        goalkeepers: ['gk'],
        defenders: ['d1', 'd2', 'd3', 'd4'],
        midfielders: ['m1', 'm2', 'm3', 'm4', 'm5'],
        attackers: ['a1'],
      );
      expect(lines, [
        ['a1'],
        ['m1', 'm2', 'm3'],
        ['m4', 'm5'],
        ['d1', 'd2', 'd3', 'd4'],
        ['gk'],
      ]);
    });
  });
}
