class LeagueApplicationModel {
  const LeagueApplicationModel({
    required this.id,
    required this.leagueId,
    required this.teamId,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    this.reviewedBy,
    this.reviewedAt,
  });

  final String id;
  final String leagueId;
  final String teamId;
  final String status;
  final String createdBy;
  final DateTime createdAt;
  final String? reviewedBy;
  final DateTime? reviewedAt;

  factory LeagueApplicationModel.fromJson(Map<String, dynamic> json) {
    final createdRaw = json['created_at'];
    final createdAt = createdRaw is String
        ? DateTime.tryParse(createdRaw) ?? DateTime.now()
        : (createdRaw is DateTime ? createdRaw : DateTime.now());
    final reviewedRaw = json['reviewed_at'];
    final reviewedAt = reviewedRaw is String
        ? DateTime.tryParse(reviewedRaw)
        : (reviewedRaw is DateTime ? reviewedRaw : null);

    return LeagueApplicationModel(
      id: json['id']?.toString() ?? '',
      leagueId: json['league_id']?.toString() ?? '',
      teamId: json['team_id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      createdBy: json['requested_by']?.toString() ??
          json['created_by']?.toString() ??
          '',
      createdAt: createdAt,
      reviewedBy: json['reviewed_by']?.toString(),
      reviewedAt: reviewedAt,
    );
  }
}
