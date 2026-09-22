import 'package:flutter/material.dart';

import '../../core/utils/account_deletion_errors.dart';
import '../../data/repositories/account_repository.dart';
import '../pages/welcome_page.dart';

/// Confirmation flow for permanent account deletion.
Future<void> showDeleteAccountDialog(BuildContext context) async {
  final pageContext = context;
  final colorScheme = Theme.of(pageContext).colorScheme;
  final textTheme = Theme.of(pageContext).textTheme;

  final confirmed = await showDialog<bool>(
    context: pageContext,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Delete account?'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(accountDeletionSummary, style: textTheme.bodyMedium),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(
            'Delete account',
            style: TextStyle(color: colorScheme.error),
          ),
        ),
      ],
    ),
  );

  if (confirmed != true || !pageContext.mounted) return;

  final typed = await showDialog<String>(
    context: pageContext,
    barrierDismissible: false,
    builder: (dialogContext) => _DeleteConfirmationDialog(),
  );

  if (typed != 'DELETE' || !pageContext.mounted) return;

  final messenger = ScaffoldMessenger.of(pageContext);
  showDialog(
    context: pageContext,
    barrierDismissible: false,
    builder: (_) => const Center(child: CircularProgressIndicator()),
  );

  try {
    await AccountRepository().deleteOwnAccount();
    if (!pageContext.mounted) return;
    Navigator.of(pageContext).pop(); // loading
    Navigator.of(pageContext).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WelcomePage()),
      (route) => false,
    );
    messenger.showSnackBar(
      const SnackBar(content: Text('Your account has been deleted')),
    );
  } catch (error) {
    if (!pageContext.mounted) return;
    Navigator.of(pageContext).pop(); // loading
    messenger.showSnackBar(
      SnackBar(
        content: Text(friendlyDeleteAccountError(error)),
        duration: const Duration(seconds: 6),
      ),
    );
  }
}

class _DeleteConfirmationDialog extends StatefulWidget {
  @override
  State<_DeleteConfirmationDialog> createState() =>
      _DeleteConfirmationDialogState();
}

class _DeleteConfirmationDialogState extends State<_DeleteConfirmationDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final canDelete = _controller.text == 'DELETE';

    return AlertDialog(
      title: const Text('Confirm deletion'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Type DELETE to confirm this cannot be undone.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autocorrect: false,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              hintText: 'DELETE',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed:
              canDelete ? () => Navigator.of(context).pop('DELETE') : null,
          child: Text(
            'Delete forever',
            style: TextStyle(color: colorScheme.error),
          ),
        ),
      ],
    );
  }
}
