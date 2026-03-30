class LeaderboardEntry {
  const LeaderboardEntry({
    required this.playerId,
    required this.playerName,
    this.imageUrl,
    required this.totalPoints,
    required this.gwPoints,
    required this.rank,
    required this.previousRank,
  });

  final String playerId;
  final String playerName;
  final String? imageUrl;
  final double totalPoints;
  final double gwPoints;
  final int rank;
  /// Rank before counting the app-wide latest gameweek points (`total - gw`).
  final int previousRank;

  /// Positive if the player moved up the table (better rank).
  int get rankDelta => previousRank - rank;

  factory LeaderboardEntry.fromRpcRow(Map<String, dynamic> json) {
    double d(dynamic v) {
      if (v == null) return 0;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString()) ?? 0;
    }

    /// Handles int, double (from JSON/JS), strings, and null.
    int parseRank(dynamic v) {
      if (v == null) return 0;
      if (v is int) return v;
      if (v is num) return v.round();
      final s = v.toString().trim();
      if (s.isEmpty) return 0;
      return int.tryParse(s) ?? double.tryParse(s)?.round() ?? 0;
    }

    final rankVal = parseRank(json['board_rank']);
    final prevRaw = json['previous_rank'];
    final previousRank =
        prevRaw != null ? parseRank(prevRaw) : rankVal;

    return LeaderboardEntry(
      playerId: json['player_id']?.toString() ?? '',
      playerName: json['player_name']?.toString() ?? 'Player',
      imageUrl: json['image_url']?.toString(),
      totalPoints: d(json['total_points']),
      gwPoints: d(json['gw_points']),
      rank: rankVal,
      previousRank: previousRank,
    );
  }
}
