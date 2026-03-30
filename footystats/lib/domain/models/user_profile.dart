class UserProfile {
  final String id;
  final String email;
  final String? username;
  final String? playerName;
  final String? position;
  final String? imageUrl;
  final String? country;

  const UserProfile({
    required this.id,
    required this.email,
    this.username,
    this.playerName,
    this.position,
    this.imageUrl,
    this.country,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      username: json['username'] as String?,
      playerName: json['player_name'] as String?,
      position: json['position'] as String?,
      imageUrl: json['image_url'] as String?,
      country: json['country'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'player_name': playerName,
      'position': position,
      'image_url': imageUrl,
      'country': country,
    };
  }
}

