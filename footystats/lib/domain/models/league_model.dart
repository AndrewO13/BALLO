import 'league_format.dart';

class LeagueModel {
  const LeagueModel({
    required this.id,
    required this.leagueName,
    this.logoId,
    required this.createdBy,
    required this.createdAt,
    this.defaultVenue,
    this.defaultVenueImageUrl,
    this.country,
    this.playersPerSide = 11,
    this.defaultFormation = '4-4-2',
  });

  final String id;
  final String leagueName;
  final String? logoId;
  final String createdBy;
  final DateTime createdAt;
  final String? defaultVenue;
  final String? defaultVenueImageUrl;
  final String? country;
  final int playersPerSide;
  final String defaultFormation;

  LeagueFormat get format => LeagueFormat.fromStored(
    playersPerSide: playersPerSide,
    formation: defaultFormation,
  );

  factory LeagueModel.fromJson(Map<String, dynamic> json) {
    final createdRaw = json['created_at'];
    final createdAt = createdRaw is String
        ? DateTime.tryParse(createdRaw) ?? DateTime.now()
        : (createdRaw is DateTime ? createdRaw : DateTime.now());
    final format = LeagueFormat.fromStored(
      playersPerSide: json['players_per_side'],
      formation: json['default_formation'],
    );

    return LeagueModel(
      id: json['id']?.toString() ?? '',
      leagueName: json['league_name']?.toString() ?? '',
      logoId: json['logo_id']?.toString(),
      createdBy: json['created_by']?.toString() ?? '',
      createdAt: createdAt,
      defaultVenue: json['default_venue']?.toString(),
      defaultVenueImageUrl: json['default_venue_image_url']?.toString(),
      country: json['country']?.toString(),
      playersPerSide: format.playersPerSide,
      defaultFormation: format.formation,
    );
  }
}
