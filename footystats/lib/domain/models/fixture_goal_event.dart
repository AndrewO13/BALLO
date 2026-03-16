/// A goal recorded during fixture stat tracking (in-memory until persisted).
class FixtureGoalEvent {
  const FixtureGoalEvent({
    required this.scorerName,
    required this.minute,
    required this.isTeamA,
    this.assistName,
  });

  final String scorerName;
  /// Display minute e.g. 23 for "23'"
  final int minute;
  final bool isTeamA;
  final String? assistName;
}

/// Squad player shown in goal/assist picker.
class FixturePickerPlayer {
  const FixturePickerPlayer({
    required this.id,
    required this.name,
    required this.position,
    this.imagePath,
    this.imageUrl,
  });

  final String id;
  final String name;
  /// From players.position or mapped label (Attacker, etc.)
  final String position;
  /// Local asset path for CircleAvatar
  final String? imagePath;
  /// If set and starts with http, use NetworkImage in UI
  final String? imageUrl;

  bool get useNetworkImage =>
      imageUrl != null &&
      (imageUrl!.startsWith('http://') || imageUrl!.startsWith('https://'));
}
