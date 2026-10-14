import 'package:flutter/material.dart';

import '../../../core/widgets/media_placeholders.dart';
import '../../../core/theme/app_shape.dart';

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
      avatar: ClipOval(child: TeamChip.logoImage(logoPath, size: 24)),
      label: Text(teamName),
      selected: isSelected,
      onSelected: onSelected,
      shape: RoundedRectangleBorder(
        borderRadius: AppShape.largeIncreasedRadius,
      ),
    );
  }

  /// Same path rules as [TeamModel.logoId] / [TeamModel.logoPath] (asset, URL, or empty).
  static Widget logoImage(String path, {double size = 24}) {
    return buildTeamLogo(path, size: size);
  }
}
