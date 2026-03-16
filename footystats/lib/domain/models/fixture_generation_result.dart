/// Result of fixture generation.
class FixtureGenerationResult {
  const FixtureGenerationResult({
    required this.success,
    this.teamsCount = 0,
    this.gameweeksCreated = 0,
    this.matchesCreated = 0,
    this.usedBye = false,
    this.errorMessage,
  });

  final bool success;
  final int teamsCount;
  final int gameweeksCreated;
  final int matchesCreated;
  final bool usedBye;
  final String? errorMessage;

  factory FixtureGenerationResult.failure(String message) {
    return FixtureGenerationResult(
      success: false,
      errorMessage: message,
    );
  }

  factory FixtureGenerationResult.success({
    required int teamsCount,
    required int gameweeksCreated,
    required int matchesCreated,
    bool usedBye = false,
  }) {
    return FixtureGenerationResult(
      success: true,
      teamsCount: teamsCount,
      gameweeksCreated: gameweeksCreated,
      matchesCreated: matchesCreated,
      usedBye: usedBye,
    );
  }
}
