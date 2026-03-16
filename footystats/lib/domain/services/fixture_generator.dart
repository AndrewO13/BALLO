import '../models/fixture_generation_options.dart';

/// Immutable result of one match to be inserted.
class PlannedMatch {
  const PlannedMatch({
    required this.teamA,
    required this.teamB,
    required this.gameweekNumber,
    required this.matchDate,
    required this.matchTime,
  });

  final String teamA;
  final String teamB;
  final int gameweekNumber;
  final DateTime matchDate;
  final String matchTime;
}

/// One gameweek with its planned matches.
class PlannedGameweek {
  const PlannedGameweek({
    required this.weekNumber,
    required this.matches,
    required this.date,
  });

  final int weekNumber;
  final List<PlannedMatch> matches;
  final DateTime date;
}

/// Round-robin fixture generator using the circle method.
class FixtureGenerator {
  static const String _bye = '__BYE__';

  /// Generates planned gameweeks and matches from options and team IDs.
  /// Does not touch the database.
  static List<PlannedGameweek> generate({
    required List<String> teamIds,
    required FixtureGenerationOptions options,
  }) {
    if (teamIds.length < 2) return [];

    final legs = options.fixtureFormat == FixtureFormat.doubleLeg ? 2 : 1;
    final homeAway = options.homeAwayMode == HomeAwayMode.homeAway;

    if (options.fullRoundPerGameweek) {
      return _generateFullRoundPerGameweek(teamIds, legs, homeAway, options);
    }

    final teams = List<String>.from(teamIds);
    final usedBye = teams.length.isOdd;
    if (usedBye) teams.add(_bye);

    final numRounds = teams.length - 1;
    final matchesPerRound = teams.length ~/ 2;

    final allRounds = <List<(String, String)>>[];
    var current = List<String>.from(teams);

    for (var r = 0; r < numRounds; r++) {
      final roundMatches = <(String, String)>[];
      for (var i = 0; i < matchesPerRound; i++) {
        final a = current[i];
        final b = current[teams.length - 1 - i];
        if (a != _bye && b != _bye) {
          roundMatches.add((a, b));
        }
      }
      allRounds.add(roundMatches);
      if (r < numRounds - 1) {
        current = _rotate(current);
      }
    }

    final gameweeks = <PlannedGameweek>[];
    var gwNum = 1;
    for (var leg = 0; leg < legs; leg++) {
      for (var r = 0; r < numRounds; r++) {
        final roundMatches = allRounds[r];
        final pairs = leg == 1 && homeAway
            ? roundMatches.map((p) => (p.$2, p.$1)).toList()
            : roundMatches;

        final date = _gameweekDate(options, gwNum);
        final times = _matchTimes(
          options: options,
          matchCount: pairs.length,
        );

        final plannedMatches = <PlannedMatch>[];
        for (var i = 0; i < pairs.length; i++) {
          plannedMatches.add(PlannedMatch(
            teamA: pairs[i].$1,
            teamB: pairs[i].$2,
            gameweekNumber: gwNum,
            matchDate: date,
            matchTime: times[i],
          ));
        }

        gameweeks.add(PlannedGameweek(
          weekNumber: gwNum,
          matches: plannedMatches,
          date: date,
        ));
        gwNum++;
      }
    }

    return gameweeks;
  }

  /// Full round per gameweek: each gameweek contains all pairs (every team plays
  /// every other once). Gameweek count = how many such full rounds. Matches are
  /// ordered so the next match never shares a team with the previous (all other
  /// teams play before a team plays again), when possible.
  static List<PlannedGameweek> _generateFullRoundPerGameweek(
    List<String> teamIds,
    int legs,
    bool homeAway,
    FixtureGenerationOptions options,
  ) {
    final allPairs = _allPairsInRoundOrder(teamIds);
    final gwPerLeg = (options.fullRoundGameweeksPerLeg ?? 1).clamp(1, 999);

    final gameweeks = <PlannedGameweek>[];
    var gwNum = 1;
    for (var leg = 0; leg < legs; leg++) {
      final pairs = leg == 1 && homeAway
          ? allPairs.map((p) => (p.$2, p.$1)).toList()
          : List<(String, String)>.from(allPairs);

      for (var g = 0; g < gwPerLeg; g++) {
        final startIdx = g % pairs.length;
        final ordered = _orderNoBackToBack(pairs, startIndex: startIdx);
        final date = _gameweekDate(options, gwNum);
        final times = _matchTimes(
          options: options,
          matchCount: ordered.length,
        );
        final plannedMatches = <PlannedMatch>[];
        for (var i = 0; i < ordered.length; i++) {
          plannedMatches.add(PlannedMatch(
            teamA: ordered[i].$1,
            teamB: ordered[i].$2,
            gameweekNumber: gwNum,
            matchDate: date,
            matchTime: times[i],
          ));
        }
        gameweeks.add(PlannedGameweek(
          weekNumber: gwNum,
          matches: plannedMatches,
          date: date,
        ));
        gwNum++;
      }
    }
    return gameweeks;
  }

