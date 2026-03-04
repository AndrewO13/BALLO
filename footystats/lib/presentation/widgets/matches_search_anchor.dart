import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants/app_assets.dart';
import '../pages/league_detail_page.dart';
import '../pages/team_detail_page.dart';

/// SearchAnchor that opens from an IconButton (like the Flutter SearchAnchor sample).
/// Tapping the search icon opens the full-screen search view with suggestions.
class MatchesSearchAnchor extends StatefulWidget {
  const MatchesSearchAnchor({super.key});

  @override
  State<MatchesSearchAnchor> createState() => _MatchesSearchAnchorState();
}

class _MatchesSearchAnchorState extends State<MatchesSearchAnchor> {
  late final SearchController _controller;
  final List<_SearchItem> _suggestions = [];
  final Map<String, List<_SearchItem>> _cache = {};
  Timer? _debounce;
  bool _isLoading = false;
  String _lastQuery = '';
  String? _errorMessage;
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    _controller = SearchController();
    _controller.addListener(_handleControllerChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.removeListener(_handleControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    _onQueryChanged(_controller.text);
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
      _controller.openView();
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

    if (_cache.containsKey(trimmed)) {
      setState(() {
        _suggestions
          ..clear()
          ..addAll(_cache[trimmed]!);
        _isLoading = false;
        _errorMessage = null;
      });
      _controller.openView();
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 250), () {
      _fetchSuggestions(trimmed);
    });
  }

  Future<void> _fetchSuggestions(String query) async {
    final requestId = ++_requestId;
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final leaguesRes = await supabase
          .from('leagues')
          .select('id, league_name, logo_id')
          .ilike('league_name', '%$query%')
          .limit(10);
      final teamsRes = await supabase
          .from('teams')
          .select('id, team_name, logo_id')
          .ilike('team_name', '%$query%')
          .limit(10);

      final leagues = (leaguesRes as List)
          .map(
            (e) => _SearchItem(
              id: (e['id'] ?? '').toString(),
              label: (e['league_name'] ?? '').toString(),
              type: 'League',
              logoPath: _resolveLogoPath(e['logo_id']?.toString()),
            ),
          )
          .where((item) => item.label.isNotEmpty)
          .toList();
      final teams = (teamsRes as List)
          .map(
            (e) => _SearchItem(
              id: (e['id'] ?? '').toString(),
              label: (e['team_name'] ?? '').toString(),
              type: 'Team',
              logoPath: _resolveLogoPath(e['logo_id']?.toString()),
            ),
          )
          .where((item) => item.label.isNotEmpty)
          .toList();

      final combined = [...leagues, ...teams];
      _cache[query] = combined;
      if (!mounted || _lastQuery != query || requestId != _requestId) return;
      setState(() {
        _suggestions
          ..clear()
          ..addAll(combined);
        _isLoading = false;
        _errorMessage = null;
      });
      _controller.openView();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Search failed. Please try again.';
      });
      _controller.openView();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SearchAnchor(
      searchController: _controller,
      builder: (BuildContext context, SearchController controller) {
        return IconButton(
          icon: const Icon(Icons.search),
          onPressed: () {
            controller.openView();
          },
          tooltip: 'Search',
        );
      },
      suggestionsBuilder:
          (BuildContext context, SearchController controller) {
        if (_isLoading) {
          return [
            const ListTile(
              leading: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              title: Text('Searching...'),
            ),
          ];
        }
        if (_errorMessage != null) {
          return [ListTile(title: Text(_errorMessage!))];
        }
        if (_suggestions.isEmpty) {
          return [
            ListTile(
              title: Text(
                controller.text.trim().isEmpty
                    ? 'Type to search leagues and teams'
                    : 'No results',
              ),
            ),
          ];
        }
        return _suggestions.map((item) {
          return ListTile(
            leading: _SearchLogo(
              logoPath: item.logoPath,
              fallbackIcon:
                  item.type == 'League' ? Icons.emoji_events : Icons.groups,
            ),
            title: Text(item.label),
            subtitle: Text(item.type),
            onTap: () {
              controller.closeView(item.label);
              if (item.type == 'League') {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LeagueDetailPage(leagueId: item.id),
                  ),
                );
              } else {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TeamDetailPage(teamId: item.id),
                  ),
                );
              }
            },
          );
        }).toList();
      },
    );
  }
}

class _SearchItem {
  const _SearchItem({
    required this.id,
    required this.label,
    required this.type,
    this.logoPath,
  });

  final String id;
  final String label;
  final String type;
  final String? logoPath;
}

String? _resolveLogoPath(String? logoId) {
  final id = logoId?.trim();
  if (id == null || id.isEmpty) return null;
  if (id.startsWith('http://') || id.startsWith('https://')) return id;
  if (id.startsWith('lib/assets/') || id.startsWith('assets/')) return id;
  final name = id.contains('.') ? id : '$id.png';
  return '${AppAssets.teamLogosPath}$name';
}

class _SearchLogo extends StatelessWidget {
  const _SearchLogo({this.logoPath, required this.fallbackIcon});

  final String? logoPath;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    final path = logoPath;
    if (path == null || path.isEmpty) {
      return CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
        child: Icon(
          fallbackIcon,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }
    final isNetwork =
        path.startsWith('http://') || path.startsWith('https://');
    final image = isNetwork
        ? Image.network(
            path,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          )
        : Image.asset(
            path,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          );
    return CircleAvatar(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: ClipOval(
          child: SizedBox(width: 36, height: 36, child: image)),
    );
  }
}
