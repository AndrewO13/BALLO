import 'package:flutter/material.dart';

import '../../../../domain/models/match_model.dart';

/// Carousel card for a match. Displays team logos, short forms, scores,
/// time/status, odds, league name, gameweek. Tapping navigates to fixture.
class MatchCard extends StatelessWidget {
  const MatchCard({
    super.key,
    required this.match,
    this.leagueName,
    this.odds = const ['1.8', '2.1', '1.3'],
    required this.onTap,
  });

  final MatchModel match;
  final String? leagueName;
  final List<String> odds;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final hasScores = match.teamAScore != null && match.teamBScore != null;
    final score1 = hasScores ? (match.teamAScore!.toString()) : '—';
    final score2 = hasScores ? (match.teamBScore!.toString()) : '—';
    final timeLabel = match.statusText;
    final gw = match.gameweek ?? '—';
    final league = leagueName ?? '—';

    return ClipRect(
      child: OverflowBox(
        maxWidth: width * 7 / 8,
        minWidth: width * 7 / 8,
        child: Material(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(28),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(28),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
              ),
              padding: const EdgeInsetsDirectional.only(
                start: 70.0,
                end: 70.0,
                top: 16.0,
                bottom: 0.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(league, style: textTheme.titleSmall),
                      Text(gw, style: textTheme.titleSmall),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            _TeamLogo(
                              path: match.teamA.logoPath,
                              size: 46.4,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              match.teamA.shortForm,
                              style: textTheme.bodyLarge,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                score1,
                                style: textTheme.displayMedium,
                              ),
                              Text(' - ', style: textTheme.displayMedium),
                              Text(
                                score2,
                                style: textTheme.displayMedium,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 0,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              timeLabel,
                              style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Expanded(
                        child: Column(
                          children: [
                            _TeamLogo(
                              path: match.teamB.logoPath,
                              size: 46.4,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              match.teamB.shortForm,
                              style: textTheme.bodyLarge,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      for (final odd in odds)
                        ActionChip(
                          label: Text(odd),
                          onPressed: () {},
                          backgroundColor: colorScheme.surfaceContainerHigh,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TeamLogo extends StatelessWidget {
  const _TeamLogo({required this.path, this.size = 46.4});

  final String path;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isNetwork =
        path.startsWith('http://') || path.startsWith('https://');
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: isNetwork
            ? Image.network(
                path,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(context),
              )
            : Image.asset(
                path,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(context),
              ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Icon(
        Icons.sports_soccer,
        size: size * 0.5,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
