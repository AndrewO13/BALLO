/// League match format: how many play a side, and the default outfield formation.
///
/// Formation numbers run **defenders → attackers** and never include the
/// goalkeeper. `4-4-2` is 4 DEF, 4 MID, 2 ATT, plus 1 GK (11-a-side).
class LeagueFormat {
  const LeagueFormat({required this.playersPerSide, required this.formation});

  static const int minPlayersPerSide = 5;
  static const int maxPlayersPerSide = 11;
  static const List<int> supportedSides = [5, 6, 7, 8, 9, 11];

  static const Map<int, List<String>> formationsBySide = {
    5: ['1-2-1', '2-1-1', '1-1-2', '2-2'],
    6: ['2-2-1', '2-1-2', '3-1-1', '1-2-2'],
    7: ['2-2-2', '3-2-1', '2-3-1', '3-1-2'],
    8: ['3-2-2', '2-3-2', '3-3-1', '2-2-3'],
    9: ['3-3-2', '3-2-3', '2-3-3', '4-3-1', '3-4-1'],
    11: [
      '4-4-2',
      '4-3-3',
      '3-5-2',
      '4-2-3-1',
      '3-4-3',
      '5-3-2',
      '4-5-1',
      '5-4-1',
    ],
  };

  static const Map<int, String> defaultFormationBySide = {
    5: '1-2-1',
    6: '2-2-1',
    7: '2-2-2',
    8: '3-2-2',
    9: '3-3-2',
    11: '4-4-2',
  };

  static const LeagueFormat elevenASide = LeagueFormat(
    playersPerSide: 11,
    formation: '4-4-2',
  );

  final int playersPerSide;
  final String formation;

  static LeagueFormat fromStored({Object? playersPerSide, Object? formation}) {
    final side = playersPerSide is num
        ? playersPerSide.toInt()
        : int.tryParse(playersPerSide?.toString() ?? '') ?? 11;
    final raw = (formation?.toString() ?? '').trim();
    final fallback = defaultFormationBySide[side] ?? elevenASide.formation;
    final format = LeagueFormat(
      playersPerSide: supportedSides.contains(side) ? side : 11,
      formation: raw.isEmpty ? fallback : raw,
    );
    return format.isValid
        ? format
        : LeagueFormat(
            playersPerSide: format.playersPerSide,
            formation:
                defaultFormationBySide[format.playersPerSide] ??
                elevenASide.formation,
          );
  }

  static List<String> formationsFor(int playersPerSide) =>
      List<String>.from(formationsBySide[playersPerSide] ?? const ['4-4-2']);

  static String defaultFormationFor(int playersPerSide) =>
      defaultFormationBySide[playersPerSide] ?? elevenASide.formation;

  /// Outfield counts from the back: first = defenders, last = attackers.
  List<int> get outfieldLines {
    final parts = <int>[];
    for (final token in formation.split('-')) {
      final n = int.tryParse(token.trim());
      if (n == null || n < 0) return const [];
      parts.add(n);
    }
    return parts;
  }

  int get outfieldCount => outfieldLines.fold<int>(0, (sum, n) => sum + n);

  bool get isValid {
    if (!supportedSides.contains(playersPerSide)) return false;
    final lines = outfieldLines;
    if (lines.length < 2) return false;
    if (lines.any((n) => n < 0)) return false;
    if (outfieldCount + 1 != playersPerSide) return false;
    return formationsFor(playersPerSide).contains(formation);
  }

  int get defenderCount => outfieldLines.isEmpty ? 0 : outfieldLines.first;

  int get attackerCount => outfieldLines.length < 2 ? 0 : outfieldLines.last;

  int get midfielderCount {
    final lines = outfieldLines;
    if (lines.length <= 2) return 0;
    return lines.sublist(1, lines.length - 1).fold<int>(0, (s, n) => s + n);
  }

  /// Pitch rows from the attacking end (top) down to the goalkeeper (bottom).
  List<LeagueFormationLine> get pitchLinesFromAttack {
    final lines = outfieldLines;
    if (lines.length < 2) {
      return const [
        LeagueFormationLine(role: LeagueFormationRole.goalkeeper, count: 1),
      ];
    }
    final rows = <LeagueFormationLine>[
      LeagueFormationLine(
        role: LeagueFormationRole.attacker,
        count: lines.last,
      ),
    ];
    for (var i = lines.length - 2; i >= 1; i--) {
      rows.add(
        LeagueFormationLine(
          role: LeagueFormationRole.midfielder,
          count: lines[i],
        ),
      );
    }
    rows.add(
      LeagueFormationLine(
        role: LeagueFormationRole.defender,
        count: lines.first,
      ),
    );
    rows.add(
      const LeagueFormationLine(role: LeagueFormationRole.goalkeeper, count: 1),
    );
    return rows.where((row) => row.count > 0).toList();
  }

  String get summaryLabel {
    final bits = <String>['1 GK'];
    bits.add('$defenderCount DEF');
    if (midfielderCount > 0) bits.add('$midfielderCount MID');
    bits.add('$attackerCount ATT');
    return bits.join(' · ');
  }

  /// Places picked players onto pitch rows from the attacking end down to GK.
  /// Extra midfield rows (e.g. `4-2-3-1`) are filled from attacking mid first.
  List<List<T>> assignToPitch<T>({
    required List<T> goalkeepers,
    required List<T> defenders,
    required List<T> midfielders,
    required List<T> attackers,
  }) {
    final remainingMids = List<T>.from(midfielders);
    final lines = <List<T>>[];
    for (final row in pitchLinesFromAttack) {
      switch (row.role) {
        case LeagueFormationRole.attacker:
          lines.add(attackers.take(row.count).toList());
        case LeagueFormationRole.midfielder:
          final taken = remainingMids.take(row.count).toList();
          remainingMids.removeRange(0, taken.length);
          lines.add(taken);
        case LeagueFormationRole.defender:
          lines.add(defenders.take(row.count).toList());
        case LeagueFormationRole.goalkeeper:
          lines.add(goalkeepers.take(row.count).toList());
      }
    }
    return lines;
  }
}

class TeamOfTheWeekSelection {
  const TeamOfTheWeekSelection({
    required this.format,
    required this.linesFromAttack,
  });

  final LeagueFormat format;
  final List<List<Map<String, dynamic>>> linesFromAttack;

  bool get hasPlayers => linesFromAttack.any((line) => line.isNotEmpty);

  factory TeamOfTheWeekSelection.empty([LeagueFormat? format]) {
    return TeamOfTheWeekSelection(
      format: format ?? LeagueFormat.elevenASide,
      linesFromAttack: const [],
    );
  }
}

enum LeagueFormationRole { goalkeeper, defender, midfielder, attacker }

class LeagueFormationLine {
  const LeagueFormationLine({required this.role, required this.count});

  final LeagueFormationRole role;
  final int count;
}
