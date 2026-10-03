/// A signed-in account kept on this device so the user can switch without
/// logging out first.
class DeviceAccount {
  const DeviceAccount({
    required this.userId,
    required this.refreshToken,
    this.accessToken,
    this.username,
    this.playerName,
    this.imageUrl,
    this.lastUsedMs = 0,
  });

  final String userId;
  final String refreshToken;
  final String? accessToken;
  final String? username;
  final String? playerName;
  final String? imageUrl;
  final int lastUsedMs;

  String get displayHandle {
    final handle = username?.trim();
    if (handle != null && handle.isNotEmpty) return '@$handle';
    final name = playerName?.trim();
    if (name != null && name.isNotEmpty) return name;
    return 'Account';
  }

  String get initial {
    final source = (playerName?.trim().isNotEmpty == true)
        ? playerName!.trim()
        : (username?.trim() ?? '');
    if (source.isEmpty) return 'A';
    return source[0].toUpperCase();
  }

  DeviceAccount copyWith({
    String? refreshToken,
    String? accessToken,
    String? username,
    String? playerName,
    String? imageUrl,
    int? lastUsedMs,
  }) {
    return DeviceAccount(
      userId: userId,
      refreshToken: refreshToken ?? this.refreshToken,
      accessToken: accessToken ?? this.accessToken,
      username: username ?? this.username,
      playerName: playerName ?? this.playerName,
      imageUrl: imageUrl ?? this.imageUrl,
      lastUsedMs: lastUsedMs ?? this.lastUsedMs,
    );
  }

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'refreshToken': refreshToken,
    'accessToken': accessToken,
    'username': username,
    'playerName': playerName,
    'imageUrl': imageUrl,
    'lastUsedMs': lastUsedMs,
  };

  factory DeviceAccount.fromJson(Map<String, dynamic> json) {
    return DeviceAccount(
      userId: json['userId']?.toString() ?? '',
      refreshToken: json['refreshToken']?.toString() ?? '',
      accessToken: json['accessToken']?.toString(),
      username: json['username']?.toString(),
      playerName: json['playerName']?.toString(),
      imageUrl: json['imageUrl']?.toString(),
      lastUsedMs: (json['lastUsedMs'] as num?)?.toInt() ?? 0,
    );
  }
}
