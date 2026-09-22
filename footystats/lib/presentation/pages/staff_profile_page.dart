import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_assets.dart';
import '../../core/utils/scroll_to_top.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/media_placeholders.dart';
import '../../data/repositories/leagues_repository.dart';
import '../../data/repositories/teams_repository.dart';
import '../../data/repositories/user_profile_repository.dart';
import '../../domain/models/league_model.dart';
import '../../domain/models/team_model.dart';
import '../../domain/models/user_profile.dart';
import '../providers/main_nav_scroll_provider.dart';
import '../widgets/profile/profile_page_shimmer.dart';
import '../widgets/socials_section_card.dart';
import 'edit_profile_page.dart';
import 'league_detail_page.dart';
import 'profile.dart';
import 'team_detail_page.dart';

/// Simpler profile for coaches, scouts, agents and other technical staff.
class StaffProfilePage extends ConsumerStatefulWidget {
  const StaffProfilePage({
    super.key,
    this.viewedUserId,
    this.refreshTick = 0,
  });

  /// Null means the signed-in user (Account tab).
  final String? viewedUserId;
  final int refreshTick;

  @override
  ConsumerState<StaffProfilePage> createState() => _StaffProfilePageState();
}

class _StaffProfilePageState extends ConsumerState<StaffProfilePage>
    with SingleTickerProviderStateMixin {
  final _profileRepository = UserProfileRepository();
  final _teamsRepository = TeamsRepository();
  final _leaguesRepository = LeaguesRepository();

  late final ScrollController _outerScrollController;
  late final TabController _tabController;

  bool _isHeaderCollapsed = false;
  bool _isLoading = true;
  UserProfile? _profile;
  int _followers = 0;
  List<TeamModel> _teams = const [];
  List<LeagueModel> _leagues = const [];
  Color? _heroToneA;
  Color? _heroToneB;
  Color? _heroToneC;
  String? _lastHeroImageKey;

  bool get _isOwnProfile {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return false;
    return widget.viewedUserId == null || widget.viewedUserId == uid;
  }

  String? get _userId =>
      widget.viewedUserId ?? Supabase.instance.client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _outerScrollController = ScrollController()
      ..addListener(_handleOuterScroll);
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void didUpdateWidget(covariant StaffProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewedUserId != widget.viewedUserId ||
        oldWidget.refreshTick != widget.refreshTick) {
      _load();
    }
  }

  @override
  void dispose() {
    _outerScrollController.removeListener(_handleOuterScroll);
    _outerScrollController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _handleOuterScroll() {
    final collapsed = _outerScrollController.hasClients &&
        _outerScrollController.offset > 0.5;
    if (collapsed == _isHeaderCollapsed) return;
    setState(() => _isHeaderCollapsed = collapsed);
  }

  Future<void> _load() async {
    final id = _userId;
    if (id == null || id.isEmpty) {
      setState(() => _isLoading = false);
      return;
    }
    setState(() => _isLoading = true);
    try {
      final profile = _isOwnProfile
          ? await _profileRepository.getCurrentProfile()
          : await _profileRepository.getProfileByPlayerId(id);
      final teams = await _teamsRepository.getTeamsByCreator(id);
      final leagues = await _leaguesRepository.getLeaguesByCreator(id);
      var followers = 0;
      try {
        final res = await Supabase.instance.client
            .from('user_follows')
            .select('follower_user_id')
            .eq('following_user_id', id)
            .limit(1)
            .count(CountOption.exact);
        followers = res.count;
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _teams = teams;
        _leagues = leagues;
        _followers = followers;
        _isLoading = false;
      });
      _deriveHeroColorsFromImage(profile?.imageUrl);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _openEdit() async {
    final profile = _profile;
    if (profile == null) return;
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => EditProfilePage(profile: profile)),
    );
    if (saved == true && mounted) _load();
  }

  String _formatCount(int value) {
    final safe = value < 0 ? 0 : value;
    return safe.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (m) => ',',
    );
  }

  Future<void> _deriveHeroColorsFromImage(String? imagePath) async {
    final key = imagePath?.trim().isNotEmpty == true
        ? imagePath!.trim()
        : '__profile_fallback__';
    if (_lastHeroImageKey == key && _heroToneA != null) return;
    _lastHeroImageKey = key;
    final provider =
        (imagePath != null &&
            imagePath.trim().isNotEmpty &&
            (imagePath.startsWith('http://') ||
                imagePath.startsWith('https://')))
        ? appCachedImageProvider(imagePath.trim())
        : (imagePath != null && imagePath.trim().isNotEmpty
            ? AssetImage(imagePath.trim())
            : AssetImage(AppAssets.pitchBg));
    try {
      final scheme = await ColorScheme.fromImageProvider(
        provider: provider,
        brightness: Theme.of(context).brightness,
      );
      if (!mounted || _lastHeroImageKey != key) return;
      setState(() {
        _heroToneA = Color.alphaBlend(
          scheme.primary.withValues(alpha: 0.32),
          scheme.surfaceContainerHigh,
        );
        _heroToneB = Color.alphaBlend(
          scheme.secondary.withValues(alpha: 0.24),
          scheme.surfaceContainer,
        );
        _heroToneC = Color.alphaBlend(
          scheme.tertiary.withValues(alpha: 0.22),
          scheme.surfaceContainerLow,
        );
      });
    } catch (_) {}
  }

  Future<void> _openProfilePhoto(String imageUrl) async {
    final resolved = resolvePlayerImagePath(imageUrl);
    if (resolved == null) return;
    final isNetwork =
        resolved.startsWith('http://') || resolved.startsWith('https://');
    if (isNetwork) {
      await precacheImage(playerProfileFullImageProvider(resolved), context);
    }
    if (!mounted) return;
    final userId = _userId ?? 'staff';
    Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black87,
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (context, animation, secondaryAnimation) {
          return _StaffProfilePhotoViewer(
            heroTag: 'staff-profile-photo-$userId',
            imagePath: resolved,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.viewedUserId == null) {
      ref.listen<int>(
        mainNavScrollToTopProvider.select((m) => m[MainNavTab.account] ?? 0),
        (previous, next) {
          if (previous == next) return;
          animateScrollControllerToTop(_outerScrollController);
        },
      );
    }

    if (_isLoading && _profile == null) {
      return const Padding(
        padding: EdgeInsets.only(top: 16),
        child: ProfileHeaderShimmer(),
      );
    }

    final profile = _profile;
    if (profile == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Could not load this profile.',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    final userId = _userId ?? profile.id;

    return NestedScrollView(
      controller: _outerScrollController,
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          SliverAppBar(
            pinned: true,
            primary: false,
            toolbarHeight: 0,
            expandedHeight: 240,
            elevation: 0,
            scrolledUnderElevation: 0,
            shadowColor: Colors.transparent,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              background: Builder(
                builder: (context) {
                  final settings = context
                      .dependOnInheritedWidgetOfExactType<
                        FlexibleSpaceBarSettings
                      >();
                  final minExtent = settings?.minExtent ?? kToolbarHeight;
                  final maxExtent = settings?.maxExtent ?? 240;
                  final currentExtent = settings?.currentExtent ?? maxExtent;
                  final collapseRange = (maxExtent - minExtent).clamp(
                    1.0,
                    double.infinity,
                  );
                  final t = ((currentExtent - minExtent) / collapseRange)
                      .clamp(0.0, 1.0);
                  final fadeOpacity = (0.15 + (0.85 * t)).clamp(0.0, 1.0);
                  return Opacity(
                    opacity: fadeOpacity,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: _StaffProfileHeader(
                        profile: profile,
                        followers: _followers,
                        formatCount: _formatCount,
                        showEditButton: _isOwnProfile,
                        heroTag: 'staff-profile-photo-$userId',
                        toneA: _heroToneA,
                        toneB: _heroToneB,
                        toneC: _heroToneC,
                        onEdit: _openEdit,
                        onPhotoTap: profile.imageUrl != null
                            ? () => _openProfilePhoto(profile.imageUrl!)
                            : null,
                      ),
                    ),
                  );
                },
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(kTextTabBarHeight + 2),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOut,
                decoration: BoxDecoration(
                  color: _isHeaderCollapsed
                      ? colorScheme.surface
                      : Colors.transparent,
                  border: Border(
                    bottom: BorderSide(
                      color: colorScheme.outlineVariant,
                      width: 1,
                    ),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: false,
                  tabAlignment: TabAlignment.fill,
                  labelPadding: EdgeInsets.zero,
                  indicatorPadding: EdgeInsets.zero,
                  dividerHeight: 0,
                  labelColor: colorScheme.onSurface,
                  unselectedLabelColor: colorScheme.onSurfaceVariant,
                  indicatorColor: colorScheme.primary,
                  indicatorWeight: 3,
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: 'Overview'),
                    Tab(text: 'Videos'),
                  ],
                ),
              ),
            ),
          ),
        ];
      },
      body: TabBarView(
        controller: _tabController,
        children: [
          RefreshIndicator(
            onRefresh: _load,
            child: _StaffOverviewTab(
              profile: profile,
              isOwnProfile: _isOwnProfile,
              teams: _teams,
              leagues: _leagues,
              onProfileChanged: _load,
            ),
          ),
          ProfileVideosTab(
            profilePlayerId: userId,
            isOwnProfile: _isOwnProfile,
          ),
        ],
      ),
    );
  }
}

