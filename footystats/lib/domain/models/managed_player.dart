class ManagedPlayer {
  const ManagedPlayer({
    required this.id,
    required this.playerName,
    required this.username,
    this.position,
    this.imageUrl,
    this.loginEnabledAt,
    this.createdAt,
  });

  final String id;
  final String playerName;
  final String username;
  final String? position;
  final String? imageUrl;
  final DateTime? loginEnabledAt;
  final DateTime? createdAt;

  bool get hasLogin => loginEnabledAt != null;

  bool get canCreatorEdit => !hasLogin;

  factory ManagedPlayer.fromProfile({
    required String id,
    required String playerName,
    required String username,
    String? position,
    String? imageUrl,
    DateTime? loginEnabledAt,
  }) {
    return ManagedPlayer(
      id: id,
      playerName: playerName,
      username: username,
      position: position,
      imageUrl: imageUrl,
      loginEnabledAt: loginEnabledAt,
    );
  }

  factory ManagedPlayer.fromJson(Map<String, dynamic> json) {
    return ManagedPlayer(
      id: json['id']?.toString() ?? '',
      playerName: (json['player_name'] as String?)?.trim() ?? 'Player',
      username: (json['username'] as String?)?.trim() ?? '',
      position: (json['position'] as String?)?.trim().isNotEmpty == true
          ? (json['position'] as String).trim()
          : null,
      imageUrl: (json['image_url'] as String?)?.trim().isNotEmpty == true
          ? (json['image_url'] as String).trim()
          : null,
      loginEnabledAt: json['login_enabled_at'] != null
          ? DateTime.tryParse(json['login_enabled_at'].toString())
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }
}

class ManagedPlayerDraftInput {
  const ManagedPlayerDraftInput({
    required this.playerName,
    required this.username,
    required this.position,
    required this.imageUrl,
  });

  final String playerName;
  final String username;
  final String position;
  final String imageUrl;

  Map<String, dynamic> toJson() => {
        'player_name': playerName,
        'username': username,
        'position': position,
        'image_url': imageUrl,
      };
}
