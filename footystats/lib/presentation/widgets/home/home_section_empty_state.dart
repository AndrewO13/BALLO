import 'package:flutter/material.dart';

/// Compact empty state for a single section on scrollable pages (e.g. Home).
///
/// Use [embedded] when the parent already provides a card or section container
/// (e.g. Performance chart). Otherwise wraps content in [surfaceContainerHigh].
class HomeSectionEmptyState extends StatelessWidget {
  const HomeSectionEmptyState({
    super.key,
    this.imageAsset,
    this.imageHeight = 80,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.actionIcon,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.embedded = false,
    this.compact = false,
  });

  final String? imageAsset;
  final double imageHeight;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? actionIcon;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  /// When true, omits the outer card (content only).
  final bool embedded;

  /// Tighter layout for nested areas (e.g. standings table).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final imgHeight = compact ? 56.0 : imageHeight;
    final verticalPad = compact ? 12.0 : (embedded ? 8.0 : 24.0);
    final horizontalPad = compact ? 8.0 : (embedded ? 8.0 : 20.0);

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (imageAsset != null) ...[
          Center(
            child: Image.asset(
              imageAsset!,
              height: imgHeight,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
            ),
          ),
          SizedBox(height: compact ? 10 : 16),
        ],
        Text(
          message,
          textAlign: TextAlign.center,
          style: (compact ? textTheme.bodySmall : textTheme.bodyMedium)?.copyWith(
            color: colorScheme.onSurfaceVariant,
            height: 1.45,
          ),
        ),
        if (actionLabel != null && onAction != null) ...[
          SizedBox(height: compact ? 12 : 20),
          FilledButton.icon(
            onPressed: onAction,
            icon: Icon(actionIcon ?? Icons.add, size: 20),
            label: Text(actionLabel!),
            style: FilledButton.styleFrom(
              minimumSize: Size.fromHeight(compact ? 40 : 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          ),
        ],
        if (secondaryActionLabel != null && onSecondaryAction != null) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: onSecondaryAction,
            style: OutlinedButton.styleFrom(
              minimumSize: Size.fromHeight(compact ? 40 : 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
            ),
            child: Text(secondaryActionLabel!),
          ),
        ],
      ],
    );

    if (embedded) {
      return Padding(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPad,
          vertical: verticalPad,
        ),
        child: content,
      );
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPad,
        vertical: verticalPad,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(28),
      ),
      child: content,
    );
  }
}
