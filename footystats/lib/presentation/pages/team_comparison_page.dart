import 'package:flutter/material.dart';
import '../../core/widgets/media_placeholders.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/repositories/teams_repository.dart';
import '../../domain/models/team_model.dart';

class TeamComparisonPage extends StatefulWidget {
  const TeamComparisonPage({super.key, required this.baseTeamId});

  final String baseTeamId;

  @override
  State<TeamComparisonPage> createState() => _TeamComparisonPageState();
}

class _TeamComparisonPageState extends State<TeamComparisonPage> {
  static const String _allLeaguesId = '__all_leagues__';
  static const String _allSeasonsId = '__all_seasons__';

  final SupabaseClient _client = Supabase.instance.client;
  final TeamsRepository _teamsRepository = TeamsRepository();

  _TeamPaneData? _leftPane;
  _TeamPaneData? _rightPane;
  _HeadToHeadStats _headToHead = const _HeadToHeadStats();
  List<TeamModel> _allTeams = const [];
  bool _isLoading = true;
  bool _isLoadingRight = false;
  bool _isApplyingLeftFilters = false;
  bool _isApplyingRightFilters = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() => _isLoading = true);
    try {
      final left = await _loadPaneForTeam(widget.baseTeamId);
      if (!mounted) return;
      setState(() {
        _leftPane = left;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      return;
    }
    try {
      final allRows = await _client
          .from('teams')
          .select('id, team_name, short_form, logo_id, banner_id, created_by')
          .order('team_name', ascending: true);
      final allTeams = (allRows as List)
          .whereType<Map>()
          .map((row) => TeamModel.fromJson(Map<String, dynamic>.from(row)))
          .where((team) => team.id.isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() => _allTeams = allTeams);
    } catch (_) {}
  }

  Future<_TeamPaneData?> _loadPaneForTeam(
    String teamId, {
    String? leagueId,
    String? seasonId,
  }) async {
    final team = await _teamsRepository.getTeamById(teamId);
    if (team == null) return null;

    final context = await _loadTeamFilterContext(teamId);
    final selectedLeagueId = leagueId ?? _allLeaguesId;
    final seasonOptions = _seasonsForLeague(context, selectedLeagueId);
    final validSeasonIds = seasonOptions.map((s) => s.id).toSet();
    final selectedSeasonId =
        (seasonId != null && validSeasonIds.contains(seasonId))
        ? seasonId
        : _allSeasonsId;

    final summary = await _loadSummary(
      teamId,
      leagueId: selectedLeagueId,
      seasonId: selectedSeasonId,
    );
    final recentForm = await _loadRecentForm(
      teamId,
      leagueId: selectedLeagueId,
      seasonId: selectedSeasonId,
    );
    return _TeamPaneData(
      team: team,
      leagueOptions: context.leagueOptions,
      selectedLeagueId: selectedLeagueId,
      seasonOptions: seasonOptions,
      selectedSeasonId: selectedSeasonId,
      summary: summary,
      recentForm: recentForm,
    );
  }

  Future<_TeamFilterContext> _loadTeamFilterContext(String teamId) async {
    final rows = await _client
        .from('matches')
        .select('league_id, season_id')
        .eq('status', 'fullTime')
        .or('teamA.eq.$teamId,teamB.eq.$teamId');

    final leagueIds = <String>{};
    final seasonIds = <String>{};
    final seasonLeagueMap = <String, String>{};
    for (final row in (rows as List).whereType<Map>()) {
      final map = Map<String, dynamic>.from(row);
      final leagueId = map['league_id']?.toString() ?? '';
      final seasonId = map['season_id']?.toString() ?? '';
      if (leagueId.isNotEmpty) leagueIds.add(leagueId);
      if (seasonId.isNotEmpty) seasonIds.add(seasonId);
      if (leagueId.isNotEmpty && seasonId.isNotEmpty) {
        seasonLeagueMap[seasonId] = leagueId;
      }
    }

    final leaguesById = <String, String>{};
    if (leagueIds.isNotEmpty) {
      final leagueRows = await _client
          .from('leagues')
          .select('id, league_name')
          .inFilter('id', leagueIds.toList());
      for (final row in (leagueRows as List).whereType<Map>()) {
        final map = Map<String, dynamic>.from(row);
        final id = map['id']?.toString() ?? '';
        final name = map['league_name']?.toString() ?? '';
        if (id.isNotEmpty) leaguesById[id] = name.isNotEmpty ? name : 'League';
      }
    }

    final seasonsById = <String, String>{};
    if (seasonIds.isNotEmpty) {
      final seasonRows = await _client
          .from('seasons')
          .select('id, season_name, end_date')
          .inFilter('id', seasonIds.toList());
      for (final row in (seasonRows as List).whereType<Map>()) {
        final map = Map<String, dynamic>.from(row);
        final id = map['id']?.toString() ?? '';
        if (id.isEmpty) continue;
        final seasonName = map['season_name']?.toString() ?? '';
        final year = DateTime.tryParse(map['end_date']?.toString() ?? '')?.year;
        seasonsById[id] =
            seasonName.isNotEmpty ? seasonName : (year?.toString() ?? 'Season');
      }
    }

    final leagueOptions = <_Option>[
      const _Option(id: _allLeaguesId, label: 'All leagues'),
      ...leaguesById.entries.map((e) => _Option(id: e.key, label: e.value)),
    ]..sort((a, b) {
      if (a.id == _allLeaguesId) return -1;
      if (b.id == _allLeaguesId) return 1;
      return a.label.compareTo(b.label);
    });

    final seasonOptions = <_SeasonLeagueOption>[
      const _SeasonLeagueOption(
        id: _allSeasonsId,
        leagueId: _allLeaguesId,
        label: 'All seasons',
      ),
      ...seasonsById.entries.map(
        (e) => _SeasonLeagueOption(
          id: e.key,
          leagueId: seasonLeagueMap[e.key] ?? '',
          label: e.value,
        ),
      ),
    ];

    return _TeamFilterContext(
      leagueOptions: leagueOptions,
      seasonOptions: seasonOptions,
    );
  }

  List<_Option> _seasonsForLeague(_TeamFilterContext context, String leagueId) {
    final options = context.seasonOptions.where((season) {
      if (season.id == _allSeasonsId) return true;
      if (leagueId == _allLeaguesId) return true;
      return season.leagueId == leagueId;
    }).map((season) => _Option(id: season.id, label: season.label)).toList();
    return options;
  }

  Future<Map<String, dynamic>> _loadSummary(
    String teamId, {
    required String leagueId,
    required String seasonId,
  }) async {
    try {
      final result = await _client.rpc(
        'get_team_summary_stats_filtered',
        params: {
          'p_team_id': teamId,
          'p_league_id': leagueId == _allLeaguesId ? null : leagueId,
          'p_season_id': seasonId == _allSeasonsId ? null : seasonId,
        },
      );
      if (result is List && result.isNotEmpty && result.first is Map) {
        return Map<String, dynamic>.from(result.first as Map);
      }
      if (result is Map) return Map<String, dynamic>.from(result);
    } catch (_) {
      // Fall through to client-side filtered aggregation.
    }
    return _buildFilteredSummaryClientSide(
      teamId: teamId,
      leagueId: leagueId,
      seasonId: seasonId,
    );
  }

  Future<Map<String, dynamic>> _buildFilteredSummaryClientSide({
    required String teamId,
    required String leagueId,
    required String seasonId,
  }) async {
    var matchesQuery = _client
        .from('matches')
        .select(
          'id, teamA, teamB, teamA_score, teamB_score, league_id, season_id',
        )
        .eq('status', 'fullTime')
        .or('teamA.eq.$teamId,teamB.eq.$teamId');
    if (leagueId != _allLeaguesId) {
      matchesQuery = matchesQuery.eq('league_id', leagueId);
    }
    if (seasonId != _allSeasonsId) {
      matchesQuery = matchesQuery.eq('season_id', seasonId);
    }

    final matchesRes = await matchesQuery;
    final matches = List<Map<String, dynamic>>.from(matchesRes as List);

    var matchesPlayed = 0;
    var goalsScored = 0;
    var goalsConceded = 0;
    var cleanSheets = 0;
    final matchIds = <String>[];

    for (final row in matches) {
      final id = row['id']?.toString() ?? '';
      if (id.isNotEmpty) matchIds.add(id);
      final teamA = row['teamA']?.toString() ?? '';
      final teamB = row['teamB']?.toString() ?? '';
      final scoreA = (row['teamA_score'] as num?)?.toInt() ?? 0;
      final scoreB = (row['teamB_score'] as num?)?.toInt() ?? 0;
      if (teamA == teamId) {
        matchesPlayed++;
        goalsScored += scoreA;
        goalsConceded += scoreB;
        if (scoreB == 0) cleanSheets++;
      } else if (teamB == teamId) {
        matchesPlayed++;
        goalsScored += scoreB;
        goalsConceded += scoreA;
        if (scoreA == 0) cleanSheets++;
      }
    }

    var assists = 0;
    var tackles = 0;
    var saves = 0;
    var yellowCards = 0;
    var redCards = 0;
    var shotsOnTarget = goalsScored;

    if (matchIds.isNotEmpty) {
      try {
        final mpsRows = await _client
            .from('match_player_stats')
            .select('assists')
            .eq('team_id', teamId)
            .inFilter('match_id', matchIds);
        for (final row in (mpsRows as List).whereType<Map>()) {
          final map = Map<String, dynamic>.from(row);
          assists += (map['assists'] as num?)?.toInt() ?? 0;
        }
      } catch (_) {}

      try {
        final eventRows = await _client
            .from('match_events')
            .select('event_type, team_id, is_deleted')
            .inFilter('match_id', matchIds);
        for (final row in (eventRows as List).whereType<Map>()) {
          final map = Map<String, dynamic>.from(row);
          if ((map['is_deleted'] as bool?) ?? false) continue;
          final type = map['event_type']?.toString() ?? '';
          final evtTeamId = map['team_id']?.toString() ?? '';
          final isOurTeam = evtTeamId == teamId;
          if (type == 'tackle' && isOurTeam) tackles++;
          if (type == 'save' && isOurTeam) saves++;
          if (type == 'yellow_card' && isOurTeam) yellowCards++;
          if (type == 'red_card' && isOurTeam) redCards++;
          if (type == 'save' && !isOurTeam) shotsOnTarget++;
        }
      } catch (_) {}
    }

    return {
      'matches_played': matchesPlayed,
      'goals_scored': goalsScored,
      'goals_conceded': goalsConceded,
      'goal_difference': goalsScored - goalsConceded,
      'assists': assists,
      'clean_sheets': cleanSheets,
      'shots_on_target': shotsOnTarget,
      'tackles': tackles,
      'saves': saves,
      'yellow_cards': yellowCards,
      'red_cards': redCards,
    };
  }

  Future<List<String>> _loadRecentForm(
    String teamId, {
    required String leagueId,
    required String seasonId,
  }) async {
    var query = _client
        .from('matches')
        .select('teamA, teamB, teamA_score, teamB_score, match_date')
        .eq('status', 'fullTime')
        .or('teamA.eq.$teamId,teamB.eq.$teamId');
    if (leagueId != _allLeaguesId) query = query.eq('league_id', leagueId);
    if (seasonId != _allSeasonsId) query = query.eq('season_id', seasonId);
    final rows = await query.order('match_date', ascending: false).limit(5);

    final out = <String>[];
    for (final row in (rows as List).whereType<Map>()) {
      final map = Map<String, dynamic>.from(row);
      final teamA = map['teamA']?.toString() ?? '';
      final teamB = map['teamB']?.toString() ?? '';
      final scoreA = (map['teamA_score'] as num?)?.toInt() ?? 0;
      final scoreB = (map['teamB_score'] as num?)?.toInt() ?? 0;
      if (teamA == teamId) {
        out.add(scoreA > scoreB ? 'W' : scoreA < scoreB ? 'L' : 'D');
      } else if (teamB == teamId) {
        out.add(scoreB > scoreA ? 'W' : scoreB < scoreA ? 'L' : 'D');
      }
    }
    return out;
  }

  Future<void> _loadHeadToHead(String leftId, String rightId) async {
    try {
      final rows = await _client
          .from('matches')
          .select('teamA, teamB, teamA_score, teamB_score')
          .eq('status', 'fullTime')
          .or('teamA.eq.$leftId,teamB.eq.$leftId,teamA.eq.$rightId,teamB.eq.$rightId');
      var leftWins = 0;
      var rightWins = 0;
      var draws = 0;
      for (final row in (rows as List).whereType<Map>()) {
        final map = Map<String, dynamic>.from(row);
        final a = map['teamA']?.toString() ?? '';
        final b = map['teamB']?.toString() ?? '';
        final isH2h = (a == leftId && b == rightId) || (a == rightId && b == leftId);
        if (!isH2h) continue;
        final scoreA = (map['teamA_score'] as num?)?.toInt() ?? 0;
        final scoreB = (map['teamB_score'] as num?)?.toInt() ?? 0;
        if (scoreA == scoreB) {
          draws++;
        } else {
          final leftWon = (a == leftId && scoreA > scoreB) || (b == leftId && scoreB > scoreA);
          if (leftWon) {
            leftWins++;
          } else {
            rightWins++;
          }
        }
      }
      if (!mounted) return;
      setState(() {
        _headToHead = _HeadToHeadStats(
          leftWins: leftWins,
          draws: draws,
          rightWins: rightWins,
        );
      });
    } catch (_) {}
  }

  Future<void> _pickOpponent() async {
    final leftId = _leftPane?.team.id;
    if (leftId == null || leftId.isEmpty) return;
    final selected = await showModalBottomSheet<TeamModel>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _TeamPickerSheet(
        teams: _allTeams.where((team) => team.id != leftId).toList(),
      ),
    );
    if (selected == null) return;
    setState(() => _isLoadingRight = true);
    try {
      final pane = await _loadPaneForTeam(selected.id);
      await _loadHeadToHead(leftId, selected.id);
      if (!mounted) return;
      setState(() {
        _rightPane = pane;
        _isLoadingRight = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingRight = false);
    }
  }

  Future<void> _onLeagueChanged({
    required bool isLeft,
    required String? leagueId,
  }) async {
    final pane = isLeft ? _leftPane : _rightPane;
    if (pane == null) return;
    setState(() {
      if (isLeft) {
        _isApplyingLeftFilters = true;
      } else {
        _isApplyingRightFilters = true;
      }
    });
    final updated = await _loadPaneForTeam(
      pane.team.id,
      leagueId: leagueId ?? _allLeaguesId,
      seasonId: _allSeasonsId,
    );
    if (!mounted) return;
    setState(() {
      if (updated != null) {
        if (isLeft) {
          _leftPane = updated;
        } else {
          _rightPane = updated;
        }
      }
      if (isLeft) {
        _isApplyingLeftFilters = false;
      } else {
        _isApplyingRightFilters = false;
      }
    });
  }

  Future<void> _onSeasonChanged({
    required bool isLeft,
    required String? seasonId,
  }) async {
    final pane = isLeft ? _leftPane : _rightPane;
    if (pane == null) return;
    setState(() {
      if (isLeft) {
        _isApplyingLeftFilters = true;
      } else {
        _isApplyingRightFilters = true;
      }
    });
    final updated = await _loadPaneForTeam(
      pane.team.id,
      leagueId: pane.selectedLeagueId,
      seasonId: seasonId ?? _allSeasonsId,
    );
    if (!mounted) return;
    setState(() {
      if (updated != null) {
        if (isLeft) {
          _leftPane = updated;
        } else {
          _rightPane = updated;
        }
      }
      if (isLeft) {
        _isApplyingLeftFilters = false;
      } else {
        _isApplyingRightFilters = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('Team vs team', style: textTheme.headlineMedium)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final left = _leftPane;
    if (left == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Team vs team', style: textTheme.headlineMedium)),
        body: const Center(child: Text('Could not load team')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Team vs team', style: textTheme.headlineMedium),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      _TeamCard(team: left.team, form: left.recentForm, onTap: null),
                      const SizedBox(height: 8),
                      _FilterControls(
                        pane: left,
                        onLeagueChanged: (value) => _onLeagueChanged(
                          isLeft: true,
                          leagueId: value,
                        ),
                        onSeasonChanged: (value) => _onSeasonChanged(
                          isLeft: true,
                          seasonId: value,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      _TeamCard(
                        team: _rightPane?.team,
                        form: _rightPane?.recentForm ?? const [],
                        onTap: _pickOpponent,
                        isLoading: _isLoadingRight,
                      ),
                      const SizedBox(height: 8),
                      _FilterControls(
                        pane: _rightPane,
                        onLeagueChanged: (value) => _onLeagueChanged(
                          isLeft: false,
                          leagueId: value,
                        ),
                        onSeasonChanged: (value) => _onSeasonChanged(
                          isLeft: false,
                          seasonId: value,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (_rightPane == null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Text(
                  'Pick another team to compare.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else ...[
              if (_isApplyingLeftFilters || _isApplyingRightFilters) ...[
                const _ComparisonLoadingCard(height: 170),
                const SizedBox(height: 12),
                const _ComparisonLoadingCard(height: 280),
              ] else ...[
                _HeadToHeadCard(
                  leftTeam: left.team,
                  rightTeam: _rightPane!.team,
                  stats: _headToHead,
                ),
                const SizedBox(height: 12),
                _TopStatsCard(
                  leftTeam: left.team,
                  rightTeam: _rightPane!.team,
                  leftSummary: left.summary,
                  rightSummary: _rightPane!.summary,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _TeamPickerSheet extends StatefulWidget {
  const _TeamPickerSheet({required this.teams});

  final List<TeamModel> teams;

  @override
  State<_TeamPickerSheet> createState() => _TeamPickerSheetState();
}

class _TeamPickerSheetState extends State<_TeamPickerSheet> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets.bottom;
    final filtered = widget.teams.where((team) {
      if (_query.trim().isEmpty) return true;
      final q = _query.trim().toLowerCase();
      return team.displayName.toLowerCase().contains(q) ||
          team.shortForm.toLowerCase().contains(q);
    }).toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, insets + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                labelText: 'Search team',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 360,
              child: ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final team = filtered[index];
                  return ListTile(
                    onTap: () => Navigator.of(context).pop(team),
                    leading: _TeamLogo(path: team.logoPath, size: 60),
                    title: Text(
                      team.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamCard extends StatelessWidget {
  const _TeamCard({
    required this.team,
    required this.form,
    required this.onTap,
    this.isLoading = false,
  });

  final TeamModel? team;
  final List<String> form;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final teamData = team;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(18),
          border: onTap != null
              ? Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.8))
              : null,
        ),
        child: isLoading
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            : teamData == null
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Text(
                    'Select team',
                    style: textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              )
            : Column(
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: Icon(
                      Icons.compare_arrows_rounded,
                      size: 18,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  _TeamLogo(path: teamData.logoPath, size: 60),
                  const SizedBox(height: 8),
                  Text(
                    teamData.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  _FormIndicator(form: form),
                ],
              ),
      ),
    );
  }
}

class _FilterControls extends StatelessWidget {
  const _FilterControls({
    required this.pane,
    required this.onLeagueChanged,
    required this.onSeasonChanged,
  });

  final _TeamPaneData? pane;
  final ValueChanged<String?> onLeagueChanged;
  final ValueChanged<String?> onSeasonChanged;

  @override
  Widget build(BuildContext context) {
    final hasData = pane != null;
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: hasData ? pane!.selectedLeagueId : null,
              hint: const Text('League'),
              items: hasData
                  ? pane!.leagueOptions
                        .map(
                          (o) => DropdownMenuItem<String>(
                            value: o.id,
                            child: Text(
                              o.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList()
                  : const [],
              onChanged: hasData ? onLeagueChanged : null,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: hasData ? pane!.selectedSeasonId : null,
              hint: const Text('Season'),
              items: hasData
                  ? pane!.seasonOptions
                        .map(
                          (o) => DropdownMenuItem<String>(
                            value: o.id,
                            child: Text(
                              o.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList()
                  : const [],
              onChanged: hasData ? onSeasonChanged : null,
            ),
          ),
        ),
      ],
    );
  }
}

class _ComparisonLoadingCard extends StatelessWidget {
  const _ComparisonLoadingCard({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class _HeadToHeadCard extends StatelessWidget {
  const _HeadToHeadCard({
    required this.leftTeam,
    required this.rightTeam,
    required this.stats,
  });

  final TeamModel leftTeam;
  final TeamModel rightTeam;
  final _HeadToHeadStats stats;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final total = stats.leftWins + stats.draws + stats.rightWins;
    final leftFlex = total == 0 ? 1 : stats.leftWins;
    final drawFlex = total == 0 ? 1 : stats.draws;
    final rightFlex = total == 0 ? 1 : stats.rightWins;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Text('Previous matches', style: textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _scoreBadge(
                context,
                score: stats.leftWins,
                label: '${leftTeam.shortForm} wins',
                color: colorScheme.tertiaryContainer,
                textColor: colorScheme.onTertiaryContainer,
              ),
              _scoreBadge(
                context,
                score: stats.draws,
                label: 'Draws',
                color: colorScheme.outline,
                textColor: colorScheme.surface,
              ),
              _scoreBadge(
                context,
                score: stats.rightWins,
                label: '${rightTeam.shortForm} wins',
                color: colorScheme.error,
                textColor: colorScheme.onError,
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(100),
            child: SizedBox(
              height: 6,
              child: Row(
                children: [
                  Expanded(
                    flex: leftFlex == 0 ? 1 : leftFlex,
                    child: Container(color: colorScheme.tertiary),
                  ),
                  Expanded(
                    flex: drawFlex == 0 ? 1 : drawFlex,
                    child: Container(color: colorScheme.outline),
                  ),
                  Expanded(
                    flex: rightFlex == 0 ? 1 : rightFlex,
                    child: Container(color: colorScheme.error),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreBadge(
    BuildContext context, {
    required int score,
    required String label,
    required Color color,
    required Color textColor,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
          child: Text(
            '$score',
            style: textTheme.titleMedium?.copyWith(color: textColor),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: textTheme.bodySmall),
      ],
    );
  }
}

class _TopStatsCard extends StatelessWidget {
  const _TopStatsCard({
    required this.leftTeam,
    required this.rightTeam,
    required this.leftSummary,
    required this.rightSummary,
  });

  final TeamModel leftTeam;
  final TeamModel rightTeam;
  final Map<String, dynamic> leftSummary;
  final Map<String, dynamic> rightSummary;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final rows = <_CompareRow>[
      _CompareRow(
        label: 'Matches',
        left: _readDouble(leftSummary, 'matches_played'),
        right: _readDouble(rightSummary, 'matches_played'),
      ),
      _CompareRow(
        label: 'Goals scored',
        left: _readDouble(leftSummary, 'goals_scored'),
        right: _readDouble(rightSummary, 'goals_scored'),
      ),
      _CompareRow(
        label: 'Goals conceded',
        left: _readDouble(leftSummary, 'goals_conceded'),
        right: _readDouble(rightSummary, 'goals_conceded'),
        lowerIsBetter: true,
      ),
      _CompareRow(
        label: 'Goal difference',
        left: _readDouble(leftSummary, 'goal_difference'),
        right: _readDouble(rightSummary, 'goal_difference'),
      ),
      _CompareRow(
        label: 'Assists',
        left: _readDouble(leftSummary, 'assists'),
        right: _readDouble(rightSummary, 'assists'),
      ),
      _CompareRow(
        label: 'Clean sheets',
        left: _readDouble(leftSummary, 'clean_sheets'),
        right: _readDouble(rightSummary, 'clean_sheets'),
      ),
      _CompareRow(
        label: 'Shots on target',
        left: _readDouble(leftSummary, 'shots_on_target'),
        right: _readDouble(rightSummary, 'shots_on_target'),
      ),
      _CompareRow(
        label: 'Tackles',
        left: _readDouble(leftSummary, 'tackles'),
        right: _readDouble(rightSummary, 'tackles'),
      ),
      _CompareRow(
        label: 'Saves',
        left: _readDouble(leftSummary, 'saves'),
        right: _readDouble(rightSummary, 'saves'),
      ),
      _CompareRow(
        label: 'Yellow cards',
        left: _readDouble(leftSummary, 'yellow_cards'),
        right: _readDouble(rightSummary, 'yellow_cards'),
        lowerIsBetter: true,
      ),
      _CompareRow(
        label: 'Red cards',
        left: _readDouble(leftSummary, 'red_cards'),
        right: _readDouble(rightSummary, 'red_cards'),
        lowerIsBetter: true,
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          Text('Top stats', style: textTheme.titleMedium),
          const SizedBox(height: 12),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _valueChip(
                        context,
                        row.format(row.left),
                        highlighted: row.leftWins,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.label,
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium,
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _valueChip(
                        context,
                        row.format(row.right),
                        highlighted: row.rightWins,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(leftTeam.shortForm, style: textTheme.bodySmall),
              Text(rightTeam.shortForm, style: textTheme.bodySmall),
            ],
          ),
        ],
      ),
    );
  }

  Widget _valueChip(BuildContext context, String text, {required bool highlighted}) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    if (!highlighted) return Text(text, style: textTheme.titleMedium);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: textTheme.titleSmall?.copyWith(color: colorScheme.onPrimaryContainer),
      ),
    );
  }

  double _readDouble(Map<String, dynamic> map, String key) {
    return (map[key] as num?)?.toDouble() ?? 0;
  }
}

class _FormIndicator extends StatelessWidget {
  const _FormIndicator({required this.form});

  final List<String> form;

  @override
  Widget build(BuildContext context) {
    final normalized = List<String>.from(form.take(5));
    while (normalized.length < 5) {
      normalized.add('-');
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final item in normalized) ...[
          Container(
            width: 10,
            height: 8,
            decoration: BoxDecoration(
              color: _colorFor(item, Theme.of(context).colorScheme),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          if (item != normalized.last) const SizedBox(width: 4),
        ],
      ],
    );
  }

  Color _colorFor(String code, ColorScheme colorScheme) {
    switch (code) {
      case 'W':
        return Colors.green;
      case 'L':
        return Colors.red;
      case 'D':
        return colorScheme.outlineVariant;
      default:
        return colorScheme.outlineVariant;
    }
  }
}

class _TeamLogo extends StatelessWidget {
  const _TeamLogo({required this.path, this.size = 40});

  final String path;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isNetwork = path.startsWith('http://') || path.startsWith('https://');
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: isNetwork
            ? Image(image: appCachedImageProvider(path), fit: BoxFit.cover)
            : Image.asset(path, fit: BoxFit.cover),
      ),
    );
  }
}

class _TeamPaneData {
  const _TeamPaneData({
    required this.team,
    required this.leagueOptions,
    required this.selectedLeagueId,
    required this.seasonOptions,
    required this.selectedSeasonId,
    required this.summary,
    required this.recentForm,
  });

  final TeamModel team;
  final List<_Option> leagueOptions;
  final String selectedLeagueId;
  final List<_Option> seasonOptions;
  final String selectedSeasonId;
  final Map<String, dynamic> summary;
  final List<String> recentForm;
}

class _TeamFilterContext {
  const _TeamFilterContext({
    required this.leagueOptions,
    required this.seasonOptions,
  });

  final List<_Option> leagueOptions;
  final List<_SeasonLeagueOption> seasonOptions;
}

class _Option {
  const _Option({required this.id, required this.label});

  final String id;
  final String label;
}

class _SeasonLeagueOption {
  const _SeasonLeagueOption({
    required this.id,
    required this.leagueId,
    required this.label,
  });

  final String id;
  final String leagueId;
  final String label;
}

class _HeadToHeadStats {
  const _HeadToHeadStats({
    this.leftWins = 0,
    this.draws = 0,
    this.rightWins = 0,
  });

  final int leftWins;
  final int draws;
  final int rightWins;
}

class _CompareRow {
  _CompareRow({
    required this.label,
    required this.left,
    required this.right,
    this.lowerIsBetter = false,
    this.decimalPlaces = 0,
  });

  final String label;
  final double left;
  final double right;
  final bool lowerIsBetter;
  final int decimalPlaces;

  bool get leftWins {
    if (left == right) return false;
    return lowerIsBetter ? left < right : left > right;
  }

  bool get rightWins {
    if (left == right) return false;
    return lowerIsBetter ? right < left : right > left;
  }

  String format(double value) {
    if (decimalPlaces <= 0) return value.round().toString();
    return value.toStringAsFixed(decimalPlaces);
  }
}
