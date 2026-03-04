class SeasonModel {
  const SeasonModel({
    required this.id,
    required this.leagueId,
    required this.seasonName,
    required this.startDate,
    required this.endDate,
    required this.status,
  });

  final String id;
  final String leagueId;
  final String seasonName;
  final DateTime startDate;
  final DateTime endDate;
  final String status;

  factory SeasonModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value) {
      if (value is String) {
        return DateTime.tryParse(value) ?? DateTime.now();
      }
      if (value is DateTime) return value;
      return DateTime.now();
    }

    return SeasonModel(
      id: json['id']?.toString() ?? '',
      leagueId: json['league_id']?.toString() ?? '',
      seasonName: json['season_name']?.toString() ?? '',
      startDate: parseDate(json['start_date']),
      endDate: parseDate(json['end_date']),
      status: json['status']?.toString() ?? 'upcoming',
    );
  }
}
