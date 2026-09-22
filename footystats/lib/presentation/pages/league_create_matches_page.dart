import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_assets.dart';
import '../../core/widgets/app_empty_state.dart';
import 'league_add_teams_page.dart';
import '../providers/league_teams_provider.dart';
import '../providers/leagues_provider.dart';
import '../providers/matches_provider.dart';
import '../providers/seasons_provider.dart';
import '../../domain/models/league_model.dart';
import '../../domain/models/season_model.dart';
import '../../domain/models/team_model.dart';
import '../widgets/create_season_bottom_sheet.dart';
import '../widgets/fixture_autogenerate_dialog.dart';
import 'fixture.dart';

class LeagueCreateMatchesPage extends ConsumerStatefulWidget {
  const LeagueCreateMatchesPage({super.key, required this.leagueId});

  final String leagueId;

  @override
  ConsumerState<LeagueCreateMatchesPage> createState() =>
      _LeagueCreateMatchesPageState();
}

class _LeagueCreateMatchesPageState
    extends ConsumerState<LeagueCreateMatchesPage> {
  final _formKey = GlobalKey<FormState>();
  final _venueController = TextEditingController();
  final _gameweekController = TextEditingController();
  TeamModel? _teamA;
  TeamModel? _teamB;
  DateTime? _matchDate;
  TimeOfDay? _matchTime;
  SeasonModel? _season;
  bool _isSubmitting = false;
  String? _venueImageUrl;
  bool _hasInitializedFromDefaults = false;

  void _applyLeagueDefaults(LeagueModel? league) {
    if (_hasInitializedFromDefaults || league == null) return;
    final hasVenue = (league.defaultVenue ?? '').trim().isNotEmpty;
    final hasImage = (league.defaultVenueImageUrl ?? '').trim().isNotEmpty;
    if (!hasVenue && !hasImage) return;
    _hasInitializedFromDefaults = true;
    setState(() {
      if (hasVenue) _venueController.text = league.defaultVenue!;
      if (hasImage) _venueImageUrl = league.defaultVenueImageUrl;
    });
  }

  @override
  void dispose() {
    _venueController.dispose();
    _gameweekController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _matchDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date != null) setState(() => _matchDate = date);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _matchTime ?? const TimeOfDay(hour: 15, minute: 0),
    );
    if (time != null) setState(() => _matchTime = time);
  }

  Future<void> _showCreateSeasonDialog() async {
    final result = await showCreateSeasonBottomSheet(context);

    if (result == null || !mounted) return;
    final name = result['name'] as String? ?? '';
    if (name.isEmpty) return;

    try {
      final repo = ref.read(seasonsRepositoryProvider);
      await repo.createSeason(
        leagueId: widget.leagueId,
        seasonName: name,
      );
      if (!mounted) return;
      ref.invalidate(allSeasonsForLeagueProvider(widget.leagueId));
      ref.invalidate(ongoingOrUpcomingSeasonProvider(widget.leagueId));
      ref.invalidate(leagueSeasonFixtureProgressProvider(widget.leagueId));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Season created')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating season: $error')),
      );
    }
  }

  Future<void> _createMatch() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid || _teamA == null || _teamB == null || _season == null) return;
    if (_teamA!.id == _teamB!.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick two different teams')),
      );
      return;
    }
    if (_matchDate == null || _matchTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a date and time')),
      );
      return;
    }
    final venue = _venueController.text.trim();
    if (venue.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a venue')),
      );
      return;
    }
    final gwText = _gameweekController.text.trim();
    if (gwText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a gameweek')),
      );
      return;
    }
    final week = int.tryParse(gwText);
    if (week == null || week < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid gameweek')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final repo = ref.read(matchesRepositoryProvider);
      final timeStr =
          '${_matchTime!.hour.toString().padLeft(2, '0')}:${_matchTime!.minute.toString().padLeft(2, '0')}';
      final gameweekId = await repo.getOrCreateGameweek(
        seasonId: _season!.id,
        week: week,
      );
      final league = ref.read(leagueByIdProvider(widget.leagueId)).value;
      final venueImageToUse =
          league?.defaultVenueImageUrl ?? _venueImageUrl;
      final id = await repo.createMatch(
        leagueId: widget.leagueId,
        seasonId: _season!.id,
        teamAId: _teamA!.id,
        teamBId: _teamB!.id,
        matchDate: _matchDate!,
        matchTime: timeStr,
        venue: venue,
        venueImageUrl: venueImageToUse,
        gameweekId: gameweekId,
      );
      if (!mounted) return;
      ref.invalidate(matchesProvider);
      ref.invalidate(leagueSeasonFixtureProgressProvider(widget.leagueId));
      ref.invalidate(leagueByIdProvider(widget.leagueId));
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => FixturePage(matchId: id)),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Match created')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error creating match: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _showAutoGenerateDialog(List<TeamModel> teams) async {
    if (_season == null) return;

    int activeCount;
    try {
      final ids = await ref.read(
        activeTeamIdsForLeagueProvider(widget.leagueId).future,
      );
      activeCount = ids.length;
    } catch (_) {
      activeCount = teams.length;
    }

    if (activeCount < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Need at least 2 active teams (end_date IS NULL) in the league',
          ),
        ),
      );
      return;
    }

    final league = ref.read(leagueByIdProvider(widget.leagueId)).value;
    final defaultVenue = league?.defaultVenue ?? _venueController.text.trim();
    final defaultVenueImageUrl =
        league?.defaultVenueImageUrl ?? _venueImageUrl;

    final result = await FixtureAutogenerateDialog.show(
      context,
      seasonId: _season!.id,
      leagueId: widget.leagueId,
      seasonName: _season!.seasonName,
      defaultVenue: defaultVenue.isNotEmpty ? defaultVenue : null,
      defaultVenueImageUrl: defaultVenueImageUrl,
      activeTeamCount: activeCount,
    );

    if (result == null || !result.confirmed || !mounted) return;

    if (result.options.allowRegeneration) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Regenerate fixtures'),
          content: const Text(
            'This will delete all existing fixtures for this season and create new ones. Continue?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Regenerate'),
            ),
          ],
        ),
      );
      if (confirm != true || !mounted) return;
    }

    setState(() => _isSubmitting = true);
    try {
      final repo = ref.read(matchesRepositoryProvider);
      final genResult = await repo.generateFixtures(result.options);
      if (!mounted) return;
      if (genResult.success) {
        ref.invalidate(matchesProvider);
        ref.invalidate(leagueSeasonFixtureProgressProvider(widget.leagueId));
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${genResult.matchesCreated} matches in ${genResult.gameweeksCreated} gameweeks created',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(genResult.errorMessage ?? 'Generation failed')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating fixtures: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final teamsAsync = ref.watch(teamsInLeagueProvider(widget.leagueId));
    final seasonAsync =
        ref.watch(ongoingOrUpcomingSeasonProvider(widget.leagueId));
    ref.listen<AsyncValue<LeagueModel?>>(
      leagueByIdProvider(widget.leagueId),
      (_, next) {
        next.whenData((league) {
          if (league != null) _applyLeagueDefaults(league);
        });
      },
    );
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Create match', style: textTheme.headlineMedium),
        centerTitle: false,
      ),
      body: teamsAsync.when(
        data: (teams) {
          if (teams.length < 2) {
            return Center(
              child: AppEmptyState(
                imageAsset: AppAssets.twoTeamsEmpty,
                title: 'Add more teams first',
                subtitle:
                    'You need at least two teams in this league before you can schedule a match.',
                actionLabel: 'Add teams',
                onAction: () async {
                  await Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          LeagueAddTeamsPage(leagueId: widget.leagueId),
                    ),
                  );
                  ref.invalidate(teamsInLeagueProvider(widget.leagueId));
                },
              ),
            );
          }
          return seasonAsync.when(
            data: (season) {
              if (season == null) {
                return Center(
                  child: AppEmptyState(
                    imageAsset: AppAssets.seasonEmpty,
                    title: 'Create a season first',
                    subtitle:
                        'You need a season in this league before you can schedule matches. Create one to get started.',
                    actionLabel: 'Create season',
                    onAction: _showCreateSeasonDialog,
                  ),
                );
              }
              if (_season == null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) setState(() => _season = season);
                });
              }
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Match details', style: textTheme.titleMedium),
                          const SizedBox(height: 8),
                          Text(
                            'Season: ${season.seasonName}',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _gameweekController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Gameweek',
                              hintText: 'e.g. 1',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Enter a gameweek';
                              }
                              final w = int.tryParse(value.trim());
                              if (w == null || w < 1) {
                                return 'Enter a positive integer';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<TeamModel>(
                            initialValue: _teamA,
                            items: teams
                                .map(
                                  (t) => DropdownMenuItem(
                                    value: t,
                                    child: Text(t.displayName),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) =>
                                setState(() => _teamA = value),
                            decoration: const InputDecoration(
                              labelText: 'Team A',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) =>
                                value == null ? 'Select Team A' : null,
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<TeamModel>(
                            initialValue: _teamB,
                            items: teams
                                .map(
                                  (t) => DropdownMenuItem(
                                    value: t,
                                    child: Text(t.displayName),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) =>
                                setState(() => _teamB = value),
                            decoration: const InputDecoration(
                              labelText: 'Team B',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) =>
                                value == null ? 'Select Team B' : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _venueController,
                            decoration: const InputDecoration(
                              labelText: 'Venue',
                              hintText: 'e.g. Main Stadium',
                              border: OutlineInputBorder(),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Enter a venue';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          Text('Default background', style: textTheme.labelLarge),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              (_venueImageUrl ?? '').isNotEmpty
                                  ? 'Using league default match background image'
                                  : 'No league default background set yet. League owner can add it from league details.',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _pickDate,
                                  child: Text(
                                    _matchDate == null
                                        ? 'Pick date'
                                        : '${_matchDate!.year}-${_matchDate!.month.toString().padLeft(2, '0')}-${_matchDate!.day.toString().padLeft(2, '0')}',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _pickTime,
                                  child: Text(
                                    _matchTime == null
                                        ? 'Pick time'
                                        : _matchTime!.format(context),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _isSubmitting ? null : _createMatch,
                              child: _isSubmitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Create match'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: _isSubmitting
                          ? null
                          : () => _showAutoGenerateDialog(teams),
                      icon: const Icon(Icons.auto_awesome),
                      label: const Text('Auto-generate fixtures'),
                    ),
                  ],
                ),
              );
            },
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
