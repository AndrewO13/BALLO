import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/adaptive/adaptive.dart';
import '../../core/constants/countries.dart';
import '../../core/utils/dismiss_keyboard.dart';
import '../../core/widgets/media_placeholders.dart';
import '../../data/repositories/players_repository.dart';
import '../../domain/models/league_model.dart';
import '../../domain/models/team_model.dart';
import '../providers/favourited_leagues_provider.dart';
import '../providers/favourited_players_provider.dart';
import '../providers/favourited_teams_provider.dart';
import '../widgets/onboarding_step_scaffold.dart';
import 'home_page.dart';
import 'league_detail_page.dart';
import 'player_profile_page.dart';
import 'team_detail_page.dart';
import '../../core/theme/app_shape.dart';

enum _PickCategory { all, teams, competitions, players }

enum _LogoShape { circular, roundedSquare }

/// First screen after guest sign-in: follow teams, competitions, and players
/// before entering the app.
class GuestAddFavouritesPage extends ConsumerStatefulWidget {
  const GuestAddFavouritesPage({super.key});

  @override
  ConsumerState<GuestAddFavouritesPage> createState() =>
      _GuestAddFavouritesPageState();
}

class _GuestAddFavouritesPageState
    extends ConsumerState<GuestAddFavouritesPage> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  final List<_PickItem> _suggestions = [];
  final Map<String, List<_PickItem>> _cache = {};
  Timer? _debounce;
  bool _isLoading = false;
  String _lastQuery = '';
  String? _errorMessage;
  int _requestId = 0;
  _PickCategory _category = _PickCategory.all;
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
    _loadPopularContent();
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

  bool get _showTeams =>
      _controller.text.trim().isEmpty &&
      (_category == _PickCategory.all || _category == _PickCategory.teams);

  bool get _showCompetitions =>
      _controller.text.trim().isEmpty &&
      (_category == _PickCategory.all ||
          _category == _PickCategory.competitions);

  bool get _showPlayers =>
      _controller.text.trim().isEmpty &&
      (_category == _PickCategory.all || _category == _PickCategory.players);

  Future<void> _loadPopularContent() async {
    setState(() {
      _loadingPopularTeams = true;
      _loadingPopularLeagues = true;
      _loadingPopularPlayers = true;
    });
    try {
      final teams = await ref.read(teamsRepositoryProvider).getPopularTeams();
      final leagues = await ref
          .read(leaguesRepositoryProvider)
          .getPopularLeagues();
      final players = await ref
          .read(playersRepositoryProvider)
          .getPopularPlayers();
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
          _category == _PickCategory.all ||
          _category == _PickCategory.competitions;
      final includeTeams =
          _category == _PickCategory.all || _category == _PickCategory.teams;
      final includePlayers =
          _category == _PickCategory.all || _category == _PickCategory.players;

      final leagues = <_PickItem>[];
      if (includeLeagues) {
        final leaguesRes = await supabase
            .from('leagues')
            .select('id, league_name, logo_id, country')
            .ilike('league_name', '%$query%')
            .limit(10);
        leagues.addAll(
          (leaguesRes as List)
              .map(
                (e) => _PickItem(
                  id: (e['id'] ?? '').toString(),
                  label: (e['league_name'] ?? '').toString(),
                  type: 'League',
                  logoPath: resolveTeamLogoPath(e['logo_id']?.toString()),
                  logoId: e['logo_id']?.toString(),
                  country: e['country']?.toString(),
                  subtitle: _leagueSubtitle(e['country']?.toString()),
                ),
              )
              .where((item) => item.label.isNotEmpty),
        );
      }

      final teams = <_PickItem>[];
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
                return _PickItem(
                  id: (e['id'] ?? '').toString(),
                  label: (e['team_name'] ?? '').toString(),
                  type: 'Team',
                  logoId: e['logo_id']?.toString(),
                  logoPath: resolveTeamLogoPath(e['logo_id']?.toString()),
                  shortForm: shortForm,
                  subtitle: shortForm.isNotEmpty
                      ? '$shortForm | Football'
                      : 'Team | Football',
                  favouriteCount: _parseCount(e['favourite_count']),
                );
              })
              .where((item) => item.label.isNotEmpty),
        );
      }

      final players = <_PickItem>[];
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
          (playersRes as List)
              .map((e) {
                final model = PlayerSearchModel.fromJson(
                  Map<String, dynamic>.from(e as Map),
                );
                return _PickItem(
                  id: model.id,
                  label: model.displayName,
                  type: 'Player',
                  avatarUrl: model.imageUrl,
                  position: model.position,
                  subtitle: model.subtitle,
                  favouriteCount: model.favouriteCount,
                );
              })
              .where((item) => item.id.isNotEmpty),
        );
      }

      final combined = [...teams, ...leagues, ...players];
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

  void _setCategory(_PickCategory category) {
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

  void _openItem(_PickItem item) {
    _focusNode.unfocus();
    dismissKeyboard();
    if (item.type == 'League') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => LeagueDetailPage(leagueId: item.id),
        ),
      );
    } else if (item.type == 'Player') {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PlayerProfilePage(playerId: item.id),
        ),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TeamDetailPage(teamId: item.id),
        ),
      );
    }
  }

  Future<void> _toggleLeagueFavourite(LeagueModel league) async {
    await ref
        .read(favouritedLeaguesProvider.notifier)
        .toggle(FavouritedLeague.fromLeagueModel(league));
  }

  Future<void> _togglePlayerFavourite(PlayerSearchModel player) async {
    await ref
        .read(favouritedPlayersProvider.notifier)
        .toggle(FavouritedPlayer.fromSearchModel(player));
  }

  Future<void> _toggleTeamFavourite(TeamModel team) async {
    await ref
        .read(favouritedTeamsProvider.notifier)
        .toggle(FavouritedTeam.fromTeamModel(team));
  }

  void _finish() {
    dismissKeyboard();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const HomePage()),
      (route) => false,
    );
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
        automaticallyImplyLeading: false,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'Add favourites',
          style: textTheme.headlineMedium,
        ),
        actions: [
          TextButton(onPressed: _finish, child: const Text('Skip')),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                children: [
                  Text.rich(
                    TextSpan(
                      style: textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                      children: [
                        const TextSpan(text: 'Tap '),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Icon(
                            Icons.star_outline_rounded,
                            size: 18,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const TextSpan(
                          text:
                              ' to follow your favourite teams, competitions and players. These will appear in your favourites tab.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Search',
                      filled: true,
                      fillColor: colorScheme.surfaceContainerHigh,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: AppShape.fullRadius,
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
                  const SizedBox(height: 16),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _CategoryChip(
                          label: 'All',
                          selected: _category == _PickCategory.all,
                          onTap: () => _setCategory(_PickCategory.all),
                        ),
                        const SizedBox(width: 8),
                        _CategoryChip(
                          label: 'Teams',
                          selected: _category == _PickCategory.teams,
                          onTap: () => _setCategory(_PickCategory.teams),
                        ),
                        const SizedBox(width: 8),
                        _CategoryChip(
                          label: 'Competitions',
                          selected: _category == _PickCategory.competitions,
                          onTap: () => _setCategory(_PickCategory.competitions),
                        ),
                        const SizedBox(width: 8),
                        _CategoryChip(
                          label: 'Players',
                          selected: _category == _PickCategory.players,
                          onTap: () => _setCategory(_PickCategory.players),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_isLoading)
                    const _LoadingSpinner()
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
                          child: _EntityCard(
                            title: item.label,
                            subtitle: item.subtitle ?? item.type,
                            logoPath: item.logoPath,
                            avatarUrl: item.avatarUrl,
                            logoShape: item.type == 'League'
                                ? _LogoShape.roundedSquare
                                : _LogoShape.circular,
                            fallbackIcon: switch (item.type) {
                              'League' => Icons.emoji_events,
                              'Player' => Icons.person,
                              _ => Icons.groups,
                            },
                            isStarred: switch (item.type) {
                              'League' => favouritedLeagueIds.contains(item.id),
                              'Player' => favouritedPlayerIds.contains(item.id),
                              _ => favouritedTeamIds.contains(item.id),
                            },
                            onTap: () => _openItem(item),
                            onStarTap: () {
                              switch (item.type) {
                                case 'League':
                                  ref
                                      .read(favouritedLeaguesProvider.notifier)
                                      .toggle(
                                        FavouritedLeague(
                                          id: item.id,
                                          name: item.label,
                                          country: item.country,
                                          logoId: item.logoId,
                                        ),
                                      );
                                case 'Player':
                                  ref
                                      .read(favouritedPlayersProvider.notifier)
                                      .toggle(
                                        FavouritedPlayer(
                                          id: item.id,
                                          name: item.label,
                                          imageUrl: item.avatarUrl,
                                          position: item.position,
                                          favouriteCount:
                                              item.favouriteCount ?? 0,
                                        ),
                                      );
                                default:
                                  ref
                                      .read(favouritedTeamsProvider.notifier)
                                      .toggle(
                                        FavouritedTeam(
                                          id: item.id,
                                          name: item.label,
                                          shortForm: item.shortForm,
                                          logoId: item.logoId,
                                          favouriteCount:
                                              item.favouriteCount ?? 0,
                                        ),
                                      );
                              }
                            },
                          ),
                        ),
                      ),
                  ] else ...[
                    if (_showTeams)
                      _Section(
                        title: 'Teams',
                        loading: _loadingPopularTeams,
                        emptyLabel: 'No teams yet',
                        children: [
                          for (final team in _popularTeams)
                            _EntityCard(
                              title: team.displayName,
                              subtitle: team.shortForm.trim().isNotEmpty
                                  ? '${team.shortForm.trim()} | Football'
                                  : 'Team | Football',
                              logoPath: resolveTeamLogoPath(team.logoId),
                              fallbackIcon: Icons.groups,
                              isStarred: favouritedTeamIds.contains(team.id),
                              onTap: () {
                                _focusNode.unfocus();
                                dismissKeyboard();
                                Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        TeamDetailPage(teamId: team.id),
                                  ),
                                );
                              },
                              onStarTap: () => _toggleTeamFavourite(team),
                            ),
                        ],
                      ),
                    if (_showCompetitions)
                      _Section(
                        title: 'Competitions',
                        loading: _loadingPopularLeagues,
                        emptyLabel: 'No competitions yet',
                        children: [
                          for (final league in _popularLeagues)
                            _EntityCard(
                              title: league.leagueName,
                              subtitle: _leagueSubtitle(league.country),
                              logoPath: resolveTeamLogoPath(league.logoId),
                              logoShape: _LogoShape.roundedSquare,
                              fallbackIcon: Icons.emoji_events,
                              isStarred: favouritedLeagueIds.contains(
                                league.id,
                              ),
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
                        ],
                      ),
                    if (_showPlayers)
                      _Section(
                        title: 'Players',
                        loading: _loadingPopularPlayers,
                        emptyLabel: 'No players yet',
                        children: [
                          for (final player in _popularPlayers)
                            _EntityCard(
                              title: player.displayName,
                              subtitle: player.subtitle,
                              avatarUrl: player.imageUrl,
                              fallbackIcon: Icons.person,
                              isStarred: favouritedPlayerIds.contains(
                                player.id,
                              ),
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
                        ],
                      ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppResponsive.horizontalInset(context, design: 24),
                8 * AppResponsive.layoutScaleOf(context),
                AppResponsive.horizontalInset(context, design: 24),
                16 * AppResponsive.layoutScaleOf(context),
              ),
              child: OnboardingContinueButton(
                label: 'Next',
                onPressed: _finish,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.loading,
    required this.emptyLabel,
    required this.children,
  });

  final String title;
  final bool loading;
  final String emptyLabel;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              title,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (loading)
            const _LoadingSpinner()
          else if (children.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                emptyLabel,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            ...children.map(
              (child) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: child,
              ),
            ),
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
      color: selected
          ? colorScheme.onSurface
          : colorScheme.surfaceContainerHigh,
      borderRadius: AppShape.fullRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppShape.fullRadius,
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

class _EntityCard extends StatelessWidget {
  const _EntityCard({
    required this.title,
    required this.subtitle,
    this.logoPath,
    this.avatarUrl,
    this.logoShape = _LogoShape.circular,
    required this.fallbackIcon,
    required this.isStarred,
    required this.onTap,
    required this.onStarTap,
  });

  final String title;
  final String subtitle;
  final String? logoPath;
  final String? avatarUrl;
  final _LogoShape logoShape;
  final IconData fallbackIcon;
  final bool isStarred;
  final VoidCallback onTap;
  final VoidCallback onStarTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Material(
      color: colorScheme.surfaceContainerHigh,
      borderRadius: AppShape.mediumRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppShape.mediumRadius,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
          child: Row(
            children: [
              if (avatarUrl != null)
                buildPlayerAvatar(imagePath: avatarUrl, size: 40)
              else
                _Logo(
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
                        fontWeight: FontWeight.w700,
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

class _Logo extends StatelessWidget {
  const _Logo({
    this.logoPath,
    required this.fallbackIcon,
    this.shape = _LogoShape.circular,
  });

  final String? logoPath;
  final IconData fallbackIcon;
  final _LogoShape shape;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final path = logoPath;
    final placeholder = SizedBox(
      width: 40,
      height: 40,
      child: Icon(fallbackIcon, color: colorScheme.onSurfaceVariant, size: 22),
    );
    final content = path == null || path.isEmpty
        ? placeholder
        : SizedBox(width: 40, height: 40, child: buildTeamLogo(path, size: 40));

    if (shape == _LogoShape.roundedSquare) {
      return ClipRRect(borderRadius: AppShape.smallRadius, child: content);
    }
    return ClipOval(child: content);
  }
}

class _LoadingSpinner extends StatelessWidget {
  const _LoadingSpinner();

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

class _PickItem {
  const _PickItem({
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
  if (code == null || code.isEmpty) return 'Competition | Football';
  return '${countryCodeToFlag(code)} ${countryCodeToName(code)} | Football';
}

int _parseCount(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
