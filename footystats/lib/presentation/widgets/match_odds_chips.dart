import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../domain/models/match_model.dart';
import '../../domain/models/match_odds.dart';
import '../providers/match_odds_provider.dart';
import 'home/team_chip.dart';

const kMatchPredictionsDisclaimer =
    'For fun only — no real-money betting';

/// Win (team A) / draw / win (team B) prediction chips from [matchOddsProvider].
class MatchOddsChips extends ConsumerStatefulWidget {
  const MatchOddsChips({
    super.key,
    required this.match,
    this.compact = false,
    this.lazyLoad = true,
    this.showHeader = false,
    this.showDisclaimer = false,
  });

  final MatchModel match;
  final bool compact;

  /// When true (home carousel), predictions are fetched only after the card is
  /// actually on screen so off-screen cards do not each fire ~10 queries.
  final bool lazyLoad;

  /// Shows a “Predictions” title above the chips (fixture detail).
  final bool showHeader;

  /// Shows the entertainment-only disclaimer under the chips.
  final bool showDisclaimer;

  @override
  ConsumerState<MatchOddsChips> createState() => _MatchOddsChipsState();
}

class _MatchOddsChipsState extends ConsumerState<MatchOddsChips> {
  bool _visibleEnough = false;

  @override
  Widget build(BuildContext context) {
    if (widget.lazyLoad && !_visibleEnough) {
      return VisibilityDetector(
        key: Key('predictions-${widget.match.id}'),
        onVisibilityChanged: (info) {
          if (!mounted || _visibleEnough) return;
          if (info.visibleFraction > 0.45) {
            setState(() => _visibleEnough = true);
          }
        },
        child: _PredictionsBody(
          compact: widget.compact,
          showHeader: widget.showHeader,
          showDisclaimer: widget.showDisclaimer,
          loading: true,
          labels: const ['…', '…', '…'],
          match: widget.match,
        ),
      );
    }

    final oddsAsync = ref.watch(matchOddsProvider(widget.match.id));
    final odds = oddsAsync.maybeWhen(
      data: (value) => value,
      orElse: () => MatchOdds.neutral(),
    );

    return _PredictionsBody(
      compact: widget.compact,
      showHeader: widget.showHeader,
      showDisclaimer: widget.showDisclaimer,
      loading: oddsAsync.isLoading,
      labels: odds.formatted,
      match: widget.match,
    );
  }
}

class _PredictionsBody extends StatelessWidget {
  const _PredictionsBody({
    required this.compact,
    required this.showHeader,
    required this.showDisclaimer,
    required this.loading,
    required this.labels,
    required this.match,
  });

  final bool compact;
  final bool showHeader;
  final bool showDisclaimer;
  final bool loading;
  final List<String> labels;
  final MatchModel match;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final chips = compact
        ? Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _CompactChip(label: labels[0], loading: loading),
              _CompactChip(label: labels[1], loading: loading),
              _CompactChip(label: labels[2], loading: loading),
            ],
          )
        : Row(
            children: [
              Expanded(
                child: _OddsChip(
                  avatar: ClipOval(
                    child: TeamChip.logoImage(match.teamA.logoPath, size: 20),
                  ),
                  label: labels[0],
                  loading: loading,
                  textTheme: textTheme,
                  colorScheme: colorScheme,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _OddsChip(
                  avatar: Text(
                    'X',
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface,
                    ),
                  ),
                  label: labels[1],
                  loading: loading,
                  mutedLabel: true,
                  textTheme: textTheme,
                  colorScheme: colorScheme,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _OddsChip(
                  avatar: ClipOval(
                    child: TeamChip.logoImage(match.teamB.logoPath, size: 20),
                  ),
                  label: labels[2],
                  loading: loading,
                  textTheme: textTheme,
                  colorScheme: colorScheme,
                ),
              ),
            ],
          );

    if (!showHeader && !showDisclaimer) return chips;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showHeader) ...[
          Text(
            'Predictions',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
        ],
        chips,
        if (showDisclaimer) ...[
          const SizedBox(height: 8),
          Text(
            kMatchPredictionsDisclaimer,
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _CompactChip extends StatelessWidget {
  const _CompactChip({required this.label, required this.loading});

  final String label;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ActionChip(
      label: Text(loading ? '…' : label),
      onPressed: () {},
      backgroundColor: colorScheme.surfaceContainerHigh,
    );
  }
}

class _OddsChip extends StatelessWidget {
  const _OddsChip({
    required this.avatar,
    required this.label,
    required this.loading,
    required this.textTheme,
    required this.colorScheme,
    this.mutedLabel = false,
  });

  final Widget avatar;
  final String label;
  final bool loading;
  final TextTheme textTheme;
  final ColorScheme colorScheme;
  final bool mutedLabel;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: avatar,
      label: Text(
        loading ? '…' : label,
        style: textTheme.labelLarge?.copyWith(
          color: mutedLabel
              ? colorScheme.onSurfaceVariant
              : colorScheme.onSurface,
        ),
      ),
      onPressed: () {},
      backgroundColor: colorScheme.surfaceContainerHigh,
      side: BorderSide(color: colorScheme.outlineVariant),
    );
  }
}
