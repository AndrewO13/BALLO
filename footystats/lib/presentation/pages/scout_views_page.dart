import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../core/constants/app_assets.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/media_placeholders.dart';
import '../../data/repositories/profile_scout_views_repository.dart';
import '../../domain/models/scout_profile_viewer.dart';
import 'player_profile_page.dart';

/// Lists scouts who have viewed the signed-in user's profile.
class ScoutViewsPage extends StatefulWidget {
  const ScoutViewsPage({super.key});

  @override
  State<ScoutViewsPage> createState() => _ScoutViewsPageState();
}

class _ScoutViewsPageState extends State<ScoutViewsPage> {
  final _repository = ProfileScoutViewsRepository();
  late Future<List<ScoutProfileViewer>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repository.listViewersOfCurrentUser();
    unawaited(_repository.markAllSeenForCurrentUser());
  }

  Future<void> _reload() async {
    setState(() {
      _future = _repository.listViewersOfCurrentUser();
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scout views'),
      ),
      body: FutureBuilder<List<ScoutProfileViewer>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final viewers = snapshot.data ?? const <ScoutProfileViewer>[];
          if (viewers.isEmpty) {
            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 48),
                  AppEmptyState(
                    imageAsset: AppAssets.emptyMailEmpty,
                    title: 'No scout visits yet',
                    subtitle:
                        'Scouts who view your profile will show up here. Keep playing — the right eyes will find you.',
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              itemCount: viewers.length + 1,
              separatorBuilder: (_, index) {
                if (index == 0) return const SizedBox(height: 16);
                return const SizedBox(height: 8);
              },
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Text(
                    'Scouts who turned on viewer history and looked at your page may appear here. You can see when they last visited.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  );
                }
                final viewer = viewers[index - 1];
                return ListTile(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            PlayerProfilePage(playerId: viewer.id),
                      ),
                    );
                  },
                  tileColor: colorScheme.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  leading: ClipOval(
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: buildPlayerAvatar(
                        imagePath: viewer.imageUrl,
                        size: 48,
                      ),
                    ),
                  ),
                  title: Text(
                    viewer.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    [
                      if (viewer.handle.isNotEmpty) viewer.handle,
                      _relativeTime(viewer.lastViewedAt),
                    ].join(' · '),
                  ),
                  trailing: FaIcon(
                    FontAwesomeIcons.shoePrints,
                    size: 16,
                    color: colorScheme.onSurfaceVariant,
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _relativeTime(DateTime time) {
    final local = time.toLocal();
    final diff = DateTime.now().difference(local);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${local.day}/${local.month}/${local.year}';
  }
}
