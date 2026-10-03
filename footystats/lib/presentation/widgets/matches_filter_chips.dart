import 'package:flutter/material.dart';

class MatchesFilterOption {
  const MatchesFilterOption({required this.value, required this.label});

  final String value;
  final String label;
}

/// Equal-width outlined filter chips with 8dp gaps, matching the main Matches page.
class MatchesFilterChipRow extends StatelessWidget {
  const MatchesFilterChipRow({
    super.key,
    required this.chips,
    this.leading,
  });

  final List<Widget> chips;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(width: 8),
        ],
        for (var i = 0; i < chips.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: chips[i]),
        ],
      ],
    );
  }
}

class MatchesFilterMenuChip extends StatelessWidget {
  const MatchesFilterMenuChip({
    super.key,
    required this.categoryLabel,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
    this.selectedLabel,
    this.enabled = true,
  });

  final String categoryLabel;
  final String? selectedLabel;
  final List<MatchesFilterOption> options;
  final String selectedValue;
  final ValueChanged<String> onSelected;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final hasSelection = selectedValue.isNotEmpty;
    final chipLabel =
        hasSelection && selectedLabel != null && selectedLabel!.isNotEmpty
        ? selectedLabel!
        : categoryLabel;

    return MenuAnchor(
      consumeOutsideTap: true,
      builder: (context, controller, _) {
        return Material(
          color: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: !enabled
                ? null
                : () =>
                      controller.isOpen ? controller.close() : controller.open(),
            customBorder: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      chipLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.labelLarge?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.keyboard_arrow_down,
                    size: 20,
                    color: colorScheme.onSurface,
                  ),
                ],
              ),
            ),
          ),
        );
      },
      menuChildren: [
        for (final option in options)
          MenuItemButton(
            onPressed: () => onSelected(option.value),
            trailingIcon: option.value == selectedValue
                ? Icon(
                    Icons.check,
                    size: 18,
                    color: colorScheme.primary,
                  )
                : const SizedBox(width: 18),
            child: Text(option.label),
          ),
      ],
    );
  }
}
