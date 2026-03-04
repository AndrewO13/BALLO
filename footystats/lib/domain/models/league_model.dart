class LeagueModel {
  const LeagueModel({
    required this.id,
    required this.leagueName,
    this.logoId,
    required this.createdBy,
    required this.createdAt,
  });

  final String id;
  final String leagueName;
  final String? logoId;
  final String createdBy;
  final DateTime createdAt;

  factory LeagueModel.fromJson(Map<String, dynamic> json) {
    final createdRaw = json['created_at'];
    final createdAt = createdRaw is String
        ? DateTime.tryParse(createdRaw) ?? DateTime.now()
        : (createdRaw is DateTime ? createdRaw : DateTime.now());

    return LeagueModel(
      id: json['id']?.toString() ?? '',
      leagueName: json['league_name']?.toString() ?? '',
      logoId: json['logo_id']?.toString(),
      createdBy: json['created_by']?.toString() ?? '',
      createdAt: createdAt,
    );
  }
}
