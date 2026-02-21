class UserProfile {
  final String id;
  final String email;
  final String? username;
  final String? playerName;

  const UserProfile({
    required this.id,
    required this.email,
    this.username,
    this.playerName,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      username: json['username'] as String?,
      playerName: json['player_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'player_name': playerName,
    };
  }
}

