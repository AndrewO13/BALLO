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
  final DateTime? deletedAt;
  final String? accountType;
  final String? staffRole;
  final String? staffRoleOther;
  final String? about;

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
    this.deletedAt,
    this.accountType,
    this.staffRole,
    this.staffRoleOther,
    this.about,
  });

  bool get isDeleted => deletedAt != null;

  bool get isTechnicalStaff => accountType == 'technical_staff';

  bool get isScout =>
      isTechnicalStaff && staffRole == 'scout';

  String get staffRoleLabel {
    if (staffRole == 'other') {
      final custom = staffRoleOther?.trim();
      if (custom != null && custom.isNotEmpty) return custom;
      return 'Technical staff';
    }
    return switch (staffRole) {
      'coach' => 'Coach',
      'scout' => 'Scout',
      'agent' => 'Agent',
      _ => 'Technical staff',
    };
  }

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
      deletedAt: json['deleted_at'] != null
          ? DateTime.tryParse(json['deleted_at'].toString())
          : null,
      accountType: json['account_type'] as String?,
      staffRole: json['staff_role'] as String?,
      staffRoleOther: json['staff_role_other'] as String?,
      about: json['about'] as String?,
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
      'deleted_at': deletedAt?.toIso8601String(),
      'account_type': accountType,
      'staff_role': staffRole,
      'staff_role_other': staffRoleOther,
      'about': about,
    };
  }
}
