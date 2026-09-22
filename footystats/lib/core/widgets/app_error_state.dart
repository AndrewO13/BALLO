import 'package:flutter/material.dart';

import '../constants/app_assets.dart';
import 'app_empty_state.dart';

/// Full-screen style 404 / not-found state.
class AppNotFoundState extends StatelessWidget {
  const AppNotFoundState({
    super.key,
    this.title = 'Page not found',
    this.subtitle =
        'This page may have been removed, or the link might be incorrect.',
    this.actionLabel = 'Go back',
    this.onAction,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      imageAsset: AppAssets.notFound404,
      title: title,
      subtitle: subtitle,
      actionLabel: actionLabel,
      onAction: onAction ?? () {
        if (Navigator.canPop(context)) {
          Navigator.of(context).pop();
        }
      },
    );
  }
}

/// Network / connectivity failure with retry.
class AppConnectionErrorState extends StatelessWidget {
  const AppConnectionErrorState({
    super.key,
    this.title = 'No connection',
    this.subtitle = 'Check your internet connection and try again.',
    this.actionLabel = 'Try again',
    this.onRetry,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return AppEmptyState(
      imageAsset: AppAssets.connectionError,
      title: title,
      subtitle: subtitle,
      actionLabel: onRetry != null ? actionLabel : null,
      onAction: onRetry,
    );
  }
}
