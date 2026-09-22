import '../../core/widgets/media_placeholders.dart';

/// Team model from Supabase teams table (id, logo_id, short_form, team_name).
class TeamModel {
  const TeamModel({
    required this.id,
    this.logoId,
    this.bannerId,
    required this.shortForm,
    this.teamName,
    this.favouriteCount = 0,
  });

  final String id;
  final String? logoId;
  final String? bannerId;
  final String shortForm;
  final String? teamName;
  final int favouriteCount;

  factory TeamModel.fromJson(Map<String, dynamic> json) {
    return TeamModel(
      id: json['id']?.toString() ?? '',
      logoId: json['logo_id']?.toString(),
      bannerId: json['banner_id']?.toString(),
      shortForm: json['short_form']?.toString() ?? '',
      teamName: json['team_name']?.toString(),
      favouriteCount: _parseInt(json['favourite_count']),
    );
  }

  /// Display name: full team name if available, otherwise short form.
  String get displayName => (teamName?.trim().isNotEmpty == true)
      ? teamName!
      : shortForm;

  /// Uses [logoId] from the teams table for the logo. Returns a URL for network
  /// images, or an asset path (e.g. lib/assets/images/team logos/Lefters.png).
  /// If [logoId] is a filename or key, it is resolved under the team logos path.
  String get logoPath => resolveTeamLogoPath(logoId) ?? '';

  String get bannerPath {
    final bid = bannerId?.trim();
    if (bid == null || bid.isEmpty) return _defaultBanner;
    if (bid.startsWith('http://') || bid.startsWith('https://')) return bid;
    if (bid.startsWith('lib/assets/') || bid.startsWith('assets/')) return bid;
    return bid;
  }

  static String get _defaultBanner => '';
}

int _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