  /// Returns all pairs in round-robin round order (each round has disjoint teams).
  static List<(String, String)> _allPairsInRoundOrder(List<String> teamIds) {
    final teams = List<String>.from(teamIds);
    final usedBye = teams.length.isOdd;
    if (usedBye) teams.add(_bye);

    final numRounds = teams.length - 1;
    final matchesPerRound = teams.length ~/ 2;
    final result = <(String, String)>[];
    var current = List<String>.from(teams);

    for (var r = 0; r < numRounds; r++) {
      for (var i = 0; i < matchesPerRound; i++) {
        final a = current[i];
        final b = current[teams.length - 1 - i];
        if (a != _bye && b != _bye) result.add((a, b));
      }
      if (r < numRounds - 1) current = _rotate(current);
    }
    return result;
  }

  /// Orders matches so the next match has NO team in common with the previous
  /// (all other teams play at least one match before a team plays again).
  /// When no such match exists, picks any remaining (inevitable back-to-back).
  /// [startIndex] rotates which pair opens each gameweek so the same teams
  /// don't start every week.
  static List<(String, String)> _orderNoBackToBack(
    List<(String, String)> pairs, {
    int startIndex = 0,
  }) {
    if (pairs.length <= 1) return pairs;
    final remaining = List<(String, String)>.from(pairs);
    final ordered = <(String, String)>[];
    final idx = startIndex % remaining.length;
    ordered.add(remaining.removeAt(idx));
    var lastTeams = {ordered.last.$1, ordered.last.$2};

    while (remaining.isNotEmpty) {
      var idx = -1;
      for (var i = 0; i < remaining.length; i++) {
        final p = remaining[i];
        final overlap = lastTeams.contains(p.$1) || lastTeams.contains(p.$2);
        if (!overlap) {
          idx = i;
          break;
        }
      }
      if (idx < 0) idx = 0;
      final next = remaining.removeAt(idx);
      ordered.add(next);
      lastTeams = {next.$1, next.$2};
    }
    return ordered;
  }

  /// Rotate indices 1..n-1 clockwise; index 0 stays fixed (circle method).
  static List<String> _rotate(List<String> list) {
    if (list.length <= 1) return list;
    final rest = list.sublist(1);
    final rotated = [rest.last, ...rest.sublist(0, rest.length - 1)];
    return [list[0], ...rotated];
  }

  static DateTime _gameweekDate(FixtureGenerationOptions opts, int gwNum) {
    if (opts.schedulingMode == SchedulingMode.compressed &&
        opts.compressedLeagueDays != null &&
        opts.compressedLeagueDays! > 0) {
      final dayOffset = (gwNum - 1) % opts.compressedLeagueDays!;
      return opts.firstGameweekDate.add(Duration(days: dayOffset));
    }
    final days = (gwNum - 1) * opts.gameweekIntervalDays;
    return opts.firstGameweekDate.add(Duration(days: days));
  }

  static List<String> _matchTimes({
    required FixtureGenerationOptions options,
    required int matchCount,
  }) {
    final start = options.startTime ?? '09:00';
    final end = options.endTime ?? '18:00';
    if (options.sameTimeForAll || matchCount <= 1) {
      return List.filled(matchCount, start);
    }
    final startMins = _timeToMinutes(start);
    final endMins = _timeToMinutes(end);
    final span = (endMins - startMins) / (matchCount + 1).clamp(1, 999);
    return List.generate(
      matchCount,
      (i) => _minutesToTime((startMins + span * (i + 1)).round()),
    );
  }

  static int _timeToMinutes(String time) {
    final parts = time.split(':');
    if (parts.length < 2) return 9 * 60;
    final h = int.tryParse(parts[0]) ?? 9;
    final m = int.tryParse(parts[1]) ?? 0;
    return h * 60 + m;
  }

  static String _minutesToTime(int mins) {
    final h = (mins ~/ 60) % 24;
    final m = mins % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }
}
