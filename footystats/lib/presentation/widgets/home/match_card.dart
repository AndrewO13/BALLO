import 'package:flutter/material.dart';
import '../../../core/adaptive/adaptive.dart';
import '../../../core/widgets/media_placeholders.dart';

import '../../../domain/models/match_model.dart';
import '../match_odds_chips.dart';

/// Carousel card for a match. Displays team logos, short forms, scores,
/// time/status, predictions, league name, gameweek. Tapping navigates to fixture.
class MatchCard extends StatelessWidget {
  const MatchCard({
    super.key,
    required this.match,
    this.leagueName,
    required this.onTap,
  });

  final MatchModel match;
  final String? leagueName;
  final VoidCallback onTap;

  static const double _designHeight = 223;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final hasScores = match.teamAScore != null && match.teamBScore != null;
    final score1 = hasScores ? (match.teamAScore!.toString()) : '—';
    final score2 = hasScores ? (match.teamBScore!.toString()) : '—';
    final timeLabel = match.statusText;
    final isUpcoming = match.status == MatchStatus.upcoming;
    final dateLabel = _formatDate(match.matchDate);
    final gw = match.gameweekNumber != null
        ? 'GW${match.gameweekNumber}'
        : (match.gameweek ?? '—');
    final league = leagueName ?? '—';

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : _designHeight;
        final itemWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : screenWidth * 0.67;
        final heightScale = (itemHeight / _designHeight).clamp(0.62, 1.15);
        final widthScale = AppResponsive.widthScaleOf(context);
        final scale = ((widthScale + heightScale) / 2).clamp(0.62, 1.12);
        final cardWidth = (screenWidth * 7 / 8).clamp(itemWidth, screenWidth);
        final cardPad = (56.0 * scale).clamp(28.0, 70.0);
        final logoSize = (46.4 * scale).clamp(28.0, 48.0);
        final topPad = (12.0 * heightScale).clamp(8.0, 16.0);
        final bottomPad = (8.0 * heightScale).clamp(4.0, 12.0);
        final showOdds = itemHeight >= 186;
        final scoreSize =
            (textTheme.displayMedium?.fontSize ?? 36) *
            heightScale.clamp(0.68, 1);
        final scoreStyle = textTheme.displayMedium?.copyWith(
          fontSize: scoreSize,
          height: 1.05,
        );

        return ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: OverflowBox(
            alignment: Alignment.center,
            minWidth: cardWidth,
            maxWidth: cardWidth,
            minHeight: itemHeight,
            maxHeight: itemHeight,
            child: Material(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(28),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(28),
                child: Center(
                  child: SizedBox(
                    width: itemWidth,
                    height: itemHeight,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        cardPad.clamp(16.0, 28.0),
                        topPad,
                        cardPad.clamp(16.0, 28.0),
                        bottomPad,
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  league,
                                  style: textTheme.titleSmall,
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(gw, style: textTheme.titleSmall),
                            ],
                          ),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Expanded(
                                  child: _TeamBlock(
                                    path: match.teamA.logoPath,
                                    shortForm: match.teamA.shortForm,
                                    logoSize: logoSize,
                                    textStyle: textTheme.bodyLarge,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (isUpcoming)
                                        Text(
                                          timeLabel,
                                          style: scoreStyle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        )
                                      else
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(score1, style: scoreStyle),
                                            Text(' - ', style: scoreStyle),
                                            Text(score2, style: scoreStyle),
                                          ],
                                        ),
                                      SizedBox(
                                        height: (6.0 * heightScale).clamp(
                                          2.0,
                                          8.0,
                                        ),
                                      ),
                                      if (isUpcoming)
                                        Text(
                                          dateLabel,
                                          style: textTheme.labelSmall?.copyWith(
                                            color: colorScheme.onSurfaceVariant,
                                          ),
                                        )
                                      else
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 7,
                                            vertical: 0,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                colorScheme.secondaryContainer,
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          child: Text(
                                            timeLabel,
                                            style: textTheme.labelSmall
                                                ?.copyWith(
                                                  color: colorScheme
                                                      .onSecondaryContainer,
                                                ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: _TeamBlock(
                                    path: match.teamB.logoPath,
                                    shortForm: match.teamB.shortForm,
                                    logoSize: logoSize,
                                    textStyle: textTheme.bodyLarge,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (showOdds)
                            MatchOddsChips(match: match, compact: true),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TeamBlock extends StatelessWidget {
  const _TeamBlock({
    required this.path,
    required this.shortForm,
    required this.logoSize,
    required this.textStyle,
  });

  final String path;
  final String shortForm;
  final double logoSize;
  final TextStyle? textStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _TeamLogo(path: path, size: logoSize),
        const SizedBox(height: 6),
        Text(
          shortForm,
          style: textStyle,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

String _formatDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final wd = weekdays[date.weekday - 1];
  final mon = months[date.month - 1];
  return '$wd ${date.day} $mon';
}

class _TeamLogo extends StatelessWidget {
  const _TeamLogo({required this.path, this.size = 46.4});

  final String path;
  final double size;

  @override
  Widget build(BuildContext context) {
    final isNetwork = path.startsWith('http://') || path.startsWith('https://');
    return ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: isNetwork
            ? Image(
                image: appCachedImageProvider(path),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _placeholder(context),
              )
            : Image.asset(
                path,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _placeholder(context),
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
