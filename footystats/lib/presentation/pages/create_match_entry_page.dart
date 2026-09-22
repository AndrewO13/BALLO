import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants/app_assets.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/media_placeholders.dart';
import 'create_team_league_page.dart';
import 'league_create_matches_page.dart';

/// Entry page for "Create match" from Add to matches. User selects a league
/// (must be admin) then navigates to LeagueCreateMatchesPage.
class CreateMatchEntryPage extends StatefulWidget {
  const CreateMatchEntryPage({super.key});

  @override
  State<CreateMatchEntryPage> createState() => _CreateMatchEntryPageState();
}

class _CreateMatchEntryPageState extends State<CreateMatchEntryPage> {
  List<Map<String, dynamic>> _leagues = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLeagues();
  }

  Future<void> _loadLeagues() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }
      final res = await supabase
          .from('leagues')
          .select('id, league_name, logo_id')
          .eq('created_by', user.id)
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _leagues = List<Map<String, dynamic>>.from(res);
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading leagues: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Create match', style: textTheme.headlineMedium),
        centerTitle: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _leagues.isEmpty
              ? Center(
                  child: AppEmptyState(
                    imageAsset: AppAssets.createLeagueEmpty,
                    title: 'Create a league first',
                    subtitle:
                        'You need a league you manage before you can schedule matches.',
                    actionLabel: 'Create league',
                    onAction: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const CreateLeaguePage(),
                        ),
                      );
                      _loadLeagues();
                    },
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadLeagues,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _leagues.length,
                    itemBuilder: (context, index) {
                      final league = _leagues[index];
                      final name =
                          league['league_name'] as String? ?? 'Unknown';
                      final logoUrl = league['logo_id'] as String?;
                      final leagueId = league['id'] as String? ?? '';
                      return Card(
                        clipBehavior: Clip.hardEdge,
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => LeagueCreateMatchesPage(
                                  leagueId: leagueId,
                                ),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor:
                                      colorScheme.surfaceContainerHighest,
                                  backgroundImage: logoUrl != null &&
                                          (logoUrl.startsWith('http://') ||
                                              logoUrl.startsWith('https://'))
                                      ? appCachedImageProvider(logoUrl)
                                      : null,
                                  child: logoUrl == null ||
                                          (!logoUrl.startsWith('http') &&
                                              !logoUrl.startsWith('https'))
                                      ? Icon(
                                          Icons.emoji_events,
                                          color: colorScheme.onSurfaceVariant,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Text(
                                    name,
                                    style: textTheme.titleMedium,
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
