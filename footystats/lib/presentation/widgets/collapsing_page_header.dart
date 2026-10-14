import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/adaptive/adaptive.dart';
import '../../core/widgets/media_placeholders.dart';

/// Collapsing masthead used by Profile and the main Matches tab.
class CollapsingPageHeader {
  const CollapsingPageHeader._();

  static const pinnedRow = 48.0;

  static ({double top, double titleExtent, double maxExtent}) metrics(
    BuildContext context, {
    required bool hasChrome,
    double bottomGap = 20,
  }) {
    final top = MediaQuery.paddingOf(context).top;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final titleHeight = 40 * 0.95 * textScale;
    final pinnedControls = hasChrome ? pinnedRow : 0.0;
    final titleBlock = 16 + titleHeight + bottomGap;
    final titleExtent = titleBlock < pinnedControls
        ? pinnedControls
        : titleBlock;
    return (top: top, titleExtent: titleExtent, maxExtent: top + titleExtent);
  }

  /// Fixed bar whose height follows [shrinkOffset], for a header that sits
  /// above a separately scrolling list.
  static Widget bar({
    required BuildContext context,
    required String title,
    required double shrinkOffset,
    Widget? leading,
    Widget? middle,
    List<Widget> actions = const [],
    double bottomGap = 20,
    bool showTitle = true,
  }) {
    final hasChrome = leading != null || actions.isNotEmpty;
    final measured = metrics(
      context,
      hasChrome: hasChrome,
      bottomGap: bottomGap,
    );
    final pinnedControls = hasChrome ? pinnedRow : 0.0;
    final titleExtent = showTitle ? measured.titleExtent : pinnedControls;
    final shrinkRange = titleExtent - pinnedControls;
    final shrink = shrinkRange <= 0
        ? 0.0
        : shrinkOffset.clamp(0.0, shrinkRange);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final delegate = _CollapsingPageHeaderDelegate(
      title: title,
      top: measured.top,
      inset: AppResponsive.horizontalInset(context),
      titleExtent: titleExtent,
      titleHeight: 40 * 0.95 * textScale,
      pinnedControls: pinnedControls,
      leading: leading,
      middle: middle,
      actions: actions,
      bottomGap: bottomGap,
      showTitle: showTitle,
    );
    return SizedBox(
      height: measured.top + titleExtent - shrink,
      width: double.infinity,
      child: delegate.build(context, shrink, shrink > 0),
    );
  }

  static Widget sliver({
    required BuildContext context,
    required String title,
    Widget? leading,
    Widget? middle,
    List<Widget> actions = const [],
    double bottomGap = 20,
    bool showTitle = true,
  }) {
    final hasChrome = leading != null || actions.isNotEmpty;
    final measured = metrics(
      context,
      hasChrome: hasChrome,
      bottomGap: bottomGap,
    );
    final pinnedControls = hasChrome ? pinnedRow : 0.0;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return SliverPersistentHeader(
      pinned: true,
      delegate: _CollapsingPageHeaderDelegate(
        title: title,
        top: measured.top,
        inset: AppResponsive.horizontalInset(context),
        titleExtent: showTitle ? measured.titleExtent : pinnedControls,
        titleHeight: 40 * 0.95 * textScale,
        pinnedControls: pinnedControls,
        leading: leading,
        middle: middle,
        actions: actions,
        bottomGap: bottomGap,
        showTitle: showTitle,
      ),
    );
  }
}

class _CollapsingPageHeaderDelegate extends SliverPersistentHeaderDelegate {
  _CollapsingPageHeaderDelegate({
    required this.title,
    required this.top,
    required this.inset,
    required this.titleExtent,
    required this.titleHeight,
    required this.pinnedControls,
    required this.leading,
    required this.middle,
    required this.actions,
    this.bottomGap = 20,
    this.showTitle = true,
  });

