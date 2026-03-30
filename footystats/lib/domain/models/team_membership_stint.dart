/// One row from `player_team_memberships` with joined team fields.
class TeamMembershipStint {
  const TeamMembershipStint({
    required this.teamId,
    this.teamName,
    this.shortForm,
    this.logoId,
    this.createdAt,
    this.endDate,
  });

  final String teamId;
  final String? teamName;
  final String? shortForm;
  final String? logoId;
  final DateTime? createdAt;
  final DateTime? endDate;

  bool get isCurrent => endDate == null;

  String get displayName {
    final n = teamName?.trim();
    if (n != null && n.isNotEmpty) return n;
    final s = shortForm?.trim();
    if (s != null && s.isNotEmpty) return s;
    return 'Team';
  }
}
