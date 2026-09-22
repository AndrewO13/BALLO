import 'match_event_display.dart';

enum LineupCardState { none, yellow, red }

class LineupPlayerMatchStats {
  const LineupPlayerMatchStats({
    this.goals = 0,
    this.assists = 0,
    this.tackles = 0,
    this.subbedIn = false,
    this.subbedOut = false,
    this.cardState = LineupCardState.none,
  });

  final int goals;
  final int assists;
  final int tackles;
  final bool subbedIn;
  final bool subbedOut;
  final LineupCardState cardState;

  bool get hasGoal => goals > 0;
  bool get hasAssist => assists > 0;
  bool get hasTackle => tackles > 0;
  bool get hasAnyBadge =>
      hasGoal || hasAssist || hasTackle || subbedIn || subbedOut;
}

const _goalEventTypes = {'goal', 'penalty_goal', 'own_goal'};

Map<String, LineupPlayerMatchStats> aggregateLineupPlayerStats(
  List<MatchEventDisplay> events,
) {
  final goals = <String, int>{};
  final assists = <String, int>{};
  final tackles = <String, int>{};
  final subIn = <String>{};
  final subOut = <String>{};
  final cards = <String, LineupCardState>{};

  for (final event in events) {
    final playerId = event.playerId;
    final secondaryId = event.secondaryPlayerId;
    final type = event.eventType;

    if (_goalEventTypes.contains(type)) {
      if (playerId != null && playerId.isNotEmpty) {
        goals[playerId] = (goals[playerId] ?? 0) + 1;
      }
      if (secondaryId != null && secondaryId.isNotEmpty) {
        assists[secondaryId] = (assists[secondaryId] ?? 0) + 1;
      }
    } else if (type == 'assist') {
      if (playerId != null && playerId.isNotEmpty) {
        assists[playerId] = (assists[playerId] ?? 0) + 1;
      }
    } else if (type == 'tackle') {
      if (playerId != null && playerId.isNotEmpty) {
        tackles[playerId] = (tackles[playerId] ?? 0) + 1;
      }
    } else if (type == 'substitution') {
      if (playerId != null && playerId.isNotEmpty) {
        subIn.add(playerId);
      }
      if (secondaryId != null && secondaryId.isNotEmpty) {
        subOut.add(secondaryId);
      }
    } else if (type == 'yellow_card') {
      if (playerId != null &&
          playerId.isNotEmpty &&
          cards[playerId] != LineupCardState.red) {
        cards[playerId] = LineupCardState.yellow;
      }
    } else if (type == 'red_card') {
      if (playerId != null && playerId.isNotEmpty) {
        cards[playerId] = LineupCardState.red;
      }
    }
  }

  final allPlayerIds = <String>{
    ...goals.keys,
    ...assists.keys,
    ...tackles.keys,
    ...subIn,
    ...subOut,
    ...cards.keys,
  };

  return {
    for (final id in allPlayerIds)
      id: LineupPlayerMatchStats(
        goals: goals[id] ?? 0,
        assists: assists[id] ?? 0,
        tackles: tackles[id] ?? 0,
        subbedIn: subIn.contains(id),
        subbedOut: subOut.contains(id),
        cardState: cards[id] ?? LineupCardState.none,
      ),
  };
}
