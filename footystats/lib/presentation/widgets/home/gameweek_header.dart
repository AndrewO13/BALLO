import 'package:flutter/material.dart';

class GameweekHeader extends StatelessWidget {
  const GameweekHeader({super.key, required this.gameweek});

  final String gameweek;

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
                    onPressed: () {
                      // navigate to previous week (placeholder)
                    },
                    tooltip: 'Previous',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: null, // disabled but visible
                    tooltip: 'Next (disabled)',
                    visualDensity: VisualDensity.compact,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () {},
                tooltip: 'Edit',
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
