class ScoutProfileViewer {
  const ScoutProfileViewer({
    required this.id,
    required this.displayName,
    this.username,
    this.imageUrl,
    this.staffRoleOther,
    required this.lastViewedAt,
  });

  final String id;
  final String displayName;
  final String? username;
  final String? imageUrl;
  final String? staffRoleOther;
  final DateTime lastViewedAt;

  String get handle {
    final name = username?.trim();
    if (name == null || name.isEmpty) return '';
    return '@$name';
  }
}