class _StaffProfileHeader extends StatelessWidget {
  const _StaffProfileHeader({
    required this.profile,
    required this.followers,
    required this.formatCount,
    required this.showEditButton,
    required this.heroTag,
    required this.onEdit,
    this.onPhotoTap,
    this.toneA,
    this.toneB,
    this.toneC,
  });

  final UserProfile profile;
  final int followers;
  final String Function(int) formatCount;
  final bool showEditButton;
  final Object heroTag;
  final VoidCallback onEdit;
  final VoidCallback? onPhotoTap;
  final Color? toneA;
  final Color? toneB;
  final Color? toneC;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final name = profile.playerName?.trim().isNotEmpty == true
        ? profile.playerName!.trim()
        : 'Staff';
    final username = profile.username?.trim().isNotEmpty == true
        ? '@${profile.username!.trim()}'
        : '@—';
    final resolvedToneA = toneA ??
        Color.alphaBlend(
          colorScheme.primary.withValues(alpha: 0.22),
          colorScheme.surfaceContainerHigh,
        );
    final resolvedToneB = toneB ??
        Color.alphaBlend(
          colorScheme.secondary.withValues(alpha: 0.18),
          colorScheme.surfaceContainer,
        );
    final resolvedToneC = toneC ??
        Color.alphaBlend(
          colorScheme.tertiary.withValues(alpha: 0.16),
          colorScheme.surfaceContainerLow,
        );

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(28),
        topRight: Radius.circular(28),
      ),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [resolvedToneA, resolvedToneB, resolvedToneC],
            stops: const [0.0, 0.55, 1.0],
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(-0.85, -0.65),
              colors: [
                Color.alphaBlend(
                  colorScheme.primary.withValues(alpha: 0.26),
                  resolvedToneA,
                ),
                Colors.transparent,
              ],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _StaffHeroAvatar(
                      imageUrl: profile.imageUrl,
                      heroTag: heroTag,
                      onTap: onPhotoTap,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name,
                            style: textTheme.displayMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            username,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (showEditButton) ...[
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: onEdit,
                        style: FilledButton.styleFrom(
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(
                              Radius.circular(999),
                            ),
                          ),
                          padding: const EdgeInsets.only(
                            left: 17,
                            right: 17,
                            top: 12,
                            bottom: 12,
                          ),
                          minimumSize: const Size(60, 40),
                        ),
                        child: const Icon(Icons.edit_outlined, size: 20),
                      ),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _StaffActionChip(
                          icon: Icons.visibility_outlined,
                          label: profile.staffRoleLabel,
                        ),
                        const SizedBox(width: 8),
                        _StaffActionChip(
                          icon: Icons.groups_outlined,
                          label: formatCount(followers),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StaffHeroAvatar extends StatelessWidget {
  const _StaffHeroAvatar({
    this.imageUrl,
    required this.heroTag,
    this.onTap,
  });

  final String? imageUrl;
  final Object heroTag;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final resolved = resolvePlayerImagePath(imageUrl);
    final hasImage = resolved != null;

    Widget avatar = Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        shape: BoxShape.circle,
        border: Border.all(
          color: colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: ClipOval(
        child: buildPlayerAvatar(
          imagePath: hasImage ? imageUrl : null,
          size: 96,
          backgroundColor: colorScheme.surfaceContainerHighest,
          iconColor: colorScheme.onSurfaceVariant,
        ),
      ),
    );

    if (hasImage) {
      avatar = Hero(
        tag: heroTag,
        child: Material(
          color: Colors.transparent,
          child: avatar,
        ),
      );
      if (onTap != null) {
        avatar = GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: avatar,
        );
      }
    }

    return avatar;
  }
}

