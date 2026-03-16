import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/fixture_goal_event.dart';

/// In-memory goal events for a single match.
class FixtureGoalEventsNotifier extends Notifier<List<FixtureGoalEvent>> {
  FixtureGoalEventsNotifier(this.matchId);

  final String matchId;

  @override
  List<FixtureGoalEvent> build() => [];

  void addGoal(FixtureGoalEvent event) {
    state = [...state, event];
  }
}

final fixtureGoalEventsProvider =
    NotifierProvider.family<FixtureGoalEventsNotifier, List<FixtureGoalEvent>,
        String>(
  FixtureGoalEventsNotifier.new,
);
