/// Pre-match win / draw / away probabilities for team A, draw, and team B.
///
/// Values are in the range 0–1 and sum to ~1. Displayed as percentages for
/// entertainment only — not betting odds or financial advice.
class MatchOdds {
  const MatchOdds({
    required this.homeWin,
    required this.draw,
    required this.awayWin,
  });

  /// Probability that team A (home / left) wins.
  final double homeWin;

  /// Probability of a draw.
  final double draw;

  /// Probability that team B (away / right) wins.
  final double awayWin;

  /// Percentage labels for UI chips, e.g. `42%`, `26%`, `32%`.
  List<String> get formatted => [
        _formatPercent(homeWin),
        _formatPercent(draw),
        _formatPercent(awayWin),
      ];

  static String _formatPercent(double probability) {
    final pct = (probability.clamp(0.0, 1.0) * 100).round();
    return '$pct%';
  }

  /// Neutral placeholder when insufficient data exists yet.
  factory MatchOdds.neutral() => const MatchOdds(
        homeWin: 0.34,
        draw: 0.32,
        awayWin: 0.34,
      );
}