class _StaffActionChip extends StatelessWidget {
  const _StaffActionChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = colorScheme.onSurface;
    return ActionChip.elevated(
      avatar: Icon(icon, size: 18, color: foreground),
      label: Text(label, style: TextStyle(color: foreground)),
      onPressed: () {},
      backgroundColor: colorScheme.surfaceContainerHighest,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }
}

class _StaffOverviewTab extends StatelessWidget {
  const _StaffOverviewTab({
    required this.profile,
    required this.isOwnProfile,
    required this.teams,
    required this.leagues,
    required this.onProfileChanged,
  });

  final UserProfile profile;
  final bool isOwnProfile;
  final List<TeamModel> teams;
  final List<LeagueModel> leagues;
  final Future<void> Function() onProfileChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _StaffAboutSection(
          profile: profile,
          isOwnProfile: isOwnProfile,
          onSaved: onProfileChanged,
        ),
        const SizedBox(height: 16),
        _StaffOverviewSectionCard(
          title: isOwnProfile ? 'Teams you run' : 'Teams they run',
          child: teams.isEmpty
              ? AppEmptyState(
                  imageAsset: AppAssets.createTeamEmpty,
                  title: isOwnProfile ? 'No teams yet' : 'No teams listed',
                  subtitle: isOwnProfile
                      ? 'Create a team from the Home tab to start building a squad.'
                      : 'This account has not created a team yet.',
                )
              : Column(
                  children: [
                    for (var i = 0; i < teams.length; i++) ...[
                      _StaffEntityRow(
                        name: teams[i].displayName,
                        logoPath: teams[i].logoPath,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  TeamDetailPage(teamId: teams[i].id),
                            ),
                          );
                        },
                      ),
                      if (i < teams.length - 1) ...[
                        const SizedBox(height: 8),
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: colorScheme.outlineVariant,
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 16),
        _StaffOverviewSectionCard(
          title: isOwnProfile ? 'Leagues you run' : 'Leagues they run',
          child: leagues.isEmpty
              ? AppEmptyState(
                  imageAsset: AppAssets.createLeagueEmpty,
                  title: isOwnProfile ? 'No leagues yet' : 'No leagues listed',
                  subtitle: isOwnProfile
                      ? 'Create a league from the Home tab to organise competitions.'
                      : 'This account has not created a league yet.',
                )
              : Column(
                  children: [
                    for (var i = 0; i < leagues.length; i++) ...[
                      _StaffEntityRow(
                        name: leagues[i].leagueName,
                        logoPath: resolveTeamLogoPath(leagues[i].logoId),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => LeagueDetailPage(
                                leagueId: leagues[i].id,
                              ),
                            ),
                          );
                        },
                      ),
                      if (i < leagues.length - 1) ...[
                        const SizedBox(height: 8),
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: colorScheme.outlineVariant,
                        ),
                        const SizedBox(height: 8),
                      ],
                    ],
                  ],
                ),
        ),
        const SizedBox(height: 16),
        SocialsSectionCard(
          title: 'Socials',
          instagramUrl: profile.socialInstagram,
          tiktokUrl: profile.socialTiktok,
          xUrl: profile.socialX,
          emptyHint: isOwnProfile
              ? 'Add Instagram, TikTok or X from Edit profile.'
              : 'No social links yet.',
        ),
      ],
    );
  }
}

