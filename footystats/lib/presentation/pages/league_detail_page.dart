import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LeagueDetailPage extends StatefulWidget {
  const LeagueDetailPage({
    super.key,
    required this.leagueId,
  });

  final String leagueId;

  @override
  State<LeagueDetailPage> createState() => _LeagueDetailPageState();
}

class _LeagueDetailPageState extends State<LeagueDetailPage> {
  Map<String, dynamic>? _league;
  bool _isLoading = true;
  bool _isDeleting = false;

  @override
  void initState() {
    super.initState();
    _loadLeague();
  }

  Future<void> _loadLeague() async {
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('leagues')
          .select()
          .eq('id', widget.leagueId)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          _league = response;
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('League not found')),
        );
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading league: $error')),
      );
    }
  }

  Future<void> _deleteLeague() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete League'),
        content: const Text(
          'Are you sure you want to delete this league? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('leagues').delete().eq('id', widget.leagueId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('League deleted')),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting league: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'League Details',
            style: textTheme.headlineMedium,
          ),
          centerTitle: false,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_league == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            'League Details',
            style: textTheme.headlineMedium,
          ),
          centerTitle: false,
        ),
        body: const Center(child: Text('League not found')),
      );
    }

    final leagueName = _league!['league_name'] as String? ?? 'Unknown';
    final logoUrl = _league!['logo_id'] as String?;
    final createdAt = _league!['created_at'];
    final createdAtDt = createdAt is DateTime
        ? createdAt
        : (createdAt is String ? DateTime.tryParse(createdAt) : null);
    final estYear = createdAtDt?.year ?? DateTime.now().year;
    final seasonOngoing =
        (_league?['season_started'] as bool?) ?? false; // heuristic / TODO
    final seasonActionLabel = seasonOngoing ? 'End season' : 'Start season';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          leagueName,
          style: textTheme.headlineMedium,
        ),
        centerTitle: false,
        actions: [
          if (_isDeleting)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'More options',
              onSelected: (value) {
                switch (value) {
                  case 'create_match':
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Create matches between league teams (coming soon)',
                        ),
                      ),
                    );
                    break;
                  case 'manage_applications':
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Manage team applications (coming soon)',
                        ),
                      ),
                    );
                    break;
                  case 'add_teams':
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Search and add teams to this league (coming soon)',
                        ),
                      ),
                    );
                    break;
                  case 'toggle_season':
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          seasonOngoing
                              ? 'Ending season (not yet implemented)'
                              : 'Starting season (not yet implemented)',
                        ),
                      ),
                    );
                    break;
                  case 'delete':
                    _deleteLeague();
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem<String>(
                  value: 'create_match',
                  child: Text('Create matches'),
                ),
                const PopupMenuItem<String>(
                  value: 'manage_applications',
                  child: Text('Manage applications'),
                ),
                const PopupMenuItem<String>(
                  value: 'add_teams',
                  child: Text('Add teams to league'),
                ),
                PopupMenuItem<String>(
                  value: 'toggle_season',
                  child: Text(seasonActionLabel),
                ),
                PopupMenuItem<String>(
                  value: 'delete',
                  child: Text(
                    'Delete league',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: DefaultTabController(
        length: 7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Column(
                children: [
                  // Header (logo + name + est. year)
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHigh,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(28),
                        topRight: Radius.circular(28),
                        bottomLeft: Radius.circular(0),
                        bottomRight: Radius.circular(0),
                      ),
                    ),
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
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
                          child: logoUrl != null && logoUrl.isNotEmpty
                              ? ClipOval(
                                  child: Image.network(
                                    logoUrl,
                                    width: 96,
                                    height: 96,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) {
                                      return Icon(
                                        Icons.emoji_events,
                                        size: 44,
                                        color: colorScheme.onSurfaceVariant,
                                      );
                                    },
                                  ),
                                )
                              : Icon(
                                  Icons.emoji_events,
                                  size: 44,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                leagueName,
                                style: textTheme.titleLarge,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Est. $estYear',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Tab bar (0 spacing, same background as header)
                  Container(
                    width: double.infinity,
                    color: colorScheme.surfaceContainerHigh,
                    child: TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      dividerColor: Colors.transparent,
                      labelColor: colorScheme.onSurface,
                      unselectedLabelColor: colorScheme.onSurfaceVariant,
                      indicatorColor: colorScheme.primary,
                      tabs: const [
                        Tab(text: 'Overview'),
                        Tab(text: 'Matches'),
                        Tab(text: 'Standings'),
                        Tab(text: 'Team stats'),
                        Tab(text: 'Player stats'),
                        Tab(text: 'Teams'),
                        Tab(text: 'Videos'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: const [
                  _LeagueTabPlaceholder(title: 'Overview'),
                  _LeagueTabPlaceholder(title: 'Matches'),
                  _LeagueTabPlaceholder(title: 'Standings'),
                  _LeagueTabPlaceholder(title: 'Team stats'),
                  _LeagueTabPlaceholder(title: 'Player stats'),
                  _LeagueTabPlaceholder(title: 'Teams'),
                  _LeagueTabPlaceholder(title: 'Videos'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
class _LeagueTabPlaceholder extends StatelessWidget {
  const _LeagueTabPlaceholder({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Text(
        '$title (coming soon)',
        style: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
