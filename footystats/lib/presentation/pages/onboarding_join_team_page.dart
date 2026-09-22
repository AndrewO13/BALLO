import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/onboarding/onboarding_completion.dart';
import '../../core/constants/onboarding_steps.dart';
import '../../core/widgets/media_placeholders.dart';
import '../../data/repositories/teams_repository.dart';
import '../../data/repositories/user_profile_repository.dart';
import '../../domain/models/onboarding_draft.dart';
import '../widgets/onboarding_step_scaffold.dart';
import 'create_team_league_page.dart';
import 'home_page.dart';

class OnboardingJoinTeamPage extends StatefulWidget {
  const OnboardingJoinTeamPage({super.key, required this.draft});

  final OnboardingDraft draft;

  @override
  State<OnboardingJoinTeamPage> createState() => _OnboardingJoinTeamPageState();
}

class _OnboardingJoinTeamPageState extends State<OnboardingJoinTeamPage> {
  final _teamsRepository = TeamsRepository();
  final _searchController = TextEditingController();

  List<SuggestedTeamListing> _teams = [];
  final Set<String> _requestedTeamIds = {};
  final Set<String> _joinedTeamIds = {};
  String? _joiningTeamId;
  bool _isLoading = true;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    var skip = widget.draft.isTechnicalStaff;
    if (!skip) {
      try {
        final profile = await UserProfileRepository().getCurrentProfile();
        skip = profile?.isTechnicalStaff == true;
      } catch (_) {}
    }
    if (!mounted) return;
    if (skip) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _finishOnboarding();
      });
      return;
    }
    _loadTeams();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  String? get _playerId => Supabase.instance.client.auth.currentUser?.id;

  Future<void> _loadTeams({String? query}) async {
    setState(() => _isLoading = true);
    try {
      final listings = query == null || query.trim().isEmpty
          ? await _teamsRepository.getSuggestedTeams(
              excludePlayerId: _playerId,
            )
          : await _teamsRepository.searchTeamsForOnboarding(
              query,
              excludePlayerId: _playerId,
            );
      if (!mounted) return;
      setState(() => _teams = listings);
    } catch (_) {
      if (!mounted) return;
      setState(() => _teams = []);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _loadTeams(query: _searchController.text);
    });
  }

  Future<void> _joinTeam(SuggestedTeamListing listing) async {
    final playerId = _playerId;
    if (playerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be signed in to join a team')),
      );
      return;
    }

    final teamId = listing.team.id;
    if (_joiningTeamId != null ||
        _requestedTeamIds.contains(teamId) ||
        _joinedTeamIds.contains(teamId)) {
      return;
    }

    setState(() => _joiningTeamId = teamId);
    try {
      await _teamsRepository.sendTeamJoinRequest(
        playerId: playerId,
        teamId: teamId,
      );
      if (!mounted) return;
      setState(() => _requestedTeamIds.add(teamId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Join request sent to ${listing.team.displayName}'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not join team: $error')),
      );
    } finally {
      if (mounted) setState(() => _joiningTeamId = null);
    }
  }

  void _openCreateTeam() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateTeamPage(
          onTeamCreated: (teamId) {
            setState(() => _joinedTeamIds.add(teamId));
          },
        ),
      ),
    );
  }

  Future<void> _finishOnboarding() async {
    await OnboardingCompletion.markComplete();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomePage()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final isSearching = _searchController.text.trim().isNotEmpty;

    return OnboardingStepScaffold(
      step: OnboardingStep.joinTeam,
      accountType: widget.draft.accountType,
      title: "It's not a solo sport",
      subtitle:
          'Join a squad to unlock match stats, league standings, and team comparisons with your mates.',
      actions: [
        TextButton(
          onPressed: _finishOnboarding,
          child: Text('Skip', style: TextStyle(color: colorScheme.onSurface)),
        ),
      ],
      bottomBar: OnboardingContinueButton(
        label: 'Continue',
        onPressed: _finishOnboarding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Find your team',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search teams on Ballo',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.55),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isSearching ? 'Search results' : 'Suggested teams',
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_teams.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                children: [
                  Icon(
                    Icons.groups_outlined,
                    size: 48,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isSearching
                        ? 'No teams match your search'
                        : 'No suggested teams yet',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _teams.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final listing = _teams[index];
                return _SuggestedTeamTile(
                  listing: listing,
                  isJoining: _joiningTeamId == listing.team.id,
                  isRequested: _requestedTeamIds.contains(listing.team.id),
                  isJoined: _joinedTeamIds.contains(listing.team.id),
                  onJoin: () => _joinTeam(listing),
                );
              },
            ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _openCreateTeam,
            icon: const Icon(Icons.add),
            label: const Text('Create a new team'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              side: BorderSide(color: colorScheme.primary),
              foregroundColor: colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _SuggestedTeamTile extends StatelessWidget {
  const _SuggestedTeamTile({
    required this.listing,
    required this.isJoining,
    required this.isRequested,
    required this.isJoined,
    required this.onJoin,
  });

  final SuggestedTeamListing listing;
  final bool isJoining;
  final bool isRequested;
  final bool isJoined;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final team = listing.team;
    final memberLabel = listing.memberCount == 1
        ? '1 player'
        : '${listing.memberCount} players';

    final joinLabel = isJoined
        ? 'Created'
        : isRequested
            ? 'Requested'
            : 'Join';

    return Material(
      color: colorScheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: buildTeamLogo(
                team.logoPath,
                size: 52,
                placeholderIconColor: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    team.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    team.shortForm,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Active squad · $memberLabel',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 92,
              child: OutlinedButton(
                onPressed: (isJoining || isRequested || isJoined) ? null : onJoin,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  side: BorderSide(
                    color: isRequested || isJoined
                        ? colorScheme.outlineVariant
                        : colorScheme.primary,
                  ),
                  foregroundColor: isRequested || isJoined
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.primary,
                ),
                child: isJoining
                    ? SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: colorScheme.primary,
                        ),
                      )
                    : Text(
                        joinLabel,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
