import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Simple notifier for the selected team on the home page.
class SelectedTeamNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void setTeam(String? teamId) {
    state = teamId;
  }
}

/// Selected team provider for home page.
final selectedTeamProvider =
    NotifierProvider<SelectedTeamNotifier, String?>(
  SelectedTeamNotifier.new,
);
