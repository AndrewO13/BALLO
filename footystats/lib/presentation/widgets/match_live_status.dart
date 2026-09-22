import 'package:flutter/material.dart';

import '../../domain/models/match_model.dart';

/// Which half of the match is in play (or half-time break).
enum MatchHalfPhase { firstHalf, halfTime, secondHalf }

/// Resolves half phase from match status and timing (DB + local timer state).
MatchHalfPhase? resolveMatchHalfPhase({
  required MatchStatus status,
  DateTime? resumedFromHalftimeAt,
  bool hasReachedHalfTime = false,
}) {
  switch (status) {
    case MatchStatus.halfTime:
      return MatchHalfPhase.halfTime;
    case MatchStatus.ongoing:
      if (resumedFromHalftimeAt != null || hasReachedHalfTime) {
        return MatchHalfPhase.secondHalf;
      }
      return MatchHalfPhase.firstHalf;
    case MatchStatus.upcoming:
    case MatchStatus.fullTime:
      return null;
  }
}

String matchHalfPhaseLabel(MatchHalfPhase phase) {
  switch (phase) {
    case MatchHalfPhase.firstHalf:
      return '1st half';
    case MatchHalfPhase.halfTime:
      return 'Half-time';
    case MatchHalfPhase.secondHalf:
      return '2nd half';
  }
}

/// Pulsing live dot — broadcast-style “match in progress” cue.
///
/// A soft expanding ring + solid core reads faster than a rotating shape:
/// red + pulse is the convention used by live sports and streaming UIs, so users
/// recognise “live” without reading copy.
class MatchLivePulseIndicator extends StatefulWidget {
  const MatchLivePulseIndicator({
    super.key,
    this.size = 8,
    this.color = const Color(0xFFFF3B30),
  });

  final double size;
  final Color color;

  @override
  State<MatchLivePulseIndicator> createState() => _MatchLivePulseIndicatorState();
}

class _MatchLivePulseIndicatorState extends State<MatchLivePulseIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final core = widget.size;
    final box = core * 2.6;

    return SizedBox(
      width: box,
      height: box,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = Curves.easeOut.transform(_controller.value);
          final ringScale = 1.0 + t * 1.1;
          final ringOpacity = (1.0 - t) * 0.55;

          return Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: ringScale,
                child: Container(
                  width: core,
                  height: core,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withValues(alpha: ringOpacity),
                  ),
                ),
              ),
              Container(
                width: core,
                height: core,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color,
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.45),
                      blurRadius: core * 0.6,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Compact chip for 1st half / 2nd half / half-time.
class MatchHalfPhaseChip extends StatelessWidget {
  const MatchHalfPhaseChip({super.key, required this.phase});

  final MatchHalfPhase phase;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final (Color bg, Color fg) = switch (phase) {
      MatchHalfPhase.firstHalf => (
        const Color(0xFF00FF5A).withValues(alpha: 0.14),
        const Color(0xFF00C247),
      ),
      MatchHalfPhase.secondHalf => (
        colorScheme.primaryContainer.withValues(alpha: 0.85),
        colorScheme.onPrimaryContainer,
      ),
      MatchHalfPhase.halfTime => (
        const Color(0xFFFFB020).withValues(alpha: 0.18),
        const Color(0xFFE69500),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        matchHalfPhaseLabel(phase),
        style: textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
          fontSize: 10,
          height: 1.2,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
