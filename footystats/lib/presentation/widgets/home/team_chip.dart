import 'package:flutter/material.dart';

class TeamChip extends StatelessWidget {
  const TeamChip({
    super.key,
    required this.teamName,
    required this.logoPath,
    required this.isSelected,
    required this.onSelected,
  });

  final String teamName;
  final String logoPath;
  final bool isSelected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      avatar: ClipOval(
        child: Image.asset(logoPath, width: 24, height: 24, fit: BoxFit.cover),
      ),
      label: Text(teamName),
      selected: isSelected,
      onSelected: onSelected,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }
}
