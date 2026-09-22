import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/countries.dart';
import '../../core/widgets/media_placeholders.dart';
import '../../data/repositories/players_repository.dart';
import '../../domain/models/league_model.dart';
import '../../domain/models/team_model.dart';
import '../pages/league_detail_page.dart';
import '../pages/player_profile_page.dart';
import '../pages/team_detail_page.dart';
import '../providers/favourited_leagues_provider.dart';
import '../providers/favourited_players_provider.dart';
import '../providers/favourited_teams_provider.dart';

enum _SearchCategory { all, teams, competitions, players }

enum _SearchImageShape { circular, roundedSquare }

class AppSearchPage extends ConsumerStatefulWidget {
  const AppSearchPage({super.key});

  @override
  ConsumerState<AppSearchPage> createState() => _AppSearchPageState();
}

class _AppSearchPageState extends ConsumerState<AppSearchPage> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  final List<_SearchItem> _suggestions = [];
  final Map<String, List<_SearchItem>> _cache = {};
  Timer? _debounce;
  bool _isLoading = false;
  String _lastQuery = '';
  String? _errorMessage;
  int _requestId = 0;
  _SearchCategory _category = _SearchCategory.all;
  List<TeamModel> _popularTeams = [];
  List<LeagueModel> _popularLeagues = [];
  List<PlayerSearchModel> _popularPlayers = [];
  bool _loadingPopularTeams = false;
  bool _loadingPopularLeagues = false;
  bool _loadingPopularPlayers = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
    _controller.addListener(_handleControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
      _loadPopularContent();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_handleControllerChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    _onQueryChanged(_controller.text);
    setState(() {});
  }

  bool get _showPopularTeams =>
      _controller.text.trim().isEmpty &&
      (_category == _SearchCategory.all ||
          _category == _SearchCategory.teams);

  bool get _showPopularCompetitions =>
      _controller.text.trim().isEmpty &&
      (_category == _SearchCategory.all ||
          _category == _SearchCategory.competitions);

  bool get _showPopularPlayers =>
      _controller.text.trim().isEmpty &&
      (_category == _SearchCategory.all ||
          _category == _SearchCategory.players);

  Future<void> _loadPopularContent() async {
    setState(() {
      _loadingPopularTeams = true;
      _loadingPopularLeagues = true;
      _loadingPopularPlayers = true;
    });
    try {
      final teams = await ref.read(teamsRepositoryProvider).getPopularTeams();
      final leagues =
          await ref.read(leaguesRepositoryProvider).getPopularLeagues();
      final players =
          await ref.read(playersRepositoryProvider).getPopularPlayers();
      if (!mounted) return;
      setState(() {
        _popularTeams = teams;
        _popularLeagues = leagues;
        _popularPlayers = players;
        _loadingPopularTeams = false;
        _loadingPopularLeagues = false;
        _loadingPopularPlayers = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingPopularTeams = false;
        _loadingPopularLeagues = false;
        _loadingPopularPlayers = false;
      });
    }
  }

  void _onQueryChanged(String query) {
    final trimmed = query.trim();
    _lastQuery = trimmed;
    _debounce?.cancel();

    if (trimmed.isEmpty) {
      setState(() {
        _suggestions.clear();
        _isLoading = false;
        _errorMessage = null;
      });
      return;
    }

    if (trimmed.length < 2) {
      setState(() {
        _suggestions.clear();
        _isLoading = false;
        _errorMessage = null;
      });
      return;
    }

    if (_cache.containsKey(_cacheKey(trimmed))) {
      setState(() {
        _suggestions
          ..clear()
          ..addAll(_cache[_cacheKey(trimmed)]!);
        _isLoading = false;
        _errorMessage = null;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 250), () {
      _fetchSuggestions(trimmed);
    });
  }

  String _cacheKey(String query) => '${_category.name}:$query';

  Future<void> _fetchSuggestions(String query) async {
    final requestId = ++_requestId;
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final includeLeagues =
          _category == _SearchCategory.all ||
          _category == _SearchCategory.competitions;
      final includeTeams =
          _category == _SearchCategory.all ||
          _category == _SearchCategory.teams;
      final includePlayers =
          _category == _SearchCategory.all ||
          _category == _SearchCategory.players;

      final leagues = <_SearchItem>[];
      if (includeLeagues) {
        final leaguesRes = await supabase
            .from('leagues')
            .select('id, league_name, logo_id, country')
            .ilike('league_name', '%$query%')
            .limit(10);
        leagues.addAll(
          (leaguesRes as List)
              .map(
                (e) => _SearchItem(
                  id: (e['id'] ?? '').toString(),
                  label: (e['league_name'] ?? '').toString(),
                  type: 'League',
                  logoPath: _resolveLogoPath(e['logo_id']?.toString()),
                  logoId: e['logo_id']?.toString(),
                  country: e['country']?.toString(),
                  subtitle: _leagueSubtitle(e['country']?.toString()),
                ),
              )
              .where((item) => item.label.isNotEmpty),
        );
      }

      final teams = <_SearchItem>[];
      if (includeTeams) {
        final teamsRes = await supabase
            .from('teams')
            .select('id, team_name, short_form, logo_id, favourite_count')
            .ilike('team_name', '%$query%')
            .limit(10);
        teams.addAll(
          (teamsRes as List)
              .map((e) {
                final shortForm = e['short_form']?.toString() ?? '';
                return _SearchItem(
                  id: (e['id'] ?? '').toString(),
                  label: (e['team_name'] ?? '').toString(),
                  type: 'Team',
                  logoId: e['logo_id']?.toString(),
                  logoPath: _resolveLogoPath(e['logo_id']?.toString()),
                  shortForm: shortForm,
                  subtitle: shortForm.isNotEmpty
                      ? '$shortForm | Football'
                      : 'Team | Football',
                  favouriteCount: _parseInt(e['favourite_count']),
                );
              })
              .where((item) => item.label.isNotEmpty),
        );
      }

      final players = <_SearchItem>[];
      if (includePlayers) {
        final playersRes = await supabase
            .from('players')
            .select(
              'id, player_name, username, image_url, position, favourite_count',
            )
            .or('player_name.ilike.%$query%,username.ilike.%$query%')
            .isFilter('deleted_at', null)
            .limit(10);
        players.addAll(
          (playersRes as List).map((e) {
            final model = PlayerSearchModel.fromJson(
              Map<String, dynamic>.from(e as Map),
            );
            return _SearchItem(
              id: model.id,
              label: model.displayName,
              type: 'Player',
              avatarUrl: model.imageUrl,
              position: model.position,
              subtitle: model.subtitle,
              favouriteCount: model.favouriteCount,
            );
          }).where((item) => item.id.isNotEmpty),
        );
      }

      final combined = [...leagues, ...teams, ...players];
      _cache[_cacheKey(query)] = combined;
      if (!mounted || _lastQuery != query || requestId != _requestId) return;
      setState(() {
        _suggestions
          ..clear()
          ..addAll(combined);
        _isLoading = false;
        _errorMessage = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Search failed. Please try again.';
      });
    }
  }

  void _clearQuery() {
    _controller.clear();
    _focusNode.requestFocus();
  }

  void _setCategory(_SearchCategory category) {
    if (_category == category) return;
    setState(() {
      _category = category;
      _suggestions.clear();
      _cache.clear();
    });
    final trimmed = _controller.text.trim();
    if (trimmed.length >= 2) {
      _fetchSuggestions(trimmed);
    }
  }

  void _openResult(_SearchItem item) {
    if (item.type == 'League') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LeagueDetailPage(leagueId: item.id),
        ),
      );
    } else if (item.type == 'Player') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlayerProfilePage(playerId: item.id),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TeamDetailPage(teamId: item.id),
        ),
      );
    }
  }

  Future<void> _toggleLeagueFavourite(LeagueModel league) async {
    await ref.read(favouritedLeaguesProvider.notifier).toggle(
      FavouritedLeague.fromLeagueModel(league),
    );
  }

  Future<void> _togglePlayerFavourite(PlayerSearchModel player) async {
    await ref
        .read(favouritedPlayersProvider.notifier)
        .toggle(FavouritedPlayer.fromSearchModel(player));
  }

  Future<void> _toggleTeamFavourite(TeamModel team) async {
    final favourited = FavouritedTeam.fromTeamModel(team);
    await ref.read(favouritedTeamsProvider.notifier).toggle(favourited);
    final isNowFavourited = ref
        .read(favouritedTeamsProvider.notifier)
        .isFavourited(team.id);
    setState(() {
      _popularTeams = [
        for (final entry in _popularTeams)
          if (entry.id == team.id)
            TeamModel(
              id: entry.id,
              logoId: entry.logoId,
              bannerId: entry.bannerId,
              shortForm: entry.shortForm,
              teamName: entry.teamName,
              favouriteCount: (entry.favouriteCount +
                      (isNowFavourited ? 1 : -1))
                  .clamp(0, 1 << 30),
            )
          else
            entry,
      ];
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final favouritedTeamIds = ref
        .watch(favouritedTeamsProvider)
        .map((team) => team.id)
        .toSet();
    final favouritedLeagueIds = ref
        .watch(favouritedLeaguesProvider)
        .map((league) => league.id)
        .toSet();
    final favouritedPlayerIds = ref
        .watch(favouritedPlayersProvider)
        .map((player) => player.id)
        .toSet();
    final query = _controller.text.trim();
    final showSearchResults = query.length >= 2;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          focusNode: _focusNode,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search',
            filled: true,
            fillColor: colorScheme.surfaceContainerHigh,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: BorderSide.none,
            ),
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.cancel_outlined),
                    tooltip: 'Clear',
                    onPressed: _clearQuery,
                  )
                : null,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _CategoryChip(
                  label: 'All',
                  selected: _category == _SearchCategory.all,
                  onTap: () => _setCategory(_SearchCategory.all),
                ),
                const SizedBox(width: 8),
                _CategoryChip(
                  label: 'Teams',
                  selected: _category == _SearchCategory.teams,
                  onTap: () => _setCategory(_SearchCategory.teams),
                ),
                const SizedBox(width: 8),
                _CategoryChip(
                  label: 'Competitions',
                  selected: _category == _SearchCategory.competitions,
                  onTap: () => _setCategory(_SearchCategory.competitions),
                ),
                const SizedBox(width: 8),
                _CategoryChip(
                  label: 'Players',
                  selected: _category == _SearchCategory.players,
                  onTap: () => _setCategory(_SearchCategory.players),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(_errorMessage!, textAlign: TextAlign.center),
            )
          else if (showSearchResults) ...[
            if (_suggestions.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No results',
                  style: textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else
              ..._suggestions.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _SearchResultCard(
                    item: item,
                    isStarred: switch (item.type) {
                      'League' => favouritedLeagueIds.contains(item.id),
                      'Player' => favouritedPlayerIds.contains(item.id),
                      _ => favouritedTeamIds.contains(item.id),
                    },
                    onTap: () => _openResult(item),
                    onStarTap: switch (item.type) {
                      'League' => () async {
                          await ref
                              .read(favouritedLeaguesProvider.notifier)
                              .toggle(
                                FavouritedLeague(
                                  id: item.id,
                                  name: item.label,
                                  country: item.country,
                                  logoId: item.logoId,
                                ),
                              );
                        },
                      'Player' => () async {
                          await ref
                              .read(favouritedPlayersProvider.notifier)
                              .toggle(
                                FavouritedPlayer(
                                  id: item.id,
                                  name: item.label,
                                  imageUrl: item.avatarUrl,
                                  position: item.position,
                                  favouriteCount: item.favouriteCount ?? 0,
                                ),
                              );
                        },
                      _ => () async {
                          await ref
                              .read(favouritedTeamsProvider.notifier)
                              .toggle(
                                FavouritedTeam(
                                  id: item.id,
                                  name: item.label,
                                  shortForm: item.shortForm,
                                  logoId: item.logoId,
                                  favouriteCount: item.favouriteCount ?? 0,
                                ),
                              );
                        },
                    },
                  ),
                ),
              ),
          ] else ...[
            if (_showPopularCompetitions) ...[
              Text(
                'Popular competitions',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              if (_loadingPopularLeagues)
                const _SearchLoadingSpinner()
              else if (_popularLeagues.isEmpty)
                Text(
                  'No popular competitions yet',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                )
              else
                ..._popularLeagues.map(
                  (league) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _PopularLeagueCard(
                      league: league,
                      isStarred: favouritedLeagueIds.contains(league.id),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                LeagueDetailPage(leagueId: league.id),
                          ),
                        );
                      },
                      onStarTap: () => _toggleLeagueFavourite(league),
                    ),
                  ),
                ),
              if (_category == _SearchCategory.all) const SizedBox(height: 20),
            ],
            if (_showPopularTeams) ...[
              Text(
                'Popular teams',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              if (_loadingPopularTeams)
                const _SearchLoadingSpinner()
              else if (_popularTeams.isEmpty)
                Text(
                  'No popular teams yet',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                )
              else
                ..._popularTeams.map(
                  (team) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _PopularTeamCard(
                      team: team,
                      isStarred: favouritedTeamIds.contains(team.id),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => TeamDetailPage(teamId: team.id),
                          ),
                        );
                      },
                      onStarTap: () => _toggleTeamFavourite(team),
                    ),
                  ),
                ),
              if (_category == _SearchCategory.all) const SizedBox(height: 20),
            ],
            if (_showPopularPlayers) ...[
              Text(
                'Popular players',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              if (_loadingPopularPlayers)
                const _SearchLoadingSpinner()
              else if (_popularPlayers.isEmpty)
                Text(
                  'No popular players yet',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                )
              else
                ..._popularPlayers.map(
                  (player) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _PopularPlayerCard(
                      player: player,
                      isStarred: favouritedPlayerIds.contains(player.id),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                PlayerProfilePage(playerId: player.id),
                          ),
                        );
                      },
                      onStarTap: () => _togglePlayerFavourite(player),
                    ),
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colorScheme.onSurface : colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: selected ? colorScheme.surface : colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({
    required this.item,
    required this.isStarred,
    required this.onTap,
    this.onStarTap,
  });

  final _SearchItem item;
  final bool isStarred;
  final VoidCallback onTap;
  final VoidCallback? onStarTap;

  @override
  Widget build(BuildContext context) {
    return _EntityCard(
      title: item.label,
      subtitle: item.subtitle ?? item.type,
      logoPath: item.logoPath,
      avatarUrl: item.avatarUrl,
      logoShape: item.type == 'League'
          ? _SearchImageShape.roundedSquare
          : _SearchImageShape.circular,
      fallbackIcon: switch (item.type) {
        'League' => Icons.emoji_events,
        'Player' => Icons.person,
        _ => Icons.groups,
      },
      isStarred: isStarred,
      onTap: onTap,
      onStarTap: onStarTap,
    );
  }
}

