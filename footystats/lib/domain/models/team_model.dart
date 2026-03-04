import '../../core/constants/app_assets.dart';

/// Team model from Supabase teams table (id, logo_id, short_form, team_name).
class TeamModel {
  const TeamModel({
    required this.id,
    this.logoId,
    required this.shortForm,
    this.teamName,
  });

  final String id;
  final String? logoId;
  final String shortForm;
  final String? teamName;

  factory TeamModel.fromJson(Map<String, dynamic> json) {
    return TeamModel(
      id: json['id']?.toString() ?? '',
      logoId: json['logo_id']?.toString(),
      shortForm: json['short_form']?.toString() ?? '',
      teamName: json['team_name']?.toString(),
    );
  }

  /// Display name: full team name if available, otherwise short form.
  String get displayName => (teamName?.trim().isNotEmpty == true)
      ? teamName!
      : shortForm;

  /// Uses [logoId] from the teams table for the logo. Returns a URL for network
  /// images, or an asset path (e.g. lib/assets/images/team logos/Lefters.png).
  /// If [logoId] is a filename or key, it is resolved under the team logos path.
  String get logoPath {
    final lid = logoId?.trim();
    if (lid == null || lid.isEmpty) return _defaultLogo;
    // URL: use as-is for Image.network
    if (lid.startsWith('http://') || lid.startsWith('https://')) return lid;
    // Already a full asset path
    if (lid.startsWith('lib/assets/') || lid.startsWith('assets/')) return lid;
    // Filename or key: resolve under team logos (e.g. "Lefters.png" or "Lefters")
    final name = lid.contains('.') ? lid : '$lid.png';
    return '${AppAssets.teamLogosPath}$name';
  }

  static String get _defaultLogo => AppAssets.leftersLogo;
}