class _StaffAboutSection extends StatelessWidget {
  const _StaffAboutSection({
    required this.profile,
    required this.isOwnProfile,
    required this.onSaved,
  });

  final UserProfile profile;
  final bool isOwnProfile;
  final Future<void> Function() onSaved;

  String get _aboutText => profile.about?.trim() ?? '';

  Future<void> _editAbout(BuildContext context) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => _EditAboutDialog(initialText: _aboutText),
    );
    if (saved == true) await onSaved();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final about = _aboutText;

    return _StaffOverviewSectionCard(
      title: 'About',
      trailing: isOwnProfile
          ? IconButton(
              tooltip: about.isEmpty ? 'Add about' : 'Edit about',
              visualDensity: VisualDensity.compact,
              onPressed: () => _editAbout(context),
              icon: Icon(
                about.isEmpty ? Icons.add : Icons.edit_outlined,
                size: 20,
              ),
            )
          : null,
      child: about.isEmpty
          ? Text(
              isOwnProfile
                  ? 'Add a short bio so players know who you are and how you work in football.'
                  : 'No about yet.',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            )
          : Text(
              about,
              style: textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
    );
  }
}

class _EditAboutDialog extends StatefulWidget {
  const _EditAboutDialog({required this.initialText});

  final String initialText;

