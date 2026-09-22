import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/widgets/media_placeholders.dart';

class PlayerComparisonPage extends StatefulWidget {
  const PlayerComparisonPage({super.key, required this.basePlayerId});

  final String basePlayerId;

  @override
  State<PlayerComparisonPage> createState() => _PlayerComparisonPageState();
}

class _PlayerComparisonPageState extends State<PlayerComparisonPage> {
  static const String _allLeaguesId = '__all_leagues__';
  static const String _allSeasonsId = '__all_seasons__';
  final SupabaseClient _client = Supabase.instance.client;

  _PlayerPaneData? _leftPane;
  _PlayerPaneData? _rightPane;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() => _isInitializing = true);
    final left = await _loadPaneForPlayer(widget.basePlayerId);
    if (!mounted) return;
    setState(() {
      _leftPane = left;
      _isInitializing = false;
    });
  }

  Future<_PlayerPaneData?> _loadPaneForPlayer(String playerId) async {
    final playerRes = await _client
        .from('players')
        .select('id, player_name, image_url')
        .eq('id', playerId)
        .maybeSingle();
    if (playerRes == null) {
      return null;
    }

    final player = _PlayerIdentity(
      id: playerRes['id']?.toString() ?? playerId,
      name: playerRes['player_name']?.toString().trim().isNotEmpty == true
          ? playerRes['player_name']?.toString().trim() ?? 'Unknown player'
          : 'Unknown player',
      imageUrl: playerRes['image_url']?.toString() ?? '',
    );

    final rows = await _loadSeasonRows(player.id);
    final competitions = _extractCompetitionOptions(rows);
    final seasons = _extractSeasonOptionsForCompetition(rows, _allLeaguesId);
    final selectedCompetitionId = _allLeaguesId;
    final selectedSeasonId = _allSeasonsId;
    final totals = _totalsForSelection(
      rows,
      selectedCompetitionId: selectedCompetitionId,
      selectedSeasonId: selectedSeasonId,
    );

    return _PlayerPaneData(
      player: player,
      rows: rows,
      competitions: competitions,
      selectedCompetitionId: selectedCompetitionId,
      seasons: seasons,
      selectedSeasonId: selectedSeasonId,
      totals: totals,
    );
  }

  Future<List<Map<String, dynamic>>> _loadSeasonRows(String playerId) async {
    List<Map<String, dynamic>> normalize(dynamic res) {
      if (res is! List) return const [];
      return res
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    }

    try {
      final leagueSeason = await _client
          .from('v_player_league_season_totals')
          .select()
          .eq('player_id', playerId);
      final rows = normalize(leagueSeason);
      if (rows.isNotEmpty) return rows;
    } catch (_) {}

    try {
      final primary = await _client
          .from('v_player_season_totals')
          .select()
          .eq('player_id', playerId);
      final rows = await _hydrateLeagueNames(normalize(primary));
      if (rows.isNotEmpty) return rows;
    } catch (_) {}

    try {
      final fallback = await _client
          .from('v_player_season_team_totals')
          .select()
          .eq('player_id', playerId);
      return _hydrateLeagueNames(normalize(fallback));
    } catch (_) {
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> _hydrateLeagueNames(
    List<Map<String, dynamic>> rows,
  ) async {
    if (rows.isEmpty) return rows;
    final missingLeagueIds = <String>{};
    for (final row in rows) {
      final hasLeagueName = _readString(row, const [
        'league_name',
        'competition_name',
        'competition',
        'league',
      ]).isNotEmpty;
      if (hasLeagueName) continue;
      final leagueId = _readString(row, const [
        'league_id',
        'competition_id',
      ]);
      if (leagueId.isNotEmpty) missingLeagueIds.add(leagueId);
    }
    if (missingLeagueIds.isEmpty) return rows;

    try {
      final response = await _client
          .from('leagues')
          .select('id, league_name')
          .inFilter('id', missingLeagueIds.toList());
      final byId = <String, String>{};
      for (final row in (response as List).whereType<Map>()) {
        final map = Map<String, dynamic>.from(row);
        final id = map['id']?.toString() ?? '';
        final name = map['league_name']?.toString() ?? '';
        if (id.isNotEmpty && name.trim().isNotEmpty) {
          byId[id] = name.trim();
        }
      }
      for (final row in rows) {
        final hasLeagueName = _readString(row, const [
          'league_name',
          'competition_name',
          'competition',
          'league',
        ]).isNotEmpty;
        if (hasLeagueName) continue;
        final leagueId = _readString(row, const [
          'league_id',
          'competition_id',
        ]);
        final resolved = byId[leagueId];
        if (resolved != null && resolved.isNotEmpty) {
          row['league_name'] = resolved;
        }
      }
    } catch (_) {}
    return rows;
  }

  List<_CompetitionOption> _extractCompetitionOptions(List<Map<String, dynamic>> rows) {
    final byId = <String, _CompetitionOption>{};
    for (final row in rows) {
      final label = _competitionLabel(row);
      final id = label.toLowerCase();
      byId.putIfAbsent(id, () => _CompetitionOption(id: id, label: label));
    }

    final options = <_CompetitionOption>[
      const _CompetitionOption(id: _allLeaguesId, label: 'All leagues'),
      ...byId.values,
    ]..sort((a, b) {
        if (a.id == _allLeaguesId) return -1;
        if (b.id == _allLeaguesId) return 1;
        return a.label.compareTo(b.label);
      });
    return options;
  }

  List<_SeasonOption> _extractSeasonOptionsForCompetition(
    List<Map<String, dynamic>> rows,
    String? competitionId,
  ) {
    final byId = <String, _SeasonOption>{};
    for (final row in rows) {
      final rowCompetition = _competitionLabel(row).toLowerCase();
      final matchesCompetition =
          competitionId == null ||
          competitionId == _allLeaguesId ||
          rowCompetition == competitionId;
      if (!matchesCompetition) continue;

      final seasonLabel = _seasonLabel(row);
      final seasonKey = _seasonSortKey(row);
      final id = seasonLabel.toLowerCase();
      byId.putIfAbsent(
        id,
        () => _SeasonOption(id: id, label: seasonLabel, sortKey: seasonKey),
      );
    }

    final options = byId.values.toList()
      ..sort((a, b) {
        final seasonOrder = b.sortKey.compareTo(a.sortKey);
        if (seasonOrder != 0) return seasonOrder;
        return a.label.compareTo(b.label);
      });
    return [
      const _SeasonOption(id: _allSeasonsId, label: 'All seasons', sortKey: 0),
      ...options,
    ];
  }

  _PlayerTotals _totalsForSelection(
    List<Map<String, dynamic>> rows,
    {String? selectedCompetitionId, String? selectedSeasonId}) {
    if (rows.isEmpty) return const _PlayerTotals.empty();

    final source = rows.where((row) {
      final competitionId = _competitionLabel(row).toLowerCase();
      final seasonId = _seasonLabel(row).toLowerCase();
      final competitionMatch =
          selectedCompetitionId == null ||
          selectedCompetitionId == _allLeaguesId ||
          selectedCompetitionId == competitionId;
      final seasonMatch =
          selectedSeasonId == null ||
          selectedSeasonId == _allSeasonsId ||
          selectedSeasonId == seasonId;
      return competitionMatch && seasonMatch;
    }).toList();
    final effectiveSource = source.isNotEmpty ? source : rows;
    var minutes = 0;
    var matches = 0;
    var goals = 0;
    var assists = 0;
    var yellowCards = 0;
    var redCards = 0;
    var tackles = 0;
    var saves = 0;
    var weightedRating = 0.0;
    var weightedRatingMatches = 0;

    for (final row in effectiveSource) {
      final rowMatches = _readInt(row, const ['matches', 'matches_played']);
      final rowRating = _readDouble(row, const ['avg_rating', 'rating']);
      minutes += _readInt(row, const ['minutes_played', 'minutes']);
      matches += rowMatches;
      goals += _readInt(row, const ['goals', 'total_goals']);
      assists += _readInt(row, const ['assists', 'total_assists']);
      yellowCards += _readInt(row, const ['yellow_cards', 'yellow']);
      redCards += _readInt(row, const ['red_cards', 'red']);
      tackles += _readInt(row, const ['tackles', 'tackles_won']);
      saves += _readInt(row, const ['saves']);

      if (rowRating > 0) {
        final weight = rowMatches > 0 ? rowMatches : 1;
        weightedRating += rowRating * weight;
        weightedRatingMatches += weight;
      }
    }

    return _PlayerTotals(
      rating: weightedRatingMatches > 0 ? weightedRating / weightedRatingMatches : 0,
      minutesPlayed: minutes,
      matchesPlayed: matches,
      goals: goals,
      assists: assists,
      tackles: tackles,
      saves: saves,
      yellowCards: yellowCards,
      redCards: redCards,
    );
  }

  static int _readInt(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value is int) return value;
      if (value is num) return value.round();
      if (value is String) {
        final parsed = num.tryParse(value.trim());
        if (parsed != null) return parsed.round();
      }
    }
    return 0;
  }

  static double _readDouble(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value is double) return value;
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value.trim());
        if (parsed != null) return parsed;
      }
    }
    return 0;
  }

  static String _readString(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
      if (value != null) {
        final asString = value.toString().trim();
        if (asString.isNotEmpty) return asString;
      }
    }
    return '';
  }

  static String _competitionLabel(Map<String, dynamic> row) {
    final league = _readString(row, const [
      'league_name',
      'league',
      'competition_name',
      'competition',
    ]);
    return league.isEmpty ? 'Unknown league' : league;
  }

  static String _seasonLabel(Map<String, dynamic> row) {
    final season = _readString(row, const [
      'season_name',
      'season_label',
      'season',
      'season_year',
      'year',
    ]);
    if (season.isNotEmpty) return season;
    final seasonKey = _seasonSortKey(row);
    return seasonKey > 0 ? '$seasonKey' : 'Unknown season';
  }

  static int _seasonSortKey(Map<String, dynamic> row) {
    return _readInt(row, const [
      'season',
      'season_year',
      'season_start_year',
      'year',
    ]);
  }

  Future<void> _pickOpponent() async {
    final selected = await showModalBottomSheet<_PlayerIdentity>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _PlayerPickerSheet(
        excludedPlayerId: _leftPane?.player.id,
      ),
    );
    if (selected == null || !mounted) return;
    final right = await _loadPaneForPlayer(selected.id);
    if (!mounted) return;
    setState(() => _rightPane = right);
  }

  void _onCompetitionChanged(bool isLeft, String? competitionId) {
    final pane = isLeft ? _leftPane : _rightPane;
    if (pane == null) return;
    final selectedCompetitionId = competitionId ?? _allLeaguesId;
    final seasons = _extractSeasonOptionsForCompetition(pane.rows, selectedCompetitionId);
    final selectedSeasonId = _allSeasonsId;
    final updated = pane.copyWith(
      selectedCompetitionId: selectedCompetitionId,
      seasons: seasons,
      selectedSeasonId: selectedSeasonId,
      totals: _totalsForSelection(
        pane.rows,
        selectedCompetitionId: selectedCompetitionId,
        selectedSeasonId: selectedSeasonId,
      ),
    );
    setState(() {
      if (isLeft) {
        _leftPane = updated;
      } else {
        _rightPane = updated;
      }
    });
  }

  void _onSeasonChanged(bool isLeft, String? seasonId) {
    final pane = isLeft ? _leftPane : _rightPane;
    if (pane == null) return;
    final selectedSeasonId = seasonId ?? _allSeasonsId;
    final updated = pane.copyWith(
      selectedSeasonId: selectedSeasonId,
      totals: _totalsForSelection(
        pane.rows,
        selectedCompetitionId: pane.selectedCompetitionId,
        selectedSeasonId: selectedSeasonId,
      ),
    );
    setState(() {
      if (isLeft) {
        _leftPane = updated;
      } else {
        _rightPane = updated;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Player vs Player')),
      body: _isInitializing
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _PlayerHeroCard(
                          pane: _leftPane,
                          onTap: null,
                          onCompetitionChanged: (id) =>
                              _onCompetitionChanged(true, id),
                          onSeasonChanged: (id) => _onSeasonChanged(true, id),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PlayerHeroCard(
                          pane: _rightPane,
                          onTap: _pickOpponent,
                          onCompetitionChanged: (id) =>
                              _onCompetitionChanged(false, id),
                          onSeasonChanged: (id) => _onSeasonChanged(false, id),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Top stats',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 14),
                        ..._buildComparisonRows(context),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  List<Widget> _buildComparisonRows(BuildContext context) {
    final leftTotals = _leftPane?.totals ?? const _PlayerTotals.empty();
    final rightTotals = _rightPane?.totals ?? const _PlayerTotals.empty();

    return [
      _ComparisonStatRow(
        label: 'Ballo rating',
        left: leftTotals.rating,
        right: rightTotals.rating,
        format: _formatDecimal2,
      ),
      _ComparisonStatRow(
        label: 'Minutes played',
        left: leftTotals.minutesPlayed.toDouble(),
        right: rightTotals.minutesPlayed.toDouble(),
        format: _formatWholeWithGrouping,
      ),
      _ComparisonStatRow(
        label: 'Matches played',
        left: leftTotals.matchesPlayed.toDouble(),
        right: rightTotals.matchesPlayed.toDouble(),
        format: _formatWhole,
      ),
      _ComparisonStatRow(
        label: 'Goals scored',
        left: leftTotals.goals.toDouble(),
        right: rightTotals.goals.toDouble(),
        format: _formatWhole,
      ),
      _ComparisonStatRow(
        label: 'Assists',
        left: leftTotals.assists.toDouble(),
        right: rightTotals.assists.toDouble(),
        format: _formatWhole,
      ),
      _ComparisonStatRow(
        label: 'Tackles',
        left: leftTotals.tackles.toDouble(),
        right: rightTotals.tackles.toDouble(),
        format: _formatWhole,
      ),
      _ComparisonStatRow(
        label: 'Saves',
        left: leftTotals.saves.toDouble(),
        right: rightTotals.saves.toDouble(),
        format: _formatWhole,
      ),
      _ComparisonStatRow(
        label: 'Yellow cards',
        left: leftTotals.yellowCards.toDouble(),
        right: rightTotals.yellowCards.toDouble(),
        format: _formatWhole,
      ),
      _ComparisonStatRow(
        label: 'Red cards',
        left: leftTotals.redCards.toDouble(),
        right: rightTotals.redCards.toDouble(),
        format: _formatWhole,
      ),
    ];
  }

  static String _formatWhole(double value) => value.round().toString();

  static String _formatDecimal2(double value) => value.toStringAsFixed(2);

  static String _formatWholeWithGrouping(double value) {
    final whole = value.round().toString();
    return whole.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  }
}

class _PlayerHeroCard extends StatelessWidget {
  const _PlayerHeroCard({
    required this.pane,
    required this.onTap,
    required this.onCompetitionChanged,
    required this.onSeasonChanged,
  });

  final _PlayerPaneData? pane;
  final VoidCallback? onTap;
  final ValueChanged<String?> onCompetitionChanged;
  final ValueChanged<String?> onSeasonChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasData = pane != null;
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: Icon(
                    Icons.compare_arrows_rounded,
                    size: 18,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                _PlayerAvatar(imageUrl: pane?.player.imageUrl ?? ''),
                const SizedBox(height: 8),
                Text(
                  pane?.player.name ?? 'Select player',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(14),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: hasData ? pane!.selectedCompetitionId : null,
              hint: const Text('League'),
              items: hasData
                  ? pane!.competitions
                        .map(
                          (c) => DropdownMenuItem<String>(
                            value: c.id,
                            child: Text(
                              c.label,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList()
                  : const [],
              onChanged: hasData ? onCompetitionChanged : null,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 10),
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
                  ? pane!.seasons
                        .map(
                          (s) => DropdownMenuItem<String>(
                            value: s.id,
                            child: Text(
                              s.label,
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

class _ComparisonStatRow extends StatelessWidget {
  const _ComparisonStatRow({
    required this.label,
    required this.left,
    required this.right,
    required this.format,
  });

  final String label;
  final double left;
  final double right;
  final String Function(double) format;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final leftWins = left > right;
    final rightWins = right > left;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          _StatValuePill(
            value: format(left),
            highlighted: leftWins,
            alignment: Alignment.centerLeft,
          ),
          Expanded(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                  ),
            ),
          ),
          _StatValuePill(
            value: format(right),
            highlighted: rightWins,
            alignment: Alignment.centerRight,
          ),
        ],
      ),
    );
  }
}

class _StatValuePill extends StatelessWidget {
  const _StatValuePill({
    required this.value,
    required this.highlighted,
    required this.alignment,
  });

  final String value;
  final bool highlighted;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final bg = highlighted ? Colors.green : colorScheme.surfaceContainerHighest;
    final fg = highlighted ? Colors.black : colorScheme.onSurface;
    return SizedBox(
      width: 88,
      child: Align(
        alignment: alignment,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: fg, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

class _PlayerAvatar extends StatelessWidget {
  const _PlayerAvatar({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return CircleAvatar(radius: 30, backgroundImage: appCachedImageProvider(imageUrl));
    }
    if (imageUrl.isNotEmpty) {
      return CircleAvatar(
        backgroundColor: colorScheme.surfaceContainerHighest,
        child: ClipOval(
          child: Image.asset(
            imageUrl,
            width: 60,
            height: 60,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Icon(Icons.person, color: colorScheme.onSurface),
          ),
        ),
      );
    }
    return CircleAvatar(
      backgroundColor: colorScheme.surfaceContainerHighest,
      child: Icon(Icons.person, color: colorScheme.onSurface),
    );
  }
}

class _PlayerPickerSheet extends StatefulWidget {
  const _PlayerPickerSheet({required this.excludedPlayerId});

  final String? excludedPlayerId;

  @override
  State<_PlayerPickerSheet> createState() => _PlayerPickerSheetState();
}

class _PlayerPickerSheetState extends State<_PlayerPickerSheet> {
  final SupabaseClient _client = Supabase.instance.client;
  final TextEditingController _controller = TextEditingController();
  List<_PlayerIdentity> _results = const [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _search('');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    setState(() => _loading = true);
    try {
      final response = await _client
          .from('players')
          .select('id, player_name, image_url')
          .ilike('player_name', '%${query.trim()}%')
          .isFilter('deleted_at', null)
          .limit(25);
      final rows = (response as List)
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .where((row) => row['id']?.toString() != widget.excludedPlayerId)
          .map(
            (row) => _PlayerIdentity(
              id: row['id']?.toString() ?? '',
              name: row['player_name']?.toString() ?? 'Unknown player',
              imageUrl: row['image_url']?.toString() ?? '',
            ),
          )
          .where((p) => p.id.isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() {
        _results = rows;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _results = const [];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, insets + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              onChanged: _search,
              decoration: const InputDecoration(
                labelText: 'Search player',
                prefixIcon: Icon(Icons.search),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 360,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.separated(
                      itemCount: _results.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final player = _results[index];
                        return ListTile(
                          onTap: () => Navigator.of(context).pop(player),
                          leading: _PlayerAvatar(imageUrl: player.imageUrl),
                          title: Text(
                            player.name,
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

class _PlayerIdentity {
  const _PlayerIdentity({
    required this.id,
    required this.name,
    required this.imageUrl,
  });

  final String id;
  final String name;
  final String imageUrl;
}

class _SeasonOption {
  const _SeasonOption({
    required this.id,
    required this.label,
    required this.sortKey,
  });

  final String id;
  final String label;
  final int sortKey;
}

class _CompetitionOption {
  const _CompetitionOption({required this.id, required this.label});

  final String id;
  final String label;
}

class _PlayerPaneData {
  const _PlayerPaneData({
    required this.player,
    required this.rows,
    required this.competitions,
    required this.selectedCompetitionId,
    required this.seasons,
    required this.selectedSeasonId,
    required this.totals,
  });

  final _PlayerIdentity player;
  final List<Map<String, dynamic>> rows;
  final List<_CompetitionOption> competitions;
  final String selectedCompetitionId;
  final List<_SeasonOption> seasons;
  final String selectedSeasonId;
  final _PlayerTotals totals;

  _PlayerPaneData copyWith({
    String? selectedCompetitionId,
    List<_SeasonOption>? seasons,
    String? selectedSeasonId,
    _PlayerTotals? totals,
  }) {
    return _PlayerPaneData(
      player: player,
      rows: rows,
      competitions: competitions,
      selectedCompetitionId: selectedCompetitionId ?? this.selectedCompetitionId,
      seasons: seasons ?? this.seasons,
      selectedSeasonId: selectedSeasonId ?? this.selectedSeasonId,
      totals: totals ?? this.totals,
    );
  }
}

class _PlayerTotals {
  const _PlayerTotals({
    required this.rating,
    required this.minutesPlayed,
    required this.matchesPlayed,
    required this.goals,
    required this.assists,
    required this.tackles,
    required this.saves,
    required this.yellowCards,
    required this.redCards,
  });

  const _PlayerTotals.empty()
      : rating = 0,
        minutesPlayed = 0,
        matchesPlayed = 0,
        goals = 0,
        assists = 0,
        tackles = 0,
        saves = 0,
        yellowCards = 0,
        redCards = 0;

  final double rating;
  final int minutesPlayed;
  final int matchesPlayed;
  final int goals;
  final int assists;
  final int tackles;
  final int saves;
  final int yellowCards;
  final int redCards;
}
