import 'package:flutter/material.dart';

import '../../domain/models/league_format.dart';

/// Players-a-side and default formation used by Team of the Week.
class LeagueFormatFields extends StatelessWidget {
  const LeagueFormatFields({
    super.key,
    required this.playersPerSide,
    required this.formation,
    required this.onChanged,
  });

  final int playersPerSide;
  final String formation;
  final void Function(int playersPerSide, String formation) onChanged;

  static void _showMatchFormatInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Match format'),
        content: const SingleChildScrollView(
          child: Text(
            'Team of the Week fills this formation with the highest-rated '
            'players from the latest completed gameweek.\n\n'
            'The numbers run from defenders to attackers and do not include '
            'the goalkeeper. 4-4-2 selects 1 goalkeeper, 4 defenders, '
            '4 midfielders and 2 attackers. 4-2-3-1 still selects 11, but '
            'places 5 midfielders on two lines on the pitch.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final format = LeagueFormat.fromStored(
      playersPerSide: playersPerSide,
      formation: formation,
    );
    final formations = LeagueFormat.formationsFor(format.playersPerSide);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Match format', style: textTheme.titleMedium),
            ),
            IconButton(
              tooltip: 'About match format',
              onPressed: () => _showMatchFormatInfo(context),
              icon: Icon(
                Icons.info_outline,
                size: 20,
                color: colorScheme.primary,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            ),
          ],
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<int>(
          key: ValueKey(format.playersPerSide),
          initialValue: format.playersPerSide,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Players a side'),
          items: LeagueFormat.supportedSides
              .map(
                (n) =>
                    DropdownMenuItem<int>(value: n, child: Text('$n-a-side')),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            final nextFormation =
                LeagueFormat.formationsFor(value).contains(formation)
                ? formation
                : LeagueFormat.defaultFormationFor(value);
            onChanged(value, nextFormation);
          },
        ),
        const SizedBox(height: 16),
        Text('Default formation', style: textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: formations.map((f) {
            return ChoiceChip(
              label: Text(f),
              selected: f == format.formation,
              onSelected: (_) => onChanged(format.playersPerSide, f),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Text(
          '${format.playersPerSide}-a-side · ${format.formation} · ${format.summaryLabel}',
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
