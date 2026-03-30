class UserProfile {
  final String id;
  final String email;
  final String? username;
  final String? playerName;
  final String? position;
  final String? imageUrl;
  final String? country;
  final String? socialInstagram;
  final String? socialTiktok;
  final String? socialX;

  const UserProfile({
    required this.id,
    required this.email,
    this.username,
    this.playerName,
    this.position,
    this.imageUrl,
    this.country,
    this.socialInstagram,
    this.socialTiktok,
    this.socialX,
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
      socialInstagram: json['social_instagram']?.toString(),
      socialTiktok: json['social_tiktok']?.toString(),
      socialX: json['social_x']?.toString(),
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
      'social_instagram': socialInstagram,
      'social_tiktok': socialTiktok,
      'social_x': socialX,
    };
  }
}

