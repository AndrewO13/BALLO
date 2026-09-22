import 'package:flutter/material.dart';

class GameweekHeader extends StatelessWidget {
  const GameweekHeader({
    super.key,
    required this.gameweek,
    this.onPreviousGameweek,
    this.onNextGameweek,
    this.canGoToPreviousGameweek = false,
    this.canGoToNextGameweek = false,
    this.onCustomizeTargets,
  });

  final String gameweek;
  final VoidCallback? onPreviousGameweek;
  final VoidCallback? onNextGameweek;
  final bool canGoToPreviousGameweek;
  final bool canGoToNextGameweek;
  final VoidCallback? onCustomizeTargets;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: canGoToPreviousGameweek
                        ? onPreviousGameweek
                        : null,
                    tooltip: 'Previous',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed:
                        canGoToNextGameweek ? onNextGameweek : null,
                    tooltip: 'Next',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: onCustomizeTargets,
                tooltip: 'Customize Targets',
                visualDensity: VisualDensity.compact,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          Center(
            child: Text(
              gameweek,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }
}
