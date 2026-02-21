import 'package:flutter/material.dart';

import '../../domain/models/match_model.dart';
import '../pages/fixture.dart';
import '../pages/matches.dart';

/// Compact match list item (home team | score/time | away team) for carousels
/// and lists. Tapping navigates to [FixturePage].
class MatchListItem extends StatelessWidget {
  const MatchListItem({
    super.key,
    required this.match,
    this.statusText,
    this.hasVideo = false,
  });

  final MatchModel match;
  /// Override status text (e.g. live clock). If null, uses [match.statusText].
  final String? statusText;
  final bool hasVideo;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final label = statusText ?? match.statusText;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => FixturePage(matchId: match.id),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      match.teamA.shortForm,
                      style: textTheme.bodySmall,
                    ),
                    const SizedBox(width: 8),
                    ClipOval(
                      child: _TeamLogo(
                        path: match.teamA.logoPath,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            Builder(
              builder: (context) {
                if (match.status == MatchStatus.upcoming) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 6.0),
                    child: Text(label, style: textTheme.titleMedium),
                  );
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: hasVideo && match.status == MatchStatus.fullTime
                            ? Border.all(
                                color: Colors.greenAccent.shade400,
                                width: 2,
                              )
                            : null,
                      ),
                      child: Text(
                        match.scoreText ?? '–',
                        style: textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (match.status == MatchStatus.ongoing ||
                            match.status == MatchStatus.halfTime) ...[
                          const Padding(
                            padding: EdgeInsets.only(right: 6.0),
                            child: DodecagonIndicator(size: 12.0),
                          ),
                        ],
                        Text(label, style: textTheme.labelSmall),
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipOval(
                      child: _TeamLogo(
                        path: match.teamB.logoPath,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      match.teamB.shortForm,
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TeamLogo extends StatelessWidget {
  const _TeamLogo({required this.path, this.size = 28});

  final String path;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isNetwork =
        path.startsWith('http://') || path.startsWith('https://');
    return SizedBox(
      width: size,
      height: size,
      child: isNetwork
          ? Image.network(
              path,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            )
          : Image.asset(
              path,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => SizedBox(
                width: size,
                height: size,
                child: Icon(
                  Icons.sports_soccer,
                  size: size * 0.6,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
    );
  }
}
