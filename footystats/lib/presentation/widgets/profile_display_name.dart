import 'package:flutter/material.dart';

import 'switch_account_sheet.dart';

/// Profile display name, with a dropdown to switch device accounts.
class ProfileDisplayName extends StatelessWidget {
  const ProfileDisplayName({
    super.key,
    required this.name,
    required this.username,
    this.canSwitchAccount = false,
    this.nameColor,
    this.usernameColor,
    this.iconColor,
  });

  final String name;
  final String username;
  final bool canSwitchAccount;
  final Color? nameColor;
  final Color? usernameColor;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                name,
                style: textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: nameColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (canSwitchAccount)
              IconButton(
                tooltip: 'Switch account',
                onPressed: () => showSwitchAccountSheet(context),
                icon: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 28,
                  color: iconColor,
                ),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
          ],
        ),
        Text(
          username,
          style: textTheme.bodySmall?.copyWith(
            color: usernameColor ?? colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