class _PopularLeagueCard extends StatelessWidget {
  const _PopularLeagueCard({
    required this.league,
    required this.isStarred,
    required this.onTap,
    required this.onStarTap,
  });

  final LeagueModel league;
  final bool isStarred;
  final VoidCallback onTap;
  final VoidCallback onStarTap;

  @override
  Widget build(BuildContext context) {
    return _EntityCard(
      title: league.leagueName,
      subtitle: _leagueSubtitle(league.country),
      logoPath: resolveTeamLogoPath(league.logoId),
      logoShape: _SearchImageShape.roundedSquare,
      fallbackIcon: Icons.emoji_events,
      isStarred: isStarred,
      onTap: onTap,
      onStarTap: onStarTap,
    );
  }
}

class _PopularPlayerCard extends StatelessWidget {
  const _PopularPlayerCard({
    required this.player,
    required this.isStarred,
    required this.onTap,
    required this.onStarTap,
  });

  final PlayerSearchModel player;
  final bool isStarred;
  final VoidCallback onTap;
  final VoidCallback onStarTap;

  @override
  Widget build(BuildContext context) {
    return _EntityCard(
      title: player.displayName,
      subtitle: player.subtitle,
      avatarUrl: player.imageUrl,
      fallbackIcon: Icons.person,
      isStarred: isStarred,
      onTap: onTap,
      onStarTap: onStarTap,
    );
  }
}