  @override
  State<_EditAboutDialog> createState() => _EditAboutDialogState();
}

class _EditAboutDialogState extends State<_EditAboutDialog> {
  late final TextEditingController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final profile = await UserProfileRepository().getCurrentProfile();
    if (profile == null) return;
    setState(() => _saving = true);
    try {
      await UserProfileRepository().upsertCurrentProfile(
        username: profile.username ?? '',
        playerName: profile.playerName ?? '',
        about: _controller.text,
        updateAbout: true,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save about: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('About'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        minLines: 4,
        maxLines: 8,
        maxLength: 280,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          hintText: 'Tell players who you are and how you work in football.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

class _StaffOverviewSectionCard extends StatelessWidget {
  const _StaffOverviewSectionCard({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _StaffEntityRow extends StatelessWidget {
  const _StaffEntityRow({
    required this.name,
    required this.logoPath,
    required this.onTap,
  });

  final String name;
  final String? logoPath;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: colorScheme.surfaceContainerHighest,
            child: buildTeamLogo(
              (logoPath == null || logoPath!.isEmpty) ? null : logoPath,
              size: 36,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(name, style: textTheme.bodySmall),
          ),
          Icon(
            Icons.chevron_right,
            color: colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}

class _StaffProfilePhotoViewer extends StatelessWidget {
  const _StaffProfilePhotoViewer({
    required this.heroTag,
    required this.imagePath,
  });

  final Object heroTag;
  final String imagePath;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        behavior: HitTestBehavior.opaque,
        child: Center(
          child: Hero(
            tag: heroTag,
            child: Material(
              color: Colors.transparent,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: size.width,
                  maxHeight: size.height,
                ),
                child: buildPlayerProfileFullImage(imagePath: imagePath),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
