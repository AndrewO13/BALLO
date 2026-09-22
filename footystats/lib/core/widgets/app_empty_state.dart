import 'package:flutter/material.dart';

import '../adaptive/adaptive.dart';
import '../constants/app_assets.dart';

/// Illustration + copy for empty list/tab views.
///
/// Scales down when the keyboard is open. Wrap in [SingleChildScrollView] inside
/// [Expanded] when a search field shares the screen (see team application pages).
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.imageAsset,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final String imageAsset;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final compact = keyboardOpen;
    final scale = AppResponsive.layoutScaleOf(context);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppResponsive.horizontalInset(context, design: 32),
        vertical: (compact ? 12 : 24) * scale,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            imageAsset,
            height: (compact ? 120 : 200) * scale,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
          ),
          SizedBox(height: compact ? 16 : 28),
          Text(
            title,
            textAlign: TextAlign.center,
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
              fontSize: compact ? 20 : null,
            ),
          ),
          if (subtitle != null) ...[
            SizedBox(height: compact ? 6 : 10),
            Text(
              subtitle!,
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.45,
                fontSize: compact ? 14 : null,
              ),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            SizedBox(height: compact ? 16 : 28),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                minimumSize: Size(200, compact ? 44 : 48),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: Text(actionLabel!),
            ),
          ],
          if (secondaryActionLabel != null && onSecondaryAction != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onSecondaryAction,
              child: Text(secondaryActionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

/// Scrollable wrapper for [AppEmptyState] under a fixed header (e.g. search field).
class ScrollableAppEmptyState extends StatelessWidget {
  const ScrollableAppEmptyState({
    super.key,
    required this.imageAsset,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final String imageAsset;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: AppEmptyState(
                imageAsset: imageAsset,
                title: title,
                subtitle: subtitle,
                actionLabel: actionLabel,
                onAction: onAction,
                secondaryActionLabel: secondaryActionLabel,
                onSecondaryAction: onSecondaryAction,
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Shared empty state for matches lists (main Matches tab and detail tabs).
class NoMatchesEmptyState extends StatelessWidget {
  const NoMatchesEmptyState({
    super.key,
    required this.hasActiveFilters,
    this.showCreateMatchCta = false,
    this.onClearFilters,
    this.onCreateMatch,
  });

  final bool hasActiveFilters;
  final bool showCreateMatchCta;
  final VoidCallback? onClearFilters;
  final VoidCallback? onCreateMatch;

  @override
  Widget build(BuildContext context) {
    final showCta = showCreateMatchCta && onCreateMatch != null;

    return AppEmptyState(
      imageAsset: AppAssets.noMatchesEmpty,
      title: 'No matches yet',
      subtitle: hasActiveFilters
          ? 'No matches fit your current filters. Try clearing one or more filters.'
          : 'Matches scheduled for your leagues and teams will appear here.',
      actionLabel: hasActiveFilters
          ? 'Clear filters'
          : (showCta ? 'Create match' : null),
      onAction: hasActiveFilters
          ? onClearFilters
          : (showCta ? onCreateMatch : null),
      secondaryActionLabel: hasActiveFilters && showCta ? 'Create match' : null,
      onSecondaryAction: hasActiveFilters && showCta ? onCreateMatch : null,
    );
  }
}