class _PopularTeamCard extends StatelessWidget {
  const _PopularTeamCard({
    required this.team,
    required this.isStarred,
    required this.onTap,
    required this.onStarTap,
  });

  final TeamModel team;
  final bool isStarred;
  final VoidCallback onTap;
  final VoidCallback onStarTap;

  @override
  Widget build(BuildContext context) {
    final shortForm = team.shortForm.trim();
    return _EntityCard(
      title: team.displayName,
      subtitle: shortForm.isNotEmpty ? '$shortForm | Football' : 'Team | Football',
      logoPath: resolveTeamLogoPath(team.logoId),
      logoShape: _SearchImageShape.circular,
      fallbackIcon: Icons.groups,
      isStarred: isStarred,
      onTap: onTap,
      onStarTap: onStarTap,
    );
  }
}

class _EntityCard extends StatelessWidget {
  const _EntityCard({
    required this.title,
    required this.subtitle,
    this.logoPath,
    this.avatarUrl,
    this.logoShape = _SearchImageShape.circular,
    required this.fallbackIcon,
    required this.isStarred,
    required this.onTap,
    this.onStarTap,
  });

  final String title;
  final String subtitle;
  final String? logoPath;
  final String? avatarUrl;
  final _SearchImageShape logoShape;
  final IconData fallbackIcon;
  final bool isStarred;
  final VoidCallback onTap;
  final VoidCallback? onStarTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: colorScheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            children: [
              if (avatarUrl != null)
                buildPlayerAvatar(imagePath: avatarUrl, size: 36)
              else
                _SearchLogo(
                  logoPath: logoPath,
                  fallbackIcon: fallbackIcon,
                  shape: logoShape,
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      subtitle,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (onStarTap != null)
                IconButton(
                  style: IconButton.styleFrom(
                    fixedSize: const Size(48, 48),
                    padding: EdgeInsets.zero,
                  ),
                  icon: Icon(
                    isStarred ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: isStarred
                        ? colorScheme.primary
                        : colorScheme.onSurface,
                    size: 26,
                  ),
                  onPressed: onStarTap,
                  tooltip: isStarred
                      ? 'Remove from favourites'
                      : 'Add to favourites',
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchItem {
  const _SearchItem({
    required this.id,
    required this.label,
    required this.type,
    this.logoPath,
    this.logoId,
    this.shortForm,
    this.subtitle,
    this.country,
    this.avatarUrl,
    this.position,
    this.favouriteCount,
  });

  final String id;
  final String label;
  final String type;
  final String? logoPath;
  final String? logoId;
  final String? shortForm;
  final String? subtitle;
  final String? country;
  final String? avatarUrl;
  final String? position;
  final int? favouriteCount;
}

String _leagueSubtitle(String? countryCode) {
  final code = countryCode?.trim();
  if (code == null || code.isEmpty) return 'Competition';
  return '${countryCodeToFlag(code)} ${countryCodeToName(code)}';
}

class _SearchLoadingSpinner extends StatelessWidget {
  const _SearchLoadingSpinner();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

int _parseInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String? _resolveLogoPath(String? logoId) => resolveTeamLogoPath(logoId);

class _SearchLogo extends StatelessWidget {
  const _SearchLogo({
    this.logoPath,
    required this.fallbackIcon,
    this.shape = _SearchImageShape.circular,
  });

  final String? logoPath;
  final IconData fallbackIcon;
  final _SearchImageShape shape;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final path = logoPath;
    final placeholder = SizedBox(
      width: 36,
      height: 36,
      child: Icon(
        fallbackIcon,
        color: colorScheme.onSurfaceVariant,
        size: 22,
      ),
    );
    final content = path == null || path.isEmpty
        ? placeholder
        : SizedBox(
            width: 36,
            height: 36,
            child: buildTeamLogo(path, size: 36),
          );

    if (shape == _SearchImageShape.roundedSquare) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: content,
      );
    }
    return ClipOval(child: content);
  }
}
