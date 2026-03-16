/// Options for auto-generating fixtures for a season.
class FixtureGenerationOptions {
  const FixtureGenerationOptions({
    required this.seasonId,
    required this.leagueId,
    required this.fixtureFormat,
    required this.homeAwayMode,
    required this.firstGameweekDate,
    required this.gameweekIntervalDays,
    required this.schedulingMode,
    this.sameDayMatches = false,
    this.gameweekMatchWeekday,
    this.startTime,
    this.endTime,
    this.matchDateSpanDays = 1,
    this.defaultVenue,
    this.defaultVenueImageUrl,
    this.defaultStatus = 'upcoming',
    this.allowRegeneration = false,
    this.sameTimeForAll = true,
    this.compressedLeagueDays,
    this.fullRoundPerGameweek = false,
    this.fullRoundGameweeksPerLeg,
  });

  /// Season to generate fixtures for.
  final String seasonId;

  /// League the season belongs to.
  final String leagueId;

  /// single-leg or double-leg.
  final FixtureFormat fixtureFormat;

  /// home_away or neutral.
  final HomeAwayMode homeAwayMode;

  /// Start date of first gameweek.
  final DateTime firstGameweekDate;

  /// Days between gameweeks (e.g. 4, 7, 14).
  final int gameweekIntervalDays;

  /// Scheduling style.
  final SchedulingMode schedulingMode;

  /// If true, all matches in a gameweek happen on the same day.
  final bool sameDayMatches;

  /// Weekday for same-day matches (1=Mon, 7=Sun). Null = use firstGameweekDate.
  final int? gameweekMatchWeekday;

  /// Start time for same-day distribution (e.g. 09:00).
  final String? startTime;

  /// End time for same-day distribution (e.g. 18:00).
  final String? endTime;

  /// If not same-day: days span for matches in a gameweek (1, 2, or 3).
  final int matchDateSpanDays;

  /// Default venue for matches.
  final String? defaultVenue;

  /// Default venue image URL.
  final String? defaultVenueImageUrl;

  /// Default match status (usually 'upcoming').
  final String defaultStatus;

  /// If true, allow regenerating over existing fixtures (with confirmation).
  final bool allowRegeneration;

  /// If true, all matches in a gameweek use same kick-off; else distribute.
  final bool sameTimeForAll;

  /// For compressed mode: total days for the whole league (1, 2, or 3).
  final int? compressedLeagueDays;

  /// If true, all round-robin pairs are played in one or more gameweeks (each
  /// team plays every other team once per leg). For double-leg, leg 2 repeats.
  final bool fullRoundPerGameweek;

  /// When [fullRoundPerGameweek] is true: number of gameweeks per leg. Each
  /// gameweek contains a full round (every team plays every other once).
  /// Defaults to 1 when null.
  final int? fullRoundGameweeksPerLeg;
}

enum FixtureFormat { singleLeg, doubleLeg }

enum HomeAwayMode { homeAway, neutral }

enum SchedulingMode {
  /// One gameweek per calendar week.
  weekly,

  /// One gameweek every two weeks.
  biweekly,

  /// Two gameweeks per week (e.g. Mon-Tue, Fri-Sun).
  twicePerWeek,

  /// Compressed: league in 1-3 days.
  compressed,
}