  final String title;
  final double top;
  final double inset;
  final double titleExtent;
  final double titleHeight;
  final double pinnedControls;
  final Widget? leading;
  final Widget? middle;
  final List<Widget> actions;
  final double bottomGap;
  final bool showTitle;

  @override
  double get maxExtent => top + titleExtent;

  @override
  double get minExtent => top + pinnedControls;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final shrinkRange = titleExtent - pinnedControls;
    final t = shrinkRange <= 0
        ? 1.0
        : (shrinkOffset / shrinkRange).clamp(0.0, 1.0);
    final titleSpace = (titleExtent - shrinkOffset).clamp(
      pinnedControls,
      titleExtent,
    );
    final expandedIconTop = (16 + (titleHeight - pinnedControls) / 2).clamp(
      0.0,
      titleExtent,
    );
    final iconTop = expandedIconTop * (1 - t);
    final titleLeft = leading == null ? inset : 48.0;
    final titleRight = inset + actions.length * 48;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        border: overlapsContent
            ? Border(
                bottom: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.65),
                ),
              )
            : null,
      ),
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: top + titleExtent,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    scheme.primary.withValues(alpha: 0.18 * (1 - t)),
                    scheme.surface.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
          Column(
            children: [
              SizedBox(height: top),
              SizedBox(
                height: titleSpace,
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    if (showTitle)
                      ClipRect(
                        child: OverflowBox(
                          alignment: Alignment.topCenter,
                          minHeight: titleExtent,
                          maxHeight: titleExtent,
                          child: Opacity(
                            opacity: (1 - t).clamp(0.0, 1.0),
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                titleLeft,
                                16,
                                titleRight,
                                bottomGap,
                              ),
                              child: Align(
                                alignment: Alignment.topLeft,
                                child: ExcludeSemantics(
                                  excluding: t > 0.5,
                                  child: Semantics(
                                    header: true,
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        title,
                                        style: GoogleFonts.anton(
                                          fontSize: 40,
                                          height: 0.95,
                                          letterSpacing: 0.6,
                                          color: scheme.onSurface,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (leading != null || actions.isNotEmpty)
                      Positioned(
                        top: iconTop,
                        left: 0,
                        right: 0,
                        height: pinnedControls,
                        child: Row(
                          children: [
                            if (leading != null)
                              leading!
                            else
                              SizedBox(width: inset),
                            if (middle != null)
                              Expanded(child: middle!)
                            else
                              const Spacer(),
                            ...actions,
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _CollapsingPageHeaderDelegate oldDelegate) =>
      true;
}

/// Logo, name, and subtitle that fade into a pinned bar as a hero scrolls away.
class CollapsedBarIdentity extends StatelessWidget {
  const CollapsedBarIdentity({
    super.key,
    required this.reveal,
    required this.name,
    this.subtitle,
    this.image,
  });

  final ValueNotifier<double> reveal;
  final String? name;
  final String? subtitle;
  final Widget? image;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return ValueListenableBuilder<double>(
      valueListenable: reveal,
      builder: (context, value, _) {
        final curved = Curves.easeOutCubic.transform(value);
        final label = name;
        if (curved <= 0 || label == null || label.isEmpty) {
          return const SizedBox.shrink();
        }
        final subtitleLabel = subtitle;
        return ClipRect(
          child: Opacity(
            opacity: curved,
            child: Transform.translate(
              offset: Offset(8 * (1 - curved), 6 * (1 - curved)),
              child: Row(
                children: [
                  if (image != null) ...[image!, const SizedBox(width: 8)],
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                          ),
                        ),
                        if (subtitleLabel != null && subtitleLabel.isNotEmpty)
                          Text(
                            subtitleLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.1,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class CollapsedBarLogo extends StatelessWidget {
  const CollapsedBarLogo({super.key, required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 32,
      height: 32,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      child: buildTeamLogo(
        imageUrl,
        size: 32,
        placeholderIconColor: scheme.onSurfaceVariant,
      ),
    );
  }
}
