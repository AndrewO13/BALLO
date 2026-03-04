class LeagueTeamModel {
  const LeagueTeamModel({
    required this.leagueId,
    required this.teamId,
    required this.status,
    required this.createdAt,
  });

  final String leagueId;
  final String teamId;
  final String status;
  final DateTime createdAt;

  factory LeagueTeamModel.fromJson(Map<String, dynamic> json) {
    final createdRaw = json['created_at'];
    final createdAt = createdRaw is String
        ? DateTime.tryParse(createdRaw) ?? DateTime.now()
        : (createdRaw is DateTime ? createdRaw : DateTime.now());

    return LeagueTeamModel(
      leagueId: json['league_id']?.toString() ?? '',
      teamId: json['team_id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'active',
      createdAt: createdAt,
    );
  }
}
